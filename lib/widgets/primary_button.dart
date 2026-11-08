
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool welcomeStyle;
  final IconData icon;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.welcomeStyle = false,
    this.icon = Icons.chevron_right,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(
          AppTheme.buttonRadius,
        ),
        boxShadow: [
          welcomeStyle
              ? BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.45),
            blurRadius: 25,
            spreadRadius: -10,
            offset: const Offset(0, 14),
          )
              : BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            AppTheme.buttonRadius,
          ),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                icon,
                color: Colors.white,
                size: welcomeStyle ? 18 : 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
