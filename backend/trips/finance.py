"""All financial writes lock the trip before reading balances (including SQLite)."""
from decimal import Decimal, InvalidOperation

from django.db import transaction
from django.db.models import F, Q
from django.utils import timezone
from rest_framework.exceptions import ValidationError, PermissionDenied, NotFound, APIException

from .models import (
    Trip,
    TripMember,
    TripOrganizerTransfer,
    Expense,
    ExpenseShare,
    Settlement,
    FinancialEvent,
)
from notifications.services import create_notification


class Conflict(APIException):
    status_code = 409
    default_detail = 'Operação em conflito. Atualize os dados e tente novamente.'


def number(value, places=2, positive=False):
    try:
        if isinstance(value, (float, bool)):
            raise ValueError()
        result = Decimal(str(value))
        if not result.is_finite() or result < 0 or (positive and result == 0):
            raise ValueError()
        if result != result.quantize(Decimal(1).scaleb(-places)) or result >= Decimal('1000000000000'):
            raise ValueError()
        return result
    except (InvalidOperation, ValueError, TypeError):
        raise ValidationError('Valor decimal inválido. Envie como string, com a precisão permitida.')


def money(value):
    return format(value, '.2f')


def accepted(trip, user_id):
    if not TripMember.objects.filter(trip=trip, user_id=user_id, status='accepted').exists():
        raise PermissionDenied('É necessário participar da viagem com status aceito.')


def lock_trip(trip_id, actor):
    # First statement is a write: SQLite serializes writers instead of relying on
    # its no-op select_for_update. A busy database fails safely; never auto-retry POST.
    if not Trip.objects.filter(pk=trip_id).update(finance_version=F('finance_version') + 1):
        raise NotFound('Viagem indisponível.')
    trip = Trip.objects.select_for_update().get(pk=trip_id)
    accepted(trip, actor.pk)
    return trip


def split_amount(amount, mode, entries):
    amount = number(amount, positive=True)
    if not entries or not isinstance(entries, list):
        raise ValidationError('Selecione pelo menos um participante.')
    ids = [entry['user_id'] for entry in entries]
    if len(ids) != len(set(ids)):
        raise ValidationError('Participantes duplicados.')
    entries = sorted(entries, key=lambda entry: entry['user_id'])
    if mode == 'equal':
        weights = [Decimal(1)] * len(entries)
        inputs = [None] * len(entries)
    elif mode in ('exact', 'percent', 'units'):
        inputs = [number(entry.get('value'), places=4 if mode == 'percent' else 2) for entry in entries]
        if mode == 'exact':
            if sum(inputs) != amount:
                raise ValidationError('As parcelas devem somar exatamente o total.')
            return [(entry['user_id'], value, value) for entry, value in zip(entries, inputs)]
        if mode == 'percent' and sum(inputs) != 100:
            raise ValidationError('Os percentuais devem somar exatamente 100%.')
        if mode == 'units' and any(value <= 0 or value != value.to_integral_value() for value in inputs):
            raise ValidationError('Cotas devem ser inteiras e positivas.')
        weights = inputs
    else:
        raise ValidationError('Modalidade inválida.')
    weights = [int(weight * 10000) for weight in weights]
    total = sum(weights)
    cents = int(amount * 100)
    quotients = [divmod(cents * weight, total) for weight in weights]
    allocated = [value[0] for value in quotients]
    remaining = cents - sum(allocated)
    priority = sorted(range(len(entries)), key=lambda i: (-quotients[i][1], entries[i]['user_id']))
    for index in priority[:remaining]:
        allocated[index] += 1
    return [(entry['user_id'], Decimal(value) / 100, original) for entry, value, original in zip(entries, allocated, inputs)]


def expense_data(expense):
    return {
        'id': expense.pk, 'trip_id': expense.trip_id, 'description': expense.description,
        'amount': money(expense.amount), 'expense_date': str(expense.expense_date),
        'paid_by': expense.paid_by_id, 'created_by': expense.created_by_id,
        'updated_by': expense.updated_by_id, 'mode': expense.mode,
        'cancelled': expense.cancelled, 'version': expense.version,
        'created_at': expense.created_at.isoformat(), 'updated_at': expense.updated_at.isoformat(),
        'shares': [{'user_id': s.user_id, 'amount': money(s.amount), 'value': str(s.input_value) if s.input_value is not None else None} for s in expense.shares.all()],
    }


def settlement_data(item):
    return {**{field: getattr(item, field) for field in ['id', 'trip_id', 'debtor_id', 'creditor_id', 'created_by_id', 'confirmed_by_id', 'cancelled_by_id', 'status']},
            'amount': money(item.amount), 'request_key': str(item.request_key),
            **{field: getattr(item, field).isoformat() if getattr(item, field) else None for field in ['created_at', 'confirmed_at', 'cancelled_at']}}


