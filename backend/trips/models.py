import uuid
from pathlib import Path

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import F, Q
from django.core.validators import MinValueValidator
from decimal import Decimal


def trip_cover_upload_path(instance, filename):
    """Store covers with opaque names, independent of user supplied paths."""
    extension = Path(filename).suffix.lower()
    return f"trip_covers/{uuid.uuid4().hex}{extension}"


class Trip(models.Model):
    """A group trip with an accepted membership for its creator.

    The future trip-creation service must create the trip and its creator's
    accepted TripMember in the same transaction.atomic block. Keeping this in
    the service makes the invariant explicit without a hidden model signal.
    Access to private trips must be limited to accepted memberships.
    """

    name = models.CharField(max_length=150)
    destination = models.CharField(max_length=200)
    start_date = models.DateField()
    end_date = models.DateField()
    description = models.TextField(blank=True)
    budget_amount = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(Decimal('0'))])
    finance_version = models.PositiveIntegerField(default=0, editable=False)
    cover_image = models.ImageField(
        upload_to=trip_cover_upload_path,
        blank=True,
        null=True,
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="created_trips",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        constraints = [
            models.CheckConstraint(condition=Q(budget_amount__isnull=True) | Q(budget_amount__gte=0), name='trip_budget_nonnegative'),
            # Model.save() does not call clean(); enforce the date rule in DB too.
            models.CheckConstraint(
                condition=Q(end_date__gte=F("start_date")),
                name="trip_end_date_gte_start_date",
            ),
        ]

    def clean(self):
        super().clean()
        if (
            self.start_date is not None
            and self.end_date is not None
            and self.end_date < self.start_date
        ):
            raise ValidationError(
                {"end_date": "A data de término não pode anteceder a data de início."}
            )

    def __str__(self):
        return f"{self.name} — {self.destination}"


class TripMember(models.Model):
    """A user's invitation or accepted participation in one trip.

    Pending and rejected rows do not grant access. Only accepted rows count as
    participation; only authorized services should create invitations.
    """

    class Status(models.TextChoices):
        PENDING = "pending", "Pendente"
        ACCEPTED = "accepted", "Aceita"
        REJECTED = "rejected", "Recusada"
        LEFT = "left", "Saiu"

    trip = models.ForeignKey(
        Trip,
        on_delete=models.CASCADE,
        related_name="memberships",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="trip_memberships",
    )
    status = models.CharField(
        max_length=10,
        choices=Status.choices,
        default=Status.PENDING,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["trip", "user"],
                name="trip_member_unique_user",
            ),
        ]

    def __str__(self):
        return f"{self.user_id} — {self.trip_id} ({self.get_status_display()})"


class TripOrganizerTransfer(models.Model):
    """Append-only audit record for each organizer handoff."""

    trip = models.ForeignKey(
        Trip,
        on_delete=models.PROTECT,
        related_name="organizer_transfers",
    )
    previous_organizer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="outgoing_trip_organizer_transfers",
    )
    new_organizer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="incoming_trip_organizer_transfers",
    )
    transferred_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="performed_trip_organizer_transfers",
    )
    transferred_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return f"{self.trip_id}: {self.previous_organizer_id} → {self.new_organizer_id}"


from .financial_models import Expense, ExpenseShare, Settlement, FinancialEvent  # noqa: E402,F401
