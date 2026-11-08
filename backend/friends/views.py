
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from datetime import timedelta

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Friendship
from notifications.services import create_notification
from .serializers import (
    FriendshipSerializer,
    PublicUserSerializer,
)
from .throttles import FriendSearchThrottle


User = get_user_model()


# ==========================================
# BUSCAR USUÁRIOS
# GET /api/friends/search/?q=nome
# ==========================================

class UserSearchView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [FriendSearchThrottle]

    def get(self, request):
        query = request.query_params.get("q", "").strip()

        if len(query) < 2:
            return Response(
                {
                    "results": [],
                    "message": (
                        "Digite pelo menos 2 caracteres "
                        "para pesquisar."
                    ),
                },
                status=status.HTTP_200_OK,
            )

        users = (
            User.objects.filter(is_active=True)
            .filter(
                Q(first_name__icontains=query)
                | Q(email__iexact=query)
            )
            .exclude(pk=request.user.pk)
            .select_related("tripmate_profile")
            .order_by("first_name", "id")[:20]
        )

        serializer = PublicUserSerializer(
            users,
            many=True,
            context={"request": request},
        )

        results = serializer.data
        user_ids = [item["id"] for item in results]
        relationships = Friendship.objects.filter(
            Q(sender=request.user, receiver_id__in=user_ids)
            | Q(receiver=request.user, sender_id__in=user_ids)
        )
        by_user_id = {}
        for relationship in relationships:
            other_id = (
                relationship.receiver_id
                if relationship.sender_id == request.user.pk
                else relationship.sender_id
            )
            by_user_id[other_id] = relationship

        for item in results:
            relationship = by_user_id.get(item["id"])
            item["friendship_status"] = (
                relationship.status if relationship else None
            )
            item["request_sent_by_me"] = bool(
                relationship
                and relationship.sender_id == request.user.pk
            )
            item["can_resend_at"] = None
            if (
                relationship
                and relationship.status == Friendship.Status.REJECTED
                and relationship.sender_id == request.user.pk
            ):
                item["can_resend_at"] = (
                    relationship.updated_at + timedelta(days=7)
                ).isoformat()

        return Response(
            {"results": results},
            status=status.HTTP_200_OK,
        )


# ==========================================
# LISTAR AMIZADES ACEITAS
# GET /api/friends/
# ==========================================

class FriendListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        friendships = (
            Friendship.objects.filter(
                Q(sender=request.user)
                | Q(receiver=request.user),
                status=Friendship.Status.ACCEPTED,
            )
            .select_related(
                "sender",
                "receiver",
                "sender__tripmate_profile",
                "receiver__tripmate_profile",
            )
            .order_by("-updated_at")
        )

        serializer = FriendshipSerializer(
            friendships,
            many=True,
            context={"request": request},
        )

        return Response(
            {
                "count": friendships.count(),
                "results": serializer.data,
            },
            status=status.HTTP_200_OK,
        )


# ==========================================
# CONSULTAR SOLICITAÇÕES
# GET /api/friends/requests/
# ==========================================

class FriendRequestListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        received = (
            Friendship.objects.filter(
                receiver=request.user,
                status=Friendship.Status.PENDING,
            )
            .select_related(
                "sender",
                "receiver",
                "sender__tripmate_profile",
                "receiver__tripmate_profile",
            )
        )

        sent = (
            Friendship.objects.filter(
                sender=request.user,
                status=Friendship.Status.PENDING,
            )
            .select_related(
                "sender",
                "receiver",
                "sender__tripmate_profile",
                "receiver__tripmate_profile",
            )
        )

        received_data = FriendshipSerializer(
            received,
            many=True,
            context={"request": request},
        ).data

        sent_data = FriendshipSerializer(
            sent,
            many=True,
            context={"request": request},
        ).data

        return Response(
            {
                "received": received_data,
                "sent": sent_data,
            },
            status=status.HTTP_200_OK,
        )


# ==========================================
# ENVIAR SOLICITAÇÃO
# POST /api/friends/requests/
# Body: {"receiver_id": 2}
# ==========================================