def event(trip, actor, action, snapshot, expense=None, settlement=None):
    FinancialEvent.objects.create(trip=trip, actor=actor, action=action, snapshot=snapshot, expense=expense, settlement=settlement)


@transaction.atomic
def write_expense(trip_id, actor, data, expense_id=None, cancel=False):
    trip = lock_trip(trip_id, actor)
    if trip.settlements.filter(status='pending').exists():
        raise Conflict('Confirme ou cancele os acertos pendentes antes de alterar despesas.')
    expense = None
    if expense_id is not None:
        try:
            expense = Expense.objects.get(pk=expense_id, trip=trip)
        except Expense.DoesNotExist:
            raise NotFound()
        if expense.created_by_id != actor.pk:
            raise PermissionDenied('Somente o autor original pode alterar a despesa.')
        if expense.cancelled or data.get('version') != expense.version:
            raise Conflict()
        if trip.settlements.exclude(status='cancelled').exists():
            raise Conflict('Há acertos pendentes ou confirmados. A despesa original fica preservada.')
        before = expense_data(expense)
        if cancel:
            expense.cancelled = True
        expense.version += 1
    else:
        before = None
    if not cancel:
        allocations = split_amount(data['amount'], data['mode'], data['shares'])
        for user_id in {data['paid_by'], *(item[0] for item in allocations)}:
            accepted(trip, user_id)
        if expense is None:
            expense = Expense(trip=trip, created_by=actor)
        for field in ['description', 'amount', 'expense_date', 'mode']:
            setattr(expense, field, data[field])
        expense.amount = number(data['amount'], positive=True)
        expense.paid_by_id = data['paid_by']
    expense.updated_by = actor
    expense.save()
    if not cancel:
        expense.shares.all().delete()
        ExpenseShare.objects.bulk_create([ExpenseShare(expense=expense, user_id=uid, amount=value, input_value=original) for uid, value, original in allocations])
    event(trip, actor, 'expense.cancelled' if cancel else 'expense.updated' if before else 'expense.created', {'before': before, 'after': expense_data(expense)}, expense=expense)
    return expense


def balances(trip):
    ids = set(trip.memberships.values_list('user_id', flat=True))
    ids.update(trip.expenses.values_list('paid_by_id', flat=True))
    ids.update(ExpenseShare.objects.filter(expense__trip=trip).values_list('user_id', flat=True))
    ids.update(trip.settlements.values_list('debtor_id', flat=True))
    ids.update(trip.settlements.values_list('creditor_id', flat=True))
    rows = {uid: {'user_id': uid, 'paid': Decimal(0), 'due': Decimal(0), 'sent': Decimal(0), 'received': Decimal(0)} for uid in ids}
    for expense in trip.expenses.filter(cancelled=False).prefetch_related('shares'):
        rows[expense.paid_by_id]['paid'] += expense.amount
        for share in expense.shares.all():
            rows[share.user_id]['due'] += share.amount
    for item in trip.settlements.filter(status='confirmed'):
        rows[item.debtor_id]['sent'] += item.amount
        rows[item.creditor_id]['received'] += item.amount
    for row in rows.values():
        row['gross_balance'] = row['paid'] - row['due']
        row['balance'] = row['gross_balance'] + row['sent'] - row['received']
    return rows


def available_balances(trip):
    values = {uid: row['balance'] for uid, row in balances(trip).items()}
    for item in trip.settlements.filter(status='pending'):
        values[item.debtor_id] += item.amount
        values[item.creditor_id] -= item.amount
    return values


def proposals(trip):
    values = available_balances(trip)
    debtors = [[uid, -value] for uid, value in sorted(values.items()) if value < 0]
    creditors = [[uid, value] for uid, value in sorted(values.items()) if value > 0]
    result = []
    for debtor in debtors:
        for creditor in creditors:
            amount = min(debtor[1], creditor[1])
            if amount:
                result.append({'debtor_id': debtor[0], 'creditor_id': creditor[0], 'amount': money(amount)})
                debtor[1] -= amount
                creditor[1] -= amount
    return result


def summary(trip):
    rows = balances(trip)
    spent = sum((row['paid'] for row in rows.values()), Decimal(0))
    budget = trip.budget_amount
    return {'budget_amount': money(budget) if budget is not None else None,
            'total_spent': money(spent), 'remaining_budget': money(budget - spent) if budget is not None else None,
            'consumed_percent': money(spent * 100 / budget) if budget else None,
            'expense_count': trip.expenses.filter(cancelled=False).count(),
            'participants': [{key: money(value) if isinstance(value, Decimal) else value for key, value in row.items()} for uid, row in sorted(rows.items())],
            'proposals': proposals(trip), 'finance_version': trip.finance_version}


