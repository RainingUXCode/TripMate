import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../models/trip.dart';
import 'user_avatar.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  const TripCard({super.key, required this.trip, required this.onTap});

  TextStyle _style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppTheme.ink,
  }) => GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = constraints.maxWidth < 340 ? 88.0 : 108.0;
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            key: ValueKey('trip-card-${trip.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              key: ValueKey('trip-card-surface-${trip.id}'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE4E3EE)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: imageSize),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _cover(imageSize),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(2, 7, 2, 7),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    trip.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: _style(18, weight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 1),
                                        child: Icon(
                                          Icons.location_on_outlined,
                                          size: 14,
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          trip.destination,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: _style(
                                            13,
                                            color: AppTheme.muted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              _participants(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cover(double size) {
    final imageUrl = trip.coverImageUrl?.trim();
    return SizedBox(
      key: ValueKey('trip-card-cover-${trip.id}'),
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _imagePlaceholder(),
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imagePlaceholder(),
              ),
            Positioned(
              left: 5,
              right: 5,
              bottom: 5,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: size - 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatTripDates(trip.startDate, trip.endDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _style(9, weight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    color: const Color(0xFFEAE7F5),
    alignment: Alignment.center,
    child: const Icon(
      Icons.landscape_outlined,
      size: 32,
      color: AppTheme.primary,
    ),
  );

  Widget _participants() {
    final visible = trip.acceptedParticipants.take(3).toList();
    if (visible.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '${trip.acceptedParticipantsCount} ${trip.acceptedParticipantsCount == 1 ? 'participante' : 'participantes'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _style(12, weight: FontWeight.w600, color: AppTheme.muted),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppTheme.primary,
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 20 + (visible.length - 1) * 16,
          height: 20,
          child: Stack(
            children: [
              for (var index = 0; index < visible.length; index++)
                Positioned(
                  left: index * 16,
                  child: UserAvatar(
                    name: visible[index].name,
                    userId: visible[index].id.toString(),
                    imageUrl: visible[index].avatarUrl,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppTheme.primary,
        ),
      ],
    );
  }

  static String _formatTripDates(DateTime start, DateTime end) {
    String date(DateTime value) =>
        '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}';
    return '${date(start)}–${date(end)}';
  }
}
