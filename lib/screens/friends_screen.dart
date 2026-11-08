import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:async';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/tripmate_bottom_navigation.dart';
import '../widgets/tripmate_back_button.dart';
import '../widgets/tripmate_header.dart';

class FriendsScreen extends StatefulWidget {
  final bool showBottomNavigation;
  final bool isActive;
  final ValueChanged<bool>? onInternalBackStateChanged;
  final bool hasUnreadNotifications;
  final VoidCallback? onNotificationsPressed;
  final int openRequestsVersion;

  const FriendsScreen({
    super.key,
    this.showBottomNavigation = true,
    this.isActive = true,
    this.onInternalBackStateChanged,
    this.hasUnreadNotifications = false,
    this.onNotificationsPressed,
    this.openRequestsVersion = 0,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendsService _friendsService = FriendsService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  int? _currentUserId;

  bool _loading = true;
  bool _searching = false;
  bool _processing = false;
  bool _searchMode = false;
  bool _showRequests = false;
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  final List<DateTime> _searchRequestTimes = [];

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _received = [];
  List<Map<String, dynamic>> _sent = [];
  List<Map<String, dynamic>> _searchResults = [];

  String? _searchError;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusChanged);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant FriendsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openRequestsVersion != oldWidget.openRequestsVersion) {
      _openRequests();
    }
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  void _notifyInternalBackState() {
    widget.onInternalBackStateChanged?.call(_searchMode || _showRequests);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  TextStyle _style(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = AppTheme.ink,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceFirst(RegExp(r'^Exception:\s*'), '')),
        backgroundColor: error ? const Color(0xFFC74D62) : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================
  // CARREGAMENTO DOS DADOS
  // ==========================================

  Future<void> _loadData({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) setState(() => _loading = true);

    try {
      final user = await _authService.getSavedUser();
      final friends = await _friendsService.getFriends();
      final requests = await _friendsService.getRequests();

      if (!mounted) return;

      setState(() {
        _currentUserId = int.tryParse('${user?['id'] ?? ''}');

        _friends = friends;

        _received = _toMapList(requests['received']);
        _sent = _toMapList(requests['sent']);

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showMessage(error.toString(), error: true);
    }
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) return [];

    return value.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Map<String, dynamic> _userFrom(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  int? _idOf(dynamic value) {
    return int.tryParse('$value');
  }

  // ==========================================
  // BUSCA DE PESSOAS
  // ==========================================

  void _enterSearch() {
    setState(() {
      _searchMode = true;
      _showRequests = false;
    });
    _notifyInternalBackState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _cancelSearch() {
    _searchDebounce?.cancel();
    _searchGeneration++;
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _searchMode = false;
      _searching = false;
      _searchResults = [];
      _searchError = null;
    });
    _notifyInternalBackState();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    final generation = ++_searchGeneration;
    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        _searching = false;
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
      _searchResults = [];
    });
    _searchDebounce = Timer(const Duration(milliseconds: 475), () {
      _searchUsers(query, generation);
    });
  }

  Future<void> _searchUsers(String query, int generation) async {
    final now = DateTime.now();
    _searchRequestTimes.removeWhere(
      (requestedAt) => now.difference(requestedAt) >= const Duration(hours: 1),
    );
    if (_searchRequestTimes.length >= 25) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searching = false;
        _searchError = 'Limite temporário de pesquisas atingido. Tente novamente mais tarde.';
      });
      return;
    }
    _searchRequestTimes.add(now);

    try {
      final results = await _friendsService.searchUsers(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchResults = [];
        _searching = false;
        _searchError = error.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        );
      });
    }
  }

  // ==========================================
  // AÇÕES DE AMIZADE
  // ==========================================

  Future<void> _performAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_processing) return;

    setState(() => _processing = true);

    try {
      await action();

      if (!mounted) return;

      await _loadData(showLoading: false);

      if (!mounted) return;

      if (_searchMode && _searchController.text.trim().length >= 2) {
        _scheduleSearch(_searchController.text);
      }

      _showMessage(successMessage);
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _sendRequest(int userId) {
    return _performAction(() async {
      await _friendsService.sendFriendRequest(userId);
    }, 'Solicitação de amizade enviada!');
  }

  Future<void> _acceptRequest(int friendshipId) {
    return _performAction(() async {
      await _friendsService.acceptFriendRequest(friendshipId);
    }, 'Solicitação aceita!');
  }

  Future<void> _rejectRequest(int friendshipId) {
    return _performAction(() async {
      await _friendsService.rejectFriendRequest(friendshipId);
    }, 'Solicitação recusada.');
  }

  Future<void> _deleteFriendship(int friendshipId, String message) {
    return _performAction(() async {
      await _friendsService.deleteFriendship(friendshipId);
    }, message);
  }

  // ==========================================
  // ESTADO DA AMIZADE NA BUSCA
  // ==========================================

  Map<String, dynamic>? _friendshipWith(int userId) {
    final all = [..._friends, ..._received, ..._sent];

    for (final friendship in all) {
      final sender = _userFrom(friendship['sender']);
      final receiver = _userFrom(friendship['receiver']);

      if (_idOf(sender['id']) == userId || _idOf(receiver['id']) == userId) {
        return friendship;
      }
    }

    return null;
  }

  // ==========================================
  // ELEMENTOS VISUAIS
  // ==========================================

  Widget _header() {
    return TripMateHeader(
      onNotificationsPressed: widget.onNotificationsPressed,
      hasUnreadNotifications: widget.hasUnreadNotifications,
    );
  }

  Widget _introduction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUA REDE',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Seus amigos',
          style: _style(
            26,
            weight: FontWeight.w600,
            color: const Color(0xFF1E1D2D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Encontre pessoas para planejar viagens em grupo.',
          style: _style(14, weight: FontWeight.w400, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _actionButton(
    String label,
    VoidCallback? onPressed, {
    bool outlined = false,
  }) {
    return OutlinedButton(
      onPressed: _processing ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: outlined ? Colors.white : AppTheme.primary,
        foregroundColor: outlined ? AppTheme.primary : Colors.white,
        side: BorderSide(
          color: outlined ? const Color(0xFFE4E0FE) : AppTheme.primary,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: label == 'Ver' ? 4 : 8,
        ),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            label == 'Ver' || label == 'Cancelar solicitação' ? 999 : 12,
          ),
        ),
      ),
      child: Text(
        label,
        style: _style(
          label == 'Ver' ? 10 : 12,
          weight: FontWeight.w700,
          color: outlined ? AppTheme.primary : Colors.white,
        ),
      ),
    );
  }

  Widget _personCard({
    required Map<String, dynamic> user,
    required Widget actions,
    double verticalPadding = 12,
    double nameSize = 16,
  }) {
    final name = user['name']?.toString() ?? 'Viajante';
    final imageUrl = user['avatar_url']?.toString();
    final id = _idOf(user['id']);

    return Container(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E3EE))),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: name,
            userId: id?.toString(),
            imageUrl: imageUrl,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _style(nameSize, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          actions,
        ],
      ),
    );
  }

  // ==========================================
  // MEUS AMIGOS
  // ==========================================

  Widget _friendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Meus amigos · ${_friends.length}',
                style: _style(
                  15,
                  weight: FontWeight.w700,
                  color: const Color(0xFF1E1D2D),
                ),
              ),
            ),
            TextButton(
              onPressed: _openRequests,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Solicitações',
                style: _style(
                  14,
                  weight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_friends.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Você ainda não tem amigos. Busque pessoas para começar sua rede.',
                textAlign: TextAlign.center,
                style: _style(
                  14,
                  weight: FontWeight.w400,
                  color: AppTheme.muted,
                ),
              ),
            ),
          ),
        for (final friendship in _friends)
          Builder(
            builder: (context) {
              final sender = _userFrom(friendship['sender']);
              final receiver = _userFrom(friendship['receiver']);

              final otherUser = _idOf(sender['id']) == _currentUserId
                  ? receiver
                  : sender;

              final friendshipId = _idOf(friendship['id']);

              return _personCard(
                user: otherUser,
                actions: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _statusBadge(
                      'Adicionado',
                      Icons.check_rounded,
                      const Color(0xFF16A56E),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Mais opções',
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      onSelected: (value) {
                        if (value == 'remove' && friendshipId != null) {
                          _confirmRemoveFriendship(friendshipId);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remover amizade'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _confirmRemoveFriendship(int friendshipId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Remover amizade?',
          style: _style(18, weight: FontWeight.w700),
        ),
        content: Text(
          'A pessoa deixará de aparecer na sua lista de amigos.',
          style: _style(13, color: AppTheme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancelar', style: _style(13, color: AppTheme.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Remover',
              style: _style(
                13,
                weight: FontWeight.w700,
                color: const Color(0xFFC74D62),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteFriendship(friendshipId, 'Amizade removida.');
    }
  }

  // ==========================================
  // SOLICITAÇÕES
  // ==========================================

  Widget _requestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recebidas (${_received.length})',
          style: _style(
            16,
            weight: FontWeight.w700,
            color: const Color(0xFF1E1D2D),
          ),
        ),
        if (_received.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE4E3EE))),
            ),
            child: Text(
              'Nenhuma solicitação recebida.',
              style: _style(14, weight: FontWeight.w400, color: AppTheme.muted),
            ),
          ),
        if (_received.isNotEmpty) const SizedBox(height: 8),
        for (final friendship in _received)
          _personCard(
            user: _userFrom(friendship['sender']),
            verticalPadding: 12,
            nameSize: 16,
            actions: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionButton('Recusar', () {
                  final id = _idOf(friendship['id']);
                  if (id != null) _rejectRequest(id);
                }, outlined: true),
                _actionButton('Aceitar', () {
                  final id = _idOf(friendship['id']);
                  if (id != null) _acceptRequest(id);
                }),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Enviadas (${_sent.length})',
          style: _style(
            16,
            weight: FontWeight.w700,
            color: const Color(0xFF1E1D2D),
          ),
        ),
        const SizedBox(height: 12),
        if (_sent.isEmpty)
          Text(
            'Nenhuma solicitação enviada.',
            style: _style(14, weight: FontWeight.w400, color: AppTheme.muted),
          ),
        for (final friendship in _sent)
          _personCard(
            user: _userFrom(friendship['receiver']),
            verticalPadding: 16,
            nameSize: 16,
            actions: _actionButton('Cancelar solicitação', () {
              final id = _idOf(friendship['id']);
              if (id != null) {
                _deleteFriendship(id, 'Solicitação cancelada.');
              }
            }, outlined: true),
          ),
      ],
    );
  }

  void _openRequests() {
    _searchDebounce?.cancel();
    _searchFocusNode.unfocus();
    setState(() {
      _searchMode = false;
      _showRequests = true;
    });
    _notifyInternalBackState();
    unawaited(_loadData(showLoading: false));
  }

  void _closeRequests() {
    setState(() => _showRequests = false);
    _notifyInternalBackState();
  }

  // ==========================================
  // BUSCAR PESSOAS
  // ==========================================

  Widget _searchAction(Map<String, dynamic> user) {
    final userId = _idOf(user['id']);

    if (userId == null) {
      return _actionButton('Indisponível', null);
    }

    final apiStatus = user['friendship_status']?.toString();
    final requestSentByMe = user['request_sent_by_me'] == true;
    final friendship = _friendshipWith(userId);
    final status = apiStatus ?? friendship?['status']?.toString();

    if (status == 'accepted') {
      return _statusBadge(
        'Adicionado',
        Icons.check_rounded,
        const Color(0xFF16A56E),
      );
    }

    if (status == 'pending') {
      final isSender = apiStatus != null
          ? requestSentByMe
          : _idOf(_userFrom(friendship?['sender'])['id']) == _currentUserId;
      return isSender
          ? _statusBadge('Pendente', Icons.schedule_rounded, AppTheme.primary)
          : _actionButton('Responder', _openRequests, outlined: true);
    }

    if (status == 'rejected' && requestSentByMe) {
      final canResendAt = DateTime.tryParse('${user['can_resend_at'] ?? ''}');
      if (canResendAt != null && DateTime.now().isBefore(canResendAt)) {
        return _statusBadge('Recusado', Icons.schedule_rounded, AppTheme.muted);
      }
    }

    return SizedBox(
      width: 36,
      height: 36,
      child: OutlinedButton(
        onPressed: _processing ? null : () => _sendRequest(userId),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primary,
          side: const BorderSide(color: Color(0xFFE4E0FE)),
          shape: const CircleBorder(),
          minimumSize: const Size(36, 36),
        ),
        child: const Icon(Icons.person_add_alt_1_rounded, size: 16),
      ),
    );
  }

  Widget _statusBadge(String label, IconData icon, Color color) {
    final pending = label == 'Pendente';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: label == 'Adicionado' ? 10 : 9,
        vertical: label == 'Adicionado' ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: pending ? const Color(0xFFEEEBFF) : color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: _style(12, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    final field = TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      readOnly: !_searchMode,
      textInputAction: TextInputAction.search,
      onTap: _searchMode ? null : _enterSearch,
      onChanged: _scheduleSearch,
      decoration: InputDecoration(
        hintText: 'Buscar por nome ou e-mail',
        hintStyle: _style(15, weight: FontWeight.w400, color: AppTheme.muted),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 16, right: 12),
          child: Icon(Icons.search_rounded, size: 16, color: AppTheme.primary),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 48,
        ),
        filled: true,
        fillColor: _searchFocusNode.hasFocus
            ? Colors.white
            : const Color(0xFFF1F1F8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        suffixIcon: _searching
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE4E3EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
      ),
    );
    final focusedField = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _searchFocusNode.hasFocus
            ? const [BoxShadow(color: Color(0xFFEEEBFF), spreadRadius: 4)]
            : null,
      ),
      child: field,
    );
    if (!_searchMode) return focusedField;
    return Row(
      children: [
        Expanded(child: focusedField),
        TextButton(
          onPressed: _cancelSearch,
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 12)),
          child: Text(
            'Cancelar',
            style: _style(13, weight: FontWeight.w700, color: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _pendingInvitesCard() {
    if (_received.isEmpty) return const SizedBox.shrink();
    final firstSender = _userFrom(
      _received.first['sender'],
    )['name']?.toString().split(' ').first;
    final subtitle = _received.length == 1 && firstSender != null
        ? '$firstSender quer adicionar você.'
        : 'Você tem ${_received.length} solicitações para responder.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x99EEEBFF),
        border: Border.all(color: const Color(0xFFE4E0FE)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppTheme.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _received.length == 1
                      ? '1 convite pendente'
                      : '${_received.length} convites pendentes',
                  style: _style(12, weight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: _style(
                    10,
                    weight: FontWeight.w400,
                    color: AppTheme.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _actionButton('Ver', _openRequests),
        ],
      ),
    );
  }

  Widget _searchResultsSection() {
    if (_searchController.text.trim().length < 2) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Text(
          'Digite pelo menos dois caracteres para pesquisar.',
          style: _style(14, weight: FontWeight.w400, color: AppTheme.muted),
        ),
      );
    }
    if (_searchError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Resultados', style: _style(14, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            _searchError!,
            style: _style(14, weight: FontWeight.w400, color: AppTheme.muted),
          ),
        ],
      );
    }
    if (!_searching && _searchResults.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Resultados', style: _style(14, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            'Nenhuma pessoa encontrada.',
            style: _style(14, weight: FontWeight.w400, color: AppTheme.muted),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Resultados', style: _style(14, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        for (final user in _searchResults)
          _personCard(user: user, actions: _searchAction(user)),
      ],
    );
  }

  // ==========================================
  // NAVEGAÇÃO
  // ==========================================

  void _goHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _goProfile() {
    Navigator.pushReplacementNamed(context, '/profile');
  }

  // ==========================================
  // TELA PRINCIPAL
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !widget.isActive || (!_searchMode && !_showRequests),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_searchMode) {
          _cancelSearch();
        } else if (_showRequests) {
          _closeRequests();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () => _loadData(showLoading: false),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        if (_showRequests) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              TripMateBackButton(onPressed: _closeRequests),
                              const SizedBox(width: 12),
                              Text(
                                'Solicitações',
                                style: _style(
                                  26,
                                  weight: FontWeight.w600,
                                  color: const Color(0xFF1E1D2D),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _requestsSection(),
                        ] else if (_searchMode) ...[
                          const SizedBox(height: 20),
                          _searchField(),
                          _searchResultsSection(),
                        ] else ...[
                          const SizedBox(height: 12),
                          _introduction(),
                          const SizedBox(height: 20),
                          _searchField(),
                          if (_received.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _pendingInvitesCard(),
                          ],
                          const SizedBox(height: 24),
                          _friendsSection(),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        bottomNavigationBar: widget.showBottomNavigation
            ? TripMateBottomNavigation(
                selectedTab: TripMateTab.friends,
                onHome: _goHome,
                onProfile: _goProfile,
              )
            : null,
      ),
    );
  }
}
