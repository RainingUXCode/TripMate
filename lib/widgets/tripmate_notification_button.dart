import 'package:flutter/material.dart';

class TripMateNotificationButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool hasUnreadNotifications;

  const TripMateNotificationButton({
    super.key,
    required this.onPressed,
    this.hasUnreadNotifications = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E3EE)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 20,
              color: Color(0xFF1E1D2D),
            ),
            if (hasUnreadNotifications)
              Positioned(
                top: 8,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDE3B3D),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