@transaction.atomic
def set_budget(trip_id, actor, amount):
    trip = lock_trip(trip_id, actor)
    if trip.created_by_id != actor.pk:
        raise PermissionDenied('Somente o organizador pode alterar o orçamento.')
    before = money(trip.budget_amount) if trip.budget_amount is not None else None
    trip.budget_amount = None if amount is None else number(amount)
    trip.save(update_fields=['budget_amount', 'updated_at'])
    event(trip, actor, 'budget.updated', {'before': before, 'after': money(trip.budget_amount) if trip.budget_amount is not None else None})
    return trip


@transaction.atomic
def create_settlement(trip_id, actor, data):
    trip = lock_trip(trip_id, actor)
    debtor, creditor = data['debtor_id'], data['creditor_id']
    if debtor == creditor or actor.pk not in (debtor, creditor):
        raise PermissionDenied('Registre somente acertos entre você e outro participante.')
    accepted(trip, debtor)
    accepted(trip, creditor)
    if trip.settlements.filter(request_key=data['request_key']).exists():
        raise Conflict('Este pagamento já foi registrado.')
    amount = number(data['amount'], positive=True)
    available = available_balances(trip)
    if amount > -available[debtor] or amount > available[creditor]:
        raise ValidationError('Valor excede a obrigação disponível, incluindo acertos em confirmação.')
    item = Settlement.objects.create(trip=trip, debtor_id=debtor, creditor_id=creditor, amount=amount, request_key=data['request_key'], created_by=actor)
    event(trip, actor, 'settlement.pending', settlement_data(item), settlement=item)
    counterparty_id = creditor if actor.pk == debtor else debtor
    create_notification(
        user_id=counterparty_id,
        event_type='settlement_pending',
        title='Acerto aguardando confirmação',
        message=f'Um participante declarou um pagamento em {trip.name}.',
        resource_type='settlement',
        resource_id=item.pk,
        context_id=trip.pk,
        event_key=f'settlement-pending:{item.pk}',
    )
    return item


@transaction.atomic
def transition_settlement(trip_id, actor, settlement_id, action):
    trip = lock_trip(trip_id, actor)
    try:
        item = trip.settlements.get(pk=settlement_id)
    except Settlement.DoesNotExist:
        raise NotFound()
    if actor.pk not in (item.debtor_id, item.creditor_id):
        raise PermissionDenied()
    if item.status != 'pending':
        raise Conflict('Este acerto já foi respondido.')
    if action == 'confirm':
        accepted(trip, item.debtor_id)
        accepted(trip, item.creditor_id)
        if actor.pk == item.created_by_id:
            raise PermissionDenied('A outra pessoa deve confirmar o pagamento.')
        item.status = 'confirmed'
        item.confirmed_by = actor
        item.confirmed_at = timezone.now()
    elif action == 'cancel':
        item.status = 'cancelled'
        item.cancelled_by = actor
        item.cancelled_at = timezone.now()
    else:
        raise NotFound()
    item.save()
    event(trip, actor, 'settlement.' + item.status, settlement_data(item), settlement=item)
    if action == 'confirm':
        create_notification(
            user_id=item.created_by_id,
            event_type='settlement_confirmed',
            title='Acerto confirmado',
            message=f'O acerto registrado em {trip.name} foi confirmado.',
            resource_type='settlement',
            resource_id=item.pk,
            context_id=trip.pk,
            event_key=f'settlement-confirmed:{item.pk}',
        )
    return item


EXIT_REASON_MESSAGES = {
    'outstanding_debt': 'Você ainda possui valores a pagar nesta viagem.',
    'outstanding_credit': 'Você possui valores a receber antes de sair.',
    'pending_settlement': 'Existe um acerto aguardando confirmação.',
    'organizer_transfer_required': 'Transfira a organização para outro participante antes de sair.',
}


def exit_eligibility_locked(trip, user):
    """Return the actor's current exit blockers while the trip row is locked."""
    reasons = []
    if trip.created_by_id == user.pk:
        reasons.append('organizer_transfer_required')

    balance = balances(trip).get(user.pk, {}).get('balance', Decimal(0))
    if balance < 0:
        reasons.append('outstanding_debt')
    elif balance > 0:
        reasons.append('outstanding_credit')

    if trip.settlements.filter(status='pending').filter(
        Q(debtor_id=user.pk) | Q(creditor_id=user.pk)
    ).exists():
        reasons.append('pending_settlement')

    can_leave = not reasons
    return {
        'can_leave': can_leave,
        'eligible': can_leave,
        'reasons': reasons,
        'reason_messages': {reason: EXIT_REASON_MESSAGES[reason] for reason in reasons},
    }


