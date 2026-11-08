import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:math' as math;

import '../core/theme/app_theme.dart';
import '../services/notifications_service.dart';
import '../widgets/tripmate_back_button.dart';

class NotificationsScreen extends StatefulWidget {
  final NotificationsService service;
  final Future<void> Function()? onChanged;
  final Future<void> Function(Map<String, dynamic>)? onOpenTarget;

  const NotificationsScreen({
    super.key,
    required this.service,
    this.onChanged,
    this.onOpenTarget,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _items = const [];
  int? _nextPage = 1;
  int _unreadCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
  String? _error;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage(first: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_error == null && _scrollController.position.extentAfter < 320) {
      _loadPage();
    }
  }

  Future<void> _loadPage({bool first = false}) async {
    if (_loadingMore || (!first && _nextPage == null)) return;
    final page = first ? 1 : _nextPage ?? 1;
    setState(() {
      _error = null;
      if (first) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await widget.service.getPage(page: page);
      if (!mounted) return;
      if (first) {
        try {
          _unreadCount = await widget.service.getUnreadCount();
        } catch (_) {
          // The list remains useful even if the separate count call fails.
        }
      }
      if (!mounted) return;
      final existingIds = _items.map((item) => _id(item['id'])).toSet();
      setState(() {
        if (first) {
          _items = result.results;
        } else {
          _items = [
            ..._items,
            ...result.results.where(
              (item) => !existingIds.contains(_id(item['id'])),
            ),
          ];
        }
        _nextPage = result.nextPage;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = _id(item['id']);
    if (id == null || item['is_read'] == true || !_busyIds.add(id)) return;
    setState(() {});
    try {
      await widget.service.markAsRead(id);
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((value) => _id(value['id']) == id);
        if (index >= 0) _items[index] = {..._items[index], 'is_read': true};
        _unreadCount = math.max(0, _unreadCount - 1);
        _busyIds.remove(id);
      });
      await widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyIds.remove(id));
      _showMessage(_message(error), error: true);
      rethrow;
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _items.every((item) => item['is_read'] == true)) return;
    setState(() => _markingAll = true);
    try {
      await widget.service.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _items = _items.map((item) => {...item, 'is_read': true}).toList();
        _unreadCount = 0;
        _markingAll = false;
      });
      await widget.onChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _markingAll = false);
      _showMessage(_message(error), error: true);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    try {
      await _markRead(item);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final actionable =
        item['resource_type'] != null && item['resource_id'] != null;
    if (!actionable || widget.onOpenTarget == null) {
      _showMessage('Este destino não está disponível.');
      return;
    }
    await widget.onOpenTarget!(item);
  }

  int? _id(Object? value) => int.tryParse('$value');

  String _message(Object error) => error is NotificationsServiceException
      ? error.message
      : 'Não foi possível carregar as notificações.';

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFC74D62) : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  IconData _icon(String? eventType) => switch (eventType) {
    'friend_request' => Icons.person_add_alt_1_rounded,
    'trip_invitation' => Icons.luggage_rounded,
    'settlement_pending' || 'settlement_confirmed' => Icons.payments_rounded,
    'organizer_transferred' => Icons.workspace_premium_rounded,
    _ => Icons.notifications_none_rounded,
  };

  String _dateLabel(Object? raw) {
    final date = DateTime.tryParse('$raw')?.toLocal();
    if (date == null) return '';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Agora';
    if (difference.inHours < 1) return 'Há ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Há ${difference.inHours} h';
    if (difference.inDays == 1) return 'Ontem';
    if (difference.inDays < 7) return 'Há ${difference.inDays} dias';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  TextStyle _style(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = AppTheme.ink,
  }) => GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) {
    final hasUnread =
        _unreadCount > 0 || _items.any((item) => item['is_read'] != true);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: TripMateBackButton(onPressed: () => Navigator.pop(context)),
        ),
        leadingWidth: 60,
        title: Text('Notificações', style: _style(20, weight: FontWeight.w700)),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: _markingAll
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Marcar todas como lidas',
                      style: _style(
                        12,
                        weight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _error != null && _items.isEmpty
          ? _errorView()
          : _items.isEmpty
          ? _emptyView()
          : RefreshIndicator(
              onRefresh: () => _loadPage(first: true),
              color: AppTheme.primary,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount:
                    _items.length +
                    (_loadingMore ? 1 : 0) +
                    (_error != null ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (_error != null && index == _items.length) {
                    return TextButton.icon(
                      onPressed: _loadPage,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        'Falha ao carregar mais. Tentar novamente',
                      ),
                    );
                  }
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _notificationCard(_items[index]);
                },
              ),
            ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> item) {
    final read = item['is_read'] == true;
    final id = _id(item['id']);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: id == null || _busyIds.contains(id) ? null : () => _open(item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE4E3EE)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFEEEBFF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icon(item['event_type']?.toString()),
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
                      item['title']?.toString() ?? 'Notificação',
                      style: _style(14, weight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['message']?.toString() ?? '',
                      style: _style(13, color: AppTheme.muted),
                      softWrap: true,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _dateLabel(item['created_at']),
                      style: _style(11, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_busyIds.contains(id))
                const SizedBox.square(
                  dimension: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else if (!read)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppTheme.primary,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text('Você está em dia', style: _style(17, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Suas notificações aparecerão aqui.',
            textAlign: TextAlign.center,
            style: _style(14, color: AppTheme.muted),
          ),
        ],
      ),
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppTheme.muted, size: 38),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Não foi possível carregar notificações.',
            textAlign: TextAlign.center,
            style: _style(14, color: AppTheme.muted),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _loadPage(first: true),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
