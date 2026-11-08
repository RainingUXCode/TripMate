
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_intro_card.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/security_footer.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ==========================================
  // CADASTRO REAL COM DJANGO
  // ==========================================

  Future<void> _register() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conta criada com sucesso! Faça seu login.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacementNamed(context, '/login');

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // CABEÇALHO
                    const AuthHeader(),

                    const SizedBox(height: 30),

                    // CARD DE APRESENTAÇÃO
                    const AuthIntroCard(
                      eyebrow: 'COMECE SUA JORNADA',
                      title: 'Sua próxima aventura começa aqui!',
                      description:
                      'Crie sua conta e comece a planejar suas viagens.',
                    ),

                    const SizedBox(height: 24),

                    // FORMULÁRIO DE CADASTRO
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                        children: [
                          // NOME
                          _fieldLabel('Nome completo'),

                          const SizedBox(height: 8),

                          AuthTextField(
                            controller: _nameController,
                            hint: 'Como podemos te chamar?',
                            icon: Icons.person_outline,
                            textCapitalization:
                            TextCapitalization.words,
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Informe seu nome.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          // E-MAIL
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

                          const SizedBox(height: 18),

                          // SENHA
                          _fieldLabel('Senha'),

                          const SizedBox(height: 8),

                          AuthTextField(
                            controller: _passwordController,
                            hint: 'Crie uma senha',
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
                                  value.length < 8) {
                                return 'Use pelo menos 8 caracteres.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          // CONFIRMAR SENHA
                          _fieldLabel('Confirmar senha'),

                          const SizedBox(height: 8),

                          AuthTextField(
                            controller: _confirmController,
                            hint: 'Repita sua senha',
                            icon: Icons.lock_outline,
                            obscure: !_showConfirmPassword,
                            suffix: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showConfirmPassword =
                                  !_showConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppTheme.muted,
                                size: 20,
                              ),
                            ),
                            validator: (value) {
                              if (value !=
                                  _passwordController.text) {
                                return 'As senhas não coincidem.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 24),

                          // BOTÃO CRIAR CONTA
                          _registerButton(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // LINK PARA LOGIN
                    _loginLink(context),

                    const SizedBox(height: 32),

                    // RODAPÉ DE SEGURANÇA
                    const SecurityFooter(),
                  ],
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
  // BOTÃO CRIAR CONTA
  // ==========================================

  Widget _registerButton() {
    return PrimaryButton(
      label: _isLoading ? 'Criando conta...' : 'Criar conta',
      onPressed: _register,
    );
  }

  // ==========================================
  // LINK PARA LOGIN
  // ==========================================

  Widget _loginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Já tem uma conta? ',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: AppTheme.muted,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/login');
          },
          child: Text(
            'Entrar',
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
