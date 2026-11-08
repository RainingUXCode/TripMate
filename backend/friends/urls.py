
from django.urls import path

from .views import (
    UserSearchView,
    FriendListView,
    FriendRequestListView,
    SendFriendRequestView,
    AcceptFriendRequestView,
    RejectFriendRequestView,
    DeleteFriendshipView,
)

urlpatterns = [
    path(
        "search/",
        UserSearchView.as_view(),
        name="friend_search",
    ),
    path(
        "",
        FriendListView.as_view(),
        name="friend_list",
    ),
    path(
        "requests/",
        FriendRequestListView.as_view(),
        name="friend_requests",
    ),
    path(
        "requests/send/",
        SendFriendRequestView.as_view(),
        name="friend_request_send",
    ),
    path(
        "requests/<int:friendship_id>/accept/",
        AcceptFriendRequestView.as_view(),
        name="friend_request_accept",
    ),
    path(
        "requests/<int:friendship_id>/reject/",
        RejectFriendRequestView.as_view(),
        name="friend_request_reject",
    ),
    path(
        "requests/<int:friendship_id>/",
        DeleteFriendshipView.as_view(),
        name="friendship_delete",
    ),
]
