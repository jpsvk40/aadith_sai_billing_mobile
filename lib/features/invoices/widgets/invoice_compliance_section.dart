import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// e-Invoice (IRN) + e-Way bill actions for an invoice — parity with the web invoice
/// detail. Renders nothing unless the company has e-Invoice enabled. Generation is
/// server-enforced (Draft/threshold/enabled/creds); this surfaces status + errors.
class InvoiceComplianceSection extends ConsumerStatefulWidget {
  final String invoiceId;
  const InvoiceComplianceSection({super.key, required this.invoiceId});
  @override
  ConsumerState<InvoiceComplianceSection> createState() => _InvoiceComplianceSectionState();
}

class _InvoiceComplianceSectionState extends ConsumerState<InvoiceComplianceSection> {
  late final ApiClient _client;
  bool _loading = true;
  bool _busy = false;
  bool _enableEinvoice = false;
  bool _enableEwayBill = false;
  Map<String, dynamic>? _irn;
  Map<String, dynamic>? _ewb;

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _client.get(ApiConstants.gstComplianceSettings);
      final enE = settings is Map && settings['enableEinvoice'] == true;
      final enW = settings is Map && settings['enableEwayBill'] == true;
      Map<String, dynamic>? irn;
      Map<String, dynamic>? ewb;
      if (enE) {
        final list = await _client.get(ApiConstants.einvoiceList, queryParams: {'invoiceId': widget.invoiceId});
        if (list is List && list.isNotEmpty) irn = (list.first as Map).cast<String, dynamic>();
      }
      if (enW) {
        final list = await _client.get(ApiConstants.ewayBillList, queryParams: {'invoiceId': widget.invoiceId});
        if (list is List && list.isNotEmpty) ewb = (list.first as Map).cast<String, dynamic>();
      }
      if (!mounted) return;
      setState(() {
        _enableEinvoice = enE;
        _enableEwayBill = enW;
        _irn = irn;
        _ewb = ewb;
        _loading = false;
      });
    } catch (_) {
      // Compliance is a best-effort add-on; on any failure just hide the section.
      if (mounted) setState(() { _loading = false; _enableEinvoice = false; });
    }
  }

  String? _s(Map<String, dynamic>? m, String k) => m?[k]?.toString();

  bool get _canGenerateIrn {
    final st = _s(_irn, 'status');
    return _irn == null || st == 'FAILED' || st == 'CANCELLED';
  }

  bool get _canGenerateEwb {
    if (!_enableEwayBill) return false;
    if (_s(_irn, 'status') != 'GENERATED') return false;
    final st = _s(_ewb, 'status');
    return _ewb == null || st == 'FAILED' || st == 'CANCELLED' || st == 'EXPIRED';
  }

  Future<void> _generateIrn() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate IRN?'),
        content: const Text('Register this invoice with the IRP and generate its IRN now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _client.post(ApiConstants.einvoiceGenerate(widget.invoiceId), data: const {});
      _snack('IRN request submitted');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      await _load(); // refetch so a GENERATED / FAILED doc shows
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateEwb() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _EwbSheet(),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await _client.post(ApiConstants.ewayBillGenerate(widget.invoiceId), data: result);
      _snack('e-Way bill request submitted');
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success, duration: Duration(seconds: error ? 6 : 3)));
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'GENERATED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.textSecondary;
      case 'EXPIRED':
        return AppColors.danger;
      default:
        return AppColors.warning; // PENDING / FAILED
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || (!_enableEinvoice && !_enableEwayBill)) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('e-Invoice & e-Way', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        // Badges
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (_irn != null) _badge('🧾 IRN: ${_s(_irn, 'status')}', _statusColor(_s(_irn, 'status'))),
          if (_ewb != null) _badge('🚛 EWB: ${_s(_ewb, 'status')}', _statusColor(_s(_ewb, 'status'))),
          if (_irn == null && _ewb == null) _badge('No e-documents yet', AppColors.textSecondary),
        ]),
        // Details when generated
        if (_s(_irn, 'status') == 'GENERATED') ...[
          const SizedBox(height: 12),
          _detail('IRN', _s(_irn, 'irn') ?? '—'),
          if (_s(_irn, 'ackNumber') != null) _detail('Ack No', _s(_irn, 'ackNumber')!),
          if (_s(_irn, 'ackDate') != null) _detail('Ack Date', _short(_s(_irn, 'ackDate'))),
        ],
        if (_s(_ewb, 'status') == 'GENERATED') ...[
          const SizedBox(height: 8),
          _detail('e-Way No', _s(_ewb, 'ewbNumber') ?? '—'),
          if (_s(_ewb, 'validUpto') != null) _detail('Valid upto', _short(_s(_ewb, 'validUpto'))),
        ],
        if (_s(_irn, 'status') == 'FAILED' && _s(_irn, 'errorDetails') != null) ...[
          const SizedBox(height: 8),
          Text(_s(_irn, 'errorDetails')!, style: const TextStyle(fontSize: 11.5, color: AppColors.danger)),
        ],
        const SizedBox(height: 12),
        // Actions
        Row(children: [
          if (_canGenerateIrn)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _generateIrn,
                icon: _busy ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.receipt_outlined, size: 18),
                label: const Text('Generate IRN'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          if (_canGenerateIrn && _canGenerateEwb) const SizedBox(width: 10),
          if (_canGenerateEwb)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _generateEwb,
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Generate e-Way'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
        ]),
        if (!_canGenerateIrn && !_canGenerateEwb && _s(_irn, 'status') == 'GENERATED' && !_enableEwayBill)
          const Padding(padding: EdgeInsets.only(top: 4), child: Text('IRN generated.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted))),
      ]),
    );
  }

  Widget _badge(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _detail(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 78, child: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ]),
      );

  String _short(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);
}

