import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/vendor_model.dart';
import '../../../data/models/scanned_bill_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/vendor_repository.dart';
import '../../../data/repositories/vendor_purchase_repository.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/purchase_list_provider.dart';

/// Optional data passed into the create form (e.g. from the AI bill scanner).
class PurchasePrefill {
  final ScannedBill? scanned;
  final String? imageDataUrl;
  const PurchasePrefill({this.scanned, this.imageDataUrl});
}

class PurchaseCreateScreen extends ConsumerStatefulWidget {
  final PurchasePrefill? prefill;
  const PurchaseCreateScreen({super.key, this.prefill});
  @override
  ConsumerState<PurchaseCreateScreen> createState() => _PurchaseCreateScreenState();
}

class _PurchaseCreateScreenState extends ConsumerState<PurchaseCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNoCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _cgstCtrl = TextEditingController();
  final _sgstCtrl = TextEditingController();
  final _igstCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Vendor> _vendors = [];
  String? _vendorId;
  DateTime _purchaseDate = DateTime.now();
  DateTime? _invoiceDate;
  bool _loadingVendors = true;
  bool _saving = false;
  bool _creatingVendor = false;
  String? _loadError;
  String? _scannedVendorName;
  String? _scannedVendorGstin;
  List<Vendor> _vendorConfirmCandidates = [];

  late final ApiClient _client;

  bool get _fromScan => widget.prefill?.scanned != null;

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    final s = widget.prefill?.scanned;
    if (s != null) {
      if (s.invoiceNumber != null) _invoiceNoCtrl.text = s.invoiceNumber!;
      if (s.totalAmount > 0) _totalCtrl.text = s.totalAmount.toStringAsFixed(2);
      if (s.cgstAmount > 0) _cgstCtrl.text = s.cgstAmount.toStringAsFixed(2);
      if (s.sgstAmount > 0) _sgstCtrl.text = s.sgstAmount.toStringAsFixed(2);
      if (s.igstAmount > 0) _igstCtrl.text = s.igstAmount.toStringAsFixed(2);
      if (s.invoiceDate != null) _invoiceDate = DateTime.tryParse(s.invoiceDate!);
    }
    _loadVendors();
  }

  @override
  void dispose() {
    _invoiceNoCtrl.dispose();
    _totalCtrl.dispose();
    _cgstCtrl.dispose();
    _sgstCtrl.dispose();
    _igstCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVendors() async {
    try {
      final vendors = await VendorRepository(_client).getVendors();
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _loadingVendors = false;
      });
      await _resolveScannedVendor();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingVendors = false;
      });
    }
  }

  // Vendor-resolution helpers — identical rules to the web bill scanner.
  String _normGstin(String? s) => (s ?? '').toUpperCase().replaceAll(RegExp(r'\s'), '');
  bool _isValidGstin(String? s) => RegExp(r'^[0-9]{2}[A-Z0-9]{13}$').hasMatch(_normGstin(s));
  String _normCity(String? s) => (s ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Resolve the scanned vendor against existing vendors, mirroring web:
  ///  1. same name + valid exact GSTIN   -> reuse
  ///  2. same name + same city           -> reuse (a differing GSTIN is an OCR variant)
  ///  3. same name, different/blank city -> ask the user to confirm (no auto-create)
  ///  4. no name match                   -> check-duplicate, else auto-create the vendor
  Future<void> _resolveScannedVendor() async {
    final scanned = widget.prefill?.scanned;
    final name = scanned?.vendorName?.trim();
    if (scanned == null || name == null || name.isEmpty) return;

    final scannedGstin = _isValidGstin(scanned.vendorGstin) ? _normGstin(scanned.vendorGstin) : null;
    final scannedCity = _normCity(scanned.vendorCity);
    final needle = name.toLowerCase();

    bool nameMatches(Vendor v) {
      final vn = v.vendorName.trim().toLowerCase();
      return vn.isNotEmpty && (vn.contains(needle) || needle.contains(vn));
    }
    final nameMatched = _vendors.where(nameMatches).toList();

    // 1. same name + exact valid GSTIN.
    Vendor? matched;
    if (scannedGstin != null) {
      for (final v in nameMatched) {
        if (_isValidGstin(v.gstin) && _normGstin(v.gstin) == scannedGstin) { matched = v; break; }
      }
    }
    // 2. same name + same city.
    if (matched == null && scannedCity.isNotEmpty) {
      for (final v in nameMatched) {
        if (_normCity(v.city) == scannedCity) { matched = v; break; }
      }
    }

    if (matched != null) {
      final id = matched.id;
      setState(() => _vendorId = id);
      return;
    }

    if (nameMatched.isNotEmpty) {
      // Name matches but neither GSTIN nor city confirms it — a new branch or a misread.
      // Do not auto-create; surface candidates so the user confirms.
      setState(() {
        _scannedVendorName = name;
        _scannedVendorGstin = scanned.vendorGstin;
        _vendorConfirmCandidates = nameMatched.take(5).toList();
      });
      return;
    }

    // 4. No confident match — widen with the duplicate check for near matches, but NEVER
    //    auto-create. Surface the scanned vendor for the user to pick an existing one or create.
    List<Vendor> candidates = [];
    try {
      final dups = await VendorRepository(_client).checkDuplicate(vendorName: name, gstin: scannedGstin ?? '');
      candidates = dups.take(5).map((d) => Vendor.fromJson(d)).toList();
      Map<String, dynamic>? strong;
      for (final d in dups) {
        final reason = d['reason']?.toString();
        final score = (d['score'] is num) ? (d['score'] as num).toDouble() : 0.0;
        final dCity = _normCity(d['city']?.toString());
        if (reason == 'Same GSTIN') { strong = d; break; }
        if (score < 0.90) continue;
        // accept a strong fuzzy name match only when the city agrees (or one side has none)
        if (scannedCity.isNotEmpty && dCity.isNotEmpty && dCity != scannedCity) continue;
        strong = d; break;
      }
      if (strong != null) {
        final v = Vendor.fromJson(strong);
        if (!mounted) return;
        setState(() {
          if (!_vendors.any((x) => x.id == v.id)) _vendors = [v, ..._vendors];
          _vendorId = v.id;
        });
        return;
      }
    } catch (_) {
      // ignore — fall through to manual review
    }

    if (!mounted) return;
    setState(() {
      _scannedVendorName = name;
      _scannedVendorGstin = scanned.vendorGstin;
      _vendorConfirmCandidates = candidates;
    });
  }

  Future<void> _createScannedVendor() async {
    final scanned = widget.prefill?.scanned;
    final name = _scannedVendorName;
    if (name == null) return;
    setState(() => _creatingVendor = true);
    try {
      final validGstin = _isValidGstin(_scannedVendorGstin) ? _normGstin(_scannedVendorGstin) : null;
      final v = await VendorRepository(_client).createVendor(
        vendorName: name,
        gstin: validGstin,
        phone: scanned?.vendorPhone,
        email: scanned?.vendorEmail,
        contactPerson: scanned?.vendorContactPerson,
        billingAddress: scanned?.vendorAddress,
        city: scanned?.vendorCity,
        state: scanned?.vendorState,
        pincode: scanned?.vendorPincode,
      );
      setState(() {
        _vendors = [v, ..._vendors];
        _vendorId = v.id;
        _scannedVendorName = null;
        _vendorConfirmCandidates = [];
        _creatingVendor = false;
      });
    } catch (e) {
      setState(() => _creatingVendor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create vendor: $e')));
      }
    }
  }

  String _apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double? _num(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _pickDate({required bool purchase}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: purchase ? _purchaseDate : (_invoiceDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (purchase) {
          _purchaseDate = picked;
        } else {
          _invoiceDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vendor')));
      return;
    }
    setState(() => _saving = true);
    try {
      await VendorPurchaseRepository(_client).createPurchase(
        vendorId: _vendorId!,
        purchaseDate: _apiDate(_purchaseDate),
        invoiceNumber: _invoiceNoCtrl.text.trim().isEmpty ? null : _invoiceNoCtrl.text.trim(),
        invoiceDate: _invoiceDate != null ? _apiDate(_invoiceDate!) : null,
        totalAmount: double.parse(_totalCtrl.text.trim()),
        cgstAmount: _num(_cgstCtrl),
        sgstAmount: _num(_sgstCtrl),
        igstAmount: _num(_igstCtrl),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        scannedInvoiceUrl: widget.prefill?.imageDataUrl,
        fromScan: _fromScan,
      );
      if (!mounted) return;
      ref.read(purchaseListProvider.notifier).load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase created'), backgroundColor: AppColors.success),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_fromScan ? 'Review Scanned Bill' : 'New Purchase')),
      body: _loadingVendors
          ? const LoadingIndicator(message: 'Loading vendors...')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_fromScan)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(child: Text('Prefilled from the scanned bill — review and adjust before saving.', style: TextStyle(fontSize: 12.5, color: AppColors.primaryDark))),
                        ],
                      ),
                    ),
                  if (_loadError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(10)),
                      child: Text('Could not load vendors: $_loadError', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),
                  _label('Vendor *'),
                  DropdownButtonFormField<String>(
                    initialValue: _vendorId,
                    isExpanded: true,
                    decoration: _dec('Select vendor'),
                    items: _vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.vendorName, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _vendorId = v),
                    validator: (v) => v == null ? 'Select a vendor' : null,
                  ),
                  if (_scannedVendorName != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 15, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _vendorConfirmCandidates.isNotEmpty
                                  ? "\"$_scannedVendorName\" may already exist (${_vendorConfirmCandidates.map((v) => (v.city == null || v.city!.isEmpty) ? v.vendorName : '${v.vendorName} – ${v.city}').join(', ')}). Select the correct vendor above, or create a new branch only if it's genuinely different."
                                  : "Scanned vendor \"$_scannedVendorName\" not found.",
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF856404)),
                            ),
                          ),
                          TextButton(
                            onPressed: _creatingVendor ? null : _createScannedVendor,
                            child: Text(_creatingVendor ? '...' : (_vendorConfirmCandidates.isNotEmpty ? 'Create new' : 'Create')),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _dateField('Purchase Date *', _purchaseDate, () => _pickDate(purchase: true))),
                      const SizedBox(width: 12),
                      Expanded(child: _dateField('Invoice Date', _invoiceDate, () => _pickDate(purchase: false))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _label('Invoice Number'),
                  TextFormField(controller: _invoiceNoCtrl, decoration: _dec('e.g. INV-1234')),
                  const SizedBox(height: 14),
                  _label('Total Amount *'),
                  TextFormField(
                    controller: _totalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: _dec('0.00'),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _amountField('CGST', _cgstCtrl)),
                      const SizedBox(width: 10),
                      Expanded(child: _amountField('SGST', _sgstCtrl)),
                      const SizedBox(width: 10),
                      Expanded(child: _amountField('IGST', _igstCtrl)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _label('Notes'),
                  TextFormField(controller: _notesCtrl, maxLines: 3, decoration: _dec('Optional notes')),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving...' : 'Create Purchase'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      );

  Widget _amountField(String label, TextEditingController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: _dec('0.00'),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(value != null ? AppDateUtils.formatDisplay(value) : 'Select',
                    style: TextStyle(fontSize: 13, color: value != null ? AppColors.textPrimary : AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
