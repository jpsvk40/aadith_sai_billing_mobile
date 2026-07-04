import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _green = Color(0xFF059669);

/// Inventory movements / stock ledger (read) — each stock transaction with its
/// reference (purchase receipt, transfer, etc.), location, party and item lines.
class InventoryMovementsScreen extends ConsumerStatefulWidget {
  const InventoryMovementsScreen({super.key});
  @override
  ConsumerState<InventoryMovementsScreen> createState() => _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends ConsumerState<InventoryMovementsScreen> {
  List<Map<String, dynamic>> _all = const [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get(ApiConstants.inventoryTransactions);
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

  String _d(dynamic v) => v == null ? '' : v.toString().length >= 10 ? v.toString().substring(0, 10) : v.toString();

  List<Map<String, dynamic>> get _visible {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((t) =>
        (t['referenceLabel'] ?? '').toString().toLowerCase().contains(q) ||
        (t['partyName'] ?? '').toString().toLowerCase().contains(q) ||
        (t['linkedNumber'] ?? '').toString().toLowerCase().contains(q) ||
        (t['linkedInvoiceNo'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Movements')),
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
                      if (i == 0) return _header(visible.length);
                      return _card(visible[i - 1]);
                    },
                  ),
                ),
    );
  }

  Widget _header(int shown) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_green, Color(0xFF047857)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$shown', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('stock movement${shown == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search reference, party or doc no…',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true, filled: true, fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
      const SizedBox(height: 12),
      if (_visible.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No stock movements', style: TextStyle(color: AppColors.textSecondary)))),
    ]);
  }

  Widget _card(Map<String, dynamic> t) {
    final ref = (t['referenceLabel'] ?? t['referenceType'] ?? 'Movement').toString();
    final location = ((t['location'] as Map?)?['locationName'] ?? '').toString();
    final party = (t['partyName'] ?? '').toString();
    final docNo = (t['linkedNumber'] ?? t['linkedInvoiceNo'] ?? '').toString();
    final lines = ((t['lines'] as List?) ?? const []).whereType<Map>().toList();

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
            Text(ref, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text([if (docNo.isNotEmpty) docNo, if (location.isNotEmpty) location].join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ])),
          Text(_d(t['txnDate']), style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
        if (party.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.store_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Expanded(child: Text(party, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          ]),
        ],
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...lines.take(4).map((ln) {
            final item = (ln['item'] as Map?)?.cast<String, dynamic>() ?? const {};
            final qty = double.tryParse(ln['quantity']?.toString() ?? '') ?? 0;
            final unit = (item['unit'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(children: [
                Expanded(child: Text((item['itemName'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                Text('${qty > 0 ? '+' : ''}${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)}${unit.isNotEmpty ? ' $unit' : ''}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: qty < 0 ? AppColors.danger : _green)),
              ]),
            );
          }),
          if (lines.length > 4) Padding(padding: const EdgeInsets.only(top: 3), child: Text('+${lines.length - 4} more lines', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
        ],
      ]),
    );
  }
}
