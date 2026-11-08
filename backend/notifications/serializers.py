from rest_framework import serializers

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    is_read = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = (
            'id', 'event_type', 'title', 'message', 'resource_type',
            'resource_id', 'context_id', 'created_at', 'read_at', 'is_read',
        )
        read_only_fields = fields

    def get_is_read(self, obj):
        return obj.read_at is not None
