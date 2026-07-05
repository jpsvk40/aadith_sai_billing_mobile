import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/vendor_model.dart';
import '../../../data/models/scanned_bill_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/product_repository.dart';
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

/// A single editable purchase line. Mirrors the web `emptyLine()` + `computeLine()`.
class _Line {
  final descCtrl = TextEditingController();
  final hsnCtrl = TextEditingController();
  final unitCtrl = TextEditingController(text: 'pcs');
  final qtyCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final gstCtrl = TextEditingController();
  final discCtrl = TextEditingController();
  String? productId;
  bool igst = false; // inter-state → tax goes to IGST; else split CGST/SGST
  List<ScannedVariantAllocation> allocations = const [];
  Map<String, dynamic>? priceHint;

  double get _qty => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get _price => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get _gstPct => double.tryParse(gstCtrl.text.trim()) ?? 0;
  double get _disc => double.tryParse(discCtrl.text.trim()) ?? 0;

  double get gross => _qty * _price;
  double get taxable => (gross - _disc) < 0 ? 0 : gross - _disc;
  double get cgst => igst ? 0 : taxable * (_gstPct / 2) / 100;
  double get sgst => igst ? 0 : taxable * (_gstPct / 2) / 100;
  double get igstAmt => igst ? taxable * _gstPct / 100 : 0;
  double get total => taxable + cgst + sgst + igstAmt;

  double get allocQty => allocations.fold<double>(0, (a, x) => a + x.quantity);

  Map<String, dynamic> toPayload() => {
        if (productId != null) 'productId': productId,
        'itemDescription': descCtrl.text.trim(),
        if (hsnCtrl.text.trim().isNotEmpty) 'hsnCode': hsnCtrl.text.trim(),
        'unit': unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim(),
        'quantity': _qty,
        'unitPrice': _price,
        'taxPercent': _gstPct,
        'cgstPercent': igst ? 0 : _gstPct / 2,
        'sgstPercent': igst ? 0 : _gstPct / 2,
        'igstPercent': igst ? _gstPct : 0,
        'discountAmount': _disc,
        if (allocations.isNotEmpty)
          'variantAllocations': allocations.map((a) => a.toPayload()).toList(),
      };

