
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_intro_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/security_footer.dart';

// ==========================================
// ETAPAS DA RECUPERAÇÃO DE SENHA
// ==========================================

enum RecoveryStep {
  email,
  verification,
  newPassword,
  success,
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  // ==========================================
  // FORMULÁRIOS E CONTROLADORES
  // ==========================================

  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  RecoveryStep _step = RecoveryStep.email;

  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ==========================================
  // AVANÇAR ENTRE ETAPAS
  // ==========================================

  void _nextStep() {
    switch (_step) {
      case RecoveryStep.email:
        if (!(_emailFormKey.currentState?.validate() ?? false)) {
          return;
        }

        setState(() {
          _step = RecoveryStep.verification;
        });
        break;

      case RecoveryStep.verification:
        if (!(_codeFormKey.currentState?.validate() ?? false)) {
          return;
        }

        setState(() {
          _step = RecoveryStep.newPassword;
        });
        break;

      case RecoveryStep.newPassword:
        if (!(_passwordFormKey.currentState?.validate() ?? false)) {
          return;
        }

        setState(() {
          _step = RecoveryStep.success;
        });
        break;

      case RecoveryStep.success:
        break;
    }
  }

  // ==========================================
  // VOLTAR ENTRE ETAPAS
  // ==========================================

  void _goBack() {
    FocusScope.of(context).unfocus();

    switch (_step) {
      case RecoveryStep.email:
        Navigator.maybePop(context);
        break;

      case RecoveryStep.verification:
        setState(() {
          _step = RecoveryStep.email;
        });
        break;

      case RecoveryStep.newPassword:
        setState(() {
          _step = RecoveryStep.verification;
        });
        break;

      case RecoveryStep.success:
        Navigator.maybePop(context);
        break;
    }
  }

  // ==========================================
  // AVISO DE FUNCIONALIDADE PROTÓTIPO
  // ==========================================

