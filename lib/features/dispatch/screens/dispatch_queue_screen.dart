import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _orange = Color(0xFFD97706);

/// Dispatch queue — the dispatch persona's home. Entries by status with one-tap
/// "Mark delivered" (the field action); creating dispatches stays on web/orders.
class DispatchQueueScreen extends ConsumerStatefulWidget {
  const DispatchQueueScreen({super.key});
  @override
  ConsumerState<DispatchQueueScreen> createState() => _DispatchQueueScreenState();
}

class _DispatchQueueScreenState extends ConsumerState<DispatchQueueScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

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
      final data = await _client.get(ApiConstants.dispatch);
      dynamic list = data is Map ? (data['data'] ?? data['rows'] ?? const []) : data;
      if (!mounted) return;
      setState(() {
        _rows = (list is List ? list : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
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
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  Color _statusColor(String s) => switch (s.toLowerCase()) {
        'delivered' => AppColors.success,
        'dispatched' || 'in transit' => const Color(0xFF2563EB),
        _ => _orange, // Pending
      };

  @override
  Widget build(BuildContext context) {
    final pending = _rows.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'pending').length;
    final delivered = _rows.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'delivered').length;
    final inTransit = _rows.length - pending - delivered;
    final statuses = ['all', ..._rows.map((r) => (r['status'] ?? '').toString()).where((s) => s.isNotEmpty).toSet()];
    final visible = _filter == 'all' ? _rows : _rows.where((r) => (r['status'] ?? '').toString() == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Dispatch'), automaticallyImplyLeading: false),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    // Hero
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_orange, Color(0xFFB45309)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                        child: Stack(children: [
                          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                          Row(children: [
                            _stat('$pending', 'Pending'),
                            _divider(),
                            _stat('$inTransit', 'In transit'),
                            _divider(),
                            _stat('$delivered', 'Delivered'),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Status filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: statuses.map((s) {
                        final sel = _filter == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s == 'all' ? 'All' : s),
                            selected: sel,
                            selectedColor: _orange.withValues(alpha: 0.15),
                            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? _orange : AppColors.textSecondary),
                            onSelected: (_) => setState(() => _filter = s),
                          ),
                        );
                      }).toList()),
                    ),
                    const SizedBox(height: 10),
                    if (visible.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 50), child: Center(child: Text('No dispatch entries', style: TextStyle(color: AppColors.textSecondary)))),
                    ...visible.map(_card),
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
        .where((e) => e != null && e.toString().isNotEmpty).join(' · ');
    final date = (r['dispatchDate'] ?? r['updatedAt'] ?? '').toString();

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
            decoration: BoxDecoration(color: _orange.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.local_shipping_outlined, color: _orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${order['orderNo'] ?? 'Order'} · ${customer['customerName'] ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text([customer['city'], customer['district']].where((e) => e != null && e.toString().isNotEmpty).join(', '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ])),
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
        if (date.length >= 10) ...[
          const SizedBox(height: 4),
          Text('Dispatched ${date.substring(0, 10)}', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
        if (status.toLowerCase() != 'delivered') ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _markDelivered(r),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.success.withValues(alpha: 0.35))),
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
