
from django.db import IntegrityError, transaction

from rest_framework import generics, status
from rest_framework.parsers import (
    FormParser,
    MultiPartParser,
)
from rest_framework.permissions import (
    AllowAny,
    IsAuthenticated,
)
from rest_framework.response import Response
from rest_framework.views import APIView

from rest_framework_simplejwt.tokens import RefreshToken

from .models import UserProfile
from .serializers import (
    RegisterSerializer,
    LoginSerializer,
    UserProfileSerializer,
    AvatarUploadSerializer,
    AccountUpdateSerializer,
    ChangePasswordSerializer,
)


# ==========================================
# CADASTRO
# ==========================================

class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]


# ==========================================
# LOGIN
# ==========================================

class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(
            data=request.data,
            context={"request": request},
        )

        serializer.is_valid(raise_exception=True)

        user = serializer.validated_data["user"]
        refresh = RefreshToken.for_user(user)

        user_data = UserProfileSerializer(
            user,
            context={"request": request},
        ).data

        return Response(
            {
                "message": "Login realizado com sucesso!",
                "user": user_data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
            status=status.HTTP_200_OK,
        )


# ==========================================
# CONSULTAR E ATUALIZAR DADOS CADASTRAIS
# GET /api/auth/me/
# PATCH /api/auth/me/
# ==========================================

class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserProfileSerializer(
            request.user,
            context={"request": request},
        )

        return Response(
            serializer.data,
            status=status.HTTP_200_OK,
        )

    def patch(self, request):
        serializer = AccountUpdateSerializer(
            request.user,
            data=request.data,
            partial=True,
            context={"request": request},
        )

        serializer.is_valid(raise_exception=True)

        try:
            with transaction.atomic():
                user = serializer.save()
        except IntegrityError:
            return Response(
                {
                    "email": [
                        "Este e-mail já está cadastrado."
                    ]
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        user_data = UserProfileSerializer(
            user,
            context={"request": request},
        ).data

        return Response(
            {
                "message": (
                    "Dados cadastrais atualizados "
                    "com sucesso!"
                ),
                "user": user_data,
            },
            status=status.HTTP_200_OK,
        )


# ==========================================
# ALTERAR SENHA
# POST /api/auth/me/password/
# ==========================================

class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(
            data=request.data,
            context={"request": request},
        )

        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(
            {
                "message": (
                    "Senha alterada com sucesso!"
                )
            },
            status=status.HTTP_200_OK,
        )


# ==========================================
# FOTO DE PERFIL
# PATCH /api/auth/me/avatar/
# DELETE /api/auth/me/avatar/
# ==========================================

class AvatarView(APIView):
    permission_classes = [IsAuthenticated]

    parser_classes = [
        MultiPartParser,
        FormParser,
    ]

    def patch(self, request):
        serializer = AvatarUploadSerializer(
            data=request.data,
        )

        serializer.is_valid(raise_exception=True)

        new_avatar = serializer.validated_data[
            "avatar"
        ]

        profile, created = (
            UserProfile.objects.get_or_create(
                user=request.user
            )
        )

        old_avatar_name = (
            profile.avatar.name
            if profile.avatar
            else None
        )

        profile.avatar.save(
            new_avatar.name,
            new_avatar,
            save=True,
        )

        if (
            old_avatar_name
            and old_avatar_name != profile.avatar.name
        ):
            profile.avatar.storage.delete(
                old_avatar_name
            )

        user_data = UserProfileSerializer(
            request.user,
            context={"request": request},
        ).data

        return Response(
            {
                "message": (
                    "Foto de perfil atualizada "
                    "com sucesso!"
                ),
                "user": user_data,
            },
            status=status.HTTP_200_OK,
        )

    def delete(self, request):
        profile = UserProfile.objects.filter(
            user=request.user
        ).first()

        if profile is not None and profile.avatar:
            old_avatar_name = profile.avatar.name

            profile.avatar = None
            profile.save(
                update_fields=["avatar"]
            )

            profile.avatar.storage.delete(
                old_avatar_name
            )

        user_data = UserProfileSerializer(
            request.user,
            context={"request": request},
        ).data

        return Response(
            {
                "message": (
                    "Foto de perfil removida "
                    "com sucesso!"
                ),
                "user": user_data,
            },
            status=status.HTTP_200_OK,
        )
