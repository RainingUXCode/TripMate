from django.conf import settings
from django.db import models


class Notification(models.Model):
    class EventType(models.TextChoices):
        FRIEND_REQUEST = 'friend_request', 'Solicitação de amizade'
        TRIP_INVITATION = 'trip_invitation', 'Convite de viagem'
        SETTLEMENT_PENDING = 'settlement_pending', 'Acerto aguardando confirmação'
        SETTLEMENT_CONFIRMED = 'settlement_confirmed', 'Acerto confirmado'
        ORGANIZER_TRANSFERRED = 'organizer_transferred', 'Organização transferida'

    class ResourceType(models.TextChoices):
        FRIENDSHIP = 'friendship', 'Amizade'
        TRIP = 'trip', 'Viagem'
        SETTLEMENT = 'settlement', 'Acerto'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications',
    )
    event_type = models.CharField(max_length=32, choices=EventType.choices)
    title = models.CharField(max_length=120)
    message = models.CharField(max_length=240)
    resource_type = models.CharField(
        max_length=20, choices=ResourceType.choices, blank=True
    )
    resource_id = models.PositiveBigIntegerField(null=True, blank=True)
    context_id = models.PositiveBigIntegerField(null=True, blank=True)
    event_key = models.CharField(max_length=180, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at', '-id']
        indexes = [
            models.Index(fields=['user', 'read_at', '-created_at'], name='notif_user_read_created'),
        ]

    def __str__(self):
        return f'{self.user_id}: {self.title}'
