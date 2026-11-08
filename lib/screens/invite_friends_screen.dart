import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/trips_service.dart';
import '../widgets/tripmate_back_button.dart';
import '../widgets/user_avatar.dart';

class InviteFriendsScreen extends StatefulWidget {
  final Trip trip;
  final TripsService tripsService;
  final FriendsService friendsService;
  final AuthService? authService;

  const InviteFriendsScreen({
    super.key,
    required this.trip,
    required this.tripsService,
    required this.friendsService,
    this.authService,
  });

  @override
  State<InviteFriendsScreen> createState() => _InviteFriendsScreenState();
}

class _InviteFriendsScreenState extends State<InviteFriendsScreen> {
  List<Map<String, dynamic>> _friends = const [];
  late Trip _trip = widget.trip;
  late final AuthService _authService = widget.authService ?? AuthService();
  final Set<int> _selected = {};
  bool _loading = true;
  bool _hasConfirmedFriends = false;
  bool _onlyRejectedFriendsRemain = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFriends(refreshTrip: true);
  }

  Future<void> _loadFriends({bool refreshTrip = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var trip = _trip;
      if (refreshTrip) {
        trip = await widget.tripsService.getTrip(widget.trip.id);
      }
      if (!mounted) return;
      final user = await _authService.getSavedUser();
      final currentUserId = _toId(user?['id']);
      if (currentUserId == null || currentUserId != trip.organizerId) {
        throw const TripsServiceException(
          'Somente o organizador atual pode convidar amigos para esta viagem.',
        );
      }

      final relationships = await widget.friendsService.getFriends();
      final friendsById = <int, Map<String, dynamic>>{};
      for (final relationship in relationships) {
        if (relationship['status']?.toString() != 'accepted') continue;
        final sender = _asMap(relationship['sender']);
        final receiver = _asMap(relationship['receiver']);
        final senderId = _toId(sender['id']);
        final receiverId = _toId(receiver['id']);
        final friend = senderId == currentUserId
            ? receiver
            : receiverId == currentUserId
            ? sender
            : null;
        final friendId = _toId(friend?['id']);
        if (friend == null || friendId == null || friendId == currentUserId) {
          continue;
        }
        friendsById[friendId] = {
          'id': friendId,
          'name': friend['name']?.toString().trim().isNotEmpty == true
              ? friend['name'].toString().trim()
              : 'Viajante',
          'avatar_url': friend['avatar_url']?.toString(),
        };
      }
      final confirmedFriends = friendsById.values.toList(growable: false);
      final excluded = {
        ...trip.acceptedParticipants.map((participant) => participant.id),
        ...trip.pendingInvites.map((participant) => participant.id),
        ...trip.rejectedInvitees.map((participant) => participant.id),
        currentUserId,
      };
      // Memberships with status `left` are intentionally not serialized by the
      // API; its invite endpoint allows those users to be invited again.
      final eligible = confirmedFriends
          .where((friend) => !excluded.contains(_toId(friend['id'])))
          .toList(growable: false);
      final eligibleIds = eligible
          .map((friend) => _toId(friend['id'])!)
          .toSet();
      _selected.removeWhere((id) => !eligibleIds.contains(id));
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _friends = eligible;
        _hasConfirmedFriends = confirmedFriends.isNotEmpty;
        _onlyRejectedFriendsRemain =
            eligible.isEmpty &&
            confirmedFriends.any(
              (friend) => trip.rejectedInvitees.any(
                (participant) => participant.id == _toId(friend['id']),
              ),
            );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _friends = const [];
        _selected.clear();
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  int? _toId(dynamic value) => value is int ? value : int.tryParse('$value');

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  Future<void> _sendInvites() async {
    if (_saving || _selected.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.tripsService.inviteUsers(
        widget.trip.id,
        _selected.toList(growable: false),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      await _loadFriends(refreshTrip: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  TextStyle _style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppTheme.ink,
  }) => GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color);

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
                Text(
                  'Convidar amigos',
                  style: _style(17, weight: FontWeight.w700),
                ),
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
          Expanded(child: _content()),
        ],
      ),
    ),
    bottomNavigationBar: _loading || _error != null || _friends.isEmpty
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: FilledButton(
                onPressed: _saving || _selected.isEmpty ? null : _sendInvites,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Enviar convite${_selected.length == 1 ? '' : 's'} (${_selected.length})',
                        style: _style(
                          14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
  );

  Widget _content() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: _style(14)),
              TextButton(
                onPressed: () => _loadFriends(refreshTrip: true),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            !_hasConfirmedFriends
                ? 'Você ainda não possui amigos para convidar.'
                : _onlyRejectedFriendsRemain
                ? 'Seus amigos restantes recusaram convites anteriores e não podem ser convidados novamente.'
                : 'Todos os seus amigos já participam ou têm um convite pendente.',
            textAlign: TextAlign.center,
            style: _style(14, color: AppTheme.muted),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Text(
          _trip.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _style(20, weight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          'Selecione amigos confirmados para convidar.',
          style: _style(13, color: AppTheme.muted),
        ),
        const SizedBox(height: 16),
        for (final friend in _friends) _friendTile(friend),
      ],
    );
  }

  Widget _friendTile(Map<String, dynamic> friend) {
    final id = _toId(friend['id'])!;
    final name = friend['name']?.toString().trim().isNotEmpty == true
        ? friend['name'].toString().trim()
        : 'Viajante';
    final avatar = friend['avatar_url']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E3EE)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          key: ValueKey('invite-friend-$id'),
          value: _selected.contains(id),
          onChanged: _saving
              ? null
              : (selected) => setState(
                  () => selected == true
                      ? _selected.add(id)
                      : _selected.remove(id),
                ),
          activeColor: AppTheme.primary,
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 3,
          ),
          secondary: UserAvatar(
            name: name,
            userId: id.toString(),
            imageUrl: avatar,
            size: 42,
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(14, weight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
