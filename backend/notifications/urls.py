from django.urls import path

from .views import (
    NotificationListView,
    NotificationReadAllView,
    NotificationReadView,
    UnreadNotificationCountView,
)


urlpatterns = [
    path('', NotificationListView.as_view(), name='notification-list'),
    path('unread-count/', UnreadNotificationCountView.as_view(), name='notification-unread-count'),
    path('read-all/', NotificationReadAllView.as_view(), name='notification-read-all'),
    path('<int:pk>/read/', NotificationReadView.as_view(), name='notification-read'),
]
