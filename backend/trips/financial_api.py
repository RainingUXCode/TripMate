from django.db import OperationalError, IntegrityError, transaction
from django.shortcuts import get_object_or_404
from rest_framework import serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError, NotFound
from rest_framework.permissions import IsAuthenticated

from .models import Trip, Expense, Settlement
from . import finance


class StrictInput(serializers.Serializer):
    def to_internal_value(self, data):
        unknown = set(data) - set(self.fields)
        if unknown:
            raise ValidationError({key: 'Campo não permitido.' for key in unknown})
        return super().to_internal_value(data)


class DecimalInput(serializers.DecimalField):
    def to_internal_value(self, data):
        if isinstance(data, (float, bool)):
            raise ValidationError('Envie valores decimais como strings.')
        return super().to_internal_value(data)


class ShareInput(StrictInput):
    user_id = serializers.IntegerField(min_value=1)
    value = DecimalInput(max_digits=18, decimal_places=4, required=False, min_value=0)


class ExpenseInput(StrictInput):
    description = serializers.CharField(max_length=250)
    amount = DecimalInput(max_digits=14, decimal_places=2, min_value=0)
    expense_date = serializers.DateField()
    paid_by = serializers.IntegerField(min_value=1)
    mode = serializers.ChoiceField(choices=Expense.Mode.choices)
    shares = ShareInput(many=True, allow_empty=False)
    version = serializers.IntegerField(min_value=1, required=False)


class VersionInput(StrictInput):
    version = serializers.IntegerField(min_value=1)


class BudgetInput(StrictInput):
    budget_amount = DecimalInput(max_digits=14, decimal_places=2, min_value=0, allow_null=True)


class SettlementInput(StrictInput):
    debtor_id = serializers.IntegerField(min_value=1)
    creditor_id = serializers.IntegerField(min_value=1)
    amount = DecimalInput(max_digits=14, decimal_places=2, min_value=0)
    request_key = serializers.UUIDField()


def validate(cls, data):
    serializer = cls(data=data)
    serializer.is_valid(raise_exception=True)
    return serializer.validated_data


class FinancialView(APIView):
    permission_classes = [IsAuthenticated]

    def handle_exception(self, exc):
        if isinstance(exc, (OperationalError, IntegrityError)):
            exc = finance.Conflict('Conflito de gravação. Atualize antes de tentar novamente; não repita pagamentos automaticamente.')
        return super().handle_exception(exc)

    @transaction.atomic
    def get(self, request, pk, resource, item_id=None, action=None):
        trip = get_object_or_404(Trip.objects.select_for_update(), pk=pk)
        finance.accepted(trip, request.user.pk)
        if resource == 'budget':
            return Response({'budget_amount': finance.money(trip.budget_amount) if trip.budget_amount is not None else None})
        if resource == 'summary':
            return Response(finance.summary(trip))
        if resource == 'proposals':
            return Response(finance.proposals(trip))
        if resource == 'expenses':
            if item_id:
                return Response(finance.expense_data(get_object_or_404(Expense, trip=trip, pk=item_id)))
            return Response([finance.expense_data(expense) for expense in trip.expenses.prefetch_related('shares')])
        if resource == 'settlements':
            if item_id:
                return Response(finance.settlement_data(get_object_or_404(Settlement, trip=trip, pk=item_id)))
            return Response([finance.settlement_data(item) for item in trip.settlements.all()])
        if resource == 'history':
            return Response([{'id': event.pk, 'action': event.action, 'actor_id': event.actor_id, 'created_at': event.created_at.isoformat(), 'snapshot': event.snapshot} for event in trip.financial_events.all()])
        raise NotFound()

    def post(self, request, pk, resource, item_id=None, action=None):
        if resource == 'expenses' and item_id is None:
            expense = finance.write_expense(pk, request.user, validate(ExpenseInput, request.data))
            return Response(finance.expense_data(expense), status=201)
        if resource == 'settlements':
            if item_id is None:
                item = finance.create_settlement(pk, request.user, validate(SettlementInput, request.data))
                return Response(finance.settlement_data(item), status=201)
            validate(StrictInput, request.data)
            return Response(finance.settlement_data(finance.transition_settlement(pk, request.user, item_id, action)))
        raise NotFound()

    def put(self, request, pk, resource, item_id=None, action=None):
        if resource == 'budget' and item_id is None:
            trip = finance.set_budget(pk, request.user, validate(BudgetInput, request.data)['budget_amount'])
            return Response({'budget_amount': finance.money(trip.budget_amount) if trip.budget_amount is not None else None})
        if resource == 'expenses' and item_id is not None:
            data = validate(ExpenseInput, request.data)
            if 'version' not in data:
                raise ValidationError({'version': 'Informe a versão da despesa.'})
            return Response(finance.expense_data(finance.write_expense(pk, request.user, data, item_id)))
        raise NotFound()

    def delete(self, request, pk, resource, item_id=None, action=None):
        if resource != 'expenses' or item_id is None:
            raise NotFound()
        data = validate(VersionInput, request.data)
        return Response(finance.expense_data(finance.write_expense(pk, request.user, data, item_id, cancel=True)))
