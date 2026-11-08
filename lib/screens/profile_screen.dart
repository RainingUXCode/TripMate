import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/trips_service.dart';
import '../widgets/user_avatar.dart';
import 'account_data_screen.dart';
import '../widgets/tripmate_bottom_navigation.dart';
import '../widgets/tripmate_header.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBottomNavigation;
  final bool isActive;
  final FriendsService? friendsService;
  final TripsService? tripsService;
  final AuthService? authService;
  final int activationVersion;
  final bool hasUnreadNotifications;
  final VoidCallback? onNotificationsPressed;

  const ProfileScreen({
    super.key,
    this.showBottomNavigation = true,
    this.isActive = true,
    this.friendsService,
    this.tripsService,
    this.authService,
    this.activationVersion = 0,
    this.hasUnreadNotifications = false,
    this.onNotificationsPressed,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final FriendsService _friendsService =
      widget.friendsService ?? FriendsService();
  late final TripsService _tripsService = widget.tripsService ?? TripsService();
  late final bool _ownsTripsService = widget.tripsService == null;
  final ImagePicker _imagePicker = ImagePicker();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _notificationsKey = 'tripmate_notifications_enabled';

  static const Color _accent = Color(0xFFEEEBFF);
  static const Color _border = Color(0xFFE4E3EE);
  static const Color _danger = Color(0xFFDE3B3D);

  Map<String, dynamic>? _user;
  int? _confirmedFriendCount;
  int? _confirmedTripCount;
  int? _tripCountUserId;
  int _tripCountRequestGeneration = 0;
  bool _loadingFriendCount = false;

  bool _loading = true;
  bool _loggingOut = false;
  bool _uploadingAvatar = false;
  bool _notificationsEnabled = true;
  bool _savingNotifications = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (widget.isActive) {
      _loadFriendCount();
      _loadTripCount();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive &&
        (oldWidget.activationVersion != widget.activationVersion ||
            !oldWidget.isActive)) {
      _loadFriendCount();
      _loadTripCount();
    }
  }

  @override
  void dispose() {
    _tripCountRequestGeneration++;
    if (_ownsTripsService) _tripsService.close();
    super.dispose();
  }

  // ==========================================
  // CARREGAMENTO DO PERFIL
  // ==========================================

  Future<void> _loadProfile() async {
    try {
      // Carrega primeiro os dados armazenados.
      final savedUser = await _authService.getSavedUser();

      final notificationPreference = await _storage.read(
        key: _notificationsKey,
      );

      if (!mounted) return;

      setState(() {
        _user = savedUser;
        _notificationsEnabled = notificationPreference != 'false';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Não foi possível carregar todas as informações.');
    }

    // Depois consulta os dados atualizados no Django.
    try {
      final currentUser = await _authService.getCurrentUser();

      if (!mounted) return;

      setState(() {
        _user = currentUser;
      });
    } catch (_) {
      // Se o servidor estiver temporariamente
      // indisponível, mantém os dados já salvos.
    }
  }

  Future<void> _loadFriendCount() async {
    if (_loadingFriendCount) return;
    _loadingFriendCount = true;

    try {
      final friends = await _friendsService.getFriends();
      if (!mounted) return;

      setState(() => _confirmedFriendCount = friends.length);
    } catch (_) {
      // Keep the last valid count; null remains neutral until first success.
    } finally {
      _loadingFriendCount = false;
    }
  }

  Future<void> _loadTripCount() async {
    final generation = ++_tripCountRequestGeneration;
    try {
      final initialUser = await _authService.getSavedUser();
      final initialUserId = _toUserId(initialUser?['id']);
      if (!mounted || generation != _tripCountRequestGeneration) return;
      if (initialUserId == null) return;

      if (_tripCountUserId != initialUserId) {
        setState(() {
          _tripCountUserId = initialUserId;
          _confirmedTripCount = null;
        });
      }

      final trips = await _tripsService.getTrips();
      final latestUser = await _authService.getSavedUser();
      final latestUserId = _toUserId(latestUser?['id']);
      if (!mounted ||
          generation != _tripCountRequestGeneration ||
          latestUserId != initialUserId) {
        return;
      }

      setState(() {
        _tripCountUserId = initialUserId;
        _confirmedTripCount = trips.length;
      });
    } catch (_) {
      // Keep the last successful value for this account; null renders as —.
    }
  }

  int? _toUserId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String get _fullName {
    final name = _user?['name']?.toString().trim();

    if (name == null || name.isEmpty) {
      return 'Viajante';
    }

    return name;
  }

  String get _email {
    return _user?['email']?.toString() ?? '';
  }

  String? get _avatarUrl {
    final url = _user?['avatar_url']?.toString().trim();

    if (url == null || url.isEmpty) {
      return null;
    }

    return url;
  }

  TextStyle _style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppTheme.ink,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ==========================================
  // SELEÇÃO DE FOTO
  // ==========================================

  Future<void> _showAvatarOptions() async {
    if (_uploadingAvatar || _loggingOut) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto de perfil',
                  style: _style(18, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Escolha como deseja atualizar seu avatar.',
                  style: _style(12, color: AppTheme.muted),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppTheme.primary,
                  ),
                  title: Text(
                    'Escolher da galeria',
                    style: _style(14, weight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAvatar();
                  },
                ),
                if (_avatarUrl != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: _danger,
                    ),
                    title: Text(
                      'Remover foto',
                      style: _style(
                        14,
                        weight: FontWeight.w600,
                        color: _danger,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _removeAvatar();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;

    try {
      final selectedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      // O usuário pode cancelar sem gerar erro.
      if (selectedImage == null || !mounted) return;

      // O backend aceita arquivos de até 2 MB.
      final fileSize = await selectedImage.length();

      if (fileSize > 2 * 1024 * 1024) {
        _showMessage('A imagem deve ter no máximo 2 MB.');
        return;
      }

      setState(() {
        _uploadingAvatar = true;
      });

      final updatedUser = await _authService.uploadAvatar(selectedImage);

      if (!mounted) return;

      setState(() {
        _user = updatedUser;
      });

      _showMessage('Foto de perfil atualizada com sucesso!');
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '');

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
      }
    }
  }

  // ==========================================
  // REMOÇÃO DE FOTO
  // ==========================================

  Future<void> _removeAvatar() async {
    if (_uploadingAvatar) return;

    setState(() {
      _uploadingAvatar = true;
    });

    try {
      final updatedUser = await _authService.removeAvatar();

      if (!mounted) return;

      setState(() {
        _user = updatedUser;
      });

      _showMessage('Foto de perfil removida com sucesso!');
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
      }
    }
  }

  // ==========================================
  // NOTIFICAÇÕES
  // ==========================================

  Future<void> _changeNotifications(bool enabled) async {
    if (_savingNotifications) return;

    setState(() {
      _savingNotifications = true;
    });

    try {
      await _storage.write(key: _notificationsKey, value: enabled.toString());

      if (!mounted) return;

      setState(() {
        _notificationsEnabled = enabled;
      });
    } catch (_) {
      _showMessage('Não foi possível salvar a preferência.');
    } finally {
      if (mounted) {
        setState(() {
          _savingNotifications = false;
        });
      }
    }
  }

  // ==========================================
  // NAVEGAÇÃO
  // ==========================================

  void _goHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ==========================================
  // DADOS CADASTRAIS
  // ==========================================

  Future<void> _openAccountData() async {
    if (_loggingOut || _uploadingAvatar) return;

    final result = await Navigator.of(context).push<AccountDataResult>(
      MaterialPageRoute(builder: (_) => const AccountDataScreen()),
    );

    if (!mounted) return;

    // Após alterar a senha, o AuthService encerra
    // a sessão. Redirecionamos para boas-vindas
    // e removemos as telas autenticadas da navegação.
    if (result == AccountDataResult.passwordChanged) {
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
      return;
    }

    // Ao retornar, atualiza os dados do Perfil
    // com as informações persistidas no Django.
    await _loadProfile();
  }

  // ==========================================
  // LOGOUT
  // ==========================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sair da conta?',
            style: _style(18, weight: FontWeight.w700),
          ),
          content: Text(
            'Você precisará fazer login novamente '
            'para acessar suas viagens.',
            style: _style(13, color: AppTheme.muted),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Cancelar',
                style: _style(
                  13,
                  weight: FontWeight.w600,
                  color: AppTheme.muted,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Sair da conta',
                style: _style(13, weight: FontWeight.w700, color: _danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _loggingOut = true;
    });

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loggingOut = false;
      });

      _showMessage('Não foi possível sair da conta.');
    }
  }

  // ==========================================
  // ESTRUTURA DA TELA
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildProfileCard(),
                    const SizedBox(height: 16),
                    _buildOptions(),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? TripMateBottomNavigation(
              selectedTab: TripMateTab.profile,
              onHome: _goHome,
              onFriends: () =>
                  Navigator.pushReplacementNamed(context, '/friends'),
            )
          : null,
    );
  }

  // ==========================================
  // HEADER
  // ==========================================

  Widget _buildHeader() {
    return TripMateHeader(
      onNotificationsPressed: widget.onNotificationsPressed,
      hasUnreadNotifications: widget.hasUnreadNotifications,
    );
  }

  // ==========================================
  // CARD DO PERFIL
  // ==========================================

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 64,
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(child: _buildProfileAvatar()),
                const SizedBox(height: 12),
                Text(
                  _fullName,
                  textAlign: TextAlign.center,
                  style: _style(22, weight: FontWeight.w600),
                ),
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    textAlign: TextAlign.center,
                    style: _style(
                      14,
                      weight: FontWeight.w400,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStat(
                        _confirmedTripCount?.toString() ?? '—',
                        'Viagens',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStat(
                        _confirmedFriendCount?.toString() ?? '—',
                        'Amigos',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // AVATAR COM BOTÃO DE CÂMERA
  // ==========================================

  Widget _buildProfileAvatar() {
    return SizedBox(
      width: 92,
      height: 86,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 6,
            child: GestureDetector(
              onTap: _uploadingAvatar ? null : _showAvatarOptions,
              child: Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: UserAvatar(
                  name: _fullName,
                  userId: _user?['id']?.toString() ?? _email,
                  imageUrl: _avatarUrl,
                  backgroundColor: AppTheme.primary,
                  size: 76,
                ),
              ),
            ),
          ),

          // Pequeno botão de edição.
          Positioned(
            bottom: 3,
            right: 0,
            child: InkWell(
              onTap: _uploadingAvatar ? null : _showAvatarOptions,
              customBorder: const CircleBorder(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _uploadingAvatar
                    ? const Padding(
                        padding: EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 15,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CONTADORES
  // ==========================================

  Widget _buildStat(String value, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(value, style: _style(18, weight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            label,
            style: _style(13, weight: FontWeight.w400, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // OPÇÕES DO PERFIL
  // ==========================================

  Widget _buildOptions() {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.notifications_none_rounded,
          title: 'Notificações',
          subtitle: 'Ativar ou desativar avisos',
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: _savingNotifications ? null : _changeNotifications,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD4D2DE),
          ),
          onTap: _savingNotifications
              ? null
              : () {
                  _changeNotifications(!_notificationsEnabled);
                },
        ),
        const Divider(height: 1, thickness: 1, color: _border),
        _buildMenuItem(
          icon: Icons.manage_accounts_outlined,
          title: 'Dados cadastrais',
          subtitle: 'Alterar nome, e-mail ou senha',
          trailing: const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppTheme.muted,
          ),
          onTap: _openAccountData,
        ),
        const Divider(height: 1, thickness: 1, color: _border),
        _buildMenuItem(
          icon: Icons.logout_rounded,
          title: _loggingOut ? 'Saindo...' : 'Sair da conta',
          subtitle: 'Voltar para boas-vindas',
          destructive: true,
          onTap: _loggingOut ? null : _logout,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
    bool destructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: destructive ? _danger.withValues(alpha: 0.10) : _accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: destructive ? _danger : AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _style(16, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: _style(
                      13,
                      weight: FontWeight.w400,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
