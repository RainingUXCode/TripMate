import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../models/trip.dart';
import 'trip_management_screen.dart';
import 'settlements_screen.dart';
import '../services/trips_service.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/tripmate_back_button.dart';
import 'invite_friends_screen.dart';

enum _TripDetailsTab { overview, expenses }

class TripDetailsScreen extends StatefulWidget {
  final int tripId;
  final TripsService? tripsService;
  final AuthService? authService;
  final FriendsService? friendsService;
  final Future<void> Function()? onTripChanged;

  const TripDetailsScreen({
    super.key,
    required this.tripId,
    this.tripsService,
    this.authService,
    this.friendsService,
    this.onTripChanged,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _ExpenseSheet extends StatefulWidget {
  final Trip trip;
  final TripsService service;
  final Map<String, dynamic>? initial;
  final int? currentUserId;
  const _ExpenseSheet({
    required this.trip,
    required this.service,
    required this.currentUserId,
    this.initial,
  });
  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final Map<int, TextEditingController> _values = {};
  String _mode = 'equal';
  DateTime _date = DateTime.now();
  int? _paidBy;
  final Set<int> _selected = {};
  bool _saving = false;
  String? _error;
  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final old = widget.initial;
    _amount.text = old?['amount']?.toString() ?? '';
    _description.text = old?['description']?.toString() ?? '';
    _mode = old?['mode']?.toString() ?? 'equal';
    _paidBy = int.tryParse('${old?['paid_by'] ?? widget.currentUserId}');
    _date = DateTime.tryParse('${old?['expense_date']}') ?? DateTime.now();
    for (final share in (old?['shares'] as List? ?? const [])) {
      if (share is! Map) continue;
      final id = int.tryParse('${share['user_id']}');
      if (id == null) continue;
      _selected.add(id);
      _values[id] = TextEditingController(
        text: share['value']?.toString() ?? share['amount']?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _toCents(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;
    final pieces = normalized.split('.');
    return (int.tryParse(pieces[0]) ?? 0) * 100 +
        int.parse((pieces.length > 1 ? pieces[1] : '0').padRight(2, '0'));
  }

  List<int> _previewCents(int total) {
    final ids = _selected.toList()..sort();
    if (ids.isEmpty || total < 0) return const [];
    if (_mode == 'exact') {
      return ids.map((id) => _toCents(_values[id]?.text ?? '') ?? 0).toList();
    }
    final weights = <int>[];
    for (final id in ids) {
      final raw = _values[id]?.text.trim() ?? '';
      if (_mode == 'equal') {
        weights.add(1);
        continue;
      }
      if (_mode == 'percent') {
        final value = raw.replaceAll(',', '.');
        final basis = RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(value)
            ? value.split('.')
            : const <String>[];
        weights.add(
          basis.isEmpty
              ? 0
              : (int.tryParse(basis.first) ?? 0) * 10000 +
                    int.parse(
                      (basis.length > 1 ? basis[1] : '0').padRight(4, '0'),
                    ),
        );
      } else {
        weights.add(int.tryParse(raw) ?? 0);
      }
    }
    final sum = weights.fold<int>(0, (a, b) => a + b);
    if (sum == 0 || weights.any((v) => v < 0)) {
      return List.filled(ids.length, 0);
    }
    final bases = weights.map((w) => total * w ~/ sum).toList();
    var remain = total - bases.fold<int>(0, (a, b) => a + b);
    final order = List.generate(ids.length, (i) => i)
      ..sort((a, b) {
        final ra = total * weights[a] % sum, rb = total * weights[b] % sum;
        final cmp = rb.compareTo(ra);
        return cmp != 0 ? cmp : ids[a].compareTo(ids[b]);
      });
    for (final i in order) {
      if (remain-- <= 0) break;
      bases[i]++;
    }
    return bases;
  }

  String _formatted(int cents) =>
      'R\$ ${(cents ~/ 100).toString()},${(cents % 100).toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    final amount = _toCents(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Informe um valor maior que zero.');
      return;
    }
    if (_paidBy == null) {
      setState(() => _error = 'Selecione quem pagou.');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'Selecione ao menos uma pessoa para dividir.');
      return;
    }
    final shares = <Map<String, dynamic>>[];
    final preview = _previewCents(amount);
    final ids = _selected.toList()..sort();
    if (_mode == 'exact' &&
        ids.any((id) => _toCents(_values[id]?.text ?? '') == null)) {
      setState(() => _error = 'Informe um valor válido para cada pessoa.');
      return;
    }
    if (_mode == 'percent' &&
        ids.any((id) => _previewPercent(_values[id]?.text ?? '') < 0)) {
      setState(
        () => _error = 'Informe uma porcentagem válida para cada pessoa.',
      );
      return;
    }
    if (_mode == 'units' &&
        ids.any(
          (id) => (int.tryParse(_values[id]?.text.trim() ?? '') ?? 0) <= 0,
        )) {
      setState(() => _error = 'Informe cotas inteiras maiores que zero.');
      return;
    }
    for (var i = 0; i < ids.length; i++) {
      final row = <String, dynamic>{'user_id': ids[i]};
      if (_mode != 'equal') {
        row['value'] = _values[ids[i]]!.text.trim().replaceAll(',', '.');
      }
      shares.add(row);
    }
    if (_mode == 'exact' && preview.fold<int>(0, (a, b) => a + b) != amount) {
      setState(() => _error = 'Os valores devem somar o total do gasto.');
      return;
    }
    if (_mode == 'percent' &&
        ids.fold<int>(
              0,
              (a, id) => a + (_previewPercent(_values[id]?.text ?? '')),
            ) !=
            1000000) {
      setState(() => _error = 'As porcentagens devem somar 100%.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'description': _description.text.trim(),
      'amount': '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}',
      'expense_date':
          '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
      'paid_by': _paidBy,
      'mode': _mode,
      'shares': shares,
    };
    if (_editing) payload['version'] = widget.initial!['version'];
    try {
      if (_editing) {
        await widget.service.updateExpense(
          widget.trip.id,
          int.parse('${widget.initial!['id']}'),
          payload,
        );
      } else {
        await widget.service.createExpense(widget.trip.id, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            e.toString().contains('409') || e.toString().contains('acertos')
            ? 'Este gasto tem acertos associados ou foi alterado. Atualize a tela e tente novamente.'
            : e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int _previewPercent(String raw) {
    final value = raw.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,4})?$').hasMatch(value)) return -1;
    final p = value.split('.');
    return (int.tryParse(p.first) ?? 0) * 10000 +
        int.parse((p.length > 1 ? p[1] : '0').padRight(4, '0'));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final total = _toCents(_amount.text) ?? 0;
    final ids = _selected.toList()..sort();
    final preview = _previewCents(total);
    return Padding(
      padding: EdgeInsets.only(top: 42, bottom: bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _editing ? 'Editar gasto' : 'Novo gasto',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEBFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'VALOR',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.muted,
                              letterSpacing: 1,
                            ),
                          ),
                          TextFormField(
                            controller: _amount,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                            ),
                            decoration: const InputDecoration(
                              prefixText: 'R\$ ',
                              border: InputBorder.none,
                              hintText: '0,00',
                            ),
                            validator: (v) => _toCents(v ?? '') == null
                                ? 'Informe um valor válido.'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _description,
                      decoration: InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Informe uma descrição.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _date = picked);
                              }
                            },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        'Data: ${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Quem pagou?',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final p in widget.trip.acceptedParticipants)
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: InkWell(
                                onTap: _saving
                                    ? null
                                    : () => setState(() => _paidBy = p.id),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _paidBy == p.id
                                              ? AppTheme.primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Opacity(
                                        opacity: _paidBy == p.id ? 1 : .6,
                                        child: UserAvatar(
                                          name: p.name,
                                          userId: '${p.id}',
                                          imageUrl: p.avatarUrl,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      p.name.split(' ').first,
                                      style: GoogleFonts.manrope(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Dividir por',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _mode,
                      items: const [
                        DropdownMenuItem(
                          value: 'equal',
                          child: Text('Igualmente'),
                        ),
                        DropdownMenuItem(
                          value: 'exact',
                          child: Text('Valores exatos'),
                        ),
                        DropdownMenuItem(
                          value: 'percent',
                          child: Text('Porcentagens'),
                        ),
                        DropdownMenuItem(
                          value: 'units',
                          child: Text('Por cotas'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _mode = v ?? 'equal'),
                    ),
                    const SizedBox(height: 8),
                    for (final p in widget.trip.acceptedParticipants)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _selected.contains(p.id),
                        title: Text(p.name),
                        subtitle: _selected.contains(p.id)
                            ? Text(
                                _mode == 'equal'
                                    ? (_previewCents(total).isEmpty
                                          ? '—'
                                          : _formatted(
                                              _previewCents(total)[ids.indexOf(
                                                p.id,
                                              )],
                                            ))
                                    : _mode == 'exact'
                                    ? 'Valor devido'
                                    : _mode == 'percent'
                                    ? 'Percentual'
                                    : 'Cotas',
                              )
                            : null,
                        secondary: _mode != 'equal' && _selected.contains(p.id)
                            ? SizedBox(
                                width: 86,
                                child: TextField(
                                  controller: _values.putIfAbsent(
                                    p.id,
                                    () => TextEditingController(),
                                  ),
                                  enabled: !_saving,
                                  onChanged: (_) => setState(() {}),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: _mode == 'exact'
                                        ? '0.00'
                                        : _mode == 'percent'
                                        ? '%'
                                        : '1',
                                  ),
                                ),
                              )
                            : null,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() {
                                if (v == true) {
                                  _selected.add(p.id);
                                  _values.putIfAbsent(
                                    p.id,
                                    () => TextEditingController(),
                                  );
                                } else {
                                  _selected.remove(p.id);
                                }
                              }),
                      ),
                    if (_mode != 'equal')
                      Text(
                        'Prévia total: ${_formatted(preview.fold<int>(0, (a, b) => a + b))}',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFDE3B3D)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _saving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                _editing ? 'Salvar alterações' : 'Salvar gasto',
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  static const _surface = Color(0xFFF7F6FC);
  static const _border = Color(0xFFE4E3EE);

  late final TripsService _tripsService = widget.tripsService ?? TripsService();
  late final bool _ownsTripsService = widget.tripsService == null;

  Trip? _trip;
  String? _error;
  bool _loading = true;
  int _requestGeneration = 0;
  _TripDetailsTab _selectedTab = _TripDetailsTab.overview;
  Map<String, dynamic>? _finance;
  List<Map<String, dynamic>> _expenses = const [];
  bool _expensesLoaded = false;
  bool _financeLoading = false;
  String? _financeError;
  int _financeGeneration = 0;
  int? _currentUserId;
  bool _leavingTrip = false;
  int? _removingParticipantId;
  bool _transferringOrganizer = false;
  bool _leaveOutcomeUnknown = false;
  late final AuthService _authService = widget.authService ?? AuthService();
  late final FriendsService _friendsService =
      widget.friendsService ?? FriendsService();

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void didUpdateWidget(covariant TripDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) _loadTrip();
  }

  @override
  void dispose() {
    _requestGeneration++;
    if (_ownsTripsService) _tripsService.close();
    super.dispose();
  }

  Future<void> _loadTrip({bool preserveSelectedTab = false}) async {
    final generation = ++_requestGeneration;
    _financeGeneration++;
    final previousTab = _selectedTab;
    setState(() {
      _trip = null;
      _error = null;
      _loading = true;
      _selectedTab = preserveSelectedTab
          ? previousTab
          : _TripDetailsTab.overview;
      _finance = null;
      _expenses = const [];
      _expensesLoaded = false;
      _financeLoading = false;
      _financeError = null;
    });

    try {
      final trip = await _tripsService.getTrip(widget.tripId);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _trip = trip;
        _loading = false;
        _leaveOutcomeUnknown = false;
      });
      _loadFinance();
      _authService.getSavedUser().then((user) {
        if (mounted) {
          setState(() => _currentUserId = int.tryParse('${user?['id']}'));
        }
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = 'Não foi possível abrir esta viagem. Verifique a conexão ou se ela ainda está disponível.';
        _loading = false;
      });
    }
  }

