import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_theme.dart';
import '../models/trip.dart';
import '../services/trips_service.dart';
import '../widgets/tripmate_back_button.dart';
import '../widgets/user_avatar.dart';

class SettlementsScreen extends StatefulWidget {
  final int tripId;
  final List<TripParticipant> participants;
  final int? currentUserId;
  final TripsService service;
  final Future<void> Function()? onFinancialChanged;

  const SettlementsScreen({
    super.key,
    required this.tripId,
    required this.participants,
    required this.currentUserId,
    required this.service,
    this.onFinancialChanged,
  });

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  List<Map<String, dynamic>> _proposals = const [];
  List<Map<String, dynamic>> _settlements = const [];
  List<Map<String, dynamic>> _history = const [];
  bool _loading = true;
  String? _error;
  int? _busySettlementId;
  bool _settlementStateUnknown = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<bool> _load({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await Future.wait([
        widget.service.getSettlementProposals(widget.tripId),
        widget.service.getSettlements(widget.tripId),
        widget.service.getFinanceHistory(widget.tripId),
      ]);
      if (!mounted) return false;
      setState(() {
        _proposals = data[0];
        _settlements = data[1];
        _history = data[2];
        _loading = false;
        _error = null;
        _settlementStateUnknown = false;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
      return false;
    }
  }

  Future<void> _afterChange() async {
    await _load();
    await widget.onFinancialChanged?.call();
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  int _id(dynamic value) => int.tryParse('$value') ?? -1;

  String _name(int id) {
    if (id == widget.currentUserId) return 'Você';
    for (final person in widget.participants) {
      if (person.id == id) return person.name;
    }
    return 'Participante';
  }

  String _firstName(int id) => _name(id).split(' ').first;

  String _fullName(int id) {
    for (final person in widget.participants) {
      if (person.id == id) return person.name;
    }
    return 'Participante';
  }

  int? _cents(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    return (int.tryParse(parts.first) ?? 0) * 100 +
        int.parse((parts.length > 1 ? parts[1] : '0').padRight(2, '0'));
  }

  String _brl(dynamic raw) {
    final cents = _cents('$raw') ?? 0;
    final whole = (cents ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'R\$ $whole,${(cents % 100).toString().padLeft(2, '0')}';
  }

  String _date(dynamic raw) {
    final parsed = DateTime.tryParse('$raw')?.toLocal();
    if (parsed == null) return 'Data indisponível';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6FC),
        elevation: 0,
        leading: Center(
          child: TripMateBackButton(
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        title: Text(
          'Acertos financeiros',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar acertos',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _proposals.isEmpty && _settlements.isEmpty
          ? _loadError()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _sectionTitle('Sugestões de acerto'),
                  const SizedBox(height: 8),
                  if (_proposals.isEmpty)
                    _emptyCard(
                      'Não há obrigações pendentes.',
                      'Os saldos atuais não indicam pagamentos a sugerir.',
                      Icons.check_circle_outline_rounded,
                    )
                  else
                    for (final proposal in _proposals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _proposalCard(proposal),
                      ),
                  const SizedBox(height: 12),
                  _sectionTitle('Acertos registrados'),
                  const SizedBox(height: 8),
                  if (_settlements.isEmpty)
                    _emptyCard(
                      'Nenhum acerto registrado.',
                      'Pagamentos declarados aparecerão aqui até serem confirmados ou cancelados.',
                      Icons.payments_outlined,
                    )
                  else
                    for (final item in _settlements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _settlementCard(item),
                      ),
                  const SizedBox(height: 12),
                  _sectionTitle('Histórico financeiro'),
                  const SizedBox(height: 8),
                  _historySection(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(
                          'Não foi possível atualizar. Tentar novamente',
                        ),
                      ),
                    ),
                  if (_settlementStateUnknown)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'O estado do último acerto ainda não pôde ser confirmado. Atualize antes de tentar novamente.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFF9A6900),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _loadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(_error ?? 'Não foi possível carregar os acertos.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
  );

  Widget _emptyCard(String title, String body, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        Icon(icon, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: GoogleFonts.manrope(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: const Color(0xFFE4E3EE)),
    borderRadius: BorderRadius.circular(20),
  );

  Widget _proposalCard(Map<String, dynamic> proposal) {
    final debtorId = _id(proposal['debtor_id']);
    final creditorId = _id(proposal['creditor_id']);
    final amount = '${proposal['amount'] ?? '0.00'}';
    final authorized =
        widget.currentUserId == debtorId || widget.currentUserId == creditorId;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_firstName(debtorId)} paga ${_firstName(creditorId)}',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_brl(amount)} disponíveis para acerto',
            style: GoogleFonts.manrope(fontSize: 13, color: AppTheme.muted),
          ),
          if (authorized) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _primaryButton(
                'Registrar acerto',
                onPressed: () => _openForm(proposal),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _primaryButton(
    String label, {
    required VoidCallback onPressed,
  }) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppTheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Text(label, style: GoogleFonts.manrope(fontWeight: FontWeight.w700)),
  );

  Future<void> _openForm(Map<String, dynamic> proposal) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettlementFormSheet(
        tripId: widget.tripId,
        proposal: proposal,
        participants: widget.participants,
        currentUserId: widget.currentUserId,
        service: widget.service,
      ),
    );
    if (created == true && mounted) await _afterChange();
  }

  Widget _settlementCard(Map<String, dynamic> item) {
    final id = _id(item['id']);
    final debtor = _id(item['debtor_id']);
    final creditor = _id(item['creditor_id']);
    final status = '${item['status'] ?? 'pending'}';
    final current = widget.currentUserId;
    final involved = current == debtor || current == creditor;
    final creator = _id(item['created_by_id']);
    final canConfirm =
        status == 'pending' &&
        involved &&
        current != creator &&
        !_settlementStateUnknown;
    final canCancel =
        status == 'pending' && involved && !_settlementStateUnknown;
    final busy = _busySettlementId == id;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${_firstName(debtor)} → ${_firstName(creditor)}',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _brl(item['amount']),
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Declarado por ${_name(creator)} · ${_date(item['created_at'])}',
            style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
          ),
          if (item['confirmed_at'] != null)
            Text(
              'Confirmado por ${_name(_id(item['confirmed_by_id']))} · ${_date(item['confirmed_at'])}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: const Color(0xFF16A56E),
              ),
            ),
          if (item['cancelled_at'] != null)
            Text(
              'Cancelado por ${_name(_id(item['cancelled_by_id']))} · ${_date(item['cancelled_at'])}',
              style: GoogleFonts.manrope(fontSize: 11, color: AppTheme.muted),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : () => _showDetails(id),
                  child: const Text('Detalhes'),
                ),
                if (canConfirm)
                  TextButton(
                    onPressed: busy ? null : () => _transition(item, 'confirm'),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar'),
                  ),
                if (canCancel)
                  TextButton(
                    onPressed: busy ? null : () => _askCancel(item),
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (label, color) = switch (status) {
      'confirmed' => ('Confirmado', const Color(0xFF16A56E)),
      'cancelled' => ('Cancelado', const Color(0xFF676874)),
      _ => ('Aguardando confirmação', const Color(0xFF9A6900)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _showDetails(int settlementId) async {
    try {
      final item = await widget.service.getSettlement(
        widget.tripId,
        settlementId,
      );
      if (!mounted) return;
      final status = switch ('${item['status']}') {
        'confirmed' => (
          label: 'Pagamento confirmado',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF137A50),
          background: const Color(0xFFE8F5EE),
        ),
        'cancelled' => (
          label: 'Acerto cancelado',
          icon: Icons.cancel_rounded,
          color: const Color(0xFFB42332),
          background: const Color(0xFFFCEBED),
        ),
        _ => (
          label: 'Aguardando confirmação',
          icon: Icons.schedule_rounded,
          color: const Color(0xFF946200),
          background: const Color(0xFFFFF4D6),
        ),
      };

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .88,
            ),
            child: SingleChildScrollView(
              child: Container(
                key: const ValueKey('settlement-details-sheet'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8D8A98),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Detalhes do acerto',
                            style: GoogleFonts.manrope(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF191928),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar detalhes',
                          onPressed: () => Navigator.pop(sheetContext),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1EFF8),
                            foregroundColor: const Color(0xFF191928),
                            fixedSize: const Size(40, 40),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _brl(item['amount']),
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: GoogleFonts.manrope(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF634CD4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: status.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status.icon, size: 18, color: status.color),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                status.label,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: status.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F0FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  _fullName(_id(item['debtor_id'])),
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF191928),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 19,
                                  color: Color(0xFF634CD4),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _fullName(_id(item['creditor_id'])),
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF191928),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Quem paga → Quem recebe',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF555364),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _settlementDetailRow(
                      'Declarado por',
                      _fullName(_id(item['created_by_id'])),
                    ),
                    const Divider(height: 20, color: Color(0xFFE4E3EE)),
                    _settlementDetailRow(
                      'Data da declaração',
                      _date(item['created_at']),
                    ),
                    if (item['confirmed_by_id'] != null) ...[
                      const Divider(height: 20, color: Color(0xFFE4E3EE)),
                      _settlementDetailRow(
                        'Confirmado por',
                        _fullName(_id(item['confirmed_by_id'])),
                      ),
                    ],
                    if (item['confirmed_at'] != null) ...[
                      const Divider(height: 20, color: Color(0xFFE4E3EE)),
                      _settlementDetailRow(
                        'Data da confirmação',
                        _date(item['confirmed_at']),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(_message(error));
    }
  }

  Widget _settlementDetailRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 4,
        child: Text(
          label,
          softWrap: true,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF555364),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 6,
        child: Text(
          value,
          softWrap: true,
          textAlign: TextAlign.right,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF191928),
          ),
        ),
      ),
    ],
  );

  Future<void> _askCancel(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar acerto?'),
        content: const Text(
          'A pendência será cancelada e continuará no histórico. Nenhuma transferência bancária é realizada pelo aplicativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar acerto'),
          ),
        ],
      ),
    );
    if (confirm == true) await _transition(item, 'cancel');
  }

  Future<void> _transition(Map<String, dynamic> item, String action) async {
    final id = _id(item['id']);
    if (_busySettlementId != null) return;
    setState(() => _busySettlementId = id);
    try {
      if (action == 'confirm') {
        await widget.service.confirmSettlement(widget.tripId, id);
      } else {
        await widget.service.cancelSettlement(widget.tripId, id);
      }
      await _afterChange();
      if (mounted) {
        _showMessage(
          action == 'confirm'
              ? 'Acerto confirmado no TripMate.'
              : 'Acerto cancelado.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _settlementStateUnknown = true);
      final refreshed = await _load(showLoading: false);
      final updated = _settlements
          .where((row) => _id(row['id']) == id)
          .firstOrNull;
      final expected = action == 'confirm' ? 'confirmed' : 'cancelled';
      if (refreshed && updated?['status'] == expected) {
        await widget.onFinancialChanged?.call();
        if (mounted) {
          _showMessage(
            action == 'confirm'
                ? 'Acerto já confirmado.'
                : 'Acerto já cancelado.',
          );
        }
      } else if (mounted) {
        _showMessage(_message(error));
      }
    } finally {
      if (mounted) setState(() => _busySettlementId = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _historySection() {
    final entries =
        _history
            .where((item) => '${item['action']}'.startsWith('settlement.'))
            .toList()
          ..sort(
            (a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'),
          );
    if (entries.isEmpty) {
      return _emptyCard(
        'Ainda sem movimentações.',
        'Declarações, confirmações e cancelamentos serão preservados aqui.',
        Icons.history_rounded,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFE4E3EE)),
            _historyRow(entries[i]),
          ],
        ],
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> event) {
    final snapshot = event['snapshot'] is Map
        ? Map<String, dynamic>.from(event['snapshot'] as Map)
        : <String, dynamic>{};
    final settlement = snapshot['after'] is Map
        ? Map<String, dynamic>.from(snapshot['after'] as Map)
        : snapshot;
    final status = '${event['action']}'.split('.').last;
    final debtor = _id(settlement['debtor_id']);
    final creditor = _id(settlement['creditor_id']);
    final actionLabel = switch (status) {
      'pending' => 'Acerto declarado',
      'confirmed' => 'Acerto confirmado',
      'cancelled' => 'Acerto cancelado',
      _ => 'Acerto atualizado',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionLabel,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${_name(_id(event['actor_id']))} · ${_firstName(debtor)} → ${_firstName(creditor)} · ${_date(event['created_at'])}',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _brl(settlement['amount']),
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementFormSheet extends StatefulWidget {
  final int tripId;
  final Map<String, dynamic> proposal;
  final List<TripParticipant> participants;
  final int? currentUserId;
  final TripsService service;

  const _SettlementFormSheet({
    required this.tripId,
    required this.proposal,
    required this.participants,
    required this.currentUserId,
    required this.service,
  });

  @override
  State<_SettlementFormSheet> createState() => _SettlementFormSheetState();
}

class _SettlementFormSheetState extends State<_SettlementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  late final String _requestKey = _uuidV4();
  bool _saving = false;
  bool _retryAllowed = true;
  String? _error;

  int get _debtorId => int.tryParse('${widget.proposal['debtor_id']}') ?? -1;
  int get _creditorId =>
      int.tryParse('${widget.proposal['creditor_id']}') ?? -1;
  int? get _maximumCents => _parseCents('${widget.proposal['amount']}');

  @override
  void initState() {
    super.initState();
    _amount.text = '${widget.proposal['amount'] ?? ''}';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? _parseCents(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    return (int.tryParse(parts.first) ?? 0) * 100 +
        int.parse((parts.length > 1 ? parts[1] : '0').padRight(2, '0'));
  }

  String _canonical(int cents) =>
      '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  String _name(int id) {
    if (id == widget.currentUserId) return 'Você';
    for (final participant in widget.participants) {
      if (participant.id == id) return participant.name;
    }
    return 'Participante';
  }

  Future<void> _submit() async {
    if (_saving || !_retryAllowed || !_formKey.currentState!.validate()) return;
    final cents = _parseCents(_amount.text);
    if (cents == null || cents <= 0 || cents > (_maximumCents ?? 0)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.createSettlement(widget.tripId, {
        'debtor_id': _debtorId,
        'creditor_id': _creditorId,
        'amount': _canonical(cents),
        'request_key': _requestKey,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      try {
        final current = await widget.service.getSettlements(widget.tripId);
        final match = current
            .where((item) => item['request_key'] == _requestKey)
            .firstOrNull;
        if (match != null) {
          if (mounted) {
            setState(() => _retryAllowed = true);
            Navigator.pop(context, true);
          }
          return;
        }
        if (!mounted) return;
        setState(() {
          _saving = false;
          _retryAllowed = true;
          _error =
              'O acerto não apareceu na consulta. Confira os acertos antes de tentar novamente; será usada a mesma chave para evitar duplicidade. ${error.toString()}';
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _retryAllowed = false;
          _error = 'Não foi possível confirmar se o acerto foi registrado. Atualize a lista de acertos antes de tentar novamente.';
        });
      }
    }
  }

  Future<void> _reconcile() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final current = await widget.service.getSettlements(widget.tripId);
      final match = current
          .where((item) => item['request_key'] == _requestKey)
          .firstOrNull;
      if (match != null) {
        if (mounted) {
          setState(() => _retryAllowed = true);
          Navigator.pop(context, true);
        }
      } else if (mounted) {
        setState(() {
          _saving = false;
          _retryAllowed = true;
          _error = 'Nenhum acerto com esta chave foi encontrado. Você pode tentar usando a mesma chave.';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _retryAllowed = false;
        _error =
            'Não foi possível consultar o estado remoto. ${error.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: _retryAllowed,
      child: Padding(
        padding: EdgeInsets.only(top: 32, bottom: bottom),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Form(
                key: _formKey,
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
                            'Registrar acerto',
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _saving || !_retryAllowed
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      'Esta declaração ficará pendente até a outra pessoa confirmar. O TripMate não realiza transferência bancária.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _partyRow('Quem paga', _debtorId),
                    const SizedBox(height: 8),
                    _partyRow('Quem recebe', _creditorId),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amount,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Valor do acerto',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (raw) {
                        final cents = _parseCents(raw ?? '');
                        if (cents == null || cents <= 0) {
                          return 'Informe um valor maior que zero.';
                        }
                        if (cents > (_maximumCents ?? 0)) {
                          return 'O valor excede a sugestão disponível (${widget.proposal['amount']}).';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFDE3B3D)),
                      ),
                      if (!_retryAllowed)
                        TextButton.icon(
                          onPressed: _saving ? null : _reconcile,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Consultar estado remoto'),
                        ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _saving || !_retryAllowed ? null : _submit,
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
                                'Registrar pagamento pendente',
                                style: GoogleFonts.manrope(
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

  Widget _partyRow(String label, int id) {
    final participant = widget.participants
        .where((item) => item.id == id)
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: participant?.name ?? 'Participante',
            userId: '$id',
            imageUrl: participant?.avatarUrl,
            size: 36,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    color: AppTheme.muted,
                  ),
                ),
                Text(
                  _name(id),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
