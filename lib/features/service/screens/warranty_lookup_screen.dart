import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/service_item_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/service_providers.dart';

/// Counter / field warranty check: type or scan a serial/IMEI → registered unit + warranty status.
class WarrantyLookupScreen extends ConsumerStatefulWidget {
  const WarrantyLookupScreen({super.key});
  @override
  ConsumerState<WarrantyLookupScreen> createState() => _WarrantyLookupScreenState();
}

class _WarrantyLookupScreenState extends ConsumerState<WarrantyLookupScreen> {
  final _serialCtrl = TextEditingController();
  bool _loading = false;
  bool _searched = false;
  ServiceItem? _result;

  @override
  void dispose() {
    _serialCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup([String? serial]) async {
    final s = (serial ?? _serialCtrl.text).trim();
    if (s.isEmpty) return;
    _serialCtrl.text = s;
    setState(() { _loading = true; _searched = true; });
    final item = await ref.read(serviceRepositoryProvider).lookupBySerial(s);
    if (mounted) setState(() { _result = item; _loading = false; });
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScannerPage()));
    if (code != null && code.isNotEmpty) _lookup(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Warranty Lookup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _serialCtrl,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(labelText: 'Serial / IMEI', prefixIcon: Icon(Icons.tag), border: OutlineInputBorder()),
                onSubmitted: (v) => _lookup(v),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), tooltip: 'Scan barcode'),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _loading ? null : () => _lookup(), icon: const Icon(Icons.search), label: const Text('Look up'))),
          const SizedBox(height: 20),
          if (_loading) const Center(child: CircularProgressIndicator())
          else if (_searched && _result == null)
            _notFound()
          else if (_result != null)
            _itemCard(_result!),
        ],
      ),
    );
  }

  Widget _notFound() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.search_off, color: AppColors.warning),
          SizedBox(width: 12),
          Expanded(child: Text('No registered unit with that serial / IMEI.', style: TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _itemCard(ServiceItem item) {
    final inWarranty = item.underWarranty;
    final color = inWarranty ? AppColors.success : AppColors.danger;
    final user = ref.watch(authProvider).user;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.label.isEmpty ? (item.category ?? 'Unit') : item.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(inWarranty ? 'IN WARRANTY' : 'OUT OF WARRANTY', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 12),
        _kv('Serial', item.serialNumber),
        if (item.imei != null) _kv('IMEI', item.imei!),
        if (item.itemCode != null) _kv('Code', item.itemCode!),
        _kv('Customer', item.customer?.name ?? '—'),
        _kv('Warranty', '${item.warrantyType} · ${item.warrantyMonths} mo'),
        if (item.warrantyEndDate != null) _kv('Expires', AppDateUtils.formatDisplay(item.warrantyEndDate)),
        _kv('Status', item.derivedStatus),
        if (user?.canBill == true) ...[
          const SizedBox(height: 8),
          // Convenience: jump to raise a ticket prefilled for this customer/unit (admin).
          Text('Tip: create a ticket from the Tickets tab and pick this unit.', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 90, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary))),
        ]),
      );
}

/// Full-screen camera scanner; pops the first decoded barcode value.
class _ScannerPage extends StatefulWidget {
  const _ScannerPage();
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan serial / IMEI')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
          if (code != null && code.isNotEmpty) {
            _done = true;
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}
