import 'package:flutter/material.dart';

import 'tripmate_logo.dart';
import 'tripmate_notification_button.dart';

/// Consistent header for the authenticated primary screens.
class TripMateHeader extends StatelessWidget {
  final VoidCallback? onNotificationsPressed;
  final bool hasUnreadNotifications;

  const TripMateHeader({
    super.key,
    this.onNotificationsPressed,
    this.hasUnreadNotifications = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const TripMateLogo(),
          if (onNotificationsPressed case final onPressed?)
            TripMateNotificationButton(
              onPressed: onPressed,
              hasUnreadNotifications: hasUnreadNotifications,
            )
          else
            const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }
}
