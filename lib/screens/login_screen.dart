
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_intro_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/security_footer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================
  // AUTENTICAÇÃO REAL COM DJANGO
  // ==========================================

  Future<void> _login() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final user = result['user'] as Map<String, dynamic>;
      final name = user['name'] ?? 'viajante';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bem-vindo(a), $name!'),
          backgroundColor: Colors.green,
        ),
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
            (route) => false,
        arguments: {
          'name': name,
        },
      );

    } catch (error) {
      if (!mounted) return;

      final message = error
          .toString()
          .replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 36,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CABEÇALHO
                      const AuthHeader(),

                      const SizedBox(height: 30),

                      // CARD DE BOAS-VINDAS
                      const AuthIntroCard(
                        eyebrow: 'BEM-VINDO DE VOLTA',
                        title: 'Que bom ter você de volta!',
                        description:
                        'Entre para continuar planejando suas aventuras.',
                      ),

                      const SizedBox(height: 24),

                      // FORMULÁRIO DE LOGIN
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                          children: [
                            _fieldLabel('E-mail'),

                            const SizedBox(height: 8),

                            AuthTextField(
                              controller: _emailController,
                              hint: 'seuemail@exemplo.com',
                              icon: Icons.mail_outline,
                              keyboardType:
                              TextInputType.emailAddress,
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

                            const SizedBox(height: 20),

                            _fieldLabel('Senha'),

                            const SizedBox(height: 8),

                            AuthTextField(
                              controller: _passwordController,
                              hint: 'Digite sua senha',
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
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'Informe sua senha.';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            // ESQUECI MINHA SENHA
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                child: Text(
                                  'Esqueci minha senha',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // BOTÃO ENTRAR
                            _loginButton(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // LINK PARA CADASTRO
                      _registerLink(context),

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
  // BOTÃO ENTRAR
  // ==========================================

  Widget _loginButton() {
    return PrimaryButton(
      label: _isLoading ? 'Entrando...' : 'Entrar',
      onPressed: _login,
    );
  }

  // ==========================================
  // RECUPERAÇÃO DE SENHA
  // ==========================================

  void _forgotPassword() {
    Navigator.pushNamed(context, '/forgot-password');
  }

  // ==========================================
  // LINK PARA CADASTRO
  // ==========================================

  Widget _registerLink(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Ainda não tem uma conta? ',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: AppTheme.muted,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, '/register');
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Cadastre-se',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