class SendFriendRequestView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        receiver_id = request.data.get("receiver_id")

        if isinstance(receiver_id, bool):
            receiver_id = None

        try:
            receiver_id = int(receiver_id)
        except (TypeError, ValueError):
            return Response(
                {
                    "detail": (
                        "Informe um identificador "
                        "de usuário válido."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if receiver_id == request.user.pk:
            return Response(
                {
                    "detail": (
                        "Você não pode enviar uma "
                        "solicitação para si próprio."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        receiver = get_object_or_404(
            User,
            pk=receiver_id,
            is_active=True,
        )

        try:
            with transaction.atomic():
                existing = Friendship.objects.select_for_update().filter(
                    Q(sender=request.user, receiver=receiver)
                    | Q(sender=receiver, receiver=request.user)
                ).first()

                if existing is not None:
                    if existing.status != Friendship.Status.REJECTED:
                        return Response(
                            {
                                "detail": "Já existe uma relação ou solicitação entre vocês.",
                                "friendship_id": existing.id,
                                "status": existing.status,
                            },
                            status=status.HTTP_409_CONFLICT,
                        )

                    # Quem recusou pode iniciar um novo convite imediatamente.
                    if existing.receiver_id == request.user.pk:
                        existing.sender = request.user
                        existing.receiver = receiver
                    # O remetente original só pode reenviar após sete dias.
                    elif timezone.now() < existing.updated_at + timedelta(days=7):
                        return Response(
                            {
                                "detail": "Aguarde 7 dias após a recusa para enviar outro convite.",
                                "status": "rejected",
                                "can_resend_at": (
                                    existing.updated_at + timedelta(days=7)
                                ).isoformat(),
                            },
                            status=status.HTTP_409_CONFLICT,
                        )

                    existing.status = Friendship.Status.PENDING
                    existing.save(
                        update_fields=[
                            "sender", "receiver", "status", "updated_at"
                        ]
                    )
                    friendship = existing
                else:
                    friendship = Friendship.objects.create(
                        sender=request.user,
                        receiver=receiver,
                        status=Friendship.Status.PENDING,
                    )

                sender_name = request.user.get_full_name().strip() or 'Uma pessoa'
                if '@' in sender_name:
                    sender_name = 'Uma pessoa'
                create_notification(
                    user=receiver,
                    event_type='friend_request',
                    title='Nova solicitação de amizade',
                    message=f'{sender_name} enviou uma solicitação de amizade.',
                    resource_type='friendship',
                    resource_id=friendship.pk,
                    event_key=f'friend-request:{friendship.pk}:{friendship.updated_at.isoformat()}',
                )

        except IntegrityError:
            # A restrição única do banco também
            # protege contra pedidos simultâneos.
            return Response(
                {
                    "detail": (
                        "Já existe uma solicitação "
                        "entre esses usuários."
                    )
                },
                status=status.HTTP_409_CONFLICT,
            )

        serializer = FriendshipSerializer(
            friendship,
            context={"request": request},
        )

        return Response(
            {
                "message": "Solicitação enviada!",
                "friendship": serializer.data,
            },
            status=status.HTTP_201_CREATED,
        )


# ==========================================
# ACEITAR SOLICITAÇÃO
# POST /api/friends/requests/<id>/accept/
# ==========================================

class AcceptFriendRequestView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, friendship_id):
        with transaction.atomic():
            friendship = get_object_or_404(
                Friendship.objects.select_for_update(),
                pk=friendship_id,
                receiver=request.user,
            )

            if friendship.status != Friendship.Status.PENDING:
                return Response(
                    {
                        "detail": (
                            "Esta solicitação não "
                            "está mais pendente."
                        )
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            friendship.status = Friendship.Status.ACCEPTED
            friendship.save(
                update_fields=["status", "updated_at"]
            )

        serializer = FriendshipSerializer(
            friendship,
            context={"request": request},
        )

        return Response(
            {
                "message": "Solicitação aceita!",
                "friendship": serializer.data,
            },
            status=status.HTTP_200_OK,
        )


# ==========================================
# RECUSAR SOLICITAÇÃO
# POST /api/friends/requests/<id>/reject/
# ==========================================

class RejectFriendRequestView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, friendship_id):
        with transaction.atomic():
            friendship = get_object_or_404(
                Friendship.objects.select_for_update(),
                pk=friendship_id,
                receiver=request.user,
            )

            if friendship.status != Friendship.Status.PENDING:
                return Response(
                    {
                        "detail": (
                            "Esta solicitação não "
                            "está mais pendente."
                        )
                    },
                    status=status.HTTP_409_CONFLICT,
                )

            friendship.status = Friendship.Status.REJECTED
            friendship.save(
                update_fields=["status", "updated_at"]
            )

        return Response(
            {
                "message": "Solicitação recusada!"
            },
            status=status.HTTP_200_OK,
        )


# ==========================================
# CANCELAR SOLICITAÇÃO OU DESFAZER AMIZADE
# DELETE /api/friends/requests/<id>/
# ==========================================

class DeleteFriendshipView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, friendship_id):
        with transaction.atomic():

            friendship = get_object_or_404(
                Friendship.objects.select_for_update().filter(
                    Q(sender=request.user)
                    | Q(receiver=request.user)
                ),
                pk=friendship_id,
            )

            if (
                friendship.status == Friendship.Status.PENDING
                and friendship.sender_id != request.user.pk
            ):
                return Response(
                    {
                        "detail": (
                            "Somente quem enviou pode "
                            "cancelar uma solicitação pendente."
                        )
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

            if (
                friendship.status == Friendship.Status.REJECTED
                and friendship.sender_id != request.user.pk
            ):
                return Response(
                    {
                        "detail": (
                            "Você não tem permissão para "
                            "remover esta solicitação."
                        )
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )

            friendship.delete()

        return Response(
            status=status.HTTP_204_NO_CONTENT,
        )
