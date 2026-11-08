
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from PIL import Image
from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError


class RegisterSerializer(serializers.ModelSerializer):
    name = serializers.CharField(
        write_only=True,
        max_length=150,
    )

    email = serializers.EmailField(required=True)

    password = serializers.CharField(
        write_only=True,
        min_length=8,
    )

    class Meta:
        model = User
        fields = [
            "id",
            "name",
            "email",
            "password",
        ]
        read_only_fields = ["id"]

    def validate_email(self, value):
        email = value.strip().lower()

        if User.objects.filter(
            email__iexact=email
        ).exists():
            raise serializers.ValidationError(
                "Este e-mail já está cadastrado."
            )

        return email

    def create(self, validated_data):
        name = validated_data.pop("name").strip()
        email = validated_data["email"]
        password = validated_data.pop("password")

        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            first_name=name,
        )

        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()

    password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )

    def validate(self, attrs):
        email = attrs["email"].strip().lower()
        password = attrs["password"]

        user = authenticate(
            request=self.context.get("request"),
            username=email,
            password=password,
        )

        if user is None or not user.is_active:
            raise serializers.ValidationError(
                "E-mail ou senha inválidos."
            )

        attrs["user"] = user
        return attrs


class UserProfileSerializer(serializers.ModelSerializer):
    name = serializers.CharField(
        source="first_name",
        read_only=True,
    )

    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "name",
            "email",
            "avatar_url",
        ]
        read_only_fields = fields

    def get_avatar_url(self, user):
        profile = getattr(
            user,
            "tripmate_profile",
            None,
        )

        if profile is None or not profile.avatar:
            return None

        request = self.context.get("request")

        avatar_url = profile.avatar.url

        if request is not None:
            return request.build_absolute_uri(
                avatar_url
            )

        return avatar_url


class AvatarUploadSerializer(serializers.Serializer):
    avatar = serializers.ImageField(
        required=True,
        allow_empty_file=False,
    )

    def validate_avatar(self, image_file):
        max_size = 2 * 1024 * 1024

        if image_file.size > max_size:
            raise serializers.ValidationError(
                "A imagem deve ter no máximo 2 MB."
            )

        try:
            image_file.seek(0)

            with Image.open(image_file) as image:
                image_format = image.format
                width, height = image.size

            image_file.seek(0)

        except (OSError, ValueError):
            raise serializers.ValidationError(
                "O arquivo enviado não é uma imagem válida."
            )

        allowed_formats = {
            "JPEG": ".jpg",
            "PNG": ".png",
            "WEBP": ".webp",
        }

        if image_format not in allowed_formats:
            raise serializers.ValidationError(
                "Envie uma imagem JPG, PNG ou WebP."
            )

        if width > 4096 or height > 4096:
            raise serializers.ValidationError(
                "A imagem deve ter no máximo "
                "4096 pixels em cada dimensão."
            )

        # Usa uma extensão coerente com o formato
        # real da imagem, não com o nome original.
        original_name = image_file.name

        image_file.name = (
            f"avatar{allowed_formats[image_format]}"
        )

        return image_file

# ==========================================
# EDIÇÃO DE DADOS CADASTRAIS
# ==========================================

class AccountUpdateSerializer(serializers.Serializer):
    name = serializers.CharField(
        required=False,
        max_length=150,
        allow_blank=False,
        trim_whitespace=True,
    )

    email = serializers.EmailField(
        required=False,
    )

    current_password = serializers.CharField(
        required=False,
        write_only=True,
        trim_whitespace=False,
    )

    def validate_name(self, value):
        name = value.strip()

        if not name:
            raise serializers.ValidationError(
                "O nome não pode ficar vazio."
            )

        return name

    def validate_email(self, value):
        email = value.strip().lower()

        # O username interno também recebe o e-mail,
        # portanto precisamos respeitar seu limite.
        if len(email) > 150:
            raise serializers.ValidationError(
                "O e-mail deve ter no máximo 150 caracteres."
            )

        user = self.context["request"].user

        if User.objects.filter(
            email__iexact=email
        ).exclude(pk=user.pk).exists():
            raise serializers.ValidationError(
                "Este e-mail já está cadastrado."
            )

        if User.objects.filter(
            username__iexact=email
        ).exclude(pk=user.pk).exists():
            raise serializers.ValidationError(
                "Este e-mail já está cadastrado."
            )

        return email

    def validate(self, attrs):
        user = self.context["request"].user

        if not any(
            field in attrs
            for field in ("name", "email")
        ):
            raise serializers.ValidationError(
                "Informe o nome ou o e-mail para atualizar."
            )

        new_email = attrs.get("email", user.email)

        if new_email != user.email:
            current_password = attrs.get(
                "current_password"
            )

            if not current_password:
                raise serializers.ValidationError({
                    "current_password":
                        "Informe sua senha atual para alterar o e-mail."
                })

            if not user.check_password(
                current_password
            ):
                raise serializers.ValidationError({
                    "current_password":
                        "Senha atual incorreta."
                })

        return attrs

    def update(self, instance, validated_data):
        if "name" in validated_data:
            instance.first_name = validated_data["name"]

        if "email" in validated_data:
            email = validated_data["email"]

            instance.email = email

            # Nosso login atual utiliza username=email.
            instance.username = email

        instance.save()

        return instance


# ==========================================
# ALTERAÇÃO DE SENHA
# ==========================================

class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )

    new_password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
        min_length=8,
    )

    confirm_password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )

    def validate(self, attrs):
        user = self.context["request"].user

        current_password = attrs["current_password"]
        new_password = attrs["new_password"]
        confirm_password = attrs["confirm_password"]

        if not user.check_password(current_password):
            raise serializers.ValidationError({
                "current_password":
                    "Senha atual incorreta."
            })

        if new_password != confirm_password:
            raise serializers.ValidationError({
                "confirm_password":
                    "As senhas não coincidem."
            })

        if current_password == new_password:
            raise serializers.ValidationError({
                "new_password":
                    "A nova senha deve ser diferente da atual."
            })

        try:
            validate_password(
                new_password,
                user=user,
            )
        except DjangoValidationError as error:
            raise serializers.ValidationError({
                "new_password": error.messages
            })

        return attrs

    def save(self):
        user = self.context["request"].user

        user.set_password(
            self.validated_data["new_password"]
        )

        user.save(
            update_fields=["password"]
        )

        return user
