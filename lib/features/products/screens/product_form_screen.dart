import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/product_admin_providers.dart';

/// Create / edit a product-master row. Mirrors the web ProductForm.jsx layout.
/// When [editId] is set, the row is fetched and the form is prefilled, and the
/// submit does a partial PUT; otherwise it POSTs a new product.
class ProductFormScreen extends ConsumerStatefulWidget {
  final String? editId;
  const ProductFormScreen({super.key, this.editId});
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

const _unitSuggestions = ['pcs', 'kg', 'gm', 'litre', 'ml', 'meter', 'box', 'dozen', 'pack', 'bottle', '250ml', '500ml', '1ltr', '1kg', '5kg', '25kg'];
const _uqcCodes = ['NOS', 'KGS', 'LTR', 'MTR', 'BOX', 'BAG', 'BTL', 'CAN', 'PKT', 'PCS', 'SET', 'TON', 'OTH'];
const _warrantyTypes = ['MANUFACTURER', 'EXTENDED', 'STORE'];
const _baseUnits = ['ltr', 'ml', 'kg', 'g'];

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _skuCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _nameTaCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _sellingPriceCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '18');
  final _hsnCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();
  final _priceGstCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _minPurchaseCtrl = TextEditingController();
  final _warrantyMonthsCtrl = TextEditingController(text: '0');
  final _packSizeCtrl = TextEditingController();

  String? _uqcCode;
  String? _warrantyType;
  String? _baseUnit;
  bool _isActive = true;

  bool get _isEdit => widget.editId != null;
  bool _loading = false;
  String? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadForEdit();
  }

  @override
  void dispose() {
    for (final c in [
      _skuCtrl, _nameCtrl, _nameEnCtrl, _nameTaCtrl, _categoryCtrl, _unitCtrl,
      _sellingPriceCtrl, _taxCtrl, _hsnCtrl, _minStockCtrl, _priceGstCtrl,
      _mrpCtrl, _minPurchaseCtrl, _warrantyMonthsCtrl, _packSizeCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _numText(num? v) => v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  Future<void> _loadForEdit() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final p = await ref.read(productAdminRepositoryProvider).getProduct(widget.editId!);
      if (!mounted) return;
      _skuCtrl.text = p.sku ?? '';
      _nameCtrl.text = p.productName;
      _nameEnCtrl.text = p.productNameEn ?? '';
      _nameTaCtrl.text = p.productNameTa ?? '';
      _categoryCtrl.text = p.category ?? '';
      _unitCtrl.text = p.unit ?? '';
      _sellingPriceCtrl.text = _numText(p.sellingPrice);
      _taxCtrl.text = _numText(p.taxPercent);
      _hsnCtrl.text = p.hsnCode ?? '';
      _minStockCtrl.text = p.minStockAlert?.toString() ?? '';
      _priceGstCtrl.text = _numText(p.priceWithGst);
      _mrpCtrl.text = _numText(p.mrpPerPiece);
      _minPurchaseCtrl.text = p.minPurchaseQty?.toString() ?? '';
      _warrantyMonthsCtrl.text = p.warrantyMonths.toString();
      _packSizeCtrl.text = _numText(p.packSize);
      setState(() {
        _uqcCode = _uqcCodes.contains(p.uqcCode) ? p.uqcCode : null;
        _warrantyType = _warrantyTypes.contains(p.warrantyType) ? p.warrantyType : null;
        _baseUnit = _baseUnits.contains(p.baseUnit) ? p.baseUnit : null;
        _isActive = p.isActive;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e.toString(); _loading = false; });
    }
  }

  double? _numOrNull(String s) => s.trim().isEmpty ? null : double.tryParse(s.trim());
  int? _intOrNull(String s) => s.trim().isEmpty ? null : int.tryParse(s.trim());

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final category = _categoryCtrl.text.trim();
    final unit = _unitCtrl.text.trim();
    final selling = _numOrNull(_sellingPriceCtrl.text);
    if (name.isEmpty || category.isEmpty || unit.isEmpty || selling == null) {
      _snack('Product name, category, unit and selling price are required', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        if (_skuCtrl.text.trim().isNotEmpty) 'sku': _skuCtrl.text.trim(),
        'productName': name,
        if (_nameEnCtrl.text.trim().isNotEmpty) 'productNameEn': _nameEnCtrl.text.trim(),
        if (_nameTaCtrl.text.trim().isNotEmpty) 'productNameTa': _nameTaCtrl.text.trim(),
        'category': category,
        'unit': unit,
        'sellingPrice': selling,
        if (_numOrNull(_taxCtrl.text) != null) 'taxPercent': _numOrNull(_taxCtrl.text),
        if (_hsnCtrl.text.trim().isNotEmpty) 'hsnCode': _hsnCtrl.text.trim(),
        if (_uqcCode != null) 'uqcCode': _uqcCode,
        if (_intOrNull(_minStockCtrl.text) != null) 'minStockAlert': _intOrNull(_minStockCtrl.text),
        if (_numOrNull(_priceGstCtrl.text) != null) 'priceWithGst': _numOrNull(_priceGstCtrl.text),
        if (_numOrNull(_mrpCtrl.text) != null) 'mrpPerPiece': _numOrNull(_mrpCtrl.text),
        if (_intOrNull(_minPurchaseCtrl.text) != null) 'minPurchaseQty': _intOrNull(_minPurchaseCtrl.text),
        if (_intOrNull(_warrantyMonthsCtrl.text) != null) 'warrantyMonths': _intOrNull(_warrantyMonthsCtrl.text),
        if (_warrantyType != null) 'warrantyType': _warrantyType,
        if (_numOrNull(_packSizeCtrl.text) != null) 'packSize': _numOrNull(_packSizeCtrl.text),
        if (_baseUnit != null) 'baseUnit': _baseUnit,
        if (_isEdit) 'isActive': _isActive,
      };
      final repo = ref.read(productAdminRepositoryProvider);
      final saved = _isEdit ? await repo.updateProduct(widget.editId!, body) : await repo.createProduct(body);
      if (!mounted) return;
      _snack('Product ${saved.productName} ${_isEdit ? 'updated' : 'created'}');
      context.pop();
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.success, duration: Duration(seconds: error ? 5 : 2)));
  }

  @override
  Widget build(BuildContext context) {
    final categorySuggestions = ref.watch(productCategoriesProvider).valueOrNull ?? const <String>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Product' : 'New Product')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load: $_loadError', style: const TextStyle(color: AppColors.danger))))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _label('SKU'),
                      TextFormField(controller: _skuCtrl, decoration: _dec('Leave blank to auto-generate'), style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 14),
                      _label('Product Name *'),
                      TextFormField(controller: _nameCtrl, decoration: _dec('e.g. Cotton Shirt'), style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 14),
                      _label('Category *'),
                      TextFormField(controller: _categoryCtrl, decoration: _dec('e.g. Apparel'), style: const TextStyle(fontSize: 13)),
                      if (categorySuggestions.isNotEmpty) _chips(categorySuggestions, (v) => setState(() => _categoryCtrl.text = v)),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _miniField('English name', _nameEnCtrl)),
                        const SizedBox(width: 8),
                        Expanded(child: _miniField('Native name', _nameTaCtrl)),
                      ]),
                      const SizedBox(height: 14),
                      _label('Unit *'),
                      TextFormField(controller: _unitCtrl, decoration: _dec('e.g. pcs'), style: const TextStyle(fontSize: 13)),
                      _chips(_unitSuggestions, (v) => setState(() => _unitCtrl.text = v)),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _miniField('Selling Price *', _sellingPriceCtrl, numeric: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _miniField('Tax %', _taxCtrl, numeric: true)),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _miniField('Min Stock Alert', _minStockCtrl, numeric: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _miniField('HSN Code', _hsnCtrl)),
                      ]),
                      const SizedBox(height: 12),
                      _miniDropdown('UQC Code', _uqcCode, _uqcCodes, (v) => setState(() => _uqcCode = v)),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _miniField('Price + GST', _priceGstCtrl, numeric: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _miniField('MRP / Piece', _mrpCtrl, numeric: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _miniField('Min Purch Qty', _minPurchaseCtrl, numeric: true)),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _miniField('Warranty (months)', _warrantyMonthsCtrl, numeric: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _miniDropdown('Warranty Type', _warrantyType, _warrantyTypes, (v) => setState(() => _warrantyType = v))),
                      ]),
                      const SizedBox(height: 16),
                      _packSizePanel(),
                      if (_isEdit) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          subtitle: const Text('Inactive products are hidden from pickers', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          value: _isActive,
                          activeThumbColor: AppColors.success,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check),
                          label: Text(_saving ? 'Saving…' : (_isEdit ? 'Save Changes' : 'Create Product')),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _packSizePanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.straighten, size: 16, color: AppColors.success),
          SizedBox(width: 6),
          Text('Pack Size / Stock Unit Conversion', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success)),
        ]),
        const SizedBox(height: 4),
        const Text('Optional: how much base unit one saleable pack contains (e.g. 1 bottle = 500 ml).', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _miniField('Pack Size', _packSizeCtrl, numeric: true, fill: AppColors.surface)),
          const SizedBox(width: 8),
          Expanded(child: _miniDropdown('Base Unit', _baseUnit, _baseUnits, (v) => setState(() => _baseUnit = v), fill: AppColors.surface)),
        ]),
      ]),
    );
  }

  Widget _chips(List<String> options, ValueChanged<String> onPick) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options
              .map((o) => InkWell(
                    onTap: () => onPick(o),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                      child: Text(o, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                  ))
              .toList(),
        ),
      );

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

  Widget _miniField(String label, TextEditingController c, {bool numeric = false, Color fill = AppColors.background}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 3),
        TextFormField(
          controller: c,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }

  Widget _miniDropdown(String label, String? value, List<String> options, ValueChanged<String?> onChanged, {Color fill = AppColors.background}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        const SizedBox(height: 3),
        DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: fill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('—', style: TextStyle(fontSize: 13, color: AppColors.textMuted))),
            ...options.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
