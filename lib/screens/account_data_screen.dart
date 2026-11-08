
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/tripmate_back_button.dart';

enum AccountDataResult {
  passwordChanged,
}

class AccountDataScreen extends StatefulWidget {
  const AccountDataScreen({super.key});

  @override
  State<AccountDataScreen> createState() =>
      _AccountDataScreenState();
}

class _AccountDataScreenState
    extends State<AccountDataScreen> {
  final AuthService _authService = AuthService();

  final _accountFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailPasswordController = TextEditingController();

  final _currentPasswordController =
  TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController =
  TextEditingController();

  bool _loading = true;
  bool _savingAccount = false;
  bool _savingPassword = false;

  bool _showEmailPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  String _originalEmail = '';

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _emailPasswordController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    try {
      final user = await _authService.getCurrentUser();

      if (!mounted) return;

      _nameController.text =
          user['name']?.toString() ?? '';

      _emailController.text =
          user['email']?.toString() ?? '';

      _originalEmail =
          _emailController.text.trim().toLowerCase();
    } catch (_) {
      final savedUser = await _authService.getSavedUser();

      if (!mounted) return;

      _nameController.text =
          savedUser?['name']?.toString() ?? '';

      _emailController.text =
          savedUser?['email']?.toString() ?? '';

      _originalEmail =
          _emailController.text.trim().toLowerCase();

      _showMessage(
        'Não foi possível atualizar os dados do servidor.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    final cleanMessage = message.replaceFirst(
      RegExp(r'^Exception:\s*'),
      '',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleanMessage),
        backgroundColor: isError
            ? const Color(0xFFC74D62)
            : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAccount() async {
    if (!_accountFormKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final email =
    _emailController.text.trim().toLowerCase();

    final emailChanged = email != _originalEmail;

    if (emailChanged &&
        _emailPasswordController.text.isEmpty) {
      _showMessage(
        'Informe sua senha atual para alterar o e-mail.',
        isError: true,
      );
      return;
    }

    setState(() => _savingAccount = true);

    try {
      final user = await _authService.updateAccount(
        name: name,
        email: email,
        currentPassword: emailChanged
            ? _emailPasswordController.text
            : null,
      );

      if (!mounted) return;

      setState(() {
        _nameController.text =
            user['name']?.toString() ?? name;

        _emailController.text =
            user['email']?.toString() ?? email;

        _originalEmail =
            _emailController.text.trim().toLowerCase();

        _emailPasswordController.clear();
      });

      _showMessage(
        'Dados cadastrais atualizados com sucesso!',
      );
    } catch (error) {
      _showMessage(
        error.toString(),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _savingAccount = false);
      }
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _savingPassword = true);

    try {
      await _authService.changePassword(
        currentPassword:
        _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword:
        _confirmPasswordController.text,
      );

      if (!mounted) return;

      // O AuthService já encerra a sessão local.
      // A tela Perfil tratará o retorno ao Login.
      Navigator.of(context).pop(
        AccountDataResult.passwordChanged,
      );
    } catch (error) {
      _showMessage(
        error.toString(),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _savingPassword = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        color: AppTheme.muted,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: AppTheme.primary,
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8F7FC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE9E6F1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE9E6F1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppTheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.ink,
        ),
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEEEBFF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: AppTheme.primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradientButton({
    required String label,
    required VoidCallback onPressed,
    required bool loading,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(
              alpha: 0.16,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _passwordVisibilityButton({
    required bool visible,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        visible
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        color: AppTheme.muted,
        size: 20,
      ),
    );
  }

  Widget _accountSection() {
    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.person_outline_rounded,
            title: 'Informações pessoais',
            subtitle:
            'Mantenha seus dados sempre atualizados.',
          ),
          const SizedBox(height: 24),

          _fieldLabel('Nome completo'),
          TextFormField(
            controller: _nameController,
            textCapitalization:
            TextCapitalization.words,
            decoration: _inputDecoration(
              hint: 'Seu nome completo',
              icon: Icons.badge_outlined,
            ),
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Informe seu nome completo.';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          _fieldLabel('E-mail'),
          TextFormField(
            controller: _emailController,
            keyboardType:
            TextInputType.emailAddress,
            autocorrect: false,
            decoration: _inputDecoration(
              hint: 'seuemail@exemplo.com',
              icon: Icons.mail_outline_rounded,
            ),
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) {
                return 'Informe seu e-mail.';
              }

              if (!RegExp(
                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
              ).hasMatch(email)) {
                return 'Informe um e-mail válido.';
              }

              return null;
            },
          ),

          const SizedBox(height: 20),

          _fieldLabel(
            'Senha atual (para alterar o e-mail)',
          ),
          TextFormField(
            controller: _emailPasswordController,
            obscureText: !_showEmailPassword,
            decoration: _inputDecoration(
              hint: 'Necessária apenas ao trocar o e-mail',
              icon: Icons.lock_outline_rounded,
              suffixIcon: _passwordVisibilityButton(
                visible: _showEmailPassword,
                onPressed: () {
                  setState(() {
                    _showEmailPassword =
                    !_showEmailPassword;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          _gradientButton(
            label: 'Salvar alterações',
            loading: _savingAccount,
            onPressed: _saveAccount,
          ),
        ],
      ),
    );
  }

  Widget _passwordSection() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.lock_outline_rounded,
            title: 'Alterar senha',
            subtitle:
            'Escolha uma senha segura para proteger sua conta.',
          ),
          const SizedBox(height: 24),

          _fieldLabel('Senha atual'),
          TextFormField(
            controller: _currentPasswordController,
            obscureText: !_showCurrentPassword,
            decoration: _inputDecoration(
              hint: 'Digite sua senha atual',
              icon: Icons.lock_outline_rounded,
              suffixIcon: _passwordVisibilityButton(
                visible: _showCurrentPassword,
                onPressed: () {
                  setState(() {
                    _showCurrentPassword =
                    !_showCurrentPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Informe a senha atual.';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          _fieldLabel('Nova senha'),
          TextFormField(
            controller: _newPasswordController,
            obscureText: !_showNewPassword,
            decoration: _inputDecoration(
              hint: 'Pelo menos 8 caracteres',
              icon: Icons.key_outlined,
              suffixIcon: _passwordVisibilityButton(
                visible: _showNewPassword,
                onPressed: () {
                  setState(() {
                    _showNewPassword =
                    !_showNewPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Informe a nova senha.';
              }

              if (value.length < 8) {
                return 'Use pelo menos 8 caracteres.';
              }

              return null;
            },
          ),

          const SizedBox(height: 20),

          _fieldLabel('Confirmar nova senha'),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            decoration: _inputDecoration(
              hint: 'Repita a nova senha',
              icon: Icons.verified_user_outlined,
              suffixIcon: _passwordVisibilityButton(
                visible: _showConfirmPassword,
                onPressed: () {
                  setState(() {
                    _showConfirmPassword =
                    !_showConfirmPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirme sua nova senha.';
              }

              if (value != _newPasswordController.text) {
                return 'As senhas não coincidem.';
              }

              return null;
            },
          ),

          const SizedBox(height: 24),

          _gradientButton(
            label: 'Alterar senha',
            loading: _savingPassword,
            onPressed: _savePassword,
          ),

          const SizedBox(height: 12),

          Text(
            'Por segurança, você precisará entrar novamente após alterar a senha.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: AppTheme.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Center(
          child: TripMateBackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Text(
          'Dados cadastrais',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primary,
        ),
      )
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            40,
          ),
          child: Column(
            children: [
              _accountSection(),
              const SizedBox(height: 30),
              const Divider(
                color: Color(0xFFECEAF2),
              ),
              const SizedBox(height: 30),
              _passwordSection(),
            ],
          ),
        ),
      ),
    );
  }
}
