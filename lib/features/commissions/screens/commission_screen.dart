import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _violet = Color(0xFF7C3AED);

enum _Period { thisMonth, lastMonth, thisFy, all, custom }

enum _RepType { all, sales, collection }

/// Rep Commission — role-aware. A rep sees only their own numbers (backend
/// self-scopes); an admin sees the whole team: a per-rep leaderboard built
/// from /rep-commissions/summary and the settlement invoices (REPINV) list,
/// both driven by one period filter.
class CommissionScreen extends ConsumerStatefulWidget {
  const CommissionScreen({super.key});

  @override
  ConsumerState<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends ConsumerState<CommissionScreen> {
  List<Map<String, dynamic>> _reps = const [];
  List<Map<String, dynamic>> _invoices = const [];
  bool _loading = true;
  String? _error;

  int _tab = 0; // 0 = Reps, 1 = Settlements, 2 = History
  _Period _period = _Period.thisMonth;
  DateTimeRange? _customRange;
  String _invStatus = 'All';
  _RepType _repType = _RepType.all;
  String _search = '';
  String _invSearch = '';
  String _histSearch = '';

  static const _invStatuses = ['All', 'Pending', 'Partial', 'Paid'];

  bool get _isRep {
    final u = ref.read(authProvider).user;
    return u?.isSalesRep == true || u?.isCollectionRep == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  (String?, String?) _range() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.thisMonth:
        return (_d(DateTime(now.year, now.month, 1)), _d(now));
      case _Period.lastMonth:
        final first = DateTime(now.year, now.month - 1, 1);
        final last = DateTime(now.year, now.month, 0);
        return (_d(first), _d(last));
      case _Period.thisFy:
        // Indian FY: 1 Apr – 31 Mar.
        final fyStart = now.month >= 4 ? DateTime(now.year, 4, 1) : DateTime(now.year - 1, 4, 1);
        return (_d(fyStart), _d(now));
      case _Period.all:
        return (null, null);
      case _Period.custom:
        final r = _customRange;
        if (r == null) return (null, null);
        return (_d(r.start), _d(r.end));
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final (from, to) = _range();
      final params = {
        if (from != null) 'fromDate': from,
        if (to != null) 'toDate': to,
      };
      // Settlements are deliberately NOT period-filtered: the backend filters them by
      // settledDate, so Pending ones (settledDate null) would vanish under any range —
      // exactly the rows an admin needs to see. The period drives the leaderboard only.
      final results = await Future.wait([
        client.get(ApiConstants.commissionSummary, queryParams: params.isEmpty ? null : params),
        client.get(ApiConstants.commissions),
      ]);
      if (!mounted) return;
      List<Map<String, dynamic>> asList(dynamic d) =>
          (d is List ? d : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      setState(() {
        _reps = asList(results[0])
          ..sort((a, b) => _num(b['totalOrderAmount']).compareTo(_num(a['totalOrderAmount'])));
        _invoices = asList(results[1]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  // Paid settlements power the History tab — derived client-side from the
  // already-loaded /rep-commissions list (no dedicated history endpoint).
  List<Map<String, dynamic>> get _paidInvoices =>
      _invoices.where((i) => _num(i['paidAmount']) > 0).toList();

  String _repName(Map<String, dynamic> i) =>
      (i['representative'] is Map ? i['representative']['name'] : null)?.toString() ?? '';

  String _payDateStr(Map<String, dynamic> i) =>
      (i['lastPaymentDate'] ?? i['settledDate'] ?? '').toString();

  /// Keeps a paid invoice if its payment date lands in the selected period
  /// window ([from]/[to] are 'YYYY-MM-DD' strings; null/null = All time).
  bool _inPeriod(Map<String, dynamic> i, String? from, String? to) {
    if (from == null && to == null) return true;
    final ds = _payDateStr(i);
    if (ds.length < 10) return false; // no payment date → exclude when a period is active
    final d = ds.substring(0, 10); // 'YYYY-MM-DD' compares lexicographically as a date
    if (from != null && d.compareTo(from) < 0) return false;
    if (to != null && d.compareTo(to) > 0) return false;
    return true;
  }

  Widget _searchField(String hint, ValueChanged<String> onChanged) => TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        ),
      );

  Future<void> _pickCustom() async {
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
    final isRep = _isRep;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isRep ? 'My Commission' : 'Rep Commission')),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    _hero(),
                    const SizedBox(height: 12),
                    _periodChips(),
                    const SizedBox(height: 12),
                    // ── Tab switch: Reps | Settlements | History ──
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        _segButton('Reps (${_reps.length})', 0),
                        _segButton('Settlements (${_invoices.length})', 1),
                        _segButton('History (${_paidInvoices.length})', 2),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    if (_tab == 0)
                      ..._repsTab(isRep)
                    else if (_tab == 1)
                      ..._settlementsTab(isRep)
                    else
                      ..._historyTab(isRep),
                  ]),
                ),
    );
  }

  // ── Hero: team totals for the selected period ──
  Widget _hero() {
    double orderAmt = 0, pending = 0, paid = 0, uninvoiced = 0;
    int orders = 0;
    for (final r in _reps) {
      orderAmt += _num(r['totalOrderAmount']);
      pending += _num(r['pendingCommission']);
      paid += _num(r['paidCommission']);
      uninvoiced += _num(r['uninvoicedCommission']);
      orders += (_num(r['totalOrders'])).toInt();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_violet, Color(0xFF6D28D9)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(children: [
          Positioned(right: -22, top: -22, child: Container(width: 105, height: 105, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rep sales in period', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(height: 4),
            Text(CurrencyUtils.format(orderAmt), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 4),
            Text('$orders orders · ${_reps.length} rep${_reps.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(children: [
              _heroMetric('Pending', CurrencyUtils.format(pending)),
              _heroMetric('Paid', CurrencyUtils.format(paid)),
              _heroMetric('Not yet invoiced', CurrencyUtils.format(uninvoiced)),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _heroMetric(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _periodChips() {
    Widget chip(String label, _Period p) {
      final sel = _period == p;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) { setState(() { _period = p; _customRange = null; }); _load(); },
          selectedColor: _violet.withValues(alpha: 0.15),
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? _violet : AppColors.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip('This month', _Period.thisMonth),
        chip('Last month', _Period.lastMonth),
        chip('This FY', _Period.thisFy),
        chip('All time', _Period.all),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(_period == _Period.custom && _customRange != null
                ? '${_d(_customRange!.start)} → ${_d(_customRange!.end)}'
                : 'Custom…'),
            selected: _period == _Period.custom,
            onSelected: (_) => _pickCustom(),
            selectedColor: _violet.withValues(alpha: 0.15),
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _period == _Period.custom ? _violet : AppColors.textSecondary),
          ),
        ),
      ]),
    );
  }

  Widget _segButton(String label, int idx) {
    final sel = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? _violet : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }

  // ── Tab 0: per-rep leaderboard ──
  List<Widget> _repsTab(bool isRep) {
    final q = _search.trim().toLowerCase();
    Iterable<Map<String, dynamic>> filtered = _reps;
    // Rep-type filter (client-side). The "No Rep" informational row is always
    // kept; reps default to SALES when the field is absent (matches web).
    if (_repType != _RepType.all) {
      final want = _repType == _RepType.sales ? 'SALES' : 'COLLECTION';
      filtered = filtered.where((r) =>
          r['isNoRep'] == true || (r['repType'] ?? 'SALES').toString().toUpperCase() == want);
    }
    if (q.isNotEmpty) {
      filtered = filtered.where((r) => (r['name'] ?? '').toString().toLowerCase().contains(q));
    }
    final rows = filtered.toList();
    return [
      if (!isRep) ...[
        _searchField('Search rep…', (v) => setState(() => _search = v)),
        const SizedBox(height: 10),
        _repTypeChips(),
        const SizedBox(height: 12),
      ],
      if (rows.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No reps in this period', style: TextStyle(color: AppColors.textSecondary)))),
      ...rows.asMap().entries.map((e) => _repCard(e.key, e.value)),
    ];
  }

  // Rep-Type quick filter (All / Sales / Collection) — Reps tab only.
  Widget _repTypeChips() {
    Widget chip(String label, _RepType t) {
      final sel = _repType == t;
      final c = switch (t) {
        _RepType.sales => const Color(0xFF2563EB),
        _RepType.collection => const Color(0xFFD97706),
        _ => _violet,
      };
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) => setState(() => _repType = t),
          selectedColor: c.withValues(alpha: 0.15),
          labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? c : AppColors.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip('All Types', _RepType.all),
        chip('Sales', _RepType.sales),
        chip('Collection', _RepType.collection),
      ]),
    );
  }

  Widget _repCard(int rank, Map<String, dynamic> r) {
    final pctSet = r['commissionPercent'] != null;
    final commission = _num(r['totalCommission']);
    final pending = _num(r['pendingCommission']);
    final paid = _num(r['paidCommission']);
    final uninvoiced = _num(r['uninvoicedCommission']);
    final medal = switch (rank) { 0 => const Color(0xFFD97706), 1 => const Color(0xFF64748B), 2 => const Color(0xFFB45309), _ => _violet };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34, alignment: Alignment.center,
            decoration: BoxDecoration(color: medal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text('#${rank + 1}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: medal)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text('${r['repType'] ?? ''} · ${_num(r['totalOrders']).toInt()} orders', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (pctSet ? _violet : AppColors.textMuted).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(pctSet ? '${r['commissionPercent']}%' : '% not set',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: pctSet ? _violet : AppColors.textMuted)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _metric('Sales', CurrencyUtils.format(_num(r['totalOrderAmount']))),
          _metric('Commission', pctSet ? CurrencyUtils.format(commission) : '—'),
          _metric('Pending', CurrencyUtils.format(pending), color: pending > 0 ? const Color(0xFFD97706) : null),
          _metric('Paid', CurrencyUtils.format(paid), color: paid > 0 ? AppColors.success : null),
        ]),
        if (uninvoiced > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(7)),
            child: Text('${CurrencyUtils.format(uninvoiced)} earned but not yet on a settlement invoice',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
          ),
        ],
      ]),
    );
  }

  // ── Tab 1: settlement invoices (REPINV) ──
  List<Widget> _settlementsTab(bool isRep) {
    final q = _invSearch.trim().toLowerCase();
    var rows = _invStatus == 'All'
        ? _invoices
        : _invoices.where((i) => (i['status'] ?? '').toString().toLowerCase() == _invStatus.toLowerCase()).toList();
    if (q.isNotEmpty) {
      rows = rows.where((i) =>
          (i['invoiceNo'] ?? '').toString().toLowerCase().contains(q) ||
          _repName(i).toLowerCase().contains(q)).toList();
    }
    return [
      _searchField('Search invoice or rep…', (v) => setState(() => _invSearch = v)),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _invStatuses.map((s) {
          final sel = _invStatus == s;
          final c = switch (s) { 'Paid' => AppColors.success, 'Partial' => const Color(0xFFD97706), 'Pending' => const Color(0xFF2563EB), _ => AppColors.primary };
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s),
              selected: sel,
              onSelected: (_) => setState(() => _invStatus = s),
              selectedColor: c.withValues(alpha: 0.15),
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? c : AppColors.textSecondary),
            ),
          );
        }).toList()),
      ),
      const SizedBox(height: 10),
      if (rows.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No settlement invoices yet.\nGenerate them from the web Rep Commission page.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)))),
      ...rows.map((i) => _invoiceCard(i, showRep: !isRep)),
    ];
  }

  Widget _invoiceCard(Map<String, dynamic> i, {required bool showRep}) {
    final status = (i['status'] ?? '').toString();
    final sc = switch (status.toLowerCase()) {
      'paid' => AppColors.success,
      'partial' => const Color(0xFFD97706),
      _ => const Color(0xFF2563EB),
    };
    final commission = _num(i['commissionAmount']);
    final paid = _num(i['paidAmount']);
    final from = (i['periodFrom'] ?? '').toString();
    final to = (i['periodTo'] ?? '').toString();
    final period = from.length >= 10 && to.length >= 10 ? '${from.substring(0, 10)} → ${to.substring(0, 10)}' : '';
    final items = (i['_count'] is Map) ? (i['_count']['items'] ?? 0) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _violet.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.percent, color: _violet, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i['invoiceNo']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(
              [
                if (showRep) (i['representative'] is Map ? i['representative']['name'] : null)?.toString() ?? '',
                if (period.isNotEmpty) period,
              ].where((s) => s.isNotEmpty).join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sc)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _metric('Sales ($items inv)', CurrencyUtils.format(_num(i['totalOrderAmount']))),
          _metric('Commission', commission > 0 ? CurrencyUtils.format(commission) : '—'),
          _metric('Paid', CurrencyUtils.format(paid), color: paid > 0 ? AppColors.success : null),
        ]),
      ]),
    );
  }

  // ── Tab 2: payment history — paid settlements in the selected period ──
  List<Widget> _historyTab(bool isRep) {
    final q = _histSearch.trim().toLowerCase();
    final (from, to) = _range();
    var rows = _paidInvoices.where((i) => _inPeriod(i, from, to)).toList();
    if (q.isNotEmpty) {
      rows = rows.where((i) =>
          (i['invoiceNo'] ?? '').toString().toLowerCase().contains(q) ||
          _repName(i).toLowerCase().contains(q)).toList();
    }
    // Most-recently-paid first.
    rows.sort((a, b) => _payDateStr(b).compareTo(_payDateStr(a)));
    double paid = 0, balance = 0;
    for (final i in rows) {
      paid += _num(i['paidAmount']);
      balance += _num(i['balanceAmount']);
    }
    return [
      _searchField('Search invoice or rep…', (v) => setState(() => _histSearch = v)),
      const SizedBox(height: 12),
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('No commission payments in this period', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary))),
        )
      else ...[
        _historySummary(rows.length, paid, balance),
        const SizedBox(height: 12),
        ...rows.map((i) => _historyCard(i, showRep: !isRep)),
      ],
    ];
  }

  Widget _historySummary(int count, double paid, double balance) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.22)),
        ),
        child: Row(children: [
          _metric('Records', '$count'),
          _metric('Total Paid', CurrencyUtils.format(paid), color: AppColors.success),
          _metric('Total Balance', balance > 0 ? CurrencyUtils.format(balance) : '—', color: balance > 0 ? const Color(0xFFDC2626) : null),
        ]),
      );

  Widget _historyCard(Map<String, dynamic> i, {required bool showRep}) {
    final status = (i['paymentStatus'] ?? i['status'] ?? '').toString();
    final sc = switch (status.toLowerCase()) {
      'settled' || 'paid' => AppColors.success,
      'partial' => const Color(0xFFD97706),
      _ => const Color(0xFF2563EB),
    };
    final paid = _num(i['paidAmount']);
    final balance = _num(i['balanceAmount']);
    final payDate = _payDateStr(i);
    final payShort = payDate.length >= 10 ? payDate.substring(0, 10) : '';
    final from = (i['periodFrom'] ?? '').toString();
    final to = (i['periodTo'] ?? '').toString();
    final period = from.length >= 10 && to.length >= 10 ? '${from.substring(0, 10)} → ${to.substring(0, 10)}' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i['invoiceNo']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(
              [
                if (showRep) _repName(i),
                if (period.isNotEmpty) period,
              ].where((s) => s.isNotEmpty).join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sc)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _metric('Paid', CurrencyUtils.format(paid), color: AppColors.success),
          _metric('Balance', balance > 0 ? CurrencyUtils.format(balance) : '—', color: balance > 0 ? const Color(0xFFDC2626) : null),
          _metric('Paid on', payShort.isEmpty ? '—' : payShort),
        ]),
      ]),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary)),
        ]),
      );
}
