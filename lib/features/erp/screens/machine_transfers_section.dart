import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/machine_detail_models.dart';
import '../providers/erp_providers.dart';
import '../providers/machinery_providers.dart';

/// "Transfers to receive" — pending/in-transit machine transfers with a one-tap
/// Receive action. Shown to supervisors+ (operators are blocked from the transfers
/// register) on the machinery home AND the fleet list.
class MachineTransfersSection extends ConsumerWidget {
  const MachineTransfersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(machineTransfersProvider);
    final pending = async.valueOrNull?.where((t) => t.status == 'PENDING' || t.status == 'IN_TRANSIT').toList() ?? const <MachineTransferLite>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text('Transfers to receive', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      ...pending.map((t) => _TransferTile(transfer: t)),
      const SizedBox(height: 6),
    ]);
  }
}

class _TransferTile extends ConsumerStatefulWidget {
  final MachineTransferLite transfer;
  const _TransferTile({required this.transfer});
  @override
  ConsumerState<_TransferTile> createState() => _TransferTileState();
}

class _TransferTileState extends ConsumerState<_TransferTile> {
  bool _busy = false;

  Future<void> _receive() async {
    setState(() => _busy = true);
    try {
      await ref.read(machineryRepositoryProvider).receiveTransfer(widget.transfer.id);
      ref.invalidate(machineTransfersProvider);
      ref.invalidate(machineryListProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.transfer.transferCode} received')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF0891B2).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.local_shipping_outlined, size: 18, color: Color(0xFF0891B2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${t.machineName ?? 'Machine'} · ${t.transferCode}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text('${t.fromName ?? '—'} → ${t.toName ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _busy ? null : _receive,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
            child: Text(_busy ? '…' : 'Receive', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}
