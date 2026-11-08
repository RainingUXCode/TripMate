import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../widgets/tripmate_back_button.dart';
import '../widgets/user_avatar.dart';

class TripManagementScreen extends StatelessWidget {
  const TripManagementScreen({
    super.key,
    required this.trip,
    required this.currentUserId,
    this.leaveOutcomeUnknown = false,
    required this.onTransferOrganizer,
    required this.onLeaveTrip,
    required this.onDeleteTrip,
    required this.onRemoveParticipant,
    required this.onRefreshTrip,
  });

  final Trip trip;
  final int currentUserId;
  final bool leaveOutcomeUnknown;
  final VoidCallback onTransferOrganizer;
  final VoidCallback onLeaveTrip;
  final VoidCallback onDeleteTrip;
  final ValueChanged<TripParticipant> onRemoveParticipant;
  final VoidCallback onRefreshTrip;

  bool get _isOrganizer => currentUserId == trip.organizerId;

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
                  'Gerenciar viagem',
                  style: _style(17, weight: FontWeight.w700),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: TripMateBackButton(
                      key: const ValueKey('trip-management-back'),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E3EE)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                Text(
                  trip.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _style(20, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  trip.destination,
                  style: _style(13, color: AppTheme.muted),
                ),
                if (leaveOutcomeUnknown) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE4E3EE)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'O resultado da saída ainda não foi confirmado.',
                          style: _style(13, weight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          onPressed: onRefreshTrip,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            'Atualizar viagem',
                            style: _style(
                              13,
                              weight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isOrganizer && !leaveOutcomeUnknown) ...[
                  const SizedBox(height: 22),
                  _sectionTitle('Participantes'),
                  const SizedBox(height: 8),
                  for (final participant in trip.acceptedParticipants)
                    _participantRow(participant),
                  if (trip.pendingInvites.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sectionTitle('Convites pendentes'),
                    const SizedBox(height: 8),
                    for (final participant in trip.pendingInvites)
                      _pendingRow(participant),
                  ],
                  const SizedBox(height: 22),
                  _sectionTitle('Organização'),
                  const SizedBox(height: 8),
                  _actionButton(
                    key: const ValueKey('management-transfer-organizer'),
                    icon: Icons.swap_horiz_rounded,
                    label: 'Transferir organização',
                    onPressed: onTransferOrganizer,
                  ),
                  const SizedBox(height: 22),
                  _sectionTitle('Ações da viagem'),
                  const SizedBox(height: 8),
                  if (trip.canDelete)
                    _actionButton(
                      key: const ValueKey('management-delete-trip'),
                      icon: Icons.delete_outline_rounded,
                      label: 'Excluir viagem',
                      destructive: true,
                      onPressed: onDeleteTrip,
                    ),
                ],
                const SizedBox(height: 12),
                if (!leaveOutcomeUnknown)
                  _actionButton(
                    key: const ValueKey('management-leave-trip'),
                    icon: Icons.logout_rounded,
                    label: 'Sair da viagem',
                    destructive: true,
                    onPressed: onLeaveTrip,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String text) => Text(
    text,
    style: _style(14, weight: FontWeight.w700, color: AppTheme.ink),
  );

  Widget _participantRow(TripParticipant participant) {
    final isSelf = participant.id == currentUserId;
    return Container(
      key: ValueKey('management-participant-${participant.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E3EE)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: UserAvatar(
          name: participant.name,
          userId: participant.id.toString(),
          imageUrl: participant.avatarUrl,
          size: 40,
        ),
        title: Text(
          participant.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style(13, weight: FontWeight.w700),
        ),
        subtitle: Text(
          isSelf ? 'Organizador' : 'Participante aceito',
          style: _style(11, color: AppTheme.muted),
        ),
        trailing: isSelf
            ? null
            : IconButton(
                key: ValueKey('management-remove-${participant.id}'),
                tooltip: 'Remover ${participant.name}',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFDE3B3D)
                      .withValues(alpha: 0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.person_remove_alt_1_rounded,
                  size: 18,
                  color: Color(0xFFDE3B3D),
                ),
                onPressed: () => onRemoveParticipant(participant),
              ),
      ),
    );
  }

  Widget _pendingRow(TripParticipant participant) => Container(
    key: ValueKey('management-pending-${participant.id}'),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE4E3EE)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: UserAvatar(
        name: participant.name,
        userId: participant.id.toString(),
        imageUrl: participant.avatarUrl,
        size: 40,
      ),
      title: Text(
        participant.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _style(13, weight: FontWeight.w700),
      ),
      subtitle: Text(
        'Aguardando resposta',
        style: _style(11, color: AppTheme.muted),
      ),
    ),
  );

  Widget _actionButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool destructive = false,
  }) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      key: key,
      onPressed: onPressed,
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: destructive
              ? const Color(0xFFDE3B3D).withValues(alpha: 0.10)
              : const Color(0xFFEEEBFF),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: destructive ? const Color(0xFFDE3B3D) : AppTheme.primary,
        ),
      ),
      label: Text(
        label,
        style: _style(13, weight: FontWeight.w700, color: AppTheme.ink),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        foregroundColor: AppTheme.ink,
        side: const BorderSide(color: Color(0xFFE4E3EE)),
      ),
    ),
  );
}
