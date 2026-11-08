
from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import Q, F
from django.db.models.functions import Least, Greatest


class Friendship(models.Model):

    class Status(models.TextChoices):
        PENDING = "pending", "Pendente"
        ACCEPTED = "accepted", "Aceita"
        REJECTED = "rejected", "Recusada"

    # Usuário que enviou a solicitação.
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="sent_friend_requests",
    )

    # Usuário que recebeu a solicitação.
    receiver = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="received_friend_requests",
    )

    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.PENDING,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = ["-created_at"]

        constraints = [
            # Impede uma pessoa de ser amiga
            # de si própria.
            models.CheckConstraint(
                condition=~Q(sender=F("receiver")),
                name="friendship_no_self",
            ),

            # Impede duas solicitações com
            # os mesmos usuários e direção.
            models.UniqueConstraint(
                fields=["sender", "receiver"],
                name="friendship_unique_direction",
            ),

            # Garante que exista apenas uma relação
            # entre o mesmo par de usuários,
            # independentemente de quem enviou.
            models.UniqueConstraint(
                Least("sender_id", "receiver_id"),
                Greatest("sender_id", "receiver_id"),
                name="friendship_unique_pair",
            ),
        ]

    def clean(self):
        super().clean()

        if (
            self.sender_id is not None
            and self.receiver_id is not None
            and self.sender_id == self.receiver_id
        ):
            raise ValidationError(
                "Você não pode adicionar a si próprio."
            )

        if (
            self.sender_id is not None
            and self.receiver_id is not None
        ):
            reverse_request = Friendship.objects.filter(
                sender_id=self.receiver_id,
                receiver_id=self.sender_id,
            )

            if self.pk:
                reverse_request = reverse_request.exclude(
                    pk=self.pk
                )

            if reverse_request.exists():
                raise ValidationError(
                    "Já existe uma solicitação entre esses usuários."
                )

    def __str__(self):
        return (
            f"{self.sender_id} → {self.receiver_id} "
            f"({self.get_status_display()})"
        )
