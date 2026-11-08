import 'package:flutter/material.dart';

import 'tripmate_back_button.dart';
import 'tripmate_logo.dart';

class AuthHeader extends StatelessWidget {
  final VoidCallback? onBack;

  const AuthHeader({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TripMateBackButton(
          onPressed: onBack ?? () => Navigator.maybePop(context),
        ),

        const Expanded(child: Center(child: TripMateLogo())),

        const SizedBox(width: 48),
      ],
    );
  }
}
