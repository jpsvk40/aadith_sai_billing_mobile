import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _amber = Color(0xFFD97706);

/// Inventory transfers (read) between locations, with one-tap Receive for
/// in-transit transfers.
class InventoryTransfersScreen extends ConsumerStatefulWidget {
  const InventoryTransfersScreen({super.key});
  @override
  ConsumerState<InventoryTransfersScreen> createState() => _InventoryTransfersScreenState();
}

class _InventoryTransfersScreenState extends ConsumerState<InventoryTransfersScreen> {
  List<Map<String, dynamic>> _all = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _client.get(ApiConstants.inventoryTransfers);
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

  Future<void> _receive(Map<String, dynamic> t) async {
    final id = t['id'].toString();
    setState(() => _busyId = id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _client.post(ApiConstants.inventoryTransferReceive(id));
      messenger.showSnackBar(const SnackBar(content: Text('✓ Transfer received')));
      await _load();
    } catch (e) {
      final raw = (e is AppException) ? e.message : e.toString();
      messenger.showSnackBar(SnackBar(content: Text(raw.isNotEmpty ? 'Could not receive: $raw' : 'Could not receive transfer.')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _d(dynamic v) => v == null ? '' : v.toString().length >= 10 ? v.toString().substring(0, 10) : v.toString();

  Color _statusColor(String s) => switch (s.toUpperCase()) {
        'RECEIVED' || 'COMPLETED' => AppColors.success,
        'IN_TRANSIT' => _amber,
        'CANCELLED' => AppColors.danger,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Transfers')),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    if (_all.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No stock transfers yet', style: TextStyle(color: AppColors.textSecondary)))),
                    ..._all.map(_card),
                  ]),
                ),
    );
  }

  Widget _card(Map<String, dynamic> t) {
    final id = t['id'].toString();
    final number = (t['transferNumber'] ?? 'Transfer').toString();
    final status = (t['status'] ?? '').toString();
    final sc = _statusColor(status);
    final from = ((t['fromLocation'] as Map?)?['locationName'] ?? '').toString();
    final to = ((t['toLocation'] as Map?)?['locationName'] ?? '').toString();
    final lines = ((t['lines'] as List?) ?? const []).whereType<Map>().toList();
    final canReceive = status.toUpperCase() == 'IN_TRANSIT';
    final busy = _busyId == id;

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
            Text(number, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(_d(t['transferDate']), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sc)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.warehouse_outlined, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(from.isEmpty ? '—' : from, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          const Icon(Icons.arrow_forward, size: 15, color: _amber),
          const SizedBox(width: 6),
          Expanded(child: Text(to.isEmpty ? '—' : to, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
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
                Text('${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)}${unit.isNotEmpty ? ' $unit' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            );
          }),
          if (lines.length > 4) Padding(padding: const EdgeInsets.only(top: 3), child: Text('+${lines.length - 4} more', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
        ],
        if (canReceive) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : () => _receive(t),
              icon: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(busy ? 'Receiving…' : 'Mark received'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: AppColors.success),
            ),
          ),
        ],
      ]),
    );
  }
}