  void _showPrototypeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Protótipo: o envio de códigos por e-mail ainda não está disponível.',
        ),
      ),
    );
  }

  // ==========================================
  // CARD DE APRESENTAÇÃO DINÂMICO
  // ==========================================

  Widget _introCard() {
    String eyebrow;
    String title;
    String description;

    switch (_step) {
      case RecoveryStep.email:
        eyebrow = 'RECUPERE SEU ACESSO';
        title = 'Esqueceu sua senha?';
        description =
        'Informe seu e-mail e enviaremos um código para recuperar sua conta.';
        break;

      case RecoveryStep.verification:
        eyebrow = 'VERIFICAÇÃO DE SEGURANÇA';
        title = 'Confira seu e-mail';
        description =
        'Digite o código de 6 dígitos enviado para o endereço informado.';
        break;

      case RecoveryStep.newPassword:
        eyebrow = 'QUASE LÁ!';
        title = 'Crie uma nova senha';
        description =
        'Escolha uma senha segura para continuar planejando suas aventuras.';
        break;

      case RecoveryStep.success:
        eyebrow = 'TUDO PRONTO!';
        title = 'Senha redefinida!';
        description =
        'Sua nova senha foi configurada. Agora você pode voltar ao login.';
        break;
    }

    return AuthIntroCard(
      eyebrow: eyebrow,
      title: title,
      description: description,
    );
  }

  // ==========================================
  // LABEL DOS CAMPOS
  // ==========================================

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.ink,
      ),
    );
  }

  // ==========================================
  // DECORAÇÃO DO CAMPO DE VERIFICAÇÃO
  // ==========================================

  InputDecoration _inputDecoration(
      String hint,
      IconData icon, {
        Widget? suffix,
      }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        fontSize: 13,
        color: AppTheme.muted,
      ),
      prefixIcon: Icon(
        icon,
        color: AppTheme.muted,
        size: 19,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppTheme.inputBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(AppTheme.fieldRadius),
        borderSide: const BorderSide(
          color: AppTheme.inputBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(AppTheme.fieldRadius),
        borderSide: const BorderSide(
          color: AppTheme.inputBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(AppTheme.fieldRadius),
        borderSide: const BorderSide(
          color: AppTheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(AppTheme.fieldRadius),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(AppTheme.fieldRadius),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  // ==========================================
  // ETAPA 1 — INFORMAR E-MAIL
  // ==========================================

  Widget _emailForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('E-mail'),

          const SizedBox(height: 8),

          AuthTextField(
            controller: _emailController,
            hint: 'seuemail@exemplo.com',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              final email = value?.trim() ?? '';

              if (!RegExp(
                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
              ).hasMatch(email)) {
                return 'Informe um e-mail válido.';
              }

              return null;
            },
          ),

          const SizedBox(height: 24),

          PrimaryButton(
            label: 'Enviar código',
            onPressed: _nextStep,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPA 2 — VERIFICAR CÓDIGO
  // ==========================================

  Widget _verificationForm() {
    return Form(
      key: _codeFormKey,
      child: Column(
        key: const ValueKey('verification'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Código de verificação'),

          const SizedBox(height: 8),

          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: AppTheme.ink,
            ),
            decoration: _inputDecoration(
              '000000',
              Icons.verified_user_outlined,
            ).copyWith(
              counterText: '',
            ),
            validator: (value) {
              if (!RegExp(r'^\d{6}$').hasMatch(value ?? '')) {
                return 'Digite os 6 dígitos do código.';
              }

              return null;
            },
          ),

          const SizedBox(height: 12),

          Center(
            child: TextButton(
              onPressed: _showPrototypeMessage,
              child: Text(
                'Não recebeu? Reenviar código',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          PrimaryButton(
            label: 'Verificar código',
            onPressed: _nextStep,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPA 3 — DEFINIR NOVA SENHA
  // ==========================================

  Widget _passwordForm() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        key: const ValueKey('newPassword'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Nova senha'),

          const SizedBox(height: 8),

          AuthTextField(
            controller: _passwordController,
            hint: 'Digite sua nova senha',
            icon: Icons.lock_outline,
            obscure: !_showPassword,
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  _showPassword = !_showPassword;
                });
              },
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.muted,
                size: 20,
              ),
            ),
            validator: (value) {
              if ((value ?? '').length < 8) {
                return 'A senha deve ter pelo menos 8 caracteres.';
              }

              return null;
            },
          ),

          const SizedBox(height: 20),

          _fieldLabel('Confirmar nova senha'),

          const SizedBox(height: 8),

          AuthTextField(
            controller: _confirmController,
            hint: 'Repita sua nova senha',
            icon: Icons.lock_outline,
            obscure: !_showConfirm,
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  _showConfirm = !_showConfirm;
                });
              },
              icon: Icon(
                _showConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.muted,
                size: 20,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirme sua nova senha.';
              }

              if (value != _passwordController.text) {
                return 'As senhas não coincidem.';
              }

              return null;
            },
          ),

          const SizedBox(height: 24),

          PrimaryButton(
            label: 'Redefinir senha',
            onPressed: _nextStep,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ETAPA 4 — CONFIRMAÇÃO VISUAL
  // ==========================================

  Widget _successView() {
    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        const Icon(
          Icons.check_circle_outline,
          color: AppTheme.primary,
          size: 76,
        ),

        const SizedBox(height: 18),

        Text(
          'Tudo pronto para sua próxima aventura!',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: AppTheme.ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Protótipo visual: nenhuma senha foi alterada.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: AppTheme.muted,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 24),

        PrimaryButton(
          label: 'Voltar para o login',
          onPressed: () => Navigator.maybePop(context),
        ),
      ],
    );
  }

  // ==========================================
  // CONTEÚDO DA ETAPA ATUAL
  // ==========================================

  Widget _currentForm() {
    switch (_step) {
      case RecoveryStep.email:
        return _emailForm();

      case RecoveryStep.verification:
        return _verificationForm();

      case RecoveryStep.newPassword:
        return _passwordForm();

      case RecoveryStep.success:
        return _successView();
    }
  }

  // ==========================================
  // ANIMAÇÃO ENTRE ETAPAS
  // ==========================================

  Widget _animatedContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: _currentForm(),
      ),
    );
  }

  // ==========================================
  // ESTRUTURA PRINCIPAL DA TELA
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 36,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                    children: [
                      // CABEÇALHO
                      AuthHeader(
                        onBack: _goBack,
                      ),

                      const SizedBox(height: 30),

                      // CARD ANIMADO
                      AnimatedSwitcher(
                        duration:
                        const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey('intro-${_step.name}'),
                          child: _introCard(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // FORMULÁRIO ANIMADO
                      _animatedContent(),

                      const Spacer(),

                      const SizedBox(height: 32),

                      // RODAPÉ DE SEGURANÇA
                      const SecurityFooter(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
