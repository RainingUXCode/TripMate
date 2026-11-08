import 'dart:async';

import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/friends_service.dart';
import '../services/trips_service.dart';
import '../services/auth_service.dart';
import '../services/notifications_service.dart';
import '../widgets/tripmate_bottom_navigation.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'trip_invitation_screen.dart';
import 'settlements_screen.dart';
import 'trip_details_screen.dart';

/// Keeps the three authenticated tabs in one route instead of stacking them.
class AuthenticatedShell extends StatefulWidget {
  final TripMateTab initialTab;
  final FriendsService? friendsService;
  final TripsService? tripsService;
  final AuthService? authService;
  final NotificationsService? notificationsService;

  const AuthenticatedShell({
    super.key,
    this.initialTab = TripMateTab.home,
    this.friendsService,
    this.tripsService,
    this.authService,
    this.notificationsService,
  });

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell>
    with WidgetsBindingObserver {
  late TripMateTab _selectedTab = widget.initialTab;
  bool _friendsHasInternalBackState = false;
  int _homeActivationVersion = 0;
  int _profileActivationVersion = 0;
  int _friendsOpenRequestsVersion = 0;
  List<Trip> _trips = const [];
  bool _loadingTrips = true;
  String? _tripsError;
  int _tripsRequestGeneration = 0;
  late final bool _ownsTripsService = widget.tripsService == null;
  late final TripsService _tripsService = widget.tripsService ?? TripsService();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final bool _ownsNotificationsService =
      widget.notificationsService == null;
  late final NotificationsService _notificationsService =
      widget.notificationsService ??
      NotificationsService(authService: _authService);
  int? _notificationUserId;
  int? _unreadNotificationCount;
  bool _notificationCountLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTrips();
    _refreshNotificationCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNotificationCount();
  }

