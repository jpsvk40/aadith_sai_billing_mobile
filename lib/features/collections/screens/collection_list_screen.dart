import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _teal = Color(0xFF0D9488);

enum _Period { all, week, month, custom }

/// Collections — role-aware. A collection rep sees only their own assignments
/// (backend self-scopes); an admin/manager sees the whole book with rep +
/// period filters (server-side) and status/search (instant, client-side).
class CollectionListScreen extends ConsumerStatefulWidget {
  const CollectionListScreen({super.key});

  @override
  ConsumerState<CollectionListScreen> createState() => _CollectionListScreenState();
}

class _CollectionListScreenState extends ConsumerState<CollectionListScreen> {
  List<Collection> _all = const [];
  List<Map<String, dynamic>> _reps = const [];
  bool _loading = true;
  String? _error;

  // Filters
  int? _repId; // null = all reps (admin only)
  String _status = 'All';
  _Period _period = _Period.all;
  DateTimeRange? _customRange;
  String _search = '';

  static const _statuses = ['All', 'Pending', 'Partial', 'Collected'];

  bool get _isRep {
    final u = ref.read(authProvider).user;
    return u?.isSalesRep == true || u?.isCollectionRep == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      if (!_isRep) _loadReps();
    });
  }

  String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  (String?, String?) _rangeParams() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.all:
        return (null, null);
      case _Period.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return (_d(start), _d(now));
      case _Period.month:
        return (_d(DateTime(now.year, now.month, 1)), _d(now));
      case _Period.custom:
        final r = _customRange;
        if (r == null) return (null, null);
        return (_d(r.start), _d(r.end));
    }
  }

  Future<void> _loadReps() async {
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get(ApiConstants.collectionReps);
      if (!mounted) return;
      setState(() => _reps = (data is List ? data : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList());
    } catch (_) {/* rep filter just stays hidden */}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final (from, to) = _rangeParams();
      final data = await client.get(ApiConstants.collections, queryParams: {
        if (_repId != null) 'repId': '$_repId',
        if (from != null) 'dateFrom': from,
        if (to != null) 'dateTo': to,
      });
      if (!mounted) return;
      setState(() {
        _all = (data is List ? data : const [])
            .whereType<Map>()
            .map((e) => Collection.fromJson(e.cast<String, dynamic>()))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Collection> get _visible {
    final q = _search.trim().toLowerCase();
    return _all.where((c) {
      if (_status != 'All' && c.status.toLowerCase() != _status.toLowerCase()) return false;
      if (q.isEmpty) return true;
      return (c.customerName ?? '').toLowerCase().contains(q) ||
          (c.invoiceNo ?? '').toLowerCase().contains(q) ||
          (c.representativeName ?? '').toLowerCase().contains(q) ||
          (c.city ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Color _statusColor(String s) => switch (s.toLowerCase()) {
        'collected' || 'settled' || 'completed' => AppColors.success,
        'partial' => const Color(0xFFD97706),
        'failed' => AppColors.danger,
        _ => const Color(0xFF2563EB), // Pending
      };

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customRange,
    );
    if (picked != null) {
      setState(() { _period = _Period.custom; _customRange = picked; });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final isRep = _isRep;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Collections')),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    itemCount: visible.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(visible, isRep);
                      return _card(visible[i - 1], showRep: !isRep);
                    },
                  ),
                ),
    );
  }

  Widget _header(List<Collection> visible, bool isRep) {
    double toCollect = 0, collected = 0;
    int pending = 0, partial = 0, done = 0;
    for (final c in visible) {
      toCollect += c.balanceAmount;
      collected += c.collectedAmount ?? 0;
      switch (c.status.toLowerCase()) {
        case 'partial':
          partial++;
        case 'collected' || 'settled' || 'completed':
          done++;
        default:
          pending++;
      }
    }
    final total = toCollect + collected;
    final pct = total > 0 ? (collected / total).clamp(0.0, 1.0) : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Hero ──
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_teal, Color(0xFF0F766E)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Stack(children: [
            Positioned(right: -22, top: -22, child: Container(width: 105, height: 105, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Outstanding to collect', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 4),
              Text(CurrencyUtils.format(toCollect), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 7),
              Text('${CurrencyUtils.format(collected)} collected · ${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                _heroCount('Pending', pending),
                _heroCount('Partial', partial),
                _heroCount('Collected', done),
              ]),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      // ── Rep filter (admin only) ──
      if (!isRep && _reps.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _repId,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 20),
              hint: const Text('All reps'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All reps', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                ..._reps.map((r) => DropdownMenuItem<int?>(
                      value: r['id'] as int?,
                      child: Text(r['name']?.toString() ?? '', style: const TextStyle(fontSize: 13.5)),
                    )),
              ],
              onChanged: (v) { setState(() => _repId = v); _load(); },
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      // ── Period chips ──
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _periodChip('All time', _Period.all),
          _periodChip('This week', _Period.week),
          _periodChip('This month', _Period.month),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_period == _Period.custom && _customRange != null
                  ? '${_d(_customRange!.start)} → ${_d(_customRange!.end)}'
                  : 'Custom…'),
              selected: _period == _Period.custom,
              onSelected: (_) => _pickCustomRange(),
              selectedColor: _teal.withValues(alpha: 0.15),
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _period == _Period.custom ? _teal : AppColors.textSecondary),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      // ── Status chips ──
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _statuses.map((s) {
          final sel = _status == s;
          final c = s == 'All' ? AppColors.primary : _statusColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s),
              selected: sel,
              onSelected: (_) => setState(() => _status = s),
              selectedColor: c.withValues(alpha: 0.15),
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? c : AppColors.textSecondary),
            ),
          );
        }).toList()),
      ),
      const SizedBox(height: 8),
      // ── Search ──
      TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search customer, invoice, rep or city…',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
      const SizedBox(height: 12),
      Text('${visible.length} assignment${visible.length == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      if (visible.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No collections match these filters', style: TextStyle(color: AppColors.textSecondary)))),
    ]);
  }

  Widget _heroCount(String label, int n) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$n', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _periodChip(String label, _Period p) {
    final sel = _period == p;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) { setState(() { _period = p; _customRange = null; }); _load(); },
        selectedColor: _teal.withValues(alpha: 0.15),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? _teal : AppColors.textSecondary),
      ),
    );
  }

  Widget _card(Collection c, {required bool showRep}) {
    final sc = _statusColor(c.status);
    final overdue = c.dueDate != null && c.dueDate!.isBefore(DateTime.now()) && c.balanceAmount > 0;
    final bill = c.totalOutstanding;
    final got = c.collectedAmount ?? 0;
    final pct = bill > 0 ? (got / bill).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      onTap: () => context.push('/collections/${c.id}').then((_) => _load()),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: overdue ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border, width: overdue ? 1 : 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.customerName ?? 'Customer', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((c.invoiceNo ?? '').isNotEmpty) c.invoiceNo!,
                    if ((c.city ?? '').isNotEmpty) c.city!,
                  ].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: Text(c.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sc)),
            ),
          ]),
          if ((showRep && (c.representativeName ?? '').isNotEmpty) || overdue) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (showRep && (c.representativeName ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _teal.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_outline, size: 12, color: _teal),
                    const SizedBox(width: 3),
                    Text(c.representativeName!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _teal)),
                  ]),
                ),
              if (overdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
                  child: Text('Overdue · due ${_d(c.dueDate!)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                ),
            ]),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 5,
              backgroundColor: AppColors.border.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(pct >= 1 ? AppColors.success : _teal),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _metric('Bill', CurrencyUtils.format(bill)),
            _metric('Collected', CurrencyUtils.format(got)),
            _metric('Balance', CurrencyUtils.format(c.balanceAmount), color: c.balanceAmount > 0 ? AppColors.danger : AppColors.success),
          ]),
        ]),
      ),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary)),
        ]),
      );
}
