import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/pdf_share.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/receivables_provider.dart';

/// Receivables Hub — a single Outstanding list. Each customer row carries inline
/// Pay + WA actions, so no separate Send-WA / Payment tabs are needed. Finance can
/// narrow by search, collection lens, and collection rep.
class ReceivablesHubScreen extends ConsumerStatefulWidget {
  const ReceivablesHubScreen({super.key});

  @override
  ConsumerState<ReceivablesHubScreen> createState() => _ReceivablesHubScreenState();
}

class _ReceivablesHubScreenState extends ConsumerState<ReceivablesHubScreen> {
  Map<String, dynamic>? _hubData;
  bool _loading = true;
  String? _error;

  String _filterRep = ''; // '' = all reps, '__unassigned__' = customers with an unassigned balance
  String _filterLens = 'all'; // all, unassigned, pending, partial, promised
  String _search = '';

  // Shared filter sheet + multi-key sort (mirrors the web Outstanding controls).
  // The sheet carries As-of / Invoices-from dates (server params) plus Overdue-aging
  // and District selects (client-side); sort runs over the loaded rows via applySort.
  ListFilterState _filter = ListFilterState();
  SortSpec _sort = const SortSpec('amount', 'Highest Outstanding');

  static const List<SortSpec> _sortOptions = [
    SortSpec('amount', 'Highest Outstanding'), // totalOutstanding desc
    SortSpec('oldest', 'Oldest Overdue'), // oldestOverdueDays desc
    SortSpec('name', 'Customer Name', ascending: true), // customerName A→Z
  ];

  static const String _repUnassigned = '__unassigned__';

