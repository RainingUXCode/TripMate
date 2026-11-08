from rest_framework.throttling import ScopedRateThrottle


class FriendSearchThrottle(ScopedRateThrottle):
    scope = "friends_search"