/// e-Way bill transport details sheet (matches the web EWB modal fields).
class _EwbSheet extends StatefulWidget {
  const _EwbSheet();
  @override
  State<_EwbSheet> createState() => _EwbSheetState();
}

class _EwbSheetState extends State<_EwbSheet> {
  final _vehicleCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _transporterIdCtrl = TextEditingController();
  final _transporterNameCtrl = TextEditingController();
  String _transportMode = '1'; // 1 Road, 2 Rail, 3 Air, 4 Ship
  String _vehicleType = 'R'; // R Regular, O ODC

  static const _modes = {'1': 'Road', '2': 'Rail', '3': 'Air', '4': 'Ship'};
  static const _vtypes = {'R': 'Regular', 'O': 'Over Dimensional Cargo'};

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _distanceCtrl.dispose();
    _transporterIdCtrl.dispose();
    _transporterNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🚛 Generate e-Way Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Consignment must exceed the threshold (default ₹50,000).', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          TextField(controller: _vehicleCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Vehicle Number (e.g. KA01AB1234)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: _transportMode,
              decoration: const InputDecoration(labelText: 'Transport Mode', border: OutlineInputBorder()),
              items: _modes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _transportMode = v ?? '1'),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _distanceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Distance (km)', border: OutlineInputBorder()),
            )),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _vehicleType,
            decoration: const InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
            items: _vtypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _vehicleType = v ?? 'R'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _transporterIdCtrl, decoration: const InputDecoration(labelText: 'Transporter ID / GSTIN (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _transporterNameCtrl, decoration: const InputDecoration(labelText: 'Transporter Name (optional)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                if (_vehicleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a vehicle number')));
                  return;
                }
                Navigator.pop(context, {
                  'vehicleNumber': _vehicleCtrl.text.trim(),
                  'transportMode': _transportMode,
                  'vehicleType': _vehicleType,
                  if (_distanceCtrl.text.trim().isNotEmpty) 'distanceKm': int.tryParse(_distanceCtrl.text.trim()) ?? 0,
                  if (_transporterIdCtrl.text.trim().isNotEmpty) 'transporterId': _transporterIdCtrl.text.trim(),
                  if (_transporterNameCtrl.text.trim().isNotEmpty) 'transporterName': _transporterNameCtrl.text.trim(),
                });
              },
              child: const Text('Generate EWB'),
            )),
          ]),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }
}