  final List<String> _lenses = ['All', '⚠ Unassigned', 'Pending', 'Partial', 'Promised'];
  final List<String> _lensKeys = ['all', 'unassigned', 'pending', 'partial', 'promised'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Distinct collection reps present in the loaded data (sorted), for the Rep filter dropdown.
  List<String> _repNames() {
    final customers = (_hubData?['customers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final names = <String>{};
    for (final c in customers) {
      final reps = (c['reps'] as List?)?.whereType<Map>() ?? const <Map>[];
      for (final r in reps) {
        final n = r['repName'] as String?;
        if (n != null && n.isNotEmpty) names.add(n);
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  /// Distinct districts present in the loaded data (sorted), for the District select.
  List<String> _districtOptions() {
    final customers = (_hubData?['customers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final set = <String>{};
    for (final c in customers) {
      final d = c['district'] as String?;
      if (d != null && d.isNotEmpty) set.add(d);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Resolves the Overdue-aging select ('30+ days' → 30, …) to a min-overdue-days cut.
  int _minOverdueDaysOf(ListFilterState f) {
    switch (f.select('overdue')) {
      case '30+ days':
        return 30;
      case '60+ days':
        return 60;
      case '90+ days':
        return 90;
    }
    return 0;
  }

  /// Comparable extractor for [applySort] over the loaded customer rows.
  Comparable? _sortValue(Map<String, dynamic> c, String key) {
    switch (key) {
      case 'amount':
        return (c['totalOutstanding'] as num?)?.toDouble() ?? 0;
      case 'oldest':
        return (c['oldestOverdueDays'] as num?)?.toInt() ?? 0;
      case 'name':
        return (c['customerName'] as String? ?? '').toLowerCase();
    }
    return null;
  }

  /// Opens the shared filter sheet; reloads from the server only when a server-side
  /// param (As-of / Invoices-from / min-overdue) actually changed.
  Future<void> _openFilterSheet() async {
    final districts = _districtOptions();
    final result = await showListFilterSheet(
      context,
      initial: _filter,
      showPeriods: false, // an as-of snapshot, not a period report
      showDateRange: true, // From = Invoices-from, To = As-of
      selects: [
        const SelectFilter(
          key: 'overdue',
          label: 'Overdue Aging',
          options: ['30+ days', '60+ days', '90+ days'],
          allLabel: 'All ages',
        ),
        if (districts.isNotEmpty)
          SelectFilter(key: 'district', label: 'District', options: districts, allLabel: 'All districts'),
      ],
    );
    if (!mounted || result == null) return;
    final serverChanged = result.dateFromParam != _filter.dateFromParam ||
        result.dateToParam != _filter.dateToParam ||
        _minOverdueDaysOf(result) != _minOverdueDaysOf(_filter);
    setState(() => _filter = result);
    if (serverChanged) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      // Thread the server-side params the filter sheet controls: balances As-of a
      // date, only invoices dated From a date, and (optionally) a minimum overdue cut.
      final query = ReceivablesQuery(
        asOfDate: _filter.dateToParam,
        fromDate: _filter.dateFromParam,
        minOverdueDays: _minOverdueDaysOf(_filter),
      );
      final data = await client.get(ApiConstants.customerOutstanding, queryParams: query.toQueryParams());
      if (!mounted) return;
      setState(() {
        _hubData = data is Map ? data.cast<String, dynamic>() : {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterCustomers() {
    final customers = (_hubData?['customers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final q = _search.trim().toLowerCase();
    final district = _filter.select('district');
    final minOverdue = _minOverdueDaysOf(_filter);
    return customers.where((c) {
      // Search widened to city / phone / whatsapp / invoice no / Tally voucher no.
      if (q.isNotEmpty) {
        final name = (c['customerName'] as String? ?? '').toLowerCase();
        final city = (c['city'] as String? ?? '').toLowerCase();
        final phone = (c['phone'] as String? ?? '').toLowerCase();
        final wa = (c['whatsapp'] as String? ?? '').toLowerCase();
        final invMatch = ((c['invoices'] as List?) ?? const []).whereType<Map>().any((i) =>
            (i['invoiceNo'] as String? ?? '').toLowerCase().contains(q) ||
            (i['tallyVoucherNo'] as String? ?? '').toLowerCase().contains(q));
        if (!name.contains(q) && !city.contains(q) && !phone.contains(q) && !wa.contains(q) && !invMatch) {
          return false;
        }
      }
      // District — client-side SelectFilter over distinct districts in the loaded rows.
      if (district != null && district.isNotEmpty && (c['district'] as String? ?? '') != district) return false;
      // Overdue aging — keep customers whose oldest bill is at least N days overdue.
      // (Also threaded server-side via minOverdueDays; this keeps re-filtering instant.)
      if (minOverdue > 0 && ((c['oldestOverdueDays'] as num?)?.toInt() ?? 0) < minOverdue) return false;
      if (_filterRep.isNotEmpty) {
        final reps = (c['reps'] as List?)?.whereType<Map>().toList() ?? [];
        if (_filterRep == _repUnassigned) {
          // Customers carrying an unassigned (no-rep) balance — the collection gap.
          if (((c['unassignedOutstanding'] as num?)?.toDouble() ?? 0) <= 0) return false;
        } else if (!reps.any((r) => (r['repName'] as String?) == _filterRep)) {
          return false;
        }
      }
      if (_filterLens != 'all') {
        final assigned = (c['assignedOutstanding'] as num?)?.toDouble() ?? 0;
        final unassigned = (c['unassignedOutstanding'] as num?)?.toDouble() ?? 0;
        switch (_filterLens) {
          case 'unassigned':
            if (unassigned <= 0) return false;
          case 'pending':
            if (assigned <= 0 || unassigned > 0) return false;
          case 'partial':
            if (assigned <= 0 || unassigned <= 0) return false;
          case 'promised':
            if ((c['promiseDate'] as String?) == null) return false;
          default:
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Light status-bar icons — the fixed header below is a dark gradient.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: LoadingIndicator())
                  : _error != null
                      ? ErrorStateWidget(message: _error!, onRetry: _load)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _buildOutstandingTab(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Gradient hero header (title + KPI tiles) — matches the Home dashboard style. ──
  Widget _buildHeader() {
    final summary = _hubData?['summary'] as Map<String, dynamic>? ?? {};
    final total = (summary['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final coverage = (summary['coveragePct'] as num?)?.toDouble() ?? 0;
    final overdue = (summary['overdueAmount'] as num?)?.toDouble() ?? 0;
    final customers = (summary['totalCustomers'] as num?)?.toInt() ?? 0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 14, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0369A1), Color(0xFF1D4ED8), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Color(0x331D4ED8), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Outstanding & Receipts',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (customers > 0)
                Text('$customers customers',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _headerStat('Total Due', _compactInr(total), Colors.white),
              _headerStat('Coverage', '${coverage % 1 == 0 ? coverage.toStringAsFixed(0) : coverage.toStringAsFixed(1)}%', const Color(0xFF4ADE80)),
              _headerStat('Overdue', _compactInr(overdue), const Color(0xFFFCA5A5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  /// Compact Indian currency for the header tiles (₹40.3L / ₹1.2Cr) — keeps big numbers readable.
  String _compactInr(double n) {
    final a = n.abs();
    if (a >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)}Cr';
    if (a >= 100000) return '₹${(n / 100000).toStringAsFixed(2)}L';
    if (a >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
    return '₹${n.toStringAsFixed(0)}';
  }

  /// A compact 5-segment aging bar (current / 1-30 / 31-60 / 61-90 / 90+), mirroring
  /// the web AgingStrip. Returns an empty box when the row carries no aging buckets.
  Widget _agingStrip(Map<String, dynamic>? aging, double total) {
    if (aging == null || total <= 0) return const SizedBox.shrink();
    const segments = <(String, Color)>[
      ('current', Color(0xFF22C55E)),
      ('d1_30', Color(0xFFEAB308)),
      ('d31_60', Color(0xFFF97316)),
      ('d61_90', Color(0xFFEF4444)),
      ('d90p', Color(0xFF7F1D1D)),
    ];
    final bars = <Widget>[];
    for (final (key, color) in segments) {
      final v = (aging[key] as num?)?.toDouble() ?? 0;
      if (v <= 0) continue;
      bars.add(Expanded(flex: ((v / total) * 1000).round().clamp(1, 1000), child: Container(color: color)));
    }
    if (bars.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(height: 6, child: Row(children: bars)),
    );
  }

  // ── Outstanding list (search / lens / rep filters + customer cards). ──
  Widget _buildOutstandingTab() {
    final filtered = applySort(_filterCustomers(), _sort, _sortValue);
    final filteredTotal = filtered.fold<double>(0, (s, c) => s + ((c['totalOutstanding'] as num?)?.toDouble() ?? 0));

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            // Filters
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search name, city, phone, invoice no…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filters (As-of / Invoices-from / Overdue aging / District) + Sort.
                  FilterSortButtons(
                    activeFilterCount: _filter.activeCount,
                    onFilterTap: _openFilterSheet,
                    sortOptions: _sortOptions,
                    currentSort: _sort,
                    onSortChanged: (s) => setState(() => _sort = s),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _lenses.asMap().entries.map((e) {
                        final selected = _filterLens == _lensKeys[e.key];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: selected,
                            label: Text(e.value),
                            onSelected: (_) => setState(() => _filterLens = _lensKeys[e.key]),
                            backgroundColor: Colors.grey[200],
                            selectedColor: const Color(0xFF1D4ED8),
                            labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Rep filter — narrow to one collection rep's customers (or the unassigned gap).
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text('Rep', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _filterRep,
                            items: [
                              const DropdownMenuItem(value: '', child: Text('All reps')),
                              ..._repNames().map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))),
                              const DropdownMenuItem(value: _repUnassigned, child: Text('⚠ Unassigned (no rep)')),
                            ],
                            onChanged: (v) => setState(() => _filterRep = v ?? ''),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Result count line — reflects the active filters.
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${filtered.length} customer(s)', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  Text('₹${fmt(filteredTotal)}', style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            // Customer list
            if (filtered.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text('No customers match filters', style: TextStyle(color: Colors.grey[600])),
                ),
              )
            else
              Column(
                children: filtered.map((c) {
                  final total = (c['totalOutstanding'] as num?)?.toDouble() ?? 0;
                  final assigned = (c['assignedOutstanding'] as num?)?.toDouble() ?? 0;
                  final unassigned = (c['unassignedOutstanding'] as num?)?.toDouble() ?? 0;
                  final rep = (c['suggestedRep'] as Map?)?.castStringDynamic();

                  return InkWell(
                    onTap: () => _openCustomer(c),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c['customerName'] as String? ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (c['city'] != null) Text(c['city'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            Text('₹${fmt(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFDC2626))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Aging distribution (current → 90d+) + oldest-overdue caption.
                        _agingStrip((c['aging'] as Map?)?.cast<String, dynamic>(), total),
                        if (((c['oldestOverdueDays'] as num?)?.toInt() ?? 0) > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'oldest ${(c['oldestOverdueDays'] as num).toInt()}d overdue',
                            style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Coverage bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? assigned / total : 0,
                            minHeight: 6,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation(unassigned > 0 ? Colors.orange : Colors.green),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                assigned > 0 ? '✓ ₹${fmt(assigned)} with ${rep?['repName'] ?? 'rep'}' : '⚠ Not assigned',
                                style: TextStyle(fontSize: 11, color: assigned > 0 ? Colors.green[700] : Colors.red[700]),
                              ),
                            ),
                            if (unassigned > 0)
                              Chip(
                                label: Text('₹${fmt(unassigned)} gap'),
                                backgroundColor: Colors.orange[100],
                                labelStyle: const TextStyle(fontSize: 10),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Buttons wrapped in Expanded: an ElevatedButton.icon inside a Row with
                        // spaceEvenly/MainAxisSize.max gets measured with unbounded width, and its
                        // Material RenderPhysicalShape then throws "BoxConstraints forces an infinite
                        // width", blanking the card. Expanded gives each a tight, finite width.
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showPaymentDialog(c),
                                icon: const Icon(Icons.payment, size: 16),
                                label: const Text('Pay', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF15803D),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _showWhatsAppDialog(c),
                                icon: const Text('💬', style: TextStyle(fontSize: 14)),
                                label: const Text('WA', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Print every one of this customer's outstanding bills as ONE PDF, then share.
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _printBills(c),
                                icon: const Icon(Icons.receipt_long, size: 16),
                                label: const Text('Bills', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4338CA),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // Tapping a customer row opens their invoice-level statement (same UI as the
  // Collections customer statement). Each row already carries the per-invoice
  // breakdown from /customer-outstanding, so no extra fetch is needed.
  void _openCustomer(Map<String, dynamic> c) {
    final id = c['customerId'];
    if (id == null) return;
    final items = ((c['invoices'] as List?) ?? const []).whereType<Map>().map((m) {
      final inv = m.cast<String, dynamic>();
      final total = (inv['grandTotal'] as num?)?.toDouble() ?? 0;
      final paid = (inv['paidAsOf'] as num?)?.toDouble() ?? 0;
      final bal = (inv['balanceAsOf'] as num?)?.toDouble() ?? 0;
      return Collection(
        id: inv['id']?.toString() ?? '',
        invoiceId: inv['id']?.toString(),
        customerId: '$id',
        customerName: c['customerName'] as String?,
        invoiceNo: inv['invoiceNo']?.toString(),
        city: c['city'] as String?,
        totalOutstanding: total,
        collectedAmount: paid,
        balanceAmount: bal,
        status: bal <= 0 ? 'Collected' : (paid > 0 ? 'Partial' : 'Pending'),
        dueDate: inv['dueDate'] != null ? DateTime.tryParse('${inv['dueDate']}') : null,
      );
    }).toList();
    context.push('/receivables/statement/$id', extra: {
      'customerName': c['customerName'] ?? 'Customer',
      'customerNameTa': c['customerNameTa'],
      'city': c['city'],
      'phone': c['whatsapp'] ?? c['phone'],
      'items': items,
    });
  }

  // ── Dialogs ──
  void _showPaymentDialog(Map<String, dynamic> customer) {
    final totalController = TextEditingController();
    final paymentModeItems = ['Cash', 'Card', 'Bank Transfer', 'Check', 'Other'];
    String selectedMode = paymentModeItems[0];
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Record Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer['customerName'] as String? ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Outstanding: ₹${fmt((customer['totalOutstanding'] as num?)?.toDouble() ?? 0)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                  controller: totalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedMode,
                  items: paymentModeItems.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => selectedMode = v ?? selectedMode),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving || totalController.text.isEmpty
                  ? null
                  : () async {
                      setState(() => saving = true);
                      final ok = await _recordPayment(customer, totalController.text, selectedMode);
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.pop(ctx);
                      } else {
                        setState(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
              child: Text(saving ? 'Saving…' : 'Pay', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Records the payment. Returns true on success (caller closes the dialog). Captures the
  /// messenger before the await so no BuildContext is used across the async gap.
  Future<bool> _recordPayment(Map<String, dynamic> customer, String amount, String mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final parsed = double.tryParse(amount.trim());
    if (parsed == null || parsed <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return false;
    }
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      await client.post(ApiConstants.recordPayment, data: {
        'customerId': customer['customerId'],
        'amount': parsed,
        'paymentMode': mode,
      });
      if (!mounted) return false;
      _load();
      messenger.showSnackBar(const SnackBar(content: Text('Payment recorded')));
      return true;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      return false;
    }
  }

  void _showWhatsAppDialog(Map<String, dynamic> customer) {
    final nameCtrl = TextEditingController(text: customer['phone'] as String?);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Phone (or override)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendWhatsAppPdf(customer, override: nameCtrl.text.isEmpty ? null : nameCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            child: const Text('Send PDF', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsAppPdf(Map<String, dynamic> customer, {String? override}) async {
    final id = customer['customerId'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing customer id')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending statement…')));
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      // Server-side: builds the statement PDF and sends it on WhatsApp. Passing `to` overrides the
      // customer's stored WhatsApp/phone. (The old /whatsapp-print endpoint needed caller-rendered
      // HTML, which the mobile can't produce — hence the "html is required" error.)
      await client.post(
        ApiConstants.collectionStatementWhatsapp('$id'),
        data: {if (override != null && override.trim().isNotEmpty) 'to': override.trim()},
        timeout: const Duration(seconds: 90), // PDF render + WhatsApp upload can be slow on a cold server
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Statement sent on WhatsApp')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Gather this customer's outstanding invoice IDs and fetch ONE combined PDF from the backend
  // (all their full bills, one per page), then open the share sheet.
  Future<void> _printBills(Map<String, dynamic> customer) async {
    final invoiceIds = ((customer['invoices'] as List?) ?? const [])
        .whereType<Map>()
        .where((inv) => ((inv['balanceAsOf'] as num?)?.toDouble() ?? 0) > 0)
        .map((inv) => inv['id'])
        .where((id) => id != null)
        .toList();
    if (invoiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No outstanding bills to print')));
      return;
    }
    final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    final name = customer['customerName'] as String? ?? 'Customer';
    await downloadAndSharePdf(
      context,
      fetch: () => client.postBytes(
        ApiConstants.invoicesPrintBatchPdf,
        data: {'invoiceIds': invoiceIds},
        timeout: const Duration(seconds: 120), // batch PDF render can be slow on a cold server
      ),
      filename: 'Bills_${name}_${invoiceIds.length}.pdf',
      shareText: '${invoiceIds.length} invoice(s) — $name',
    );
  }
}

extension on Map {
  Map<String, dynamic> castStringDynamic() => cast<String, dynamic>();
}

String fmt(double n) => n.toStringAsFixed(2).replaceAll(RegExp(r'\.0$'), '');