  void dispose() {
    descCtrl.dispose();
    hsnCtrl.dispose();
    unitCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    gstCtrl.dispose();
    discCtrl.dispose();
  }
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
  final _freightCtrl = TextEditingController();
  final _miscCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Vendor> _vendors = [];
  List<Product> _products = [];
  final List<_Line> _lines = [];
  String? _vendorId;
  DateTime _purchaseDate = DateTime.now();
  DateTime? _invoiceDate;
  bool _loading = true;
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
      if (s.invoiceDate != null) _invoiceDate = DateTime.tryParse(s.invoiceDate!);
      if (s.freightCharges != null && s.freightCharges! > 0) _freightCtrl.text = s.freightCharges!.toStringAsFixed(2);
      if (s.roundOffAmount != null && s.roundOffAmount! > 0) _miscCtrl.text = s.roundOffAmount!.toStringAsFixed(2);
      if (s.notes != null) _notesCtrl.text = s.notes!;
      for (final it in s.items) {
        _lines.add(_lineFromScan(it));
      }
    }
    if (_lines.isEmpty) _lines.add(_Line());
    _load();
  }

  _Line _lineFromScan(ScannedItem it) {
    final l = _Line();
    l.descCtrl.text = it.itemDescription;
    if (it.hsnCode != null) l.hsnCtrl.text = it.hsnCode!;
    l.unitCtrl.text = (it.unit == null || it.unit!.isEmpty) ? 'pcs' : it.unit!;
    // If variant widths were extracted, the line quantity is their sum.
    final qty = it.variantAllocations.isNotEmpty
        ? it.variantAllocations.fold<double>(0, (a, x) => a + x.quantity)
        : it.quantity;
    if (qty > 0) l.qtyCtrl.text = _trim(qty);
    if (it.unitPrice > 0) l.priceCtrl.text = _trim(it.unitPrice);
    if (it.discountAmount != null && it.discountAmount! > 0) l.discCtrl.text = _trim(it.discountAmount!);
    final igstPct = it.igstPercent;
    if (igstPct > 0) {
      l.igst = true;
      l.gstCtrl.text = _trim(igstPct);
    } else {
      final tot = it.cgstPercent + it.sgstPercent;
      if (tot > 0) l.gstCtrl.text = _trim(tot);
    }
    l.allocations = it.variantAllocations;
    return l;
  }

  String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _invoiceNoCtrl.dispose();
    _freightCtrl.dispose();
    _miscCtrl.dispose();
    _notesCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final vendors = await VendorRepository(_client).getVendors();
      List<Product> products = [];
      try {
        products = await ProductRepository(_client).getProducts();
      } catch (_) {/* catalog optional */}
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _products = products;
        _loading = false;
      });
      await _resolveScannedVendor();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  // ── Vendor resolution — identical rules to the web bill scanner ──
  String _normGstin(String? s) => (s ?? '').toUpperCase().replaceAll(RegExp(r'\s'), '');
  bool _isValidGstin(String? s) => RegExp(r'^[0-9]{2}[A-Z0-9]{13}$').hasMatch(_normGstin(s));
  String _normCity(String? s) => (s ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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

    Vendor? matched;
    if (scannedGstin != null) {
      for (final v in nameMatched) {
        if (_isValidGstin(v.gstin) && _normGstin(v.gstin) == scannedGstin) { matched = v; break; }
      }
    }
    if (matched == null && scannedCity.isNotEmpty) {
      for (final v in nameMatched) {
        if (_normCity(v.city) == scannedCity) { matched = v; break; }
      }
    }

    if (matched != null) {
      setState(() => _vendorId = matched!.id);
      _refreshPriceHints();
      return;
    }

    if (nameMatched.isNotEmpty) {
      setState(() {
        _scannedVendorName = name;
        _scannedVendorGstin = scanned.vendorGstin;
        _vendorConfirmCandidates = nameMatched.take(5).toList();
      });
      return;
    }

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
        _refreshPriceHints();
        return;
      }
    } catch (_) {/* fall through to manual review */}

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
        forceCreate: true,
      );
      setState(() {
        _vendors = [v, ..._vendors];
        _vendorId = v.id;
        _scannedVendorName = null;
        _vendorConfirmCandidates = [];
        _creatingVendor = false;
      });
      _refreshPriceHints();
    } catch (e) {
      setState(() => _creatingVendor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create vendor: $e')));
      }
    }
  }

  String _apiDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Totals (mirror web) ──
  double get _linesTotal => _lines.fold<double>(0, (a, l) => a + l.total);
  double get _subtotal => _lines.fold<double>(0, (a, l) => a + l.gross);
  double get _discountTotal => _lines.fold<double>(0, (a, l) => a + l._disc);
  double get _cgstTotal => _lines.fold<double>(0, (a, l) => a + l.cgst);
  double get _sgstTotal => _lines.fold<double>(0, (a, l) => a + l.sgst);
  double get _igstTotal => _lines.fold<double>(0, (a, l) => a + l.igstAmt);
  double get _freight => double.tryParse(_freightCtrl.text.trim()) ?? 0;
  double get _misc => double.tryParse(_miscCtrl.text.trim()) ?? 0;
  double get _grandTotal => _linesTotal + _freight + _misc;

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

  // ── Product picker (catalog + non-catalog) ──
  Future<void> _pickProduct(_Line line) async {
    final selected = await showModalBottomSheet<Product?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => _ProductPickerSheet(products: _products),
    );
    if (selected == null) return;
    setState(() {
      if (selected.id.isEmpty) {
        // "Non-catalog item" sentinel
        line.productId = null;
      } else {
        line.productId = selected.id;
        if (line.descCtrl.text.trim().isEmpty) line.descCtrl.text = selected.name;
        if (selected.unit != null && selected.unit!.isNotEmpty) line.unitCtrl.text = selected.unit!;
        if (selected.hsnCode != null && line.hsnCtrl.text.trim().isEmpty) line.hsnCtrl.text = selected.hsnCode!;
        if (selected.taxPercent > 0 && line.gstCtrl.text.trim().isEmpty) line.gstCtrl.text = _trim(selected.taxPercent);
      }
    });
    if (line.productId != null) _loadPriceHint(line);
  }

  Future<void> _loadPriceHint(_Line line) async {
    final pid = line.productId;
    if (pid == null) return;
    final hint = await VendorPurchaseRepository(_client).priceHint(productId: pid, vendorId: _vendorId);
    if (!mounted) return;
    setState(() => line.priceHint = hint);
  }

  void _refreshPriceHints() {
    for (final l in _lines) {
      if (l.productId != null) _loadPriceHint(l);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vendor')));
      return;
    }
    final validLines = _lines.where((l) => l.descCtrl.text.trim().isNotEmpty && l._qty > 0).toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item with a description and quantity')));
      return;
    }
    setState(() => _saving = true);
    try {
      await VendorPurchaseRepository(_client).createPurchase(
        vendorId: _vendorId!,
        purchaseDate: _apiDate(_purchaseDate),
        invoiceNumber: _invoiceNoCtrl.text.trim().isEmpty ? null : _invoiceNoCtrl.text.trim(),
        invoiceDate: _invoiceDate != null ? _apiDate(_invoiceDate!) : null,
        items: validLines.map((l) => l.toPayload()).toList(),
        freightCharges: _freight,
        miscCharges: _misc,
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
      body: _loading
          ? const LoadingIndicator(message: 'Loading...')
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_fromScan) _scanBanner(),
                  if (widget.prefill?.scanned?.validationWarnings.isNotEmpty ?? false) _warningsBanner(),
                  if (_loadError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(10)),
                      child: Text('Could not load: $_loadError', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    ),
                  _label('Vendor *'),
                  DropdownButtonFormField<String>(
                    initialValue: _vendorId,
                    isExpanded: true,
                    decoration: _dec('Select vendor'),
                    items: _vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.vendorName, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) { setState(() => _vendorId = v); _refreshPriceHints(); },
                    validator: (v) => v == null ? 'Select a vendor' : null,
                  ),
                  if (_scannedVendorName != null) _vendorConfirmBanner(),
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
                  const SizedBox(height: 20),
                  Row(children: [
                    const Text('Invoice Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const Spacer(),
                    Text('${_lines.length} line${_lines.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 10),
                  ...List.generate(_lines.length, (i) => _lineCard(i)),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _lines.add(_Line())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: _amountField('Freight Charges (₹)', _freightCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _amountField('Misc Charges (₹)', _miscCtrl)),
                  ]),
                  const SizedBox(height: 14),
                  _label('Notes'),
                  TextFormField(controller: _notesCtrl, maxLines: 3, decoration: _dec('Optional notes')),
                  const SizedBox(height: 16),
                  _totalsCard(),
                  const SizedBox(height: 20),
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

  Widget _scanBanner() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(child: Text('Prefilled from the scanned bill — review items and totals before saving.', style: TextStyle(fontSize: 12.5, color: AppColors.primaryDark))),
        ]),
      );

  Widget _warningsBanner() {
    final w = widget.prefill!.scanned!.validationWarnings;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
          SizedBox(width: 6),
          Text('Review needed', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF856404))),
        ]),
        const SizedBox(height: 4),
        ...w.map((m) => Text('• $m', style: const TextStyle(fontSize: 11.5, color: Color(0xFF856404)))),
      ]),
    );
  }

  Widget _vendorConfirmBanner() => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
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
        ]),
      );

  Widget _lineCard(int i) {
    final l = _lines[i];
    final selectedProduct = l.productId == null
        ? null
        : _products.where((p) => p.id == l.productId).cast<Product?>().firstWhere((p) => true, orElse: () => null);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22, height: 22, alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
            child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _pickProduct(l),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Icon(selectedProduct != null ? Icons.inventory_2_outlined : Icons.edit_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      selectedProduct?.displayName ?? 'Non-catalog item — tap to pick a product',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: selectedProduct != null ? AppColors.textPrimary : AppColors.textMuted, fontWeight: selectedProduct != null ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18, color: AppColors.textMuted),
                ]),
              ),
            ),
          ),
          if (_lines.length > 1)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
              onPressed: () => setState(() { _lines.removeAt(i).dispose(); }),
            ),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          controller: l.descCtrl,
          decoration: _dec('Item description *'),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(flex: 3, child: _miniField('Qty', l.qtyCtrl, numeric: true, onChanged: () => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _miniField('Unit', l.unitCtrl)),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _miniField('Unit Price', l.priceCtrl, numeric: true, onChanged: () => setState(() {}))),
        ]),
        _priceHintRow(l),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 3, child: _miniField('GST %', l.gstCtrl, numeric: true, onChanged: () => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _miniField('Disc ₹', l.discCtrl, numeric: true, onChanged: () => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _miniField('HSN', l.hsnCtrl)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          InkWell(
            onTap: () => setState(() => l.igst = !l.igst),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: l.igst ? AppColors.primary.withValues(alpha: 0.12) : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: l.igst ? AppColors.primary : AppColors.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(l.igst ? Icons.check_circle : Icons.circle_outlined, size: 14, color: l.igst ? AppColors.primary : AppColors.textMuted),
                const SizedBox(width: 5),
                Text('IGST (inter-state)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: l.igst ? AppColors.primary : AppColors.textSecondary)),
              ]),
            ),
          ),
          const Spacer(),
          Text('Line ${CurrencyUtils.format(l.total)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ]),
        if (l.allocations.isNotEmpty) _allocationsChip(l),
      ]),
    );
  }

  Widget _priceHintRow(_Line l) {
    final h = l.priceHint;
    if (h == null) return const SizedBox(height: 4);
    final selling = double.tryParse(h['currentSellingPrice']?.toString() ?? '');
    final lastVendor = h['lastVendorPrice'] is Map ? h['lastVendorPrice'] as Map : null;
    final lastAny = h['lastAnyPrice'] is Map ? h['lastAnyPrice'] as Map : null;
    final chips = <Widget>[];
    if (selling != null && selling > 0) {
      chips.add(_hintChip('Sell ${CurrencyUtils.format(selling)}', AppColors.textSecondary));
    }
    if (lastVendor != null) {
      final up = double.tryParse(lastVendor['unitPrice']?.toString() ?? '') ?? 0;
      chips.add(InkWell(
        onTap: () { l.priceCtrl.text = _trim(up); setState(() {}); },
        child: _hintChip('Last ${CurrencyUtils.format(up)} · use', AppColors.primary),
      ));
    } else if (lastAny != null) {
      final up = double.tryParse(lastAny['unitPrice']?.toString() ?? '') ?? 0;
      final vn = (lastAny['vendor'] is Map) ? (lastAny['vendor'] as Map)['vendorName']?.toString() : null;
      chips.add(InkWell(
        onTap: () { l.priceCtrl.text = _trim(up); setState(() {}); },
        child: _hintChip('Any ${CurrencyUtils.format(up)}${vn != null ? ' ($vn)' : ''} · use', AppColors.textMuted),
      ));
    }
    if (chips.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  Widget _hintChip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _allocationsChip(_Line l) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.straighten, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('${l.allocations.length} widths · ${_trim(l.allocQty)} ${l.unitCtrl.text.trim().isEmpty ? '' : l.unitCtrl.text.trim()}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: l.allocations.map((a) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(5), border: Border.all(color: AppColors.border)),
              child: Text('${a.label ?? '—'}: ${_trim(a.quantity)}', style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
            )).toList()),
          ]),
        ),
      );

  Widget _totalsCard() {
    Widget row(String label, double value, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? AppColors.textSecondary)),
            Text(CurrencyUtils.format(value), style: TextStyle(fontSize: bold ? 16 : 12.5, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color ?? AppColors.textPrimary)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        row('Subtotal', _subtotal),
        if (_discountTotal > 0) row('Discount', -_discountTotal, color: AppColors.danger),
        if (_cgstTotal > 0) row('CGST', _cgstTotal),
        if (_sgstTotal > 0) row('SGST', _sgstTotal),
        if (_igstTotal > 0) row('IGST', _igstTotal),
        if (_freight > 0) row('Freight', _freight),
        if (_misc > 0) row('Misc', _misc),
        const Divider(height: 18),
        row('Grand Total', _grandTotal, bold: true, color: AppColors.primary),
      ]),
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

  Widget _miniField(String label, TextEditingController c, {bool numeric = false, VoidCallback? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 3),
        TextFormField(
          controller: c,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
          onChanged: onChanged == null ? null : (_) => onChanged(),
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }

  Widget _amountField(String label, TextEditingController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          onChanged: (_) => setState(() {}),
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

/// Searchable catalog product picker + a "Non-catalog item" option.
class _ProductPickerSheet extends StatefulWidget {
  final List<Product> products;
  const _ProductPickerSheet({required this.products});
  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.products
        : widget.products.where((p) => p.displayName.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true, filled: true, fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
            title: const Text('Non-catalog item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Free-text description, no catalog product', style: TextStyle(fontSize: 11.5)),
            onTap: () => Navigator.pop(context, const Product(id: '', name: '')),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No products', style: TextStyle(color: AppColors.textMuted)))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(p.displayName, style: const TextStyle(fontSize: 13)),
                        subtitle: p.sellingPrice > 0 ? Text('Sell ${CurrencyUtils.format(p.sellingPrice)}', style: const TextStyle(fontSize: 11)) : null,
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
