import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

enum TripMateIconButtonStyle { light, glass }

/// Circular 48 dp icon button for secondary-screen and hero headers.
class TripMateIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;
  final TripMateIconButtonStyle style;

  const TripMateIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.tooltip,
    this.style = TripMateIconButtonStyle.light,
  });

  @override
  Widget build(BuildContext context) {
    final isGlass = style == TripMateIconButtonStyle.glass;
    final button = ClipOval(
      child: isGlass
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: _buttonSurface(isGlass: true),
            )
          : _buttonSurface(isGlass: false),
    );

    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(message: tooltip, child: button),
    );
  }

  Widget _buttonSurface({required bool isGlass}) => Material(
    color: isGlass ? Colors.black.withValues(alpha: 0.28) : Colors.white,
    shape: CircleBorder(
      side: BorderSide(
        color: isGlass
            ? Colors.white.withValues(alpha: 0.20)
            : const Color(0xFFE4E3EE),
      ),
    ),
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          icon,
          size: 20,
          color: isGlass ? Colors.white : const Color(0xFF1E1D2D),
        ),
      ),
    ),
  );
}

class TripMateBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final TripMateIconButtonStyle style;

  const TripMateBackButton({
    super.key,
    required this.onPressed,
    this.style = TripMateIconButtonStyle.light,
  });

  @override
  Widget build(BuildContext context) => TripMateIconButton(
    onPressed: onPressed,
    icon: Icons.arrow_back_rounded,
    tooltip: 'Voltar',
    style: style,
  );
}
