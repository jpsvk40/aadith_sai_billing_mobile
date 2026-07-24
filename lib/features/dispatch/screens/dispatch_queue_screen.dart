import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dispatch_queue_provider.dart';

const _orange = Color(0xFFD97706);

/// Dispatch queue — the dispatch persona's home. A scope toggle switches between
/// orders "Ready to Dispatch" (Packed) and already-"Dispatched" entries, matching
/// the web Dispatch Queue tabs. Search + date/period + sort mirror the web too;
/// one-tap "Mark delivered" stays as the field action (creating dispatches stays
/// on web/orders).
class DispatchQueueScreen extends ConsumerStatefulWidget {
  const DispatchQueueScreen({super.key});
  @override
  ConsumerState<DispatchQueueScreen> createState() => _DispatchQueueScreenState();
}

class _DispatchQueueScreenState extends ConsumerState<DispatchQueueScreen> {
  final _searchController = TextEditingController();
  String _scope = DispatchScope.packed;
  String? _statusFilter; // fixed-enum status chip (null = All)

  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  static const _sortOptions = <SortSpec>[
    SortSpec('date', 'Date'),
    SortSpec('customer', 'Customer'),
  ];

  // Fixed status enum (was data-derived) — covers both scopes.
  static const _statusChips = <String>['All', 'Packed', 'Dispatched', 'Delivered'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ApiClient get _client =>
      ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  void _reload() {
    ref.read(dispatchQueueProvider.notifier).load(
          scope: _scope,
          dateFrom: _filters.dateFromParam,
          dateTo: _filters.dateToParam,
        );
  }

  void _setScope(String s) {
    if (_scope == s) return;
    setState(() {
      _scope = s;
      _statusFilter = null;
    });
    _reload();
  }

  Future<void> _openFilters() async {
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      showPeriods: true,
      showDateRange: true,
    );
    if (res != null) {
      setState(() => _filters = res);
      _reload(); // date/period is threaded server-side (Packed) / re-applied client-side (Dispatched)
    }
  }

