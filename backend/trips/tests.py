from datetime import date, timedelta
from io import BytesIO
import json
from uuid import uuid4
from pathlib import Path
from tempfile import TemporaryDirectory

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken
from unittest.mock import patch
from PIL import Image, PngImagePlugin
from django.core.files.uploadedfile import SimpleUploadedFile

from friends.models import Friendship

from .models import Trip, TripMember, TripOrganizerTransfer, Expense
from . import finance


User = get_user_model()


class TripModelTests(TestCase):
    def setUp(self):
        self.organizer = User.objects.create_user(
            username="organizer@example.com",
            email="organizer@example.com",
            password=None,
        )
        self.trip_data = {
            "name": "Viagem de teste",
            "destination": "Lisboa, Portugal",
            "start_date": date(2026, 8, 10),
            "end_date": date(2026, 8, 15),
            "created_by": self.organizer,
        }

    def test_creates_valid_trip_and_links_existing_organizer(self):
        trip = Trip.objects.create(**self.trip_data)

        self.assertEqual(trip.created_by, self.organizer)
        self.assertEqual(trip.created_by_id, self.organizer.pk)
        self.assertIn(trip, self.organizer.created_trips.all())
        self.assertIsNotNone(trip.created_at)
        self.assertIsNotNone(trip.updated_at)

    def test_description_is_optional(self):
        trip = Trip.objects.create(**self.trip_data)

        self.assertEqual(trip.description, "")

    def test_end_date_before_start_date_fails_model_validation(self):
        invalid_data = {**self.trip_data, "end_date": date(2026, 8, 9)}
        trip = Trip(**invalid_data)

        with self.assertRaises(ValidationError):
            trip.full_clean()

    def test_database_constraint_blocks_invalid_direct_save(self):
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                invalid_data = {
                    **self.trip_data,
                    "end_date": date(2026, 8, 9),
                }
                Trip.objects.create(**invalid_data)

    def test_trip_membership_statuses_are_available(self):
        trip = Trip.objects.create(**self.trip_data)
        user_b = User.objects.create_user(
            username="member-b@example.com",
            email="member-b@example.com",
            password=None,
        )
        user_c = User.objects.create_user(
            username="member-c@example.com",
            email="member-c@example.com",
            password=None,
        )
        users_and_statuses = (
            (self.organizer, TripMember.Status.ACCEPTED),
            (user_b, TripMember.Status.PENDING),
            (user_c, TripMember.Status.REJECTED),
        )

        for user, status in users_and_statuses:
            with self.subTest(status=status):
                member = TripMember.objects.create(
                    trip=trip,
                    user=user,
                    status=status,
                )
                self.assertEqual(member.status, status)

    def test_duplicate_trip_member_is_rejected_by_database(self):
        trip = Trip.objects.create(**self.trip_data)
        TripMember.objects.create(
            trip=trip,
            user=self.organizer,
            status=TripMember.Status.ACCEPTED,
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                TripMember.objects.create(
                    trip=trip,
                    user=self.organizer,
                    status=TripMember.Status.ACCEPTED,
                )

    def test_trips_order_by_creation_date_then_descending_id(self):
        oldest = Trip.objects.create(**self.trip_data)
        tied_first_data = {**self.trip_data, "name": "Empate A"}
        tied_second_data = {**self.trip_data, "name": "Empate B"}
        tied_first = Trip.objects.create(**tied_first_data)
        tied_second = Trip.objects.create(**tied_second_data)
        timestamp = timezone.now()
        Trip.objects.filter(pk=oldest.pk).update(
            created_at=timestamp - timedelta(days=1),
        )
        Trip.objects.filter(pk__in=[tied_first.pk, tied_second.pk]).update(
            created_at=timestamp,
        )

        self.assertEqual(
            list(Trip.objects.values_list("pk", flat=True)),
            [tied_second.pk, tied_first.pk, oldest.pk],
        )


class TripAPITests(APITestCase):
    def setUp(self):
        self.media_dir = TemporaryDirectory()
        self.addCleanup(self.media_dir.cleanup)
        media_override = override_settings(MEDIA_ROOT=self.media_dir.name)
        media_override.enable()
        self.addCleanup(media_override.disable)
        self.owner = self._create_user("owner")
        self.accepted_member = self._create_user("accepted")
        self.pending_member = self._create_user("pending")
        self.rejected_member = self._create_user("rejected")
        self.unrelated_user = self._create_user("unrelated")

    def _create_user(self, prefix):
        email = f"{prefix}@example.com"
        return User.objects.create_user(
            username=email,
            email=email,
            password=None,
        )

    def authenticate(self, user):
        access_token = RefreshToken.for_user(user).access_token
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access_token}")

    def _trip_payload(self, **overrides):
        payload = {
            "name": "Viagem em grupo",
            "destination": "Lisboa, Portugal",
            "start_date": "2026-08-10",
            "end_date": "2026-08-15",
            "description": "",
        }
        payload.update(overrides)
        return payload

    def _create_trip(self, owner=None, **overrides):
        trip = Trip.objects.create(
            name=overrides.get("name", "Viagem privada"),
            destination="Lisboa, Portugal",
            start_date=date(2026, 8, 10),
            end_date=date(2026, 8, 15),
            created_by=owner or self.owner,
        )
        TripMember.objects.create(
            trip=trip,
            user=owner or self.owner,
            status=TripMember.Status.ACCEPTED,
        )
        return trip

    def _add_member(self, trip, user, member_status):
        return TripMember.objects.create(
            trip=trip,
            user=user,
            status=member_status,
        )

    def _make_friend(self, user):
        return Friendship.objects.create(
            sender=self.owner,
            receiver=user,
            status=Friendship.Status.ACCEPTED,
        )

    def _png_upload(self, name="cover.png", color="purple"):
        output = BytesIO()
        Image.new("RGB", (16, 12), color=color).save(output, format="PNG")
        return SimpleUploadedFile(name, output.getvalue(), content_type="image/png")

    def _oversized_png_upload(self):
        output = BytesIO()
        metadata = PngImagePlugin.PngInfo()
        metadata.add_text("payload", "x" * (8 * 1024 * 1024 + 1))
        Image.new("RGB", (16, 12), color="purple").save(
            output,
            format="PNG",
            pnginfo=metadata,
        )
        return SimpleUploadedFile("large.png", output.getvalue(), content_type="image/png")

    def test_all_endpoints_require_authentication(self):
        detail_url = "/api/trips/999/"
        responses = (
            self.client.get("/api/trips/"),
            self.client.post("/api/trips/", self._trip_payload(), format="json"),
            self.client.get(detail_url),
            self.client.patch(detail_url, {"name": "Novo"}, format="json"),
            self.client.delete(detail_url),
        )

        self.assertTrue(
            all(response.status_code == status.HTTP_401_UNAUTHORIZED for response in responses)
        )

    def test_create_trip_and_accepted_organizer_membership(self):
        self.authenticate(self.owner)

        response = self.client.post("/api/trips/", self._trip_payload(), format="json")

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        trip = Trip.objects.get(pk=response.data["id"])
        self.assertEqual(trip.created_by_id, self.owner.pk)
        self.assertTrue(
            TripMember.objects.filter(
                trip=trip,
                user=self.owner,
                status=TripMember.Status.ACCEPTED,
            ).exists()
        )
        self.assertEqual(response.data["accepted_participants_count"], 1)
        self.assertEqual(response.data["created_by"], self.owner.pk)
        self.assertNotIn("email", response.data)
        self.assertIsNone(response.data["cover_image_url"])
        self.assertEqual(response.data["accepted_participants"][0]["id"], self.owner.pk)
        self.assertNotIn("email", response.data["organizer"])

    def test_create_trip_with_valid_cover_and_friend_invites(self):
        self._make_friend(self.accepted_member)
        self.authenticate(self.owner)

        response = self.client.post(
            "/api/trips/",
            {
                **self._trip_payload(),
                "cover_image": self._png_upload(),
                "invitee_ids": json.dumps([self.accepted_member.pk]),
            },
            format="multipart",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        trip = Trip.objects.get(pk=response.data["id"])
        invite = TripMember.objects.get(trip=trip, user=self.accepted_member)
        self.assertTrue(trip.cover_image.name.startswith("trip_covers/"))
        self.assertTrue(response.data["cover_image_url"].endswith(trip.cover_image.name))
        self.assertEqual(invite.status, TripMember.Status.PENDING)
        self.assertEqual(response.data["accepted_participants_count"], 1)
        self.assertEqual(len(response.data["accepted_participants"]), 1)
        self.assertEqual(response.data["pending_invites"][0]["id"], self.accepted_member.pk)
        self.assertNotIn("email", response.data["pending_invites"][0])

    def test_create_trip_rejects_invalid_or_oversized_cover(self):
        self.authenticate(self.owner)
        invalid = self.client.post(
            "/api/trips/",
            {
                **self._trip_payload(),
                "cover_image": SimpleUploadedFile(
                    "not-an-image.png", b"not an image", content_type="image/png"
                ),
            },
            format="multipart",
        )
        oversized = self.client.post(
            "/api/trips/",
            {
                **self._trip_payload(),
                "cover_image": self._oversized_png_upload(),
            },
            format="multipart",
        )

        self.assertEqual(invalid.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("cover_image", invalid.data)
        self.assertEqual(oversized.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("cover_image", oversized.data)
        self.assertEqual(Trip.objects.count(), 0)

    def test_create_with_invite_failure_rolls_back_trip_and_cover(self):
        self._make_friend(self.accepted_member)
        self.authenticate(self.owner)

        with patch(
            "trips.views.create_trip_memberships",
            side_effect=IntegrityError("invite insert failed"),
        ):
            response = self.client.post(
                "/api/trips/",
                {
                    **self._trip_payload(),
                    "cover_image": self._png_upload(),
                    "invitee_ids": json.dumps([self.accepted_member.pk]),
                },
                format="multipart",
            )

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(Trip.objects.count(), 0)
        self.assertEqual(TripMember.objects.count(), 0)
        self.assertFalse(any(path.is_file() for path in Path(self.media_dir.name).rglob("*")))

    def test_create_is_atomic_when_organizer_membership_fails(self):
        self.authenticate(self.owner)

        with patch(
            "trips.views.TripMember.objects.create",
            side_effect=IntegrityError("membership insert failed"),
        ):
            response = self.client.post(
                "/api/trips/",
                self._trip_payload(),
                format="json",
            )

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(Trip.objects.count(), 0)
        self.assertEqual(TripMember.objects.count(), 0)

    def test_invalid_dates_and_missing_required_fields_return_400(self):
        self.authenticate(self.owner)
        invalid_date = self.client.post(
            "/api/trips/",
            self._trip_payload(end_date="2026-08-09"),
            format="json",
        )
        missing_fields = self.client.post("/api/trips/", {}, format="json")

        self.assertEqual(invalid_date.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("end_date", invalid_date.data)
        self.assertEqual(missing_fields.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("name", missing_fields.data)

    def test_protected_creator_and_membership_fields_are_ignored(self):
        self.authenticate(self.owner)

        response = self.client.post(
            "/api/trips/",
            self._trip_payload(
                created_by=self.unrelated_user.pk,
                created_at="2000-01-01T00:00:00Z",
                memberships=[{"user": self.unrelated_user.pk, "status": "accepted"}],
            ),
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        trip = Trip.objects.get(pk=response.data["id"])
        self.assertEqual(trip.created_by_id, self.owner.pk)
        self.assertEqual(
            list(trip.memberships.values_list("user_id", flat=True)),
            [self.owner.pk],
        )

    def test_user_without_access_gets_404_for_private_detail(self):
        trip = self._create_trip()
        self.authenticate(self.unrelated_user)

        response = self.client.get(f"/api/trips/{trip.pk}/")

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_accepted_member_can_view_but_pending_member_cannot(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self._add_member(trip, self.pending_member, TripMember.Status.PENDING)

        self.authenticate(self.accepted_member)
        accepted_response = self.client.get(f"/api/trips/{trip.pk}/")
        self.authenticate(self.pending_member)
        pending_response = self.client.get(f"/api/trips/{trip.pk}/")

        self.assertEqual(accepted_response.status_code, status.HTTP_200_OK)
        self.assertEqual(pending_response.status_code, status.HTTP_404_NOT_FOUND)

    def test_list_only_includes_owned_or_accepted_trips(self):
        owned = self._create_trip(name="Minha viagem")
        accepted_trip = self._create_trip(
            owner=self.unrelated_user,
            name="Viagem aceita",
        )
        pending_trip = self._create_trip(
            owner=self.unrelated_user,
            name="Convite pendente",
        )
        rejected_trip = self._create_trip(
            owner=self.unrelated_user,
            name="Convite recusado",
        )
        self._add_member(accepted_trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self._add_member(pending_trip, self.pending_member, TripMember.Status.PENDING)
        self._add_member(rejected_trip, self.rejected_member, TripMember.Status.REJECTED)
        self._add_member(accepted_trip, self.owner, TripMember.Status.ACCEPTED)
        self._add_member(pending_trip, self.owner, TripMember.Status.PENDING)
        self._add_member(rejected_trip, self.owner, TripMember.Status.REJECTED)
        self.authenticate(self.owner)

        response = self.client.get("/api/trips/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        returned_ids = {item["id"] for item in response.data}
        self.assertEqual(returned_ids, {owned.pk, accepted_trip.pk})

    def test_list_order_and_accepted_participant_count(self):
        older = self._create_trip(name="Mais antiga")
        newer = self._create_trip(name="Mais recente")
        tied_newer = self._create_trip(name="Mesmo horário")
        timestamp = timezone.now()
        Trip.objects.filter(pk=older.pk).update(
            created_at=timestamp - timedelta(days=1),
        )
        Trip.objects.filter(pk__in=[newer.pk, tied_newer.pk]).update(
            created_at=timestamp,
        )
        self._add_member(newer, self.accepted_member, TripMember.Status.ACCEPTED)
        self._add_member(newer, self.pending_member, TripMember.Status.PENDING)
        self._add_member(newer, self.rejected_member, TripMember.Status.REJECTED)
        self.authenticate(self.owner)

        response = self.client.get("/api/trips/")

        self.assertEqual(
            [item["id"] for item in response.data],
            [tied_newer.pk, newer.pk, older.pk],
        )
        self.assertEqual(response.data[1]["accepted_participants_count"], 2)
        self.assertEqual(response.data[2]["accepted_participants_count"], 1)

    def test_organizer_can_edit_trip(self):
        trip = self._create_trip()
        self.authenticate(self.owner)

        response = self.client.patch(
            f"/api/trips/{trip.pk}/",
            {
                "name": "Nome atualizado",
                "created_by": self.unrelated_user.pk,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["name"], "Nome atualizado")
        self.assertEqual(response.data["created_by"], self.owner.pk)

    def test_accepted_non_organizer_cannot_edit(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self.authenticate(self.accepted_member)

        response = self.client.patch(
            f"/api/trips/{trip.pk}/",
            {"name": "Não autorizado"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_organizer_can_invite_confirmed_friend_and_duplicate_is_rejected(self):
        trip = self._create_trip()
        self._make_friend(self.accepted_member)
        self.authenticate(self.owner)

        response = self.client.post(
            f"/api/trips/{trip.pk}/invitations/",
            {"user_ids": [self.accepted_member.pk]},
            format="json",
        )
        duplicate = self.client.post(
            f"/api/trips/{trip.pk}/invitations/",
            {"user_ids": [self.accepted_member.pk]},
            format="json",
        )

        membership = TripMember.objects.get(trip=trip, user=self.accepted_member)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertEqual(membership.status, TripMember.Status.PENDING)
        self.assertEqual(response.data["accepted_participants_count"], 1)
        self.assertEqual(len(response.data["accepted_participants"]), 1)
        self.assertEqual(response.data["pending_invites"][0]["id"], self.accepted_member.pk)
        self.assertEqual(duplicate.status_code, status.HTTP_400_BAD_REQUEST)

    def test_non_friend_and_non_organizer_cannot_send_trip_invites(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)

        self.authenticate(self.accepted_member)
        non_organizer = self.client.post(
            f"/api/trips/{trip.pk}/invitations/",
            {"user_ids": [self.pending_member.pk]},
            format="json",
        )
        self.authenticate(self.owner)
        non_friend = self.client.post(
            f"/api/trips/{trip.pk}/invitations/",
            {"user_ids": [self.pending_member.pk]},
            format="json",
        )

        self.assertEqual(non_organizer.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(non_friend.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(TripMember.objects.filter(trip=trip, user=self.pending_member).exists())

    def test_rejected_invitees_are_visible_only_to_the_organizer(self):
        trip = self._create_trip()
        self._add_member(trip, self.rejected_member, TripMember.Status.REJECTED)
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)

        self.authenticate(self.owner)
        organizer_response = self.client.get(f"/api/trips/{trip.pk}/")
        self.authenticate(self.accepted_member)
        participant_response = self.client.get(f"/api/trips/{trip.pk}/")

        self.assertEqual(organizer_response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            [user["id"] for user in organizer_response.data["rejected_invitees"]],
            [self.rejected_member.pk],
        )
        self.assertNotIn("email", organizer_response.data["rejected_invitees"][0])
        self.assertEqual(participant_response.status_code, status.HTTP_200_OK)
        self.assertEqual(participant_response.data["rejected_invitees"], [])

    def test_rejected_member_cannot_be_invited_again(self):
        trip = self._create_trip()
        self._add_member(trip, self.rejected_member, TripMember.Status.REJECTED)
        self._make_friend(self.rejected_member)
        self.authenticate(self.owner)

        response = self.client.post(
            f"/api/trips/{trip.pk}/invitations/",
            {"user_ids": [self.rejected_member.pk]},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(
            TripMember.objects.get(trip=trip, user=self.rejected_member).status,
            TripMember.Status.REJECTED,
        )

    def test_invitee_can_list_preview_and_accept_own_invitation(self):
        trip = self._create_trip()
        self._make_friend(self.accepted_member)
        self.authenticate(self.owner)
        invite = self.client.post(
            f"/api/trips/{trip.pk}/invitations/",
            {"user_ids": [self.accepted_member.pk]},
            format="json",
        )
        self.assertEqual(invite.status_code, status.HTTP_201_CREATED)

        self.authenticate(self.accepted_member)
        invitations = self.client.get("/api/trips/invitations/")
        self.assertEqual(invitations.status_code, status.HTTP_200_OK)
        self.assertEqual(invitations.data[0]["trip_id"], trip.pk)
        self.assertNotIn("description", invitations.data[0])
        self.assertNotIn("email", invitations.data[0]["organizer"])
        self.assertEqual(
            self.client.get(f"/api/trips/{trip.pk}/").status_code,
            status.HTTP_404_NOT_FOUND,
        )
        accepted = self.client.post(
            f"/api/trips/{trip.pk}/invitation/accept/",
            {},
            format="json",
        )

        self.assertEqual(accepted.status_code, status.HTTP_200_OK)
        self.assertEqual(accepted.data["status"], TripMember.Status.ACCEPTED)
        self.assertEqual(accepted.data["accepted_participants_count"], 2)
        self.assertEqual(
            self.client.get(f"/api/trips/{trip.pk}/").status_code,
            status.HTTP_200_OK,
        )

    def test_invitee_can_reject_own_invitation_but_third_party_cannot_act(self):
        trip = self._create_trip()
        self._make_friend(self.pending_member)
        self.authenticate(self.owner)
        self.client.post(
            f"/api/trips/{trip.pk}/invitations/",
            {"user_ids": [self.pending_member.pk]},
            format="json",
        )

        self.authenticate(self.unrelated_user)
        forbidden_action = self.client.post(
            f"/api/trips/{trip.pk}/invitation/accept/",
            {},
            format="json",
        )
        self.authenticate(self.pending_member)
        rejected = self.client.post(
            f"/api/trips/{trip.pk}/invitation/reject/",
            {},
            format="json",
        )

        self.assertEqual(forbidden_action.status_code, status.HTTP_404_NOT_FOUND)
        self.assertEqual(rejected.status_code, status.HTTP_200_OK)
        self.assertEqual(rejected.data["status"], TripMember.Status.REJECTED)
        self.assertEqual(rejected.data["accepted_participants_count"], 1)

    def test_only_organizer_can_add_trip_cover(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self.authenticate(self.accepted_member)
        denied = self.client.patch(
            f"/api/trips/{trip.pk}/",
            {"cover_image": self._png_upload()},
            format="multipart",
        )
        self.authenticate(self.owner)
        allowed = self.client.patch(
            f"/api/trips/{trip.pk}/",
            {"cover_image": self._png_upload("replacement.png", "blue")},
            format="multipart",
        )

        self.assertEqual(denied.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(allowed.status_code, status.HTTP_200_OK, allowed.data)
        trip.refresh_from_db()
        self.assertTrue(trip.cover_image)
        self.assertTrue(allowed.data["cover_image_url"])

        previous_name = trip.cover_image.name
        with self.captureOnCommitCallbacks(execute=True):
            replaced = self.client.patch(
                f"/api/trips/{trip.pk}/",
                {"cover_image": self._png_upload("next.png", "green")},
                format="multipart",
            )
        trip.refresh_from_db()
        self.assertEqual(replaced.status_code, status.HTTP_200_OK, replaced.data)
        self.assertNotEqual(trip.cover_image.name, previous_name)
        self.assertFalse((Path(self.media_dir.name) / previous_name).exists())

    def test_patch_validates_dates_against_existing_value(self):
        trip = self._create_trip()
        self.authenticate(self.owner)

        response = self.client.patch(
            f"/api/trips/{trip.pk}/",
            {"start_date": "2026-08-20"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("end_date", response.data)
        trip.refresh_from_db()
        self.assertEqual(trip.start_date, date(2026, 8, 10))

    def test_organizer_can_delete_and_memberships_are_cascaded(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self.authenticate(self.owner)

        response = self.client.delete(f"/api/trips/{trip.pk}/")

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Trip.objects.filter(pk=trip.pk).exists())
        self.assertFalse(TripMember.objects.filter(trip_id=trip.pk).exists())

    def test_trip_with_financial_history_cannot_be_deleted(self):
        trip = self._create_trip()
        expense = finance.write_expense(
            trip.pk,
            self.owner,
            {
                'description': 'Registro preservado',
                'amount': '12.00',
                'expense_date': '2026-08-10',
                'paid_by': self.owner.pk,
                'mode': 'equal',
                'shares': [{'user_id': self.owner.pk}],
            },
        )
        self.authenticate(self.owner)

        response = self.client.delete(f'/api/trips/{trip.pk}/')

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.assertTrue(Trip.objects.filter(pk=trip.pk).exists())
        self.assertTrue(Expense.objects.filter(pk=expense.pk).exists())
        self.assertTrue(expense.events.filter(action='expense.created').exists())

    def test_other_accepted_participant_cannot_delete(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self.authenticate(self.accepted_member)

        response = self.client.delete(f"/api/trips/{trip.pk}/")

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(Trip.objects.filter(pk=trip.pk).exists())

    def test_can_delete_is_limited_to_organizer_without_protected_history(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self.authenticate(self.owner)
        owner_response = self.client.get(f'/api/trips/{trip.pk}/')

        self.authenticate(self.accepted_member)
        participant_response = self.client.get(f'/api/trips/{trip.pk}/')

        self.assertTrue(owner_response.data['can_delete'])
        self.assertFalse(participant_response.data['can_delete'])

        self.authenticate(self.owner)
        finance.write_expense(
            trip.pk,
            self.owner,
            {
                'description': 'Histórico protegido',
                'amount': '1.00',
                'expense_date': '2026-08-10',
                'paid_by': self.owner.pk,
                'mode': 'equal',
                'shares': [{'user_id': self.owner.pk}],
            },
        )
        protected_response = self.client.get(f'/api/trips/{trip.pk}/')
        self.assertFalse(protected_response.data['can_delete'])

    def test_member_can_leave_and_history_and_trip_remain(self):
        trip = self._create_trip()
        membership = self._add_member(
            trip,
            self.accepted_member,
            TripMember.Status.ACCEPTED,
        )
        expense = finance.write_expense(
            trip.pk,
            self.owner,
            {
                'description': 'Registro histórico',
                'amount': '12.00',
                'expense_date': '2026-08-10',
                'paid_by': self.owner.pk,
                'mode': 'equal',
                'shares': [{'user_id': self.owner.pk}],
            },
        )
        eligibility_url = f'/api/trips/{trip.pk}/leave-eligibility/'
        leave_url = f'/api/trips/{trip.pk}/leave/'
        self.authenticate(self.accepted_member)

        trip.refresh_from_db()
        finance_version_before_eligibility = trip.finance_version
        eligibility = self.client.get(eligibility_url)
        trip.refresh_from_db()
        self.assertEqual(trip.finance_version, finance_version_before_eligibility)
        invalid = self.client.post(leave_url, {'user_id': self.owner.pk}, format='json')
        response = self.client.post(leave_url, {}, format='json')

        self.assertEqual(eligibility.status_code, status.HTTP_200_OK)
        self.assertTrue(eligibility.data['can_leave'])
        self.assertEqual(eligibility.data['reasons'], [])
        self.assertEqual(invalid.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        membership.refresh_from_db()
        self.assertEqual(membership.status, TripMember.Status.LEFT)
        self.assertTrue(Trip.objects.filter(pk=trip.pk).exists())
        self.assertTrue(Expense.objects.filter(pk=expense.pk).exists())
        self.assertTrue(expense.events.filter(action='expense.created').exists())
        self.assertEqual(
            self.client.get(f'/api/trips/{trip.pk}/').status_code,
            status.HTTP_404_NOT_FOUND,
        )
        self.assertNotIn(
            trip.pk,
            {item['id'] for item in self.client.get('/api/trips/').data},
        )
        self.authenticate(self.owner)
        owner_view = self.client.get(f'/api/trips/{trip.pk}/')
        self.assertEqual(owner_view.status_code, status.HTTP_200_OK)
        self.assertEqual(owner_view.data['accepted_participants_count'], 1)

    def test_leave_revalidates_financial_state_after_eligibility_query(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self.authenticate(self.accepted_member)
        eligibility = self.client.get(f'/api/trips/{trip.pk}/leave-eligibility/')
        self.assertTrue(eligibility.data['can_leave'])

        finance.write_expense(
            trip.pk,
            self.owner,
            {
                'description': 'Dívida criada após a consulta',
                'amount': '10.00',
                'expense_date': '2026-08-10',
                'paid_by': self.owner.pk,
                'mode': 'exact',
                'shares': [{'user_id': self.accepted_member.pk, 'value': '10.00'}],
            },
        )
        response = self.client.post(f'/api/trips/{trip.pk}/leave/', {}, format='json')

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.assertIn('outstanding_debt', response.data['reasons'])
        self.assertEqual(
            TripMember.objects.get(trip=trip, user=self.accepted_member).status,
            TripMember.Status.ACCEPTED,
        )

    def test_organizer_removes_accepted_member_without_deleting_financial_history(self):
        trip = self._create_trip()
        membership = self._add_member(
            trip,
            self.accepted_member,
            TripMember.Status.ACCEPTED,
        )
        shares = [{'user_id': self.owner.pk}, {'user_id': self.accepted_member.pk}]
        for paid_by in (self.owner, self.accepted_member):
            finance.write_expense(
                trip.pk,
                self.owner,
                {
                    'description': f'Despesa paga por {paid_by.pk}',
                    'amount': '10.00',
                    'expense_date': '2026-08-10',
                    'paid_by': paid_by.pk,
                    'mode': 'equal',
                    'shares': shares,
                },
            )
        self.authenticate(self.owner)

        response = self.client.delete(
            f'/api/trips/{trip.pk}/members/{self.accepted_member.pk}/'
        )

        membership.refresh_from_db()
        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertEqual(response.data['status'], TripMember.Status.LEFT)
        self.assertEqual(membership.status, TripMember.Status.LEFT)
        self.assertEqual(Expense.objects.filter(trip=trip).count(), 2)
        self.assertEqual(trip.financial_events.count(), 2)

    def test_only_organizer_can_remove_an_accepted_member(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self._add_member(trip, self.pending_member, TripMember.Status.ACCEPTED)
        self.authenticate(self.accepted_member)

        response = self.client.delete(
            f'/api/trips/{trip.pk}/members/{self.pending_member.pk}/'
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(
            TripMember.objects.get(trip=trip, user=self.pending_member).status,
            TripMember.Status.ACCEPTED,
        )

    def test_removal_is_blocked_by_financial_balance(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        finance.write_expense(
            trip.pk,
            self.owner,
            {
                'description': 'Despesa com saldo pendente',
                'amount': '10.00',
                'expense_date': '2026-08-10',
                'paid_by': self.accepted_member.pk,
                'mode': 'equal',
                'shares': [
                    {'user_id': self.owner.pk},
                    {'user_id': self.accepted_member.pk},
                ],
            },
        )
        self.authenticate(self.owner)

        response = self.client.delete(
            f'/api/trips/{trip.pk}/members/{self.accepted_member.pk}/'
        )

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(
            TripMember.objects.get(trip=trip, user=self.accepted_member).status,
            TripMember.Status.ACCEPTED,
        )

    def test_transfer_preserves_membership_and_financial_authorship_then_old_owner_can_leave(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        expense = finance.write_expense(
            trip.pk,
            self.owner,
            {
                'description': 'Autoria original',
                'amount': '5.00',
                'expense_date': '2026-08-10',
                'paid_by': self.owner.pk,
                'mode': 'equal',
                'shares': [{'user_id': self.owner.pk}],
            },
        )
        self.authenticate(self.owner)

        response = self.client.post(
            f'/api/trips/{trip.pk}/transfer-organizer/',
            {'new_organizer_id': self.accepted_member.pk},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertEqual(response.data['created_by'], self.accepted_member.pk)
        self.assertEqual(response.data['organizer']['id'], self.accepted_member.pk)
        self.assertEqual(
            TripMember.objects.get(trip=trip, user=self.owner).status,
            TripMember.Status.ACCEPTED,
        )
        expense.refresh_from_db()
        self.assertEqual(expense.created_by_id, self.owner.pk)
        audit = TripOrganizerTransfer.objects.get(trip=trip)
        self.assertEqual(audit.previous_organizer_id, self.owner.pk)
        self.assertEqual(audit.new_organizer_id, self.accepted_member.pk)
        self.assertEqual(audit.transferred_by_id, self.owner.pk)
        self.assertIsNotNone(audit.transferred_at)

        eligibility = self.client.get(f'/api/trips/{trip.pk}/leave-eligibility/')
        self.assertTrue(eligibility.data['can_leave'])
        left = self.client.post(f'/api/trips/{trip.pk}/leave/', {}, format='json')
        self.assertEqual(left.status_code, status.HTTP_200_OK)
        self.assertEqual(left.data['status'], TripMember.Status.LEFT)
        self.assertFalse(TripOrganizerTransfer.objects.filter(trip__pk=999999).exists())

        self.authenticate(self.owner)
        self.assertEqual(
            self.client.get(f'/api/trips/{trip.pk}/').status_code,
            status.HTTP_404_NOT_FOUND,
        )
        self.authenticate(self.accepted_member)
        self.assertEqual(
            self.client.get(f'/api/trips/{trip.pk}/').status_code,
            status.HTTP_200_OK,
        )

    def test_transfer_requires_current_organizer_and_accepted_successor(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self._add_member(trip, self.pending_member, TripMember.Status.PENDING)

        self.authenticate(self.accepted_member)
        denied = self.client.post(
            f'/api/trips/{trip.pk}/transfer-organizer/',
            {'new_organizer_id': self.owner.pk},
            format='json',
        )
        self.assertEqual(denied.status_code, status.HTTP_403_FORBIDDEN)

        self.authenticate(self.owner)
        pending = self.client.post(
            f'/api/trips/{trip.pk}/transfer-organizer/',
            {'new_organizer_id': self.pending_member.pk},
            format='json',
        )
        self.assertEqual(pending.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(TripOrganizerTransfer.objects.exists())

        TripMember.objects.filter(
            trip=trip,
            user=self.accepted_member,
        ).update(status=TripMember.Status.LEFT)
        left_member = self.client.post(
            f'/api/trips/{trip.pk}/transfer-organizer/',
            {'new_organizer_id': self.accepted_member.pk},
            format='json',
        )
        self.assertEqual(left_member.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(TripOrganizerTransfer.objects.exists())

    def test_left_member_can_be_invited_again_without_duplicate_membership(self):
        trip = self._create_trip()
        membership = self._add_member(
            trip,
            self.accepted_member,
            TripMember.Status.ACCEPTED,
        )
        membership.status = TripMember.Status.LEFT
        membership.save(update_fields=['status'])
        self._make_friend(self.accepted_member)
        self.authenticate(self.owner)

        response = self.client.post(
            f'/api/trips/{trip.pk}/invitations/',
            {'user_ids': [self.accepted_member.pk]},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        membership.refresh_from_db()
        self.assertEqual(membership.status, TripMember.Status.PENDING)
        self.assertEqual(
            TripMember.objects.filter(trip=trip, user=self.accepted_member).count(),
            1,
        )

    def test_exit_eligibility_reports_debt_credit_pending_and_organizer(self):
        trip = self._create_trip()
        self._add_member(trip, self.accepted_member, TripMember.Status.ACCEPTED)
        self._add_member(trip, self.pending_member, TripMember.Status.ACCEPTED)
        finance.write_expense(
            trip.pk,
            self.owner,
            {
                'description': 'Deve pagar',
                'amount': '10.00',
                'expense_date': '2026-08-10',
                'paid_by': self.owner.pk,
                'mode': 'exact',
                'shares': [{'user_id': self.accepted_member.pk, 'value': '10.00'}],
            },
        )
        finance.write_expense(
            trip.pk,
            self.accepted_member,
            {
                'description': 'Deve receber',
                'amount': '7.00',
                'expense_date': '2026-08-10',
                'paid_by': self.pending_member.pk,
                'mode': 'equal',
                'shares': [{'user_id': self.accepted_member.pk}],
            },
        )
        self.authenticate(self.accepted_member)
        debt = self.client.get(f'/api/trips/{trip.pk}/leave-eligibility/')
        self.assertIn('outstanding_debt', debt.data['reasons'])

        finance.create_settlement(
            trip.pk,
            self.accepted_member,
            {
                'debtor_id': self.accepted_member.pk,
                'creditor_id': self.owner.pk,
                'amount': '3.00',
                'request_key': uuid4(),
            },
        )
        debt_with_settlement = self.client.get(
            f'/api/trips/{trip.pk}/leave-eligibility/'
        )
        self.assertIn('pending_settlement', debt_with_settlement.data['reasons'])

        self.authenticate(self.pending_member)
        credit = self.client.get(f'/api/trips/{trip.pk}/leave-eligibility/')
        self.assertIn('outstanding_credit', credit.data['reasons'])

        # A member with a pending settlement is blocked separately even where
        # the response is called directly without asking the client to infer it.
        self.authenticate(self.owner)
        organizer = self.client.get(f'/api/trips/{trip.pk}/leave-eligibility/')
        self.assertIn('organizer_transfer_required', organizer.data['reasons'])

    def test_nonexistent_trip_ids_return_404_for_authenticated_user(self):
        self.authenticate(self.owner)
        detail_url = "/api/trips/999999/"

        responses = (
            self.client.get(detail_url),
            self.client.patch(detail_url, {"name": "Novo"}, format="json"),
            self.client.delete(detail_url),
        )

        self.assertTrue(
            all(response.status_code == status.HTTP_404_NOT_FOUND for response in responses)
        )
