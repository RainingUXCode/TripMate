import logging

from django.db import IntegrityError, transaction
from django.db.models.deletion import ProtectedError
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404

from rest_framework import generics, serializers, status
from rest_framework.permissions import BasePermission, IsAuthenticated, SAFE_METHODS
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Trip, TripMember
from .serializers import (
    TripInvitationPreviewSerializer,
    TripInviteSerializer,
    TripSerializer,
)
from .services import create_trip_memberships, invite_users_to_trip
from . import finance
from notifications.services import create_notification


logger = logging.getLogger(__name__)


def _delete_stored_file(storage, name):
    if not name:
        return
    try:
        storage.delete(name)
    except Exception:
        logger.exception("Could not delete trip cover file %s", name)


class IsTripOrganizerOrReadOnly(BasePermission):
    """Accepted members may read; only the organizer may change a trip."""

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        return obj.created_by_id == request.user.pk


class AuthorizedTripQuerysetMixin:
    def get_queryset(self):
        user = self.request.user
        return (
            Trip.objects.filter(
                Q(created_by=user)
                | Q(
                    memberships__user=user,
                    memberships__status=TripMember.Status.ACCEPTED,
                )
            )
            .annotate(
                accepted_participants_count=Count(
                    "memberships__id",
                    filter=Q(memberships__status=TripMember.Status.ACCEPTED),
                    distinct=True,
                )
            )
            .select_related("created_by", "created_by__tripmate_profile")
            .prefetch_related(
                "memberships__user",
                "memberships__user__tripmate_profile",
            )
            .distinct()
            .order_by("-created_at", "-id")
        )


