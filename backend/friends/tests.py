
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta
from django.urls import reverse

from rest_framework import status
from rest_framework.test import APITestCase

from .models import Friendship


User = get_user_model()


class FriendshipAPITests(APITestCase):

    def setUp(self):
        self.user_a = User.objects.create_user(
            username="alice@example.com",
            email="alice@example.com",
            password="Teste123!Segura",
            first_name="Alice Silva",
        )

        self.user_b = User.objects.create_user(
            username="bruno@example.com",
            email="bruno@example.com",
            password="Teste123!Segura",
            first_name="Bruno Costa",
        )

        self.user_c = User.objects.create_user(
            username="carla@example.com",
            email="carla@example.com",
            password="Teste123!Segura",
            first_name="Carla Lima",
        )

    def authenticate(self, user):
        self.client.force_authenticate(user=user)

    def test_search_requires_authentication(self):
        response = self.client.get(
            "/api/friends/search/?q=Bruno"
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

    def test_search_returns_other_users(self):
        self.authenticate(self.user_a)

        response = self.client.get(
            "/api/friends/search/?q=Bruno"
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        self.assertEqual(
            len(response.data["results"]),
            1,
        )

        self.assertEqual(
            response.data["results"][0]["name"],
            "Bruno Costa",
        )

        self.assertNotIn(
            "email",
            response.data["results"][0],
        )
        self.assertEqual(
            set(response.data["results"][0]),
            {
                "id", "name", "avatar_url", "friendship_status",
                "request_sent_by_me", "can_resend_at",
            },
        )

    def test_search_supports_partial_name(self):
        self.authenticate(self.user_a)
        response = self.client.get("/api/friends/search/?q=run")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual([u["name"] for u in response.data["results"]], ["Bruno Costa"])

    def test_search_email_is_exact_and_case_insensitive(self):
        self.authenticate(self.user_a)
        exact = self.client.get("/api/friends/search/?q=BRUNO%40EXAMPLE.COM")
        partial = self.client.get("/api/friends/search/?q=bruno%40")
        self.assertEqual([u["id"] for u in exact.data["results"]], [self.user_b.id])
        self.assertEqual(partial.data["results"], [])

    def test_search_excludes_self_and_inactive_accounts(self):
        inactive = User.objects.create_user(
            username="inactive@example.com", email="inactive@example.com",
            password="Teste123!Segura", first_name="Inactive Person", is_active=False,
        )
        self.authenticate(self.user_a)
        response = self.client.get("/api/friends/search/?q=Alice")
        self.assertEqual(response.data["results"], [])
        response = self.client.get("/api/friends/search/?q=inactive")
        self.assertEqual(response.data["results"], [])

    def test_user_cannot_add_themselves(self):
        self.authenticate(self.user_a)

        response = self.client.post(
            "/api/friends/requests/send/",
            {"receiver_id": self.user_a.id},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

    def test_send_friend_request(self):
        self.authenticate(self.user_a)

        response = self.client.post(
            "/api/friends/requests/send/",
            {"receiver_id": self.user_b.id},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
        )

        self.assertTrue(
            Friendship.objects.filter(
                sender=self.user_a,
                receiver=self.user_b,
                status=Friendship.Status.PENDING,
            ).exists()
        )

    def test_duplicate_friend_request_is_blocked(self):
        self.authenticate(self.user_a)

        self.client.post(
            "/api/friends/requests/send/",
            {"receiver_id": self.user_b.id},
            format="json",
        )

        response = self.client.post(
            "/api/friends/requests/send/",
            {"receiver_id": self.user_b.id},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_409_CONFLICT,
        )

        self.assertEqual(
            Friendship.objects.count(),
            1,
        )

    def test_reverse_request_is_blocked(self):
        self.authenticate(self.user_a)

        self.client.post(
            "/api/friends/requests/send/",
            {"receiver_id": self.user_b.id},
            format="json",
        )

        self.authenticate(self.user_b)

        response = self.client.post(
            "/api/friends/requests/send/",
            {"receiver_id": self.user_a.id},
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_409_CONFLICT,
        )

        self.assertEqual(
            Friendship.objects.count(),
            1,
        )

    def test_receiver_can_reject_and_sender_is_blocked_for_seven_days(self):
        friendship = Friendship.objects.create(sender=self.user_a, receiver=self.user_b)
        self.authenticate(self.user_b)
        rejected = self.client.post(f"/api/friends/requests/{friendship.id}/reject/")
        self.assertEqual(rejected.status_code, status.HTTP_200_OK)
        self.authenticate(self.user_a)
        blocked = self.client.post("/api/friends/requests/send/", {"receiver_id": self.user_b.id}, format="json")
        self.assertEqual(blocked.status_code, status.HTTP_409_CONFLICT)
        friendship.refresh_from_db()
        self.assertEqual(friendship.status, Friendship.Status.REJECTED)

    def test_original_sender_can_resend_after_seven_days(self):
        friendship = Friendship.objects.create(
            sender=self.user_a, receiver=self.user_b,
            status=Friendship.Status.REJECTED,
        )
        Friendship.objects.filter(pk=friendship.pk).update(
            updated_at=timezone.now() - timedelta(days=7, seconds=1)
        )
        self.authenticate(self.user_a)
        response = self.client.post("/api/friends/requests/send/", {"receiver_id": self.user_b.id}, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Friendship.objects.count(), 1)
        friendship.refresh_from_db()
        self.assertEqual(friendship.status, Friendship.Status.PENDING)

    def test_declining_user_can_start_new_request_immediately(self):
        friendship = Friendship.objects.create(
            sender=self.user_a, receiver=self.user_b,
            status=Friendship.Status.REJECTED,
        )
        self.authenticate(self.user_b)
        response = self.client.post("/api/friends/requests/send/", {"receiver_id": self.user_a.id}, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        friendship.refresh_from_db()
        self.assertEqual(friendship.sender_id, self.user_b.id)
        self.assertEqual(friendship.receiver_id, self.user_a.id)
        self.assertEqual(friendship.status, Friendship.Status.PENDING)

    def test_only_recipient_can_reject_request(self):
        friendship = Friendship.objects.create(sender=self.user_a, receiver=self.user_b)
        self.authenticate(self.user_a)
        response = self.client.post(f"/api/friends/requests/{friendship.id}/reject/")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        friendship.refresh_from_db()
        self.assertEqual(friendship.status, Friendship.Status.PENDING)

    def test_participant_can_cancel_pending_and_remove_friendship(self):
        pending = Friendship.objects.create(sender=self.user_a, receiver=self.user_b)
        self.authenticate(self.user_b)
        denied = self.client.delete(f"/api/friends/requests/{pending.id}/")
        self.assertEqual(denied.status_code, status.HTTP_403_FORBIDDEN)
        self.authenticate(self.user_a)
        cancelled = self.client.delete(f"/api/friends/requests/{pending.id}/")
        self.assertEqual(cancelled.status_code, status.HTTP_204_NO_CONTENT)
        accepted = Friendship.objects.create(sender=self.user_a, receiver=self.user_b, status=Friendship.Status.ACCEPTED)
        removed = self.client.delete(f"/api/friends/requests/{accepted.id}/")
        self.assertEqual(removed.status_code, status.HTTP_204_NO_CONTENT)

    def test_receiver_can_accept_request(self):
        friendship = Friendship.objects.create(
            sender=self.user_a,
            receiver=self.user_b,
        )

        self.authenticate(self.user_b)

        response = self.client.post(
            f"/api/friends/requests/{friendship.id}/accept/"
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        friendship.refresh_from_db()

        self.assertEqual(
            friendship.status,
            Friendship.Status.ACCEPTED,
        )

    def test_sender_cannot_accept_request(self):
        friendship = Friendship.objects.create(
            sender=self.user_a,
            receiver=self.user_b,
        )

        self.authenticate(self.user_a)

        response = self.client.post(
            f"/api/friends/requests/{friendship.id}/accept/"
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_accepted_friendship_is_visible_to_both(self):
        Friendship.objects.create(
            sender=self.user_a,
            receiver=self.user_b,
            status=Friendship.Status.ACCEPTED,
        )

        self.authenticate(self.user_a)
        response_a = self.client.get("/api/friends/")

        self.authenticate(self.user_b)
        response_b = self.client.get("/api/friends/")

        self.assertEqual(response_a.data["count"], 1)
        self.assertEqual(response_b.data["count"], 1)

    def test_unrelated_user_cannot_delete_friendship(self):
        friendship = Friendship.objects.create(
            sender=self.user_a,
            receiver=self.user_b,
            status=Friendship.Status.ACCEPTED,
        )

        self.authenticate(self.user_c)

        response = self.client.delete(
            f"/api/friends/requests/{friendship.id}/"
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

        self.assertTrue(
            Friendship.objects.filter(
                pk=friendship.id,
            ).exists()
        )
