
from rest_framework import serializers

from .models import Friendship


# ==========================================
# DADOS PÚBLICOS DOS USUÁRIOS
# ==========================================

class PublicUserSerializer(serializers.Serializer):
    id = serializers.IntegerField(read_only=True)
    name = serializers.CharField(
        source="first_name",
        read_only=True,
    )
    avatar_url = serializers.SerializerMethodField()

    def get_avatar_url(self, user):
        profile = getattr(
            user,
            "tripmate_profile",
            None,
        )

        if profile is None or not profile.avatar:
            return None

        request = self.context.get("request")

        if request is not None:
            return request.build_absolute_uri(
                profile.avatar.url
            )

        return profile.avatar.url


# ==========================================
# SOLICITAÇÕES DE AMIZADE
# ==========================================

class FriendshipSerializer(serializers.ModelSerializer):
    sender = PublicUserSerializer(read_only=True)
    receiver = PublicUserSerializer(read_only=True)

    class Meta:
        model = Friendship

        fields = [
            "id",
            "sender",
            "receiver",
            "status",
            "created_at",
            "updated_at",
        ]

        read_only_fields = fields
