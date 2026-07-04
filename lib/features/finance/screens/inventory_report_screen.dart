import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../finance_reports.dart';

const _cyan = Color(0xFF0891B2);

/// Inventory stock report — mirrors the web Inventory Reports "Stock View": every item
/// with its actual count and a stock state (Out of Stock / Low / In Stock / No Reorder),
/// state filter chips, search, and a link to Stock Valuation. Shared by all 3 verticals.
class InventoryReportScreen extends ConsumerStatefulWidget {
  const InventoryReportScreen({super.key});
  @override
  ConsumerState<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends ConsumerState<InventoryReportScreen> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  String _state = 'all';
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _client.get(ApiConstants.inventoryStockSummary);
      final m = (data is Map ? data : const {}).cast<String, dynamic>();
      final totals = ((m['itemTotals'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      if (!mounted) return;
      setState(() { _items = totals; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Same rules as the web report's getStockState.
  (String, String, Color) _stockState(Map<String, dynamic> r) {
    final qty = _num(r['totalQuantity']);
    final reorder = _num(r['reorderLevel']);
    if (qty <= 0) return ('out_of_stock', 'Out of Stock', const Color(0xFFDC2626));
    if (reorder > 0 && qty <= reorder) return ('low_stock', 'Low Stock', const Color(0xFFD97706));
    if (reorder <= 0) return ('no_reorder', 'No Reorder Set', const Color(0xFF0284C7));
    return ('in_stock', 'In Stock', const Color(0xFF16A34A));
  }

  String _qty(Map<String, dynamic> r) {
    final q = _num(r['totalQuantity']);
    final unit = (r['itemUnit'] ?? r['unit'] ?? '').toString();
    final s = q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
    return unit.isEmpty ? s : '$s $unit';
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{'out_of_stock': 0, 'low_stock': 0, 'in_stock': 0, 'no_reorder': 0};
    for (final r in _items) {
      counts[_stockState(r).$1] = (counts[_stockState(r).$1] ?? 0) + 1;
    }
    final visible = _items.where((r) {
      if (_state != 'all' && _stockState(r).$1 != _state) return false;
      if (_q.isEmpty) return true;
      final s = _q.toLowerCase();
      return (r['displayName'] ?? r['itemName'] ?? '').toString().toLowerCase().contains(s) ||
          (r['itemCode'] ?? '').toString().toLowerCase().contains(s);
    }).toList();

    const chips = <(String, String)>[
      ('all', 'All'),
      ('out_of_stock', 'Out of Stock'),
      ('low_stock', 'Low Stock'),
      ('in_stock', 'In Stock'),
      ('no_reorder', 'No Reorder'),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/reports/view', extra: FinanceReports.inventoryValuation),
            icon: const Icon(Icons.currency_rupee, size: 16, color: Colors.white),
            label: const Text('Valuation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    // Hero — state counts
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_cyan, Color(0xFF0E7490)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                        child: Row(children: [
                          _stat('${counts['out_of_stock']}', 'Out of stock'),
                          _divider(),
                          _stat('${counts['low_stock']}', 'Low stock'),
                          _divider(),
                          _stat('${counts['in_stock']}', 'In stock'),
                          _divider(),
                          _stat('${_items.length}', 'Items'),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setState(() => _q = v),
                      decoration: InputDecoration(
                        hintText: 'Search item, code…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true, filled: true, fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: chips.map((c) {
                        final sel = _state == c.$1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.$2),
                            selected: sel,
                            selectedColor: _cyan.withValues(alpha: 0.15),
                            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? _cyan : AppColors.textSecondary),
                            onSelected: (_) => setState(() => _state = c.$1),
                          ),
                        );
                      }).toList()),
                    ),
                    const SizedBox(height: 10),
                    if (visible.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Center(child: Text('No matching items', style: TextStyle(color: AppColors.textSecondary)))),
                    ...visible.map((r) {
                      final st = _stockState(r);
                      final reorder = _num(r['reorderLevel']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(color: st.$3.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.inventory_2_outlined, color: st.$3, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text((r['displayName'] ?? r['itemName'] ?? '—').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('${r['itemCode'] ?? ''}${reorder > 0 ? ' · reorder at ${reorder % 1 == 0 ? reorder.toInt() : reorder}' : ''}',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ])),
                          const SizedBox(width: 8),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(_qty(r), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: st.$3.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text(st.$2, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: st.$3)),
                            ),
                          ]),
                        ]),
                      );
                    }),
                  ]),
                ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.78))),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.22), margin: const EdgeInsets.symmetric(horizontal: 10));
}
