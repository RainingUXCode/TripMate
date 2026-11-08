import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? userId;
  final Color? backgroundColor;
  final double size;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.userId,
    this.backgroundColor,
    this.size = 24,
  });

  // Paleta de avatares do TripMate.
  static const List<Color> _colors = [
    Color(0xFF634CD4), // Roxo
    Color(0xFF00B6BE), // Turquesa
    Color(0xFFF47A7D), // Coral
    Color(0xFFE6AC3D), // Âmbar
    Color(0xFF648BD8), // Azul
    Color(0xFF6DAF85), // Verde
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts.first.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color get _avatarColor {
    // Permite definir uma cor específica para o usuário.
    if (backgroundColor != null) {
      return backgroundColor!;
    }

    // Caso contrário, escolhe uma cor consistente
    // com base no identificador do usuário.
    final identifier = userId ?? name;

    final sum = identifier.runes.fold<int>(0, (total, rune) => total + rune);

    return _colors[sum % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackSurface(),
              )
            else
              _fallbackSurface(),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackSurface() =>
      ColoredBox(color: _avatarColor, child: _fallback());

  Widget _fallback() {
    return Center(
      child: Text(
        _initials,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: size <= 24 ? 8 : size * 0.25,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