def exit_eligibility(trip, user):
    # This is an advisory read; the actual leave operation repeats the check
    # under the trip write lock. Do not mutate finance_version during a GET.
    accepted(trip, user.pk)
    return exit_eligibility_locked(trip, user)


@transaction.atomic
def leave_trip(trip_id, actor):
    """Revalidate finances and mark the actor left without deleting history."""
    trip = lock_trip(trip_id, actor)
    eligibility = exit_eligibility_locked(trip, actor)
    if not eligibility['can_leave']:
        raise Conflict({
            'detail': 'Você ainda não pode sair desta viagem.',
            'reasons': eligibility['reasons'],
            'reason_messages': eligibility['reason_messages'],
        })

    membership = TripMember.objects.select_for_update().get(
        trip=trip,
        user=actor,
        status=TripMember.Status.ACCEPTED,
    )
    membership.status = TripMember.Status.LEFT
    membership.save(update_fields=['status', 'updated_at'])
    return {'trip_id': trip.pk, 'status': TripMember.Status.LEFT}


@transaction.atomic
def remove_trip_member(trip_id, actor, user_id):
    """Let the organizer remove an accepted member without erasing history."""
    trip = lock_trip(trip_id, actor)
    if trip.created_by_id != actor.pk:
        raise PermissionDenied('Somente o organizador pode remover participantes.')
    if user_id == trip.created_by_id:
        raise ValidationError('O organizador não pode remover a si mesmo.')

    membership = TripMember.objects.select_for_update().select_related('user').filter(
        trip=trip,
        user_id=user_id,
        status=TripMember.Status.ACCEPTED,
    ).first()
    if membership is None:
        raise NotFound('O participante aceito não foi encontrado nesta viagem.')

    eligibility = exit_eligibility_locked(trip, membership.user)
    if not eligibility['can_leave']:
        name = membership.user.get_full_name().strip() or 'Este participante'
        participant_messages = {
            'outstanding_debt': f'{name} ainda possui valores a pagar nesta viagem.',
            'outstanding_credit': f'{name} possui valores a receber antes de sair.',
            'pending_settlement': f'Existe um acerto aguardando confirmação para {name}.',
            'organizer_transfer_required': 'Transfira a organização antes de remover esse participante.',
        }
        raise Conflict({
            'detail': f'{name} ainda não pode ser removido desta viagem.',
            'reasons': eligibility['reasons'],
            'reason_messages': {
                reason: participant_messages[reason]
                for reason in eligibility['reasons']
            },
        })

    membership.status = TripMember.Status.LEFT
    membership.save(update_fields=['status', 'updated_at'])
    return {
        'trip_id': trip.pk,
        'user_id': membership.user_id,
        'status': TripMember.Status.LEFT,
    }


@transaction.atomic
def transfer_organizer(trip_id, actor, new_organizer_id):
    """Transfer organizer authority, keeping the prior organizer accepted."""
    trip = lock_trip(trip_id, actor)
    if trip.created_by_id != actor.pk:
        raise PermissionDenied('Somente o organizador atual pode transferir a organização.')
    if new_organizer_id == actor.pk:
        raise ValidationError({'new_organizer_id': 'Escolha outro participante aceito.'})

    successor = TripMember.objects.select_for_update().filter(
        trip=trip,
        user_id=new_organizer_id,
        status=TripMember.Status.ACCEPTED,
    ).first()
    if successor is None:
        raise ValidationError({
            'new_organizer_id': 'O sucessor precisa ser um participante aceito desta viagem.'
        })

    old_organizer_id = trip.created_by_id
    transfer = TripOrganizerTransfer.objects.create(
        trip=trip,
        previous_organizer_id=old_organizer_id,
        new_organizer_id=new_organizer_id,
        transferred_by=actor,
    )
    trip.created_by_id = new_organizer_id
    trip.save(update_fields=['created_by', 'updated_at'])
    create_notification(
        user_id=new_organizer_id,
        event_type='organizer_transferred',
        title='Você agora organiza a viagem',
        message=f'A organização de {trip.name} foi transferida para você.',
        resource_type='trip',
        resource_id=trip.pk,
        event_key=f'organizer-transfer:{transfer.pk}',
    )
    trip.refresh_from_db()
    return trip
