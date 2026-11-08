
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

class AuthIntroCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;

  const AuthIntroCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
              ),
            ),
          ),

          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.cardGlow,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.7,
                    color: AppTheme.primary,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 23,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.ink,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  description,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.5,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
