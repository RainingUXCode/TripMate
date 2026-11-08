
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

class TripMateLogo extends StatelessWidget {
  final bool welcomeStyle;

  const TripMateLogo({
    super.key,
    this.welcomeStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.send_rounded,
            color: Colors.white,
            size: welcomeStyle ? 18 : 17,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'TripMate',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: welcomeStyle ? -0.6 : null,
            color: AppTheme.ink,
          ),
        ),
      ],
    );
  }
}
