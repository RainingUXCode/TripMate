from django.urls import path
from .financial_api import FinancialView

from .views import (
    TripDetailView,
    TripInvitationListView,
    TripInvitationResponseView,
    TripInviteCreateView,
    TripLeaveEligibilityView,
    TripLeaveView,
    TripListCreateView,
    TripMemberRemoveView,
    TripOrganizerTransferView,
)


urlpatterns = [
    path('<int:pk>/finance/<str:resource>/', FinancialView.as_view(), name='trip-finance'),
    path('<int:pk>/finance/<str:resource>/<int:item_id>/', FinancialView.as_view(), name='trip-finance-detail'),
    path('<int:pk>/finance/<str:resource>/<int:item_id>/<str:action>/', FinancialView.as_view(), name='trip-finance-action'),
    path("", TripListCreateView.as_view(), name="trip-list"),
    path("invitations/", TripInvitationListView.as_view(), name="trip-invitation-list"),
    path(
        "<int:pk>/invitations/",
        TripInviteCreateView.as_view(),
        name="trip-invitation-create",
    ),
    path(
        "<int:pk>/invitation/<str:action>/",
        TripInvitationResponseView.as_view(),
        name="trip-invitation-response",
    ),
    path(
        "<int:pk>/leave-eligibility/",
        TripLeaveEligibilityView.as_view(),
        name="trip-leave-eligibility",
    ),
    path("<int:pk>/leave/", TripLeaveView.as_view(), name="trip-leave"),
    path(
        "<int:pk>/members/<int:user_id>/",
        TripMemberRemoveView.as_view(),
        name="trip-member-remove",
    ),
    path(
        "<int:pk>/transfer-organizer/",
        TripOrganizerTransferView.as_view(),
        name="trip-transfer-organizer",
    ),
    path("<int:pk>/", TripDetailView.as_view(), name="trip-detail"),
]
