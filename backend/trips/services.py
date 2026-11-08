from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, ValidationError

from friends.models import Friendship
from notifications.services import create_notification

from . import finance
from .models import TripMember


def validate_trip_invitees(organizer, invitee_ids, trip=None):
    """Validate all invitees together so an invitation batch is all-or-none."""
    if len(invitee_ids) != len(set(invitee_ids)):
        raise ValidationError({"invitee_ids": "Há usuários repetidos na lista."})

    if organizer.pk in invitee_ids:
        raise ValidationError({"invitee_ids": "O organizador já participa da viagem."})

    confirmed_friend_ids = set(
        Friendship.objects.filter(
            status=Friendship.Status.ACCEPTED,
        )
        .filter(
            Q(sender=organizer, receiver_id__in=invitee_ids)
            | Q(receiver=organizer, sender_id__in=invitee_ids)
        )
        .values_list("sender_id", "receiver_id")
    )
    confirmed_friend_ids = {
        user_id
        for pair in confirmed_friend_ids
        for user_id in pair
        if user_id != organizer.pk
    }

    if confirmed_friend_ids != set(invitee_ids):
        raise ValidationError({
            "invitee_ids": "Somente amigos confirmados podem ser convidados."
        })

    if trip is not None:
        existing = dict(
            TripMember.objects.filter(trip=trip, user_id__in=invitee_ids)
            .values_list('user_id', 'status')
        )
        if any(status != TripMember.Status.LEFT for status in existing.values()):
            raise ValidationError({
                "invitee_ids": "Um ou mais usuários já foram convidados para esta viagem."
            })

    return invitee_ids


def create_trip_memberships(trip, organizer, invitee_ids):
    """Create the organizer and all pending invitees in the caller's transaction."""
    validate_trip_invitees(organizer, invitee_ids, trip=trip)
    TripMember.objects.create(
        trip=trip,
        user=organizer,
        status=TripMember.Status.ACCEPTED,
    )
    TripMember.objects.bulk_create([
        TripMember(
            trip=trip,
            user_id=user_id,
            status=TripMember.Status.PENDING,
        )
        for user_id in invitee_ids
    ])


@transaction.atomic
def invite_users_to_trip(trip, organizer, invitee_ids):
    trip = finance.lock_trip(trip.pk, organizer)
    if trip.created_by_id != organizer.pk:
        raise PermissionDenied('Somente o organizador atual pode convidar participantes.')
    validate_trip_invitees(organizer, invitee_ids, trip=trip)
    existing_ids = set(
        TripMember.objects.filter(
            trip=trip,
            user_id__in=invitee_ids,
            status=TripMember.Status.LEFT,
        ).values_list('user_id', flat=True)
    )
    if existing_ids:
        TripMember.objects.filter(
            trip=trip,
            user_id__in=existing_ids,
            status=TripMember.Status.LEFT,
        ).update(status=TripMember.Status.PENDING, updated_at=timezone.now())
    TripMember.objects.bulk_create([
        TripMember(
            trip=trip,
            user_id=user_id,
            status=TripMember.Status.PENDING,
        )
        for user_id in invitee_ids
        if user_id not in existing_ids
    ])
    for membership in trip.memberships.filter(
        user_id__in=invitee_ids,
        status=TripMember.Status.PENDING,
    ).select_related('user'):
        create_notification(
            user=membership.user,
            event_type='trip_invitation',
            title='Novo convite de viagem',
            message=f'Você recebeu um convite para participar de {trip.name}.',
            resource_type='trip',
            resource_id=trip.pk,
            event_key=(
                f'trip-invitation:{trip.pk}:{membership.user_id}:'
                f'{membership.updated_at.isoformat()}'
            ),
        )
