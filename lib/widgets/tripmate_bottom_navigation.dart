import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

enum TripMateTab { home, friends, profile }

class TripMateBottomNavigation extends StatelessWidget {
  final TripMateTab selectedTab;
  final VoidCallback? onHome;
  final VoidCallback? onFriends;
  final VoidCallback? onProfile;

  const TripMateBottomNavigation({
    super.key,
    required this.selectedTab,
    this.onHome,
    this.onFriends,
    this.onProfile,
  });

  static const Color _accent = Color(0xFFEEEBFF);
  static const Color _border = Color(0xFFE4E3EE);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 2, 24, 2),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navigationItem(
              icon: selectedTab == TripMateTab.home
                  ? Icons.home_rounded
                  : Icons.home_outlined,
              label: 'Início',
              selected: selectedTab == TripMateTab.home,
              onTap: onHome,
            ),
            _navigationItem(
              icon: Icons.people_outline_rounded,
              label: 'Amigos',
              selected: selectedTab == TripMateTab.friends,
              onTap: onFriends,
            ),
            _navigationItem(
              icon: Icons.person_outline_rounded,
              label: 'Perfil',
              selected: selectedTab == TripMateTab.profile,
              onTap: onProfile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigationItem({
    required IconData icon,
    required String label,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 40,
              decoration: BoxDecoration(
                color: selected ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 26,
                color: selected ? AppTheme.primary : AppTheme.muted,
              ),
            ),
            const SizedBox(height: 0),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppTheme.primary : AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
