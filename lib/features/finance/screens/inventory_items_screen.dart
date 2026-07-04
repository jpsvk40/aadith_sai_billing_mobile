import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _blue = Color(0xFF1D4ED8);

/// Inventory item master (read) — code, category, material type, rate & reorder level.
class InventoryItemsScreen extends ConsumerStatefulWidget {
  const InventoryItemsScreen({super.key});
  @override
  ConsumerState<InventoryItemsScreen> createState() => _InventoryItemsScreenState();
}

class _InventoryItemsScreenState extends ConsumerState<InventoryItemsScreen> {
  List<Map<String, dynamic>> _all = const [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get(ApiConstants.inventoryItems);
      if (!mounted) return;
      setState(() {
        _all = (data is List ? data : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((it) =>
        (it['itemName'] ?? '').toString().toLowerCase().contains(q) ||
        (it['displayName'] ?? '').toString().toLowerCase().contains(q) ||
        (it['itemCode'] ?? '').toString().toLowerCase().contains(q) ||
        (it['category'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final active = _all.where((i) => i['isActive'] != false).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Items')),
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
                      if (i == 0) return _header(active);
                      return _card(visible[i - 1]);
                    },
                  ),
                ),
    );
  }

  Widget _header(int active) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_blue, Color(0xFF1E3A8A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.category_outlined, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_all.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('$active active item${active == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search item, code or category…',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true, filled: true, fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
      const SizedBox(height: 12),
      if (_visible.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No items', style: TextStyle(color: AppColors.textSecondary)))),
    ]);
  }

  Widget _card(Map<String, dynamic> it) {
    final name = (it['displayName'] ?? it['itemName'] ?? 'Item').toString();
    final code = (it['itemCode'] ?? '').toString();
    final category = (it['category'] ?? '').toString();
    final material = (it['materialType'] ?? '').toString();
    final unit = ((it['product'] as Map?)?['unit'] ?? it['unit'] ?? '').toString();
    final cost = _num(it['defaultUnitCost']);
    final reorder = _num(it['reorderLevel']);
    final inactive = it['isActive'] == false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text([if (code.isNotEmpty) code, if (category.isNotEmpty) category].join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ])),
          if (material.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _blue.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
              child: Text(material, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _blue)),
            ),
          if (inactive)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.textMuted.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: const Text('Inactive', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _metric('Rate', cost > 0 ? CurrencyUtils.format(cost) : '—'),
          _metric('Reorder at', reorder > 0 ? '${reorder.toStringAsFixed(reorder == reorder.roundToDouble() ? 0 : 2)}${unit.isNotEmpty ? ' $unit' : ''}' : '—'),
          _metric('Unit', unit.isNotEmpty ? unit : '—'),
        ]),
      ]),
    );
  }

  Widget _metric(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
      );
}
