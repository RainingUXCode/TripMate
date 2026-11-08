import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../services/auth_service.dart';
import '../services/trips_service.dart';
import '../widgets/tripmate_back_button.dart';
import '../widgets/user_avatar.dart';
import 'trip_details_screen.dart';

class TripInvitationsScreen extends StatefulWidget {
  final TripsService? tripsService;
  final AuthService? authService;
  final Future<void> Function()? onChanged;

  const TripInvitationsScreen({
    super.key,
    this.tripsService,
    this.authService,
    this.onChanged,
  });

  @override
  State<TripInvitationsScreen> createState() => _TripInvitationsScreenState();
}

class _TripInvitationsScreenState extends State<TripInvitationsScreen> {
  late final TripsService _service = widget.tripsService ?? TripsService();
  late final bool _ownsService = widget.tripsService == null;
  List<TripInvitation> _invitations = const [];
  bool _loading = true;
  final Set<int> _busyIds = {};
  final Set<int> _uncertainIds = {};
  String? _error;
  bool _lastLoadSucceeded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_ownsService) _service.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _lastLoadSucceeded = false;
    });
    try {
      final invitations = await _service.getInvitations();
      if (!mounted) return;
      setState(() {
        _invitations = invitations;
        _loading = false;
        _lastLoadSucceeded = true;
        _uncertainIds.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _loading = false;
        _lastLoadSucceeded = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is TripsServiceException && error.statusCode == 404) {
      return 'Este convite já foi respondido ou não está mais disponível.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _respond(
    TripInvitation invitation, {
    required bool accept,
  }) async {
    if (!_busyIds.add(invitation.tripId)) return;
    setState(() {});
    try {
      await _service.respondToInvitation(invitation.tripId, accept: accept);
      if (!mounted) return;
      setState(() {
        _invitations = _invitations
            .where((item) => item.tripId != invitation.tripId)
            .toList(growable: false);
        _busyIds.remove(invitation.tripId);
      });
      await widget.onChanged?.call();
      if (!mounted) return;
      if (!accept) {
        _message('Convite recusado.');
        return;
      }
      final openTrip = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Convite aceito', style: _style(18, FontWeight.w700)),
          content: Text(
            'Agora você pode acessar os detalhes de ${invitation.name}.',
            style: _style(14, FontWeight.w400),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Continuar', style: _style(14, FontWeight.w600)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Abrir viagem',
                style: _style(14, FontWeight.w700, Colors.white),
              ),
            ),
          ],
        ),
      );
      if (openTrip == true && mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => TripDetailsScreen(
              tripId: invitation.tripId,
              tripsService: widget.tripsService,
              authService: widget.authService,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
      });
      _message(_error!);
      // Recheck the server before enabling another attempt. This also handles
      // a timeout where the write may have reached the backend.
      await _load();
      if (mounted) {
        setState(() {
          _busyIds.remove(invitation.tripId);
          if (!_lastLoadSucceeded &&
              _invitations.any((item) => item.tripId == invitation.tripId)) {
            _uncertainIds.add(invitation.tripId);
          }
        });
      }
    }
  }

  Future<void> _confirmReject(TripInvitation invitation) async {
    final reject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recusar convite?', style: _style(18, FontWeight.w700)),
        content: Text(
          'Você poderá pedir ao organizador para convidar novamente.',
          style: _style(14, FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Voltar', style: _style(14, FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Recusar',
              style: _style(14, FontWeight.w700, const Color(0xFFDE3B3D)),
            ),
          ),
        ],
      ),
    );
    if (reject == true) await _respond(invitation, accept: false);
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
  );

  TextStyle _style(
    double size,
    FontWeight weight, [
    Color color = AppTheme.ink,
  ]) => GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color);

  String _dateRange(TripInvitation invitation) {
    const months = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];
    final start = invitation.startDate;
    final end = invitation.endDate;
    return '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F6FC),
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text('Convites de viagem', style: _style(17, FontWeight.w700)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: TripMateBackButton(
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E3EE)),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: _content(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _content() {
    if (_loading && _invitations.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 300,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          ),
        ],
      );
    }
    if (_error != null && _invitations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 130),
          const Icon(Icons.cloud_off_outlined, size: 40, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: _style(14, FontWeight.w500),
          ),
          TextButton(onPressed: _load, child: const Text('Tentar novamente')),
        ],
      );
    }
    if (_invitations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 130),
          const Icon(
            Icons.mail_outline_rounded,
            size: 42,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum convite pendente',
            textAlign: TextAlign.center,
            style: _style(17, FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            'Quando alguém convidar você para uma viagem, ela aparecerá aqui.',
            textAlign: TextAlign.center,
            style: _style(13, FontWeight.w400, AppTheme.muted),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemCount: _invitations.length + (_error == null ? 1 : 2),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Convites pendentes',
              style: _style(21, FontWeight.w700),
            ),
          );
        }
        if (_error != null && index == 1) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  _error!,
                  style: _style(12, FontWeight.w500, AppTheme.muted),
                ),
              ),
              TextButton(onPressed: _load, child: const Text('Tentar')),
            ],
          );
        }
        final invitationIndex = index - (_error == null ? 1 : 2);
        final invitation = _invitations[invitationIndex];
        return _invitationCard(invitation);
      },
    );
  }

  Widget _invitationCard(TripInvitation invitation) {
    final busy = _busyIds.contains(invitation.tripId);
    final uncertain = _uncertainIds.contains(invitation.tripId);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E3EE)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: .04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: invitation.coverImageUrl == null
                      ? const ColoredBox(
                          color: Color(0xFFEEEBFF),
                          child: Icon(
                            Icons.flight_takeoff_rounded,
                            color: AppTheme.primary,
                            size: 30,
                          ),
                        )
                      : Image.network(
                          invitation.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Color(0xFFEEEBFF),
                            child: Icon(
                              Icons.flight_takeoff_rounded,
                              color: AppTheme.primary,
                              size: 30,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _style(16, FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      invitation.destination,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _style(13, FontWeight.w400, AppTheme.muted),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _dateRange(invitation),
                      style: _style(12, FontWeight.w600, AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (uncertain) ...[
            Text(
              'Não foi possível confirmar o resultado. Atualize os convites antes de responder novamente.',
              style: _style(12, FontWeight.w500, AppTheme.muted),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              UserAvatar(
                name: invitation.organizer.name,
                userId: invitation.organizer.id.toString(),
                imageUrl: invitation.organizer.avatarUrl,
                size: 34,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Convidado por ${invitation.organizer.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _style(12, FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy || uncertain
                      ? null
                      : () => _confirmReject(invitation),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppTheme.muted,
                    side: const BorderSide(color: Color(0xFFE4E3EE)),
                  ),
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Recusar', style: _style(13, FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: ValueKey('trip-invitation-accept-${invitation.tripId}'),
                  onPressed: busy || uncertain
                      ? null
                      : () => _respond(invitation, accept: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppTheme.primary,
                  ),
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Aceitar',
                          style: _style(13, FontWeight.w700, Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
