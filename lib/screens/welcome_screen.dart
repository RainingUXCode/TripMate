
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/tripmate_logo.dart';
import '../widgets/primary_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // Identidade visual do TripMate
  static const Color primary = Color(0xFF634CD4);
  static const Color glow = Color(0xFF9B79EE);
  static const Color ink = Color(0xFF191928);
  static const Color muted = Color(0xFF676874);
  static const Color background = Color(0xFFF7F6FC);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, glow],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;

            // Largura interna após as margens de 20 px.
            final contentWidth = screenWidth - 40;

            // Proporção próxima à imagem original (896 x 1024).
            // Impede que o card fique alto demais e dê zoom.
            final naturalPhotoHeight =
                contentWidth * (1024 / 896);

            // Em telas menores, a foto reduz um pouco.
            // Em telas altas, não ultrapassa a proporção
            // natural, evitando cortes excessivos.
            final photoHeight = naturalPhotoHeight
                .clamp(
              240.0,
              screenHeight < 700 ? 340.0 : 440.0,
            )
                .toDouble();

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20, 10, 20, 24,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                      children: [
                        _header(),

                        const SizedBox(height: 12),

                        SizedBox(
                          height: photoHeight,
                          child: _photo(),
                        ),

                        // Distribui o espaço extra em telas altas,
                        // sem aumentar o zoom da fotografia.

                        const SizedBox(height: 20),

                        _welcomeContent(),

                        const SizedBox(height: 16),

                        _primaryButton(context),

                        const SizedBox(height: 12),

                        _secondaryButton(context),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==================================================
  // CABEÇALHO
  // ==================================================


  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const TripMateLogo(welcomeStyle: true),

          const SizedBox(width: 8),

          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  'PLANEJE • COMPARTILHE • VIAJE',
                  maxLines: 1,
                  softWrap: false,
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ==================================================
  // FOTOGRAFIA PRINCIPAL
  // ==================================================

  Widget _photo() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6626B3)
                .withValues(alpha: 0.18),
            blurRadius: 30,
            spreadRadius: -12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Foto sem distorção e com proporção
            // próxima à imagem original.
            Image.asset(
              'assets/images/welcome.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),

            // Degradê escuro na parte inferior.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xD92D1E3C),
                  ],
                  stops: [0, 0.35, 1],
                ),
              ),
            ),

            // Badge +2 mil grupos
            Positioned(
              top: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 8,
                    sigmaY: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.90,
                      ),
                      borderRadius:
                      BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+2 mil grupos',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Card inferior
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _groupCard(),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================
  // CARD MELHOR EM GRUPO
  // ==================================================

  Widget _groupCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people_outline,
                  color: primary,
                  size: 18,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Melhor em grupo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Planos que todos acompanham',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFE5E3EB),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              SizedBox(
                width: 68,
                height: 28,
                child: Stack(
                  children: [
                    _avatar('MA', primary, 0),
                    _avatar(
                      'JL',
                      const Color(0xFF00B6BE),
                      20,
                    ),
                    _avatar(
                      'AP',
                      const Color(0xFFF47A7D),
                      40,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String label,
      Color color,
      double left,) {
    return Positioned(
      left: left,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ==================================================
  // TEXTOS DE BOAS-VINDAS
  // ==================================================

  Widget _welcomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BEM-VINDO AO TRIPMATE',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: primary,
          ),
        ),

        const SizedBox(height: 9),

        Text(
          'Sua próxima aventura\ncomeça aqui.',
          style: GoogleFonts.manrope(
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.8,
            color: ink,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Planeje viagens em grupo, reúna seus amigos e acompanhe as despesas em um só lugar.',
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: muted,
          ),
        ),
      ],
    );
  }

  // ==================================================
  // BOTÃO COMEÇAR
  // ==================================================


  Widget _primaryButton(BuildContext context) {
    return PrimaryButton(
      label: 'Começar',
      welcomeStyle: true,
      onPressed: () => _navigate(context, '/register'),
    );
  }


  // ==================================================
  // BOTÃO JÁ TENHO UMA CONTA
  // ==================================================

  Widget _secondaryButton(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: () => _navigate(context, '/login'),
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: const Color(0xFF4931A8),
          side: const BorderSide(
            color: Color(0xFFE4E0FE),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Já tenho uma conta',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ==================================================
  // NAVEGAÇÃO TEMPORÁRIA
  // ==================================================


  void _navigate(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }
}
