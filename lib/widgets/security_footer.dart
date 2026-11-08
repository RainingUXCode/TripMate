
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';

class SecurityFooter extends StatelessWidget {
  const SecurityFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          size: 15,
          color: AppTheme.primary,
        ),

        const SizedBox(width: 6),

        Text(
          'Seus dados estão protegidos',
          style: GoogleFonts.manrope(
            fontSize: 10,
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }
}
