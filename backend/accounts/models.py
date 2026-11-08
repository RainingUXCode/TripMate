
import uuid
from pathlib import Path

from django.conf import settings
from django.db import models


def avatar_upload_path(instance, filename):
    extension = Path(filename).suffix.lower()
    unique_name = f"{uuid.uuid4().hex}{extension}"

    return f"avatars/user_{instance.user_id}/{unique_name}"


class UserProfile(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="tripmate_profile",
    )

    avatar = models.ImageField(
        upload_to=avatar_upload_path,
        blank=True,
        null=True,
    )

    def __str__(self):
        return f"Perfil de {self.user.email}"
