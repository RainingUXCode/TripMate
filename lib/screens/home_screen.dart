import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/tripmate_bottom_navigation.dart';
import '../widgets/tripmate_header.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/trips_service.dart';
import '../models/trip.dart';
import '../widgets/trip_card.dart';
import 'create_trip_screen.dart';
import 'all_trips_screen.dart';
import 'trip_details_screen.dart';
import 'trip_invitation_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool showBottomNavigation;
  final int activationVersion;
  final Future<void> Function()? onTripsRefresh;
  final bool isLoadingTrips;
  final String? tripsError;
  final TripsService? tripsService;
  final FriendsService? friendsService;
  final AuthService? authService;
  final Future<XFile?> Function()? selectCoverImage;
  final List<Trip> trips;
  final bool hasUnreadNotifications;
  final VoidCallback? onNotificationsPressed;
  final Future<void> Function()? onNotificationsRefresh;

  const HomeScreen({
    super.key,
    this.showBottomNavigation = true,
    this.activationVersion = 0,
    this.onTripsRefresh,
    this.isLoadingTrips = false,
    this.tripsError,
    this.tripsService,
    this.friendsService,
    this.authService,
    this.selectCoverImage,
    this.trips = const [],
    this.hasUnreadNotifications = false,
    this.onNotificationsPressed,
    this.onNotificationsRefresh,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Recupera o primeiro nome enviado pela tela de Login.

  // ==========================================
  // DADOS ATUALIZADOS DO USUÁRIO
  // ==========================================

  late final AuthService _authService = widget.authService ?? AuthService();
  late final TripsService _tripsService = widget.tripsService ?? TripsService();
  late final bool _ownsTripsService = widget.tripsService == null;

  String? _savedName;
  int? _pendingInvitationCount;
  int _invitationRequestGeneration = 0;

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activationVersion != widget.activationVersion) {
      _loadUserName();
      _loadInvitationCount();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadInvitationCount();
  }

  @override
  void dispose() {
    if (_ownsTripsService) _tripsService.close();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    try {
      // Recupera os dados mais recentes salvos
      // pelo AuthService após a edição cadastral.
      final user = await _authService.getSavedUser();

      if (!mounted) return;

      setState(() {
        _savedName = user?['name']?.toString();
      });
    } catch (_) {
      // Mantém o nome anterior caso não seja
      // possível acessar o armazenamento local.
    }
  }

  String _getUserFirstName() {
    // Prioriza o nome atualizado do usuário.
    final savedName = _savedName?.trim();

    if (savedName != null && savedName.isNotEmpty) {
      return savedName.split(RegExp(r'\s+')).first;
    }

    // Compatibilidade com os argumentos enviados
    // anteriormente pela tela de Login.
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is Map && arguments['name'] is String) {
      final fullName = (arguments['name'] as String).trim();

      if (fullName.isNotEmpty) {
        return fullName.split(RegExp(r'\s+')).first;
      }
    }

    return 'viajante';
  }

  Future<void> _openCreateTrip() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateTripScreen(
          tripsService: widget.tripsService,
          friendsService: widget.friendsService,
          authService: widget.authService,
          selectCoverImage: widget.selectCoverImage,
        ),
      ),
    );

    if (!mounted || created != true) return;

    final requestRefresh = widget.onTripsRefresh;
    if (requestRefresh != null) unawaited(requestRefresh());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viagem criada com sucesso.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  TextStyle _style(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = AppTheme.ink,
    double? spacing,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
    );
  }

  double _responsiveCardHeight(BuildContext context) {
    final scaledBodySize = MediaQuery.textScalerOf(context).scale(20);
    return 112 + (scaledBodySize - 20).clamp(0.0, 32.0) * 1.5;
  }

  String _formattedDate() {
    const weekdays = [
      'segunda-feira',
      'terça-feira',
      'quarta-feira',
      'quinta-feira',
      'sexta-feira',
      'sábado',
      'domingo',
    ];

    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    final now = DateTime.now();

    return '${weekdays[now.weekday - 1]}, '
        '${now.day} de ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _refreshTrips,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                _buildGreeting(),
                const SizedBox(height: 20),
                _buildSummaryCards(),
                const SizedBox(height: 24),
                _buildTripsSection(),
                const SizedBox(height: 14),
                _buildInvitationsEntry(),

                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 184,
                    child: PrimaryButton(
                      label: 'Nova viagem',
                      icon: Icons.add_rounded,
                      onPressed: _openCreateTrip,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? TripMateBottomNavigation(
              selectedTab: TripMateTab.home,
              onFriends: () =>
                  Navigator.pushReplacementNamed(context, '/friends'),
              onProfile: () =>
                  Navigator.pushReplacementNamed(context, '/profile'),
            )
          : null,
    );
  }

  Future<void> _refreshTrips() async {
    final refresh = widget.onTripsRefresh;
    if (refresh != null) await refresh();
  }

  Future<void> _loadInvitationCount() async {
    final generation = ++_invitationRequestGeneration;
    try {
      final invitations = await _tripsService.getInvitations();
      if (!mounted || generation != _invitationRequestGeneration) return;
      setState(() => _pendingInvitationCount = invitations.length);
    } catch (_) {
      // Preserve the last server-derived count on temporary failures.
    }
  }

  Widget _buildInvitationsEntry() => Material(
    color: const Color(0xFFF7F6FC),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      key: const ValueKey('trip-invitations-entry'),
      onTap: _openInvitations,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.mail_outline_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Convites de viagem',
                style: _style(13, weight: FontWeight.w700),
              ),
            ),
            if ((_pendingInvitationCount ?? 0) > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_pendingInvitationCount',
                  style: _style(
                    12,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
          ],
        ),
      ),
    ),
  );

  Future<void> _openInvitations() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TripInvitationsScreen(
          tripsService: _tripsService,
          authService: widget.authService,
          onChanged: widget.onTripsRefresh,
        ),
      ),
    );
    if (!mounted) return;
    await _loadInvitationCount();
    await _refreshTrips();
    await widget.onNotificationsRefresh?.call();
  }

  Widget _buildHeader() {
    return TripMateHeader(
      onNotificationsPressed: widget.onNotificationsPressed,
      hasUnreadNotifications: widget.hasUnreadNotifications,
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formattedDate().toUpperCase(),
          style: _style(
            12,
            weight: FontWeight.w700,
            color: AppTheme.primary,
            spacing: 1.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Olá, ${_getUserFirstName()}!',
          style: _style(
            26,
            weight: FontWeight.w600,
            color: const Color(0xFF1E1D2D),
          ).copyWith(height: 1.25),
        ),
        const SizedBox(height: 4),
        Text(
          'Vamos organizar a próxima viagem?',
          style: _style(14, weight: FontWeight.w400, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Gasto em viagens',
            value: 'R\$ 0,00',
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.30),
                  blurRadius: 22,
                  spreadRadius: -10,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryCard(
            icon: Icons.map_outlined,
            title: 'Viagens ativas',
            value:
                '${widget.trips.length} ${widget.trips.length == 1 ? 'viagem' : 'viagens'}',
            decoration: BoxDecoration(
              color: const Color(0xFF1E1D2D),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required BoxDecoration decoration,
  }) {
    return Container(
      height: _responsiveCardHeight(context),
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(13, color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: _style(20, weight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsSection() {
    final recentTrips = widget.trips.take(2).toList(growable: false);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUAS VIAGENS',
                    style: _style(
                      12,
                      weight: FontWeight.w700,
                      color: AppTheme.primary,
                      spacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Viagens em grupo',
                    style: _style(22, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            InkWell(
              key: const ValueKey('all-trips-button'),
              onTap: _openAllTrips,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver todas',
                      style: _style(
                        14,
                        weight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.tripsError != null) _tripErrorMessage(widget.tripsError!),
        if (widget.isLoadingTrips && widget.trips.isEmpty)
          const SizedBox(
            height: 112,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          )
        else if (widget.trips.isEmpty && widget.tripsError != null)
          _retryTripsMessage()
        else if (widget.trips.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F6FC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4E3EE)),
            ),
            child: Text(
              'Você ainda não criou nenhuma viagem.',
              style: _style(14, color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (var index = 0; index < recentTrips.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            TripCard(
              trip: recentTrips[index],
              onTap: () => _openTrip(recentTrips[index]),
            ),
          ],
      ],
    );
  }

  Widget _tripErrorMessage(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 16, color: AppTheme.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _style(12, color: AppTheme.muted),
            ),
          ),
          TextButton(onPressed: _refreshTrips, child: const Text('Tentar')),
        ],
      ),
    );
  }

  Widget _retryTripsMessage() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _refreshTrips,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(
          'Tentar carregar novamente',
          style: _style(13, weight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _openAllTrips() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AllTripsScreen(
          tripsService: _tripsService,
          onTripsRefresh: widget.onTripsRefresh,
          onNotificationsRefresh: widget.onNotificationsRefresh,
        ),
      ),
    );
  }

  Future<void> _openTrip(Trip trip) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TripDetailsScreen(
          tripId: trip.id,
          tripsService: _tripsService,
          onTripChanged: _onTripChanged,
        ),
      ),
    );
  }

  Future<void> _onTripChanged() async {
    await widget.onTripsRefresh?.call();
    await widget.onNotificationsRefresh?.call();
  }
}
