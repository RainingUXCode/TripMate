from django.conf import settings
from django.db import models
from django.db.models import Q, F


class Expense(models.Model):
    class Mode(models.TextChoices):
        EQUAL = 'equal', 'Igualitária'
        EXACT = 'exact', 'Valores exatos'
        PERCENT = 'percent', 'Percentuais'
        UNITS = 'units', 'Cotas'

    trip = models.ForeignKey('trips.Trip', on_delete=models.PROTECT, related_name='expenses')
    description = models.CharField(max_length=250)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    expense_date = models.DateField()
    paid_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='paid_trip_expenses')
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='created_trip_expenses')
    updated_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='updated_trip_expenses')
    mode = models.CharField(max_length=10, choices=Mode.choices)
    cancelled = models.BooleanField(default=False)
    version = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-expense_date', '-id']
        constraints = [models.CheckConstraint(condition=Q(amount__gt=0), name='expense_positive'), models.CheckConstraint(condition=Q(mode__in=['equal', 'exact', 'percent', 'units']), name='expense_valid_mode')]


class ExpenseShare(models.Model):
    expense = models.ForeignKey(Expense, on_delete=models.PROTECT, related_name='shares')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='expense_shares')
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    input_value = models.DecimalField(max_digits=18, decimal_places=4, null=True, blank=True)

    class Meta:
        ordering = ['user_id']
        constraints = [models.UniqueConstraint(fields=['expense', 'user'], name='expense_unique_share'), models.CheckConstraint(condition=Q(amount__gte=0), name='share_nonnegative'), models.CheckConstraint(condition=Q(input_value__isnull=True) | Q(input_value__gte=0), name='share_input_nonnegative')]


class Settlement(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pendente'
        CONFIRMED = 'confirmed', 'Confirmado'
        CANCELLED = 'cancelled', 'Cancelado'

    trip = models.ForeignKey('trips.Trip', on_delete=models.PROTECT, related_name='settlements')
    debtor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='sent_trip_settlements')
    creditor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='received_trip_settlements')
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    request_key = models.UUIDField()
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='created_settlements')
    confirmed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='confirmed_settlements', null=True, blank=True)
    cancelled_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='cancelled_settlements', null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-id']
        constraints = [models.CheckConstraint(condition=Q(amount__gt=0), name='settlement_positive'), models.CheckConstraint(condition=~Q(debtor=F('creditor')), name='settlement_different_users'), models.UniqueConstraint(fields=['trip', 'request_key'], name='settlement_unique_request'), models.CheckConstraint(condition=Q(status='pending', confirmed_by__isnull=True, confirmed_at__isnull=True, cancelled_by__isnull=True, cancelled_at__isnull=True) | Q(status='confirmed', confirmed_by__isnull=False, confirmed_at__isnull=False, cancelled_by__isnull=True, cancelled_at__isnull=True) | Q(status='cancelled', cancelled_by__isnull=False, cancelled_at__isnull=False, confirmed_by__isnull=True, confirmed_at__isnull=True), name='settlement_transition_consistent')]


class FinancialEvent(models.Model):
    trip = models.ForeignKey('trips.Trip', on_delete=models.PROTECT, related_name='financial_events')
    expense = models.ForeignKey(Expense, on_delete=models.PROTECT, related_name='events', null=True, blank=True)
    settlement = models.ForeignKey(Settlement, on_delete=models.PROTECT, related_name='events', null=True, blank=True)
    actor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='financial_events')
    action = models.CharField(max_length=40)
    snapshot = models.JSONField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['id']
