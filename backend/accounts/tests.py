from io import BytesIO
import secrets
from tempfile import TemporaryDirectory

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase
from django.test import override_settings
from PIL import Image


class AuthenticationApiTests(APITestCase):
    def setUp(self):
        self.password = secrets.token_urlsafe(24)
        self.media_directory = TemporaryDirectory(prefix="tripmate-account-qa-")
        self.addCleanup(self.media_directory.cleanup)
        self.media_settings = override_settings(
            MEDIA_ROOT=self.media_directory.name
        )
        self.media_settings.enable()
        self.addCleanup(self.media_settings.disable)
        self.user = get_user_model().objects.create_user(
            username="qa-user@example.test",
            email="qa-user@example.test",
            first_name="QA User",
            password=self.password,
        )
        self.other_user = get_user_model().objects.create_user(
            username="qa-other@example.test",
            email="qa-other@example.test",
            first_name="Other User",
            password=self.password,
        )

    def test_login_returns_jwt_and_normalized_public_user(self):
        response = self.client.post(
            "/api/auth/login/",
            {"email": " QA-USER@EXAMPLE.TEST ", "password": self.password},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        self.assertEqual(response.data["user"]["id"], self.user.pk)
        self.assertEqual(response.data["user"]["name"], "QA User")
        self.assertNotIn("password", response.data["user"])

    def test_invalid_credentials_are_rejected(self):
        response = self.client.post(
            "/api/auth/login/",
            {"email": self.user.email, "password": "incorrect"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("E-mail ou senha inválidos.", str(response.data))

    def test_current_user_requires_valid_jwt(self):
        anonymous = self.client.get("/api/auth/me/")
        self.assertEqual(anonymous.status_code, status.HTTP_401_UNAUTHORIZED)

        self.client.credentials(HTTP_AUTHORIZATION="Bearer invalid-token")
        invalid = self.client.get("/api/auth/me/")
        self.assertEqual(invalid.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_current_user_exposes_only_authenticated_account(self):
        login = self.client.post(
            "/api/auth/login/",
            {"email": self.user.email, "password": self.password},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.data['access']}"
        )

        response = self.client.get("/api/auth/me/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["id"], self.user.pk)
        self.assertEqual(response.data["email"], self.user.email)
        self.assertNotEqual(response.data["id"], self.other_user.pk)
        self.assertNotIn("password", response.data)

    def test_refresh_rotates_access_token_for_valid_refresh(self):
        login = self.client.post(
            "/api/auth/login/",
            {"email": self.user.email, "password": self.password},
            format="json",
        )

        response = self.client.post(
            "/api/auth/token/refresh/",
            {"refresh": login.data["refresh"]},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertNotEqual(response.data["access"], login.data["access"])

    def test_refresh_rejects_invalid_token(self):
        response = self.client.post(
            "/api/auth/token/refresh/",
            {"refresh": "invalid-refresh-token"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_profile_can_be_read_and_name_updated_without_leaking_password(self):
        self.client.force_authenticate(self.user)

        profile = self.client.get("/api/auth/me/")
        self.assertEqual(profile.status_code, status.HTTP_200_OK)
        self.assertIsNone(profile.data["avatar_url"])
        self.assertNotIn("password", profile.data)

        updated = self.client.patch(
            "/api/auth/me/",
            {"name": "  Updated QA Name  "},
            format="json",
        )
        self.assertEqual(updated.status_code, status.HTTP_200_OK)
        self.assertEqual(updated.data["user"]["name"], "Updated QA Name")
        self.user.refresh_from_db()
        self.assertEqual(self.user.first_name, "Updated QA Name")
        self.assertEqual(self.user.email, "qa-user@example.test")

    def test_email_update_requires_current_password_and_updates_login_username(self):
        self.client.force_authenticate(self.user)

        missing_password = self.client.patch(
            "/api/auth/me/",
            {"email": "changed@example.test"},
            format="json",
        )
        self.assertEqual(missing_password.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("current_password", missing_password.data)

        wrong_password = self.client.patch(
            "/api/auth/me/",
            {"email": "changed@example.test", "current_password": "wrong"},
            format="json",
        )
        self.assertEqual(wrong_password.status_code, status.HTTP_400_BAD_REQUEST)

        updated = self.client.patch(
            "/api/auth/me/",
            {
                "email": "  CHANGED@EXAMPLE.TEST ",
                "current_password": self.password,
            },
            format="json",
        )
        self.assertEqual(updated.status_code, status.HTTP_200_OK)
        self.assertEqual(updated.data["user"]["email"], "changed@example.test")
        self.user.refresh_from_db()
        self.assertEqual(self.user.username, "changed@example.test")

    def test_profile_rejects_duplicate_email_and_empty_patch(self):
        self.client.force_authenticate(self.user)

        duplicate = self.client.patch(
            "/api/auth/me/",
            {
                "email": self.other_user.email,
                "current_password": self.password,
            },
            format="json",
        )
        self.assertEqual(duplicate.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("Este e-mail já está cadastrado.", str(duplicate.data))

        empty = self.client.patch("/api/auth/me/", {}, format="json")
        self.assertEqual(empty.status_code, status.HTTP_400_BAD_REQUEST)

    def test_password_change_validates_and_requires_reauthentication(self):
        self.client.force_authenticate(self.user)
        new_password = f"Trip-QA-{secrets.token_hex(8)}!9"

        mismatch = self.client.post(
            "/api/auth/me/password/",
            {
                "current_password": self.password,
                "new_password": new_password,
                "confirm_password": "different-value",
            },
            format="json",
        )
        self.assertEqual(mismatch.status_code, status.HTTP_400_BAD_REQUEST)

        wrong_current = self.client.post(
            "/api/auth/me/password/",
            {
                "current_password": "wrong",
                "new_password": new_password,
                "confirm_password": new_password,
            },
            format="json",
        )
        self.assertEqual(wrong_current.status_code, status.HTTP_400_BAD_REQUEST)

        changed = self.client.post(
            "/api/auth/me/password/",
            {
                "current_password": self.password,
                "new_password": new_password,
                "confirm_password": new_password,
            },
            format="json",
        )
        self.assertEqual(changed.status_code, status.HTTP_200_OK)
        self.assertTrue(self.user.check_password(new_password))

        old_login = self.client.post(
            "/api/auth/login/",
            {"email": self.user.email, "password": self.password},
            format="json",
        )
        new_login = self.client.post(
            "/api/auth/login/",
            {"email": self.user.email, "password": new_password},
            format="json",
        )
        self.assertEqual(old_login.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(new_login.status_code, status.HTTP_200_OK)

    def test_avatar_upload_persists_safe_image_and_delete_is_idempotent(self):
        self.client.force_authenticate(self.user)
        image = Image.new("RGB", (16, 16), color=(99, 76, 212))
        content = BytesIO()
        image.save(content, format="PNG")
        upload = SimpleUploadedFile(
            "user-controlled-name.png",
            content.getvalue(),
            content_type="image/png",
        )

        response = self.client.patch(
            "/api/auth/me/avatar/", {"avatar": upload}, format="multipart"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("/media/avatars/user_", response.data["user"]["avatar_url"])
        self.user.refresh_from_db()
        profile = self.user.tripmate_profile
        self.assertTrue(profile.avatar.name.endswith(".png"))
        self.assertTrue(profile.avatar.storage.exists(profile.avatar.name))

        # force_authenticate reuses this in-memory user instance across calls.
        # Reload it so its cached reverse OneToOne profile cannot mask deletion.
        authenticated_user = get_user_model().objects.get(pk=self.user.pk)
        self.client.force_authenticate(user=authenticated_user)
        removed = self.client.delete("/api/auth/me/avatar/")
        self.assertEqual(removed.status_code, status.HTTP_200_OK)
        self.assertIsNone(removed.data["user"]["avatar_url"])
        self.assertFalse(profile.avatar.storage.exists(profile.avatar.name))

        removed_again = self.client.delete("/api/auth/me/avatar/")
        self.assertEqual(removed_again.status_code, status.HTTP_200_OK)
        self.assertIsNone(removed_again.data["user"]["avatar_url"])

    def test_avatar_rejects_non_image_and_oversized_upload(self):
        self.client.force_authenticate(self.user)

        invalid = self.client.patch(
            "/api/auth/me/avatar/",
            {
                "avatar": SimpleUploadedFile(
                    "fake.png", b"not-an-image", content_type="image/png"
                )
            },
            format="multipart",
        )
        self.assertEqual(invalid.status_code, status.HTTP_400_BAD_REQUEST)

        large_image = Image.effect_noise((3200, 3200), 100).convert("RGB")
        large_content = BytesIO()
        large_image.save(large_content, format="JPEG", quality=98)
        self.assertGreater(len(large_content.getvalue()), 2 * 1024 * 1024)
        oversized = self.client.patch(
            "/api/auth/me/avatar/",
            {
                "avatar": SimpleUploadedFile(
                    "large.jpg",
                    large_content.getvalue(),
                    content_type="image/jpeg",
                )
            },
            format="multipart",
        )
        self.assertEqual(oversized.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("no máximo 2 MB", str(oversized.data))

    def test_profile_and_avatar_require_authentication(self):
        self.client.force_authenticate(user=None)

        profile = self.client.get("/api/auth/me/")
        avatar = self.client.delete("/api/auth/me/avatar/")
        password = self.client.post(
            "/api/auth/me/password/",
            {
                "current_password": self.password,
                "new_password": self.password,
                "confirm_password": self.password,
            },
            format="json",
        )
        self.assertEqual(profile.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(avatar.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(password.status_code, status.HTTP_401_UNAUTHORIZED)