class TripListCreateView(AuthorizedTripQuerysetMixin, generics.ListCreateAPIView):
    serializer_class = TripSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        invitee_ids = serializer.validated_data.pop("invitee_ids", [])
        stored_name = None
        storage = Trip._meta.get_field("cover_image").storage
        try:
            with transaction.atomic():
                trip = serializer.save(created_by=self.request.user)
                stored_name = trip.cover_image.name if trip.cover_image else None
                create_trip_memberships(trip, self.request.user, invitee_ids)
                for membership in trip.memberships.filter(
                    status=TripMember.Status.PENDING
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
                trip.accepted_participants_count = 1
        except Exception:
            _delete_stored_file(storage, stored_name)
            raise

    def create(self, request, *args, **kwargs):
        try:
            return super().create(request, *args, **kwargs)
        except IntegrityError:
            return Response(
                {"detail": "Não foi possível criar a viagem ou seus convites."},
                status=status.HTTP_409_CONFLICT,
            )


class TripDetailView(AuthorizedTripQuerysetMixin, generics.RetrieveUpdateDestroyAPIView):
    serializer_class = TripSerializer
    permission_classes = [IsAuthenticated, IsTripOrganizerOrReadOnly]
    queryset = Trip.objects.all()

    def perform_update(self, serializer):
        trip = serializer.instance
        old_name = trip.cover_image.name if trip.cover_image else None
        storage = trip.cover_image.storage if trip.cover_image else Trip._meta.get_field(
            "cover_image"
        ).storage
        new_name = old_name
        try:
            with transaction.atomic():
                updated_trip = serializer.save()
                new_name = updated_trip.cover_image.name if updated_trip.cover_image else None
                if old_name and old_name != new_name:
                    transaction.on_commit(
                        lambda storage=storage, name=old_name: _delete_stored_file(
                            storage, name
                        )
                    )
        except Exception:
            current_name = (
                serializer.instance.cover_image.name
                if serializer.instance.cover_image
                else None
            )
            if current_name and current_name != old_name:
                _delete_stored_file(storage, current_name)
            raise

    def perform_destroy(self, instance):
        if instance.organizer_transfers.exists():
            raise finance.Conflict(
                'Esta viagem possui um histórico de transferência de organização e não pode ser removida.'
            )
        cover_name = instance.cover_image.name if instance.cover_image else None
        storage = instance.cover_image.storage if instance.cover_image else Trip._meta.get_field(
            "cover_image"
        ).storage
        try:
            with transaction.atomic():
                instance.delete()
                if cover_name:
                    transaction.on_commit(
                        lambda storage=storage, name=cover_name: _delete_stored_file(
                            storage, name
                        )
                    )
        except ProtectedError as error:
            raise finance.Conflict(
                'Esta viagem possui registros financeiros e não pode ser excluída.'
            ) from error


class TripInviteCreateView(AuthorizedTripQuerysetMixin, APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        trip = get_object_or_404(self.get_queryset(), pk=pk)
        if trip.created_by_id != request.user.pk:
            return Response(
                {"detail": "Somente o organizador pode convidar participantes."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = TripInviteSerializer(
            data=request.data,
            context={"request": request, "trip": trip},
        )
        serializer.is_valid(raise_exception=True)
        try:
            invite_users_to_trip(
                trip,
                request.user,
                serializer.validated_data["user_ids"],
            )
        except IntegrityError:
            return Response(
                {"detail": "Um ou mais usuários já foram convidados."},
                status=status.HTTP_409_CONFLICT,
            )

        trip.refresh_from_db()
        trip.accepted_participants_count = trip.memberships.filter(
            status=TripMember.Status.ACCEPTED
        ).count()
        return Response(
            TripSerializer(trip, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class TripInvitationListView(generics.ListAPIView):
    serializer_class = TripInvitationPreviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            TripMember.objects.filter(
                user=self.request.user,
                status=TripMember.Status.PENDING,
            )
            .select_related(
                "trip",
                "trip__created_by",
                "trip__created_by__tripmate_profile",
            )
            .order_by("-created_at", "-id")
        )


class TripInvitationResponseView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk, action):
        if action not in ("accept", "reject"):
            return Response(
                {"detail": "Ação de convite inválida."},
                status=status.HTTP_404_NOT_FOUND,
            )
        with transaction.atomic():
            membership = get_object_or_404(
                TripMember.objects.select_for_update().select_related("trip"),
                trip_id=pk,
                user=request.user,
                status=TripMember.Status.PENDING,
            )
            membership.status = (
                TripMember.Status.ACCEPTED
                if action == "accept"
                else TripMember.Status.REJECTED
            )
            membership.save(update_fields=["status", "updated_at"])
            count = membership.trip.memberships.filter(
                status=TripMember.Status.ACCEPTED
            ).count()

        return Response(
            {
                "trip_id": pk,
                "status": membership.status,
                "accepted_participants_count": count,
            },
            status=status.HTTP_200_OK,
        )


class OrganizerTransferInput(serializers.Serializer):
    new_organizer_id = serializers.IntegerField(min_value=1)

    def to_internal_value(self, data):
        unknown = set(data) - set(self.fields)
        if unknown:
            raise serializers.ValidationError({key: 'Campo não permitido.' for key in unknown})
        return super().to_internal_value(data)


class EmptyTripActionInput(serializers.Serializer):
    def to_internal_value(self, data):
        if data:
            raise serializers.ValidationError(
                {
                    'non_field_errors': [
                        'Esta operação sempre atua sobre o usuário autenticado; não envie IDs de usuário.'
                    ]
                }
            )
        return {}


class TripStateChangeAPIView(AuthorizedTripQuerysetMixin, APIView):
    permission_classes = [IsAuthenticated]

    def handle_exception(self, exc):
        from django.db import OperationalError

        if isinstance(exc, (OperationalError, IntegrityError)):
            exc = finance.Conflict(
                'Conflito de gravação. Atualize os dados e tente novamente.'
            )
        return super().handle_exception(exc)


class TripLeaveEligibilityView(TripStateChangeAPIView):
    def get(self, request, pk):
        trip = get_object_or_404(self.get_queryset(), pk=pk)
        return Response(finance.exit_eligibility(trip, request.user))


class TripLeaveView(TripStateChangeAPIView):
    def post(self, request, pk):
        EmptyTripActionInput(data=request.data).is_valid(raise_exception=True)
        trip = get_object_or_404(self.get_queryset(), pk=pk)
        return Response(finance.leave_trip(trip.pk, request.user))


class TripMemberRemoveView(TripStateChangeAPIView):
    def delete(self, request, pk, user_id):
        trip = get_object_or_404(self.get_queryset(), pk=pk)
        return Response(finance.remove_trip_member(trip.pk, request.user, user_id))


class TripOrganizerTransferView(TripStateChangeAPIView):
    def post(self, request, pk):
        data = OrganizerTransferInput(data=request.data)
        data.is_valid(raise_exception=True)
        trip = get_object_or_404(self.get_queryset(), pk=pk)
        trip = finance.transfer_organizer(
            trip.pk,
            request.user,
            data.validated_data['new_organizer_id'],
        )
        trip.accepted_participants_count = trip.memberships.filter(
            status=TripMember.Status.ACCEPTED
        ).count()
        return Response(TripSerializer(trip, context={'request': request}).data)
