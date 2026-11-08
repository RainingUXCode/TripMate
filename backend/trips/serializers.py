import json

from PIL import Image, UnidentifiedImageError
from rest_framework import serializers

from friends.serializers import PublicUserSerializer

from .models import Trip, TripMember
from .services import validate_trip_invitees


class UserIdListField(serializers.ListField):
    """Accept JSON lists and JSON-encoded lists in multipart form fields."""

    def get_value(self, dictionary):
        value = super().get_value(dictionary)
        if isinstance(value, list) and len(value) == 1 and isinstance(value[0], str):
            try:
                decoded = json.loads(value[0])
            except json.JSONDecodeError:
                return value
            if isinstance(decoded, list):
                return decoded
        return value


class TripSerializer(serializers.ModelSerializer):
    accepted_participants_count = serializers.IntegerField(read_only=True)
    organizer = PublicUserSerializer(source="created_by", read_only=True)
    accepted_participants = serializers.SerializerMethodField()
    pending_invites = serializers.SerializerMethodField()
    rejected_invitees = serializers.SerializerMethodField()
    can_delete = serializers.SerializerMethodField()
    cover_image = serializers.ImageField(
        write_only=True,
        required=False,
        allow_empty_file=False,
        allow_null=False,
    )
    cover_image_url = serializers.SerializerMethodField()
    invitee_ids = UserIdListField(
        child=serializers.IntegerField(min_value=1),
        write_only=True,
        required=False,
        allow_empty=True,
    )

    class Meta:
        model = Trip
        fields = (
            "id",
            "name",
            "destination",
            "start_date",
            "end_date",
            "description",
            "cover_image",
            "cover_image_url",
            "created_at",
            "created_by",
            "organizer",
            "accepted_participants",
            "pending_invites",
            "rejected_invitees",
            "can_delete",
            "accepted_participants_count",
            "invitee_ids",
        )
        read_only_fields = (
            "id",
            "created_at",
            "created_by",
            "organizer",
            "accepted_participants",
            "pending_invites",
            "rejected_invitees",
            "can_delete",
            "cover_image_url",
            "accepted_participants_count",
        )
        extra_kwargs = {"description": {"required": False, "allow_blank": True}}

    def validate_cover_image(self, image_file):
        max_size = 8 * 1024 * 1024
        if image_file.size > max_size:
            raise serializers.ValidationError("A capa deve ter no máximo 8 MB.")

        try:
            image_file.seek(0)
            with Image.open(image_file) as image:
                image_format = image.format
                width, height = image.size
                image.verify()
            image_file.seek(0)
        except (OSError, ValueError, UnidentifiedImageError, Image.DecompressionBombError):
            raise serializers.ValidationError("O arquivo enviado não é uma imagem válida.")

        allowed_formats = {"JPEG": ".jpg", "PNG": ".png", "WEBP": ".webp"}
        if image_format not in allowed_formats:
            raise serializers.ValidationError("Envie uma imagem JPG, PNG ou WebP.")
        if width > 8192 or height > 8192:
            raise serializers.ValidationError(
                "A imagem deve ter no máximo 8192 pixels em cada dimensão."
            )

        image_file.name = f"cover{allowed_formats[image_format]}"
        return image_file

    def validate_invitee_ids(self, invitee_ids):
        if self.instance is not None:
            raise serializers.ValidationError(
                "Use o endpoint de convites para adicionar participantes."
            )
        request = self.context["request"]
        validate_trip_invitees(request.user, invitee_ids)
        return invitee_ids

    def validate(self, attrs):
        start_date = attrs.get(
            "start_date",
            self.instance.start_date if self.instance is not None else None,
        )
        end_date = attrs.get(
            "end_date",
            self.instance.end_date if self.instance is not None else None,
        )
        if start_date is not None and end_date is not None and end_date < start_date:
            raise serializers.ValidationError({
                "end_date": "A data de término não pode anteceder a data de início."
            })
        return attrs

    def get_cover_image_url(self, trip):
        if not trip.cover_image:
            return None
        url = trip.cover_image.url
        request = self.context.get("request")
        return request.build_absolute_uri(url) if request else url

    def get_accepted_participants(self, trip):
        members = (
            trip.memberships.filter(status=TripMember.Status.ACCEPTED)
            .select_related("user", "user__tripmate_profile")
            .order_by("created_at", "id")
        )
        return PublicUserSerializer(
            [member.user for member in members],
            many=True,
            context=self.context,
        ).data

    def get_pending_invites(self, trip):
        request = self.context.get("request")
        if request is None or request.user.pk != trip.created_by_id:
            return []
        members = (
            trip.memberships.filter(status=TripMember.Status.PENDING)
            .select_related("user", "user__tripmate_profile")
            .order_by("created_at", "id")
        )
        return PublicUserSerializer(
            [member.user for member in members],
            many=True,
            context=self.context,
        ).data

    def get_rejected_invitees(self, trip):
        request = self.context.get("request")
        if request is None or request.user.pk != trip.created_by_id:
            return []
        members = (
            trip.memberships.filter(status=TripMember.Status.REJECTED)
            .select_related("user", "user__tripmate_profile")
            .order_by("created_at", "id")
        )
        return PublicUserSerializer(
            [member.user for member in members],
            many=True,
            context=self.context,
        ).data

    def get_can_delete(self, trip):
        request = self.context.get("request")
        if request is None or request.user.pk != trip.created_by_id:
            return False
        return not (
            trip.organizer_transfers.exists()
            or trip.expenses.exists()
            or trip.settlements.exists()
            or trip.financial_events.exists()
        )


class TripInviteSerializer(serializers.Serializer):
    user_ids = UserIdListField(
        child=serializers.IntegerField(min_value=1),
        allow_empty=False,
    )

    def validate_user_ids(self, user_ids):
        request = self.context["request"]
        trip = self.context["trip"]
        validate_trip_invitees(request.user, user_ids, trip=trip)
        return user_ids


class TripInvitationPreviewSerializer(serializers.ModelSerializer):
    trip_id = serializers.IntegerField(read_only=True)
    name = serializers.CharField(source="trip.name", read_only=True)
    destination = serializers.CharField(source="trip.destination", read_only=True)
    start_date = serializers.DateField(source="trip.start_date", read_only=True)
    end_date = serializers.DateField(source="trip.end_date", read_only=True)
    cover_image_url = serializers.SerializerMethodField()
    organizer = PublicUserSerializer(source="trip.created_by", read_only=True)

    class Meta:
        model = TripMember
        fields = (
            "trip_id",
            "name",
            "destination",
            "start_date",
            "end_date",
            "cover_image_url",
            "organizer",
            "created_at",
        )

    def get_cover_image_url(self, membership):
        image = membership.trip.cover_image
        if not image:
            return None
        url = image.url
        request = self.context.get("request")
        return request.build_absolute_uri(url) if request else url
