from django.contrib import admin

from .models import Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'event_type', 'title', 'created_at', 'read_at')
    list_filter = ('event_type', 'read_at')
    search_fields = ('user__username', 'title', 'message', 'event_key')
    readonly_fields = (
        'user', 'event_type', 'title', 'message', 'resource_type',
        'resource_id', 'context_id', 'event_key', 'created_at', 'read_at',
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