  Future<void> _markDelivered(Map<String, dynamic> entry) async {
    final remarks = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delivered — ${(entry['order'] as Map?)?['orderNo'] ?? '#${entry['id']}'}'),
        content: TextField(controller: remarks, decoration: const InputDecoration(labelText: 'Remarks (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark delivered')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _client.post(ApiConstants.dispatchDelivered('${entry['id']}'), data: {
        if (remarks.text.trim().isNotEmpty) 'remarks': remarks.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked delivered.')));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  // ─────────────────────────── client-side filtering ───────────────────────────

  String _orderNo(Map<String, dynamic> r) => ((r['order'] as Map?)?['orderNo'] ?? '').toString();
  String _customerName(Map<String, dynamic> r) =>
      (((r['order'] as Map?)?['customer'] as Map?)?['customerName'] ?? '').toString();

  DateTime? _rowDate(Map<String, dynamic> r) {
    final raw = (_scope == DispatchScope.packed
            ? r['orderDate']
            : (r['dispatchDate'] ?? r['updatedAt'] ?? r['orderDate']))
        ?.toString();
    return (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);
  }

  Comparable? _rowSortValue(Map<String, dynamic> r, String key) {
    switch (key) {
      case 'date':
        return _rowDate(r);
      case 'customer':
        return _customerName(r).toLowerCase();
    }
    return null;
  }

  List<Map<String, dynamic>> _visible(List<Map<String, dynamic>> rows) {
    var list = rows;

    // Fixed-enum status chip.
    if (_statusFilter != null && _statusFilter != 'All') {
      list = list.where((r) => (r['status'] ?? '').toString().toLowerCase() == _statusFilter!.toLowerCase()).toList();
    }

    // Search (order # / customer name) — client-side over the loaded list.
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) => _orderNo(r).toLowerCase().contains(q) || _customerName(r).toLowerCase().contains(q)).toList();
    }

    // The /dispatch endpoint ignores date params, so re-apply the window client-side.
    if (_scope == DispatchScope.dispatched) {
      final w = _filters.effectiveWindow;
      final from = w?.from ?? _filters.dateFrom;
      final to = w?.to ?? _filters.dateTo;
      if (from != null || to != null) {
        final lo = from == null ? null : DateTime(from.year, from.month, from.day);
        final hi = to == null ? null : DateTime(to.year, to.month, to.day, 23, 59, 59);
        list = list.where((r) {
          final d = _rowDate(r);
          if (d == null) return false;
          if (lo != null && d.isBefore(lo)) return false;
          if (hi != null && d.isAfter(hi)) return false;
          return true;
        }).toList();
      }
    }

    if (_sort != null) list = applySort(list, _sort!, _rowSortValue);
    return list;
  }

  // ─────────────────────────── build ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dispatchQueueProvider);
    final visible = _visible(state.rows);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Dispatch'), automaticallyImplyLeading: false),
      body: Column(
        children: [
          _scopeToggle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search order # or customer…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchController.clear()),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          FilterSortButtons(
            activeFilterCount: _filters.activeCount,
            onFilterTap: _openFilters,
            sortOptions: _sortOptions,
            currentSort: _sort,
            onSortChanged: (s) => setState(() => _sort = s),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _statusChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = _statusChips[i];
                final sel = (s == 'All' && _statusFilter == null) || s == _statusFilter;
                return ChoiceChip(
                  label: Text(s),
                  selected: sel,
                  selectedColor: _orange.withValues(alpha: 0.15),
                  labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? _orange : AppColors.textSecondary),
                  side: BorderSide(color: sel ? _orange : AppColors.border),
                  onSelected: (_) => setState(() => _statusFilter = s == 'All' ? null : s),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: state.isLoading && state.rows.isEmpty
                ? const LoadingIndicator()
                : state.error != null && state.rows.isEmpty
                    ? ErrorStateWidget(message: state.error!, onRetry: _reload)
                    : RefreshIndicator(
                        onRefresh: () async => _reload(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                          children: [
                            _hero(visible),
                            const SizedBox(height: 12),
                            if (visible.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 50),
                                child: Center(
                                  child: Text(
                                    _scope == DispatchScope.packed ? 'No packed orders' : 'No dispatch entries',
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ...visible.map(_card),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _scopeToggle() {
    Widget seg(String key, String label, IconData icon) {
      final sel = _scope == key;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setScope(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: sel ? _orange : Colors.transparent, borderRadius: BorderRadius.circular(9)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: sel ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        seg(DispatchScope.packed, 'Ready to Dispatch', Icons.inventory_2_outlined),
        seg(DispatchScope.dispatched, 'Dispatched', Icons.local_shipping_outlined),
      ]),
    );
  }

  Widget _hero(List<Map<String, dynamic>> visible) {
    final value = visible.fold<double>(0, (a, r) => a + _num((r['order'] as Map?)?['grandTotal']));
    int countStatus(String s) => visible.where((r) => (r['status'] ?? '').toString().toLowerCase() == s).length;

    final stats = _scope == DispatchScope.packed
        ? <(String, String)>[
            ('${visible.length}', 'Ready'),
            (CurrencyUtils.formatCompact(value), 'Value'),
          ]
        : <(String, String)>[
            ('${countStatus('dispatched')}', 'Dispatched'),
            ('${countStatus('delivered')}', 'Delivered'),
            (CurrencyUtils.formatCompact(value), 'Value'),
          ];

    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      children.add(_stat(stats[i].$1, stats[i].$2));
      if (i != stats.length - 1) children.add(_divider());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_orange, Color(0xFFB45309)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10))),
          ),
          Row(children: children),
        ]),
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.78))),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.22), margin: const EdgeInsets.symmetric(horizontal: 12));

  Color _statusColor(String s) => switch (s.toLowerCase()) {
        'delivered' => AppColors.success,
        'dispatched' || 'in transit' => const Color(0xFF2563EB),
        'packed' => _orange,
        _ => _orange, // Pending
      };

  Widget _card(Map<String, dynamic> r) {
    final order = (r['order'] as Map?)?.cast<String, dynamic>() ?? const {};
    final customer = (order['customer'] as Map?)?.cast<String, dynamic>() ?? const {};
    final status = (r['status'] ?? 'Pending').toString();
    final sc = _statusColor(status);
    final counts = <String>[
      if (_num(r['bagCount']) > 0) '${_num(r['bagCount']).toInt()} bags',
      if (_num(r['canCount']) > 0) '${_num(r['canCount']).toInt()} cans',
      if (_num(r['boxCount']) > 0) '${_num(r['boxCount']).toInt()} boxes',
    ];
    final transport = [r['transporterName'], r['vehicleNo'], if ((r['lrNo'] ?? '').toString().isNotEmpty) 'LR ${r['lrNo']}']
        .where((e) => e != null && e.toString().isNotEmpty)
        .join(' · ');
    final isPacked = _scope == DispatchScope.packed;
    final rawDate = ((isPacked ? r['orderDate'] : (r['dispatchDate'] ?? r['updatedAt'] ?? r['orderDate'])) ?? '').toString();
    final dateLabel = isPacked ? 'Ordered' : 'Dispatched';
    // "Mark delivered" only applies to dispatched (not delivered) entries; Packed
    // rows are view-only (creating dispatches stays on web/orders).
    final canDeliver = !isPacked && status.toLowerCase() != 'delivered';

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _orange.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.local_shipping_outlined, color: _orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${order['orderNo'] ?? 'Order'} · ${customer['customerName'] ?? '—'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text([customer['city'], customer['district']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sc)),
          ),
        ]),
        const SizedBox(height: 8),
        if (transport.isNotEmpty)
          Row(children: [
            const Icon(Icons.route_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Expanded(child: Text(transport, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
          ]),
        const SizedBox(height: 6),
        Row(children: [
          if (counts.isNotEmpty)
            Expanded(child: Text(counts.join(' · '), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)))
          else
            const Spacer(),
          if (_num(order['grandTotal']) > 0)
            Text(CurrencyUtils.format(_num(order['grandTotal'])), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        if (rawDate.length >= 10) ...[
          const SizedBox(height: 4),
          Text('$dateLabel ${rawDate.substring(0, 10)}', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
        if (canDeliver) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _markDelivered(r),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                SizedBox(width: 6),
                Text('Mark delivered', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.success)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