  Future<void> _openInviteFriends(Trip trip) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => InviteFriendsScreen(
          trip: trip,
          tripsService: _tripsService,
          friendsService: _friendsService,
          authService: _authService,
        ),
      ),
    );
    if (changed != true || !mounted) return;
    await _loadTrip(preserveSelectedTab: true);
    await widget.onTripChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Convites enviados com sucesso.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openTripManagement(Trip trip) async {
    var userId = _currentUserId;
    if (userId == null) {
      try {
        final user = await _authService.getSavedUser();
        userId = int.tryParse('${user?['id']}');
      } catch (_) {
        _showMessage('Não foi possível confirmar sua conta. Tente novamente.');
        return;
      }
    }
    if (!mounted) return;
    if (userId == null) {
      _showMessage('Não foi possível confirmar sua conta. Tente novamente.');
      return;
    }
    if (_currentUserId != userId) setState(() => _currentUserId = userId);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TripManagementScreen(
          trip: trip,
          currentUserId: userId!,
          leaveOutcomeUnknown: _leaveOutcomeUnknown,
          onTransferOrganizer: () => _chooseNewOrganizer(trip),
          onLeaveTrip: () => _leaveTrip(trip),
          onDeleteTrip: () => _deleteTrip(trip),
          onRefreshTrip: _refreshTripFromManagement,
          onRemoveParticipant: (participant) =>
              _removeTripParticipant(trip, participant),
        ),
      ),
    );
  }

  Future<void> _refreshTripFromManagement() async {
    await _loadTrip(preserveSelectedTab: true);
    if (!mounted || _loading || _error != null || _leaveOutcomeUnknown) return;
    Navigator.of(context).pop();
  }

  Future<void> _removeTripParticipant(
    Trip trip,
    TripParticipant participant,
  ) async {
    if (_removingParticipantId != null) return;
    setState(() => _removingParticipantId = participant.id);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Remover participante?',
            style: _style(18, weight: FontWeight.w700),
          ),
          content: Text(
            '${participant.name} perderá acesso à viagem. O histórico financeiro será preservado e a remoção será bloqueada se houver pendências de saldo ou acerto.',
            style: _style(14, color: AppTheme.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancelar',
                style: _style(14, weight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B3E46),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Remover ${participant.name}',
                style: _style(14, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      try {
        await _tripsService.removeParticipant(trip.id, participant.id);
        if (!mounted) return;
        await _finishParticipantRemoval(trip);
      } catch (error) {
        if (!mounted) return;
        try {
          final refreshed = await _tripsService.getTrip(trip.id);
          if (!mounted) return;
          final stillAccepted = refreshed.acceptedParticipants.any(
            (item) => item.id == participant.id,
          );
          if (!stillAccepted) {
            setState(() => _trip = refreshed);
            await _finishParticipantRemoval(trip);
            return;
          }
        } catch (_) {
          // Keep the management screen available; never repeat an ambiguous DELETE.
        }
        _showMessage(_tripServiceMessage(error));
      }
    } finally {
      if (mounted) setState(() => _removingParticipantId = null);
    }
  }

  Future<void> _finishParticipantRemoval(Trip trip) async {
    await _loadTrip(preserveSelectedTab: true);
    await widget.onTripChanged?.call();
    if (!mounted) return;
    Navigator.of(context).pop();
    _showMessage(
      'Participante removido. O histórico financeiro foi preservado.',
    );
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmTripDeletionDialog(tripName: trip.name),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _tripsService.deleteTrip(trip.id);
      if (!mounted) return;
      await widget.onTripChanged?.call();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      try {
        await _tripsService.getTrip(trip.id);
        if (!mounted) return;
        _showMessage(_tripServiceMessage(error));
      } on TripsServiceException catch (refreshError) {
        if (!mounted) return;
        if (refreshError.statusCode == 404 || refreshError.statusCode == 403) {
          await widget.onTripChanged?.call();
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          _showMessage(_tripServiceMessage(error));
        }
      } catch (_) {
        if (mounted) {
          _showMessage(
            'Não foi possível confirmar a exclusão. Atualize suas viagens antes de tentar novamente.',
          );
        }
      }
    }
  }

  Future<void> _leaveTrip(Trip trip) async {
    if (_leavingTrip || _leaveOutcomeUnknown) return;
    setState(() => _leavingTrip = true);

    late final Map<String, dynamic> eligibility;
    try {
      eligibility = await _tripsService.getLeaveEligibility(trip.id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _leavingTrip = false);
      _showMessage(_tripServiceMessage(error));
      return;
    }

    if (eligibility['can_leave'] != true) {
      if (mounted) setState(() => _leavingTrip = false);
      await _showLeaveBlockers(eligibility);
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sair da viagem?',
          style: _style(18, weight: FontWeight.w700),
        ),
        content: Text(
          'Você perderá acesso aos detalhes privados desta viagem. Seus registros financeiros serão preservados.',
          style: _style(14, color: AppTheme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: _style(14, weight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Sair da viagem',
              style: _style(14, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      if (mounted) setState(() => _leavingTrip = false);
      return;
    }

    try {
      await _tripsService.leaveTrip(trip.id);
      await _returnHomeAfterLeaving();
    } catch (error) {
      if (!mounted) return;
      if (error is TripsServiceException && error.statusCode == 409) {
        try {
          final refreshed = await _tripsService.getLeaveEligibility(trip.id);
          if (!mounted) return;
          setState(() => _leavingTrip = false);
          await _showLeaveBlockers(refreshed);
        } catch (eligibilityError) {
          await _reconcileLeaveFailure(trip, eligibilityError);
        }
      } else {
        await _reconcileLeaveFailure(trip, error);
      }
    }
  }

  Future<void> _showLeaveBlockers(Map<String, dynamic> eligibility) async {
    if (!mounted) return;
    final reasons = (eligibility['reasons'] as List? ?? const [])
        .map((reason) => reason.toString())
        .toList(growable: false);
    final rawMessages = eligibility['reason_messages'];
    final messages = rawMessages is Map
        ? Map<String, dynamic>.from(rawMessages)
        : const <String, dynamic>{};
    final lines = reasons
        .map((reason) => messages[reason]?.toString())
        .whereType<String>()
        .where((message) => message.trim().isNotEmpty)
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Você ainda não pode sair',
          style: _style(18, weight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.isEmpty
              ? [
                  Text(
                    'Não foi possível confirmar sua elegibilidade. Atualize e tente novamente.',
                    style: _style(14, color: AppTheme.muted),
                  ),
                ]
              : [
                  for (final message in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $message', style: _style(14)),
                    ),
                ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Entendi',
              style: _style(
                14,
                weight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reconcileLeaveFailure(Trip trip, Object error) async {
    if (!mounted) return;
    try {
      final currentTrip = await _tripsService.getTrip(trip.id);
      if (!mounted) return;
      setState(() {
        _trip = currentTrip;
        _leavingTrip = false;
        _leaveOutcomeUnknown = false;
      });
      _showMessage(_tripServiceMessage(error));
    } catch (reconciliationError) {
      if (!mounted) return;
      if (reconciliationError is TripsServiceException &&
          (reconciliationError.statusCode == 403 ||
              reconciliationError.statusCode == 404)) {
        await _returnHomeAfterLeaving();
        return;
      }
      setState(() {
        _leavingTrip = false;
        _leaveOutcomeUnknown = true;
      });
      Navigator.of(context).pop();
      _showMessage(
        'Não foi possível confirmar o resultado. Atualize a viagem antes de tentar novamente.',
      );
    }
  }

  Future<void> _returnHomeAfterLeaving() async {
    await widget.onTripChanged?.call();
    if (!mounted) return;
    setState(() {
      _trip = null;
      _loading = false;
      _error = 'Você não participa mais desta viagem.';
      _leavingTrip = false;
      _leaveOutcomeUnknown = false;
    });
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _chooseNewOrganizer(Trip trip) async {
    if (_transferringOrganizer) return;
    final eligible = trip.acceptedParticipants
        .where((participant) => participant.id != _currentUserId)
        .toList(growable: false);
    if (eligible.isEmpty) {
      _showMessage(
        'Não há outros participantes aceitos para assumir a organização.',
      );
      return;
    }
    final newOrganizerId = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Transferir organização',
          style: _style(18, weight: FontWeight.w700),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .55,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final participant in eligible)
                  ListTile(
                    key: ValueKey('organizer-successor-${participant.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(
                      name: participant.name,
                      userId: participant.id.toString(),
                      imageUrl: participant.avatarUrl,
                      size: 40,
                    ),
                    title: Text(
                      participant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _style(14, weight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.pop(context, participant.id),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: _style(14, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (newOrganizerId == null || !mounted) return;
    final successor = eligible.firstWhere(
      (participant) => participant.id == newOrganizerId,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirmar transferência?',
          style: _style(18, weight: FontWeight.w700),
        ),
        content: Text(
          '${successor.name} passará a organizar a viagem. Você continuará como participante e não sairá automaticamente.',
          style: _style(14, color: AppTheme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: _style(14, weight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Transferir',
              style: _style(14, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _transferOrganizer(trip, newOrganizerId, successor.name);
  }

  Future<void> _transferOrganizer(
    Trip trip,
    int newOrganizerId,
    String name,
  ) async {
    setState(() => _transferringOrganizer = true);
    try {
      final updatedTrip = await _tripsService.transferOrganizer(
        trip.id,
        newOrganizerId,
      );
      if (!mounted) return;
      setState(() {
        _trip = updatedTrip;
        _transferringOrganizer = false;
      });
      await widget.onTripChanged?.call();
      if (mounted) {
        Navigator.of(context).pop();
        _showMessage(
          'A organização foi transferida para $name. Você continua nesta viagem.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      try {
        final currentTrip = await _tripsService.getTrip(trip.id);
        if (!mounted) return;
        setState(() {
          _trip = currentTrip;
          _transferringOrganizer = false;
        });
        await widget.onTripChanged?.call();
        if (currentTrip.organizerId == newOrganizerId && mounted) {
          Navigator.of(context).pop();
        }
        _showMessage(
          currentTrip.organizerId == newOrganizerId
              ? 'A transferência foi concluída.'
              : _tripServiceMessage(error),
        );
      } catch (reconciliationError) {
        if (!mounted) return;
        if (reconciliationError is TripsServiceException &&
            (reconciliationError.statusCode == 403 ||
                reconciliationError.statusCode == 404)) {
          setState(() {
            _trip = null;
            _error = 'Esta viagem não está mais disponível.';
            _loading = false;
            _transferringOrganizer = false;
          });
        } else {
          setState(() {
            _transferringOrganizer = false;
            _trip = null;
            _loading = true;
          });
          await _loadTrip();
          if (mounted) {
            _showMessage(
              'Não foi possível confirmar a transferência. Os dados foram consultados novamente.',
            );
          }
        }
      }
    }
  }

  String _tripServiceMessage(Object error) => error is TripsServiceException
      ? error.message
      : error.toString().replaceFirst('Exception: ', '');

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadFinance({
    bool force = false,
    bool includeExpenses = true,
  }) async {
    if ((_financeLoading && !force) || _trip == null) return;
    final generation = ++_financeGeneration;
    setState(() {
      _financeLoading = true;
      _financeError = null;
    });
    try {
      Map<String, dynamic>? summary;
      List<Map<String, dynamic>>? expenses;
      Object? loadError;
      if (includeExpenses) {
        final results = await Future.wait<Object?>([
          _tripsService
              .getFinanceSummary(_trip!.id)
              .then<Object?>((value) => value)
              .catchError((Object error) {
                loadError ??= error;
                return null;
              }),
          _tripsService
              .getExpenses(_trip!.id)
              .then<Object?>((value) => value)
              .catchError((Object error) {
                loadError ??= error;
                return null;
              }),
        ]);
        summary = results[0] as Map<String, dynamic>?;
        expenses = results[1] as List<Map<String, dynamic>>?;
      } else {
        try {
          summary = await _tripsService.getFinanceSummary(_trip!.id);
        } catch (error) {
          loadError = error;
        }
      }
      if (!mounted || generation != _financeGeneration) return;
      setState(() {
        if (summary != null) _finance = summary;
        if (expenses != null) {
          _expenses = expenses;
          _expensesLoaded = true;
        }
        _financeError = loadError?.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && generation == _financeGeneration) {
        setState(() => _financeLoading = false);
      }
    }
  }

  TextStyle _style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppTheme.ink,
  }) => GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color);

  double _heroHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(27) / 27;
    return 256 + ((scale - 1) * 110).clamp(0.0, 96.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _trip != null && !_loading && _error == null
          ? AppTheme.darkImageSystemUi
          : AppTheme.lightPageSystemUi,
      child: Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          top: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : _error != null
              ? _buildError()
              : _trip == null
              ? _buildError()
              : _buildTrip(_trip!),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TripMateBackButton(
              key: const ValueKey('trip-details-back'),
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Não foi possível encontrar esta viagem.',
              textAlign: TextAlign.center,
              style: _style(14, color: AppTheme.muted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadTrip,
              child: Text(
                'Tentar novamente',
                style: _style(
                  14,
                  weight: FontWeight.w700,
                ).copyWith(color: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrip(Trip trip) {
    final heroHeight = _heroHeight(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          SizedBox(
            height: heroHeight,
            width: double.infinity,
            child: _buildHero(context, trip, heroHeight),
          ),
          Transform.translate(
            offset: const Offset(0, -20),
            child: _buildContent(trip),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, Trip trip, double height) {
    final imageUrl = trip.coverImageUrl?.trim();
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        _heroPlaceholder(),
        if (imageUrl != null && imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            key: const ValueKey('trip-details-hero-image'),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _heroPlaceholder(),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x60000000), Color(0x17000000), Color(0xCC11111B)],
              stops: [0, 0.42, 1],
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: topInset + 12,
          child: TripMateBackButton(
            key: const ValueKey('trip-details-back'),
            onPressed: () => Navigator.maybePop(context),
            style: TripMateIconButtonStyle.glass,
          ),
        ),
        Positioned(
          right: 20,
          top: topInset + 12,
          child: TripMateIconButton(
            key: const ValueKey('trip-details-settings'),
            icon: Icons.settings_outlined,
            tooltip: 'Gerenciar viagem',
            onPressed: () => _openTripManagement(trip),
            style: TripMateIconButtonStyle.glass,
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: _heroInformation(trip, height),
        ),
      ],
    );
  }

  Widget _heroPlaceholder() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8170CC), Color(0xFF302B46)],
      ),
    ),
    child: Center(
      child: Icon(Icons.landscape_outlined, size: 54, color: Color(0x99FFFFFF)),
    ),
  );

  Widget _heroInformation(Trip trip, double height) {
    final activeParticipants = trip.acceptedParticipants;
    final participants = activeParticipants.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'VIAGEM EM GRUPO · ${_formatHeroDates(trip.startDate, trip.endDate)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _style(11, weight: FontWeight.w700, color: Colors.white)
              .copyWith(
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.86),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          trip.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _style(
            27,
            weight: FontWeight.w500,
            color: Colors.white,
          ).copyWith(height: 1.08),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                trip.destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(13, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            if (participants.isNotEmpty)
              SizedBox(
                width: 26 + (participants.length - 1) * 18,
                height: 26,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    for (var index = 0; index < participants.length; index++)
                      Positioned(
                        left: index * 18,
                        child: UserAvatar(
                          key: ValueKey(
                            'trip-details-hero-participant-${participants[index].id}',
                          ),
                          name: participants[index].name,
                          userId: participants[index].id.toString(),
                          imageUrl: participants[index].avatarUrl,
                          size: 26,
                        ),
                      ),
                  ],
                ),
              ),
            if (participants.isNotEmpty) const SizedBox(width: 8),
            Flexible(
              child: Text(
                _participantCount(activeParticipants.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(12, weight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(Trip trip) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabs(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _buildSelectedTab(trip),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const tabs = [
      (label: 'Visão geral', value: _TripDetailsTab.overview),
      (label: 'Gastos', value: _TripDetailsTab.expenses),
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(child: _tabButton(tab.label, tab.value)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _TripDetailsTab tab) {
    final selected = _selectedTab == tab;
    final key = switch (tab) {
      _TripDetailsTab.overview => 'trip-tab-overview',
      _TripDetailsTab.expenses => 'trip-tab-expenses',
    };

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey(key),
        onTap: () => setState(() => _selectedTab = tab),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(
              12,
              weight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? Colors.white : AppTheme.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTab(Trip trip) {
    return switch (_selectedTab) {
      _TripDetailsTab.overview => Column(
        children: [
          _groupExpenseCard(),
          const SizedBox(height: 14),
          _buildParticipantsCard(trip),
          const SizedBox(height: 14),
          _balanceCard(trip),
        ],
      ),
      _TripDetailsTab.expenses => _expensesView(trip),
    };
  }

  String _money(dynamic value) => value?.toString() ?? '0.00';
  int _cents(dynamic value) {
    final text = _money(value).replaceAll(',', '.');
    final parts = text.split('.');
    return (int.tryParse(parts.first) ?? 0) * 100 +
        int.parse(
          (parts.length > 1 ? parts[1] : '0').padRight(2, '0').substring(0, 2),
        );
  }

  String _brl(dynamic value) {
    final cents = _cents(value);
    return _brlFromCents(cents);
  }

  String _brlFromCents(int cents) {
    final whole = (cents ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'R\$ $whole,${(cents % 100).toString().padLeft(2, '0')}';
  }

  Widget _groupExpenseCard() {
    final spent = _finance?['total_spent'];
    final expenseCount = _expensesLoaded
        ? _expenses.where((expense) => expense['cancelled'] != true).length
        : null;
    return Container(
      key: const ValueKey('group-expense-card'),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: .25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -40,
                    right: -24,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gasto total do grupo',
                            style: _style(10, color: Colors.white70),
                          ),
                          Text(
                            spent == null ? '—' : _brl(spent),
                            softWrap: true,
                            style: _style(
                              24,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => setState(
                          () => _selectedTab = _TripDetailsTab.expenses,
                        ),
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.primary,
                        ),
                        tooltip: 'Ver gastos',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: .28),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 16,
                            color: Colors.white.withValues(alpha: .88),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Despesas registradas',
                              softWrap: true,
                              style: _style(
                                12,
                                weight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Text(
                        key: const ValueKey('finance-active-expense-count'),
                        expenseCount == null
                            ? '—'
                            : '$expenseCount ${expenseCount == 1 ? 'gasto' : 'gastos'}',
                        textAlign: TextAlign.right,
                        softWrap: true,
                        style: _style(
                          13,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_financeError != null)
                  TextButton(
                    onPressed: _loadFinance,
                    child: Text(
                      'Tentar atualizar',
                      style: _style(12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(Trip trip) {
    final financialRows =
        (_finance?['participants'] as List?)?.whereType<Map>().toList() ??
        const [];
    final people = {for (final p in trip.acceptedParticipants) p.id: p};
    final rows = financialRows
        .where((row) {
          final id = int.tryParse('${row['user_id']}');
          return id != null && people.containsKey(id);
        })
        .toList(growable: false);
    return KeyedSubtree(
      key: const ValueKey('trip-per-person-card'),
      child: _card(
        title: 'Pago por pessoa',
        subtitle: 'Quem pagou e como fica o acerto',
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 18, color: Color(0xFFE4E3EE)),
              _balanceRow(Map<String, dynamic>.from(rows[i]), people),
            ],
            if (rows.isEmpty)
              Text(
                _financeLoading
                    ? 'Carregando saldos…'
                    : 'Ainda não há saldos para exibir.',
                style: _style(13, color: AppTheme.muted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _balanceRow(
    Map<String, dynamic> row,
    Map<int, TripParticipant> people,
  ) {
    final id = int.tryParse('${row['user_id']}') ?? -1;
    final person = people[id];
    if (person == null) return const SizedBox.shrink();
    final balance = _cents(row['balance']);
    final paid = _cents(row['paid']);
    final color = balance > 0
        ? const Color(0xFF16A56E)
        : balance < 0
        ? const Color(0xFFDE3B3D)
        : AppTheme.muted;
    return Row(
      key: ValueKey('trip-balance-user-$id'),
      children: [
        UserAvatar(
          name: person.name,
          userId: '$id',
          imageUrl: person.avatarUrl,
          size: 32,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(12, weight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:
                      _finance?['total_spent'] == null ||
                          _cents(_finance!['total_spent']) == 0
                      ? 0
                      : (paid / _cents(_finance!['total_spent'])).clamp(
                          0.0,
                          1.0,
                        ),
                  minHeight: 4,
                  backgroundColor: const Color(0xFFF1F1F8),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _brl(row['paid']),
              style: _style(
                12,
                weight: FontWeight.w800,
                color: AppTheme.primary,
              ),
            ),
            Text(
              balance > 0
                  ? 'recebe ${_brl(row['balance'])}'
                  : balance < 0
                  ? 'deve ${_brl(row['balance']).replaceFirst('R\$ ', '')}'
                  : 'equilibrado',
              style: _style(9, weight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ],
    );
  }

  Widget _expensesView(Trip trip) {
    final active = _expenses.where((e) => e['cancelled'] != true).toList();
    final total = _finance?['total_spent'] ?? '0.00';
    return Column(
      children: [
        _card(
          title: 'Total acumulado',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalText = Text(
                _brl(total),
                style: _style(20, weight: FontWeight.w800),
              );
              final addButton = _primaryButton(
                'Adicionar gasto',
                Icons.add_rounded,
                () => _openExpenseSheet(trip),
              );
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    totalText,
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: addButton),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [totalText, addButton],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _card(
          title: 'Acertos financeiros',
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('open-settlements'),
              onPressed: () => _openSettlements(trip),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Ver sugestões, pendências e histórico'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_financeLoading && active.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: CircularProgressIndicator(),
          )
        else if (active.isEmpty)
          _emptyState(
            key: const ValueKey('trip-empty-expenses'),
            icon: Icons.receipt_long_outlined,
            title: 'Nenhum gasto registrado',
            message: 'Adicione uma despesa para começar o balanço da viagem.',
          )
        else
          for (final expense in active)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _expenseCard(trip, expense),
            ),
        if (_financeError != null)
          TextButton(
            onPressed: _loadFinance,
            child: const Text('Tentar novamente'),
          ),
      ],
    );
  }

  Widget _expenseCard(Trip trip, Map<String, dynamic> expense) {
    final paidBy = trip.acceptedParticipants
        .where((p) => p.id == int.tryParse('${expense['paid_by']}'))
        .firstOrNull;
    final own = int.tryParse('${expense['created_by']}') == _currentUserId;
    final date = DateTime.tryParse('${expense['expense_date']}');
    final formattedDate = date == null
        ? '${expense['expense_date']}'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEBFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${expense['description']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _style(14, weight: FontWeight.w700),
                ),
                Text(
                  'Pago por ${paidBy?.name ?? 'participante'} • $formattedDate',
                  style: _style(10, color: AppTheme.muted),
                ),
                if (own)
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _openExpenseSheet(trip, expense: expense),
                        child: const Text('Editar'),
                      ),
                      TextButton(
                        onPressed: () => _cancelExpense(expense),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Color(0xFFDE3B3D)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _brl(expense['amount']),
            style: _style(14, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelExpense(Map<String, dynamic> expense) async {
    try {
      await _tripsService.cancelExpense(
        _trip!.id,
        int.parse('${expense['id']}'),
        int.parse('${expense['version']}'),
      );
      await _loadFinance(force: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('acertos')
                  ? 'Este gasto está bloqueado por acertos financeiros.'
                  : e.toString(),
            ),
          ),
        );
      }
    }
  }

  Widget _card({
    required String title,
    String? subtitle,
    required Widget child,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _style(14, weight: FontWeight.w600)),
        if (subtitle != null)
          Text(subtitle, style: _style(11, color: AppTheme.muted)),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _primaryButton(String label, IconData icon, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: .22),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: _style(11, weight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      );

  Future<void> _openExpenseSheet(
    Trip trip, {
    Map<String, dynamic>? expense,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseSheet(
        trip: trip,
        service: _tripsService,
        initial: expense,
        currentUserId: _currentUserId,
      ),
    );
    if (result == true && mounted) await _loadFinance(force: true);
  }

  Future<void> _openSettlements(Trip trip) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SettlementsScreen(
          tripId: trip.id,
          participants: trip.acceptedParticipants,
          currentUserId: _currentUserId,
          service: _tripsService,
          onFinancialChanged: () async {
            await _loadFinance(force: true, includeExpenses: false);
            await widget.onTripChanged?.call();
          },
        ),
      ),
    );
  }

  Widget _buildParticipantsCard(Trip trip) {
    final participants = trip.acceptedParticipants;
    return Container(
      key: const ValueKey('trip-participants-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _participantsHeader(trip, participants.length),
          if (participants.isNotEmpty) ...[
            const SizedBox(height: 16),
            _participantGrid(trip),
          ] else ...[
            const SizedBox(height: 18),
            Text(
              'Nenhum participante confirmado ainda.',
              style: _style(13, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _participantsHeader(Trip trip, int participantCount) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Participantes', style: _style(17, weight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          _peopleCount(participantCount),
          style: _style(12, color: AppTheme.muted),
        ),
      ],
    );
    if (_currentUserId != trip.organizerId) return details;

    final inviteButton = TextButton.icon(
      key: const ValueKey('invite-trip-friends'),
      onPressed: () => _openInviteFriends(trip),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.primary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
      label: Text(
        'Convidar amigos',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _style(12, weight: FontWeight.w700, color: AppTheme.primary),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledTextSize = MediaQuery.textScalerOf(context).scale(12);
        if (constraints.maxWidth < 295 || scaledTextSize > 15) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              details,
              Align(alignment: Alignment.centerRight, child: inviteButton),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: details),
            const SizedBox(width: 4),
            Flexible(
              child: Align(alignment: Alignment.topRight, child: inviteButton),
            ),
          ],
        );
      },
    );
  }

  Widget _participantGrid(Trip trip) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 280
            ? 4
            : constraints.maxWidth >= 205
            ? 3
            : 2;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 16,
          children: [
            for (final participant in trip.acceptedParticipants)
              SizedBox(
                key: ValueKey('trip-details-participant-${participant.id}'),
                width: itemWidth,
                child: _participantTile(trip, participant),
              ),
          ],
        );
      },
    );
  }

  Widget _participantTile(Trip trip, TripParticipant participant) {
    final parts = participant.name.trim().split(RegExp(r'\s+'));
    final firstName = parts.isEmpty ? 'Viajante' : parts.first;
    final role = participant.id == trip.organizerId
        ? 'Organizador'
        : 'Participante';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(
          name: participant.name,
          userId: participant.id.toString(),
          imageUrl: participant.avatarUrl,
          size: 46,
        ),
        const SizedBox(height: 5),
        Text(
          firstName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: _style(12, weight: FontWeight.w700),
        ),
        const SizedBox(height: 1),
        Text(
          role,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: _style(10, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _emptyState({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEBFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 24, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _style(16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: _style(13, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  String _participantCount(int count) =>
      '$count ${count == 1 ? 'participante' : 'participantes'}';

  String _peopleCount(int count) {
    if (count == 1) return '1 pessoa nesta viagem';
    return '$count pessoas nesta viagem';
  }

  String _formatHeroDates(DateTime start, DateTime end) {
    const months = [
      'JAN',
      'FEV',
      'MAR',
      'ABR',
      'MAI',
      'JUN',
      'JUL',
      'AGO',
      'SET',
      'OUT',
      'NOV',
      'DEZ',
    ];

    if (start.year == end.year && start.month == end.month) {
      return '${start.day} – ${end.day} ${months[end.month - 1]}';
    }

    final startYear = start.year == end.year ? '' : ' ${start.year}';
    return '${start.day} ${months[start.month - 1]}$startYear – '
        '${end.day} ${months[end.month - 1]} ${end.year}';
  }
}

class _ConfirmTripDeletionDialog extends StatefulWidget {
  const _ConfirmTripDeletionDialog({required this.tripName});

  final String tripName;

  @override
  State<_ConfirmTripDeletionDialog> createState() =>
      _ConfirmTripDeletionDialogState();
}

class _ConfirmTripDeletionDialogState
    extends State<_ConfirmTripDeletionDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canConfirm = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  TextStyle _style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppTheme.ink,
  }) => GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color);

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text('Excluir viagem?', style: _style(18, weight: FontWeight.w700)),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Esta ação é permanente. Para confirmar, digite o nome da viagem:',
          style: _style(14, color: AppTheme.muted),
        ),
        const SizedBox(height: 8),
        Text(widget.tripName, style: _style(15, weight: FontWeight.w800)),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('delete-trip-name-confirmation'),
          controller: _controller,
          autofocus: true,
          onChanged: (value) => setState(
            () => _canConfirm = value.trim() == widget.tripName.trim(),
          ),
          decoration: InputDecoration(
            hintText: 'Nome da viagem',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text('Cancelar', style: _style(14, weight: FontWeight.w600)),
      ),
      FilledButton(
        key: const ValueKey('confirm-delete-trip'),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B3E46)),
        onPressed: _canConfirm ? () => Navigator.pop(context, true) : null,
        child: Text(
          'Excluir viagem',
          style: _style(14, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
    ],
  );
}
