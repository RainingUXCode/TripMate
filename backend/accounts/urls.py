
from django.urls import path

from rest_framework_simplejwt.views import (
    TokenRefreshView,
)

from .views import (
    RegisterView,
    LoginView,
    CurrentUserView,
    ChangePasswordView,
    AvatarView,
)

urlpatterns = [
    path(
        "register/",
        RegisterView.as_view(),
        name="register",
    ),
    path(
        "login/",
        LoginView.as_view(),
        name="login",
    ),
    path(
        "token/refresh/",
        TokenRefreshView.as_view(),
        name="token_refresh",
    ),
    path(
        "me/",
        CurrentUserView.as_view(),
        name="current_user",
    ),
    path(
        "me/password/",
        ChangePasswordView.as_view(),
        name="change_password",
    ),
    path(
        "me/avatar/",
        AvatarView.as_view(),
        name="user_avatar",
    ),
]