  Future<void> _refreshTrips() async {
    final generation = ++_tripsRequestGeneration;
    if (mounted) {
      setState(() {
        _loadingTrips = true;
        _tripsError = null;
      });
    }
    try {
      final trips = await _tripsService.getTrips();
      if (!mounted || generation != _tripsRequestGeneration) return;
      setState(() {
        _trips = trips;
        _loadingTrips = false;
        _tripsError = null;
        _homeActivationVersion++;
        _profileActivationVersion++;
      });
    } catch (error) {
      if (!mounted || generation != _tripsRequestGeneration) return;
      setState(() {
        _loadingTrips = false;
        _tripsError = error is TripsServiceException
            ? error.message
            : 'Não foi possível carregar as viagens.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsTripsService) _tripsService.close();
    if (_ownsNotificationsService) _notificationsService.close();
    super.dispose();
  }

  void _selectTab(TripMateTab tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
      if (tab == TripMateTab.home) _homeActivationVersion++;
      if (tab == TripMateTab.profile) _profileActivationVersion++;
    });
    if (tab == TripMateTab.home) unawaited(_refreshTrips());
    unawaited(_refreshNotificationCount());
  }

  Future<void> _refreshNotificationCount() async {
    if (_notificationCountLoading) return;
    _notificationCountLoading = true;
    try {
      final user = await _authService.getSavedUser();
      final userId = int.tryParse('${user?['id']}');
      if (userId != _notificationUserId && mounted) {
        setState(() {
          _notificationUserId = userId;
          _unreadNotificationCount = null;
        });
      }
      if (userId == null) return;
      final count = await _notificationsService.getUnreadCount();
      if (!mounted || userId != _notificationUserId) return;
      setState(() => _unreadNotificationCount = count);
    } catch (_) {
      // Keep the last confirmed count during transient server failures.
    } finally {
      _notificationCountLoading = false;
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          service: _notificationsService,
          onChanged: _refreshNotificationCount,
          onOpenTarget: _openNotificationTarget,
        ),
      ),
    );
    await _refreshNotificationCount();
  }

  Future<void> _openNotificationTarget(Map<String, dynamic> item) async {
    if (!mounted) return;
    Navigator.of(context).pop();
    final type = item['event_type']?.toString();
    if (type == 'friend_request') {
      _selectTab(TripMateTab.friends);
      setState(() => _friendsOpenRequestsVersion++);
      return;
    }
    if (type == 'trip_invitation') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TripInvitationsScreen(
            tripsService: _tripsService,
            authService: _authService,
            onChanged: _refreshNotificationCount,
          ),
        ),
      );
      await _refreshNotificationCount();
      return;
    }

    final isSettlement =
        type == 'settlement_pending' || type == 'settlement_confirmed';
    final tripId = int.tryParse(
      '${isSettlement ? item['context_id'] : item['resource_id']}',
    );
    if (tripId == null) {
      _showUnavailableMessage();
      return;
    }
    try {
      // Current API authorization is authoritative; notification IDs grant no access.
      final trip = await _tripsService.getTrip(tripId);
      if (!mounted) return;
      if (isSettlement) {
        final savedUser = await _authService.getSavedUser();
        if (!mounted) return;
        final currentUserId = int.tryParse('${savedUser?['id']}');
        if (currentUserId == null) {
          _showUnavailableMessage();
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => SettlementsScreen(
              tripId: trip.id,
              participants: trip.acceptedParticipants,
              currentUserId: currentUserId,
              service: _tripsService,
              onFinancialChanged: _refreshNotificationCount,
            ),
          ),
        );
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => TripDetailsScreen(
              tripId: trip.id,
              tripsService: _tripsService,
              authService: _authService,
              onTripChanged: _onTripChanged,
            ),
          ),
        );
      }
      await _refreshNotificationCount();
    } catch (_) {
      if (mounted) _showUnavailableMessage();
    }
  }

  Future<void> _onTripChanged() async {
    await _refreshTrips();
    await _refreshNotificationCount();
  }

  void _showUnavailableMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Este item não está mais disponível ou você não tem acesso.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedTab.index;
    final friendsOwnsBack =
        _selectedTab == TripMateTab.friends && _friendsHasInternalBackState;
    final canHandleTabBack =
        selectedIndex == TripMateTab.home.index || friendsOwnsBack;

    return PopScope<Object?>(
      canPop: canHandleTabBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !friendsOwnsBack && _selectedTab != TripMateTab.home) {
          _selectTab(TripMateTab.home);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: selectedIndex,
          children: [
            HomeScreen(
              showBottomNavigation: false,
              activationVersion: _homeActivationVersion,
              onTripsRefresh: _refreshTrips,
              isLoadingTrips: _loadingTrips,
              tripsError: _tripsError,
              tripsService: _tripsService,
              authService: widget.authService,
              trips: _trips,
              hasUnreadNotifications: (_unreadNotificationCount ?? 0) > 0,
              onNotificationsPressed: _openNotifications,
              onNotificationsRefresh: _refreshNotificationCount,
            ),
            FriendsScreen(
              showBottomNavigation: false,
              isActive: _selectedTab == TripMateTab.friends,
              openRequestsVersion: _friendsOpenRequestsVersion,
              hasUnreadNotifications: (_unreadNotificationCount ?? 0) > 0,
              onNotificationsPressed: _openNotifications,
              onInternalBackStateChanged: (hasState) {
                if (_friendsHasInternalBackState != hasState && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _friendsHasInternalBackState == hasState) {
                      return;
                    }
                    setState(() => _friendsHasInternalBackState = hasState);
                  });
                }
              },
            ),
            ProfileScreen(
              showBottomNavigation: false,
              isActive: _selectedTab == TripMateTab.profile,
              friendsService: widget.friendsService,
              tripsService: _tripsService,
              authService: widget.authService,
              activationVersion: _profileActivationVersion,
              hasUnreadNotifications: (_unreadNotificationCount ?? 0) > 0,
              onNotificationsPressed: _openNotifications,
            ),
          ],
        ),
        bottomNavigationBar: TripMateBottomNavigation(
          selectedTab: _selectedTab,
          onHome: () => _selectTab(TripMateTab.home),
          onFriends: () => _selectTab(TripMateTab.friends),
          onProfile: () => _selectTab(TripMateTab.profile),
        ),
      ),
    );
  }
}
