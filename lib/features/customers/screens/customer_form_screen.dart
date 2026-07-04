import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/customer_list_provider.dart';

/// Create / edit a customer — FULL parity with the web form: names (En/Ta), contact,
/// GST (mode + value), billing/shipping addresses (En/Ta), location, commercials
/// (discount, payment terms, credit limit, opening balance, pays-transport).
/// Special product pricing stays on web.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.editCustomer});
  final Customer? editCustomer;
  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  // Identity & contact
  final _name = TextEditingController();
  final _nameTa = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  // GST
  final _gstin = TextEditingController();
  final _stateCode = TextEditingController();
  String _gstMode = 'FULL';
  final _gstValue = TextEditingController();
  // Addresses & location
  final _billingAddress = TextEditingController();
  final _billingAddressTa = TextEditingController();
  final _shippingAddress = TextEditingController();
  final _shippingAddressTa = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  // Commercials
  final _discount = TextEditingController();
  final _paymentTerms = TextEditingController();
  final _creditLimit = TextEditingController();
  final _openingBalance = TextEditingController();
  bool _paysTransport = false;

  bool _saving = false;
  bool _loading = false;

  bool get _isEdit => widget.editCustomer != null;
  static const _gstModes = <(String, String)>[
    ('FULL', 'Full (18%)'),
    ('HALF', 'Half (9%)'),
    ('QUARTER', 'Quarter (4.5%)'),
    ('FLAT', 'Flat Amount'),
    ('CUSTOM', 'Custom %'),
  ];

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      // Prefill from the lite model immediately, then hydrate every field from the API.
      final c = widget.editCustomer!;
      _name.text = c.name;
      _phone.text = c.phone ?? '';
      _email.text = c.email ?? '';
      _city.text = c.city ?? '';
      _district.text = c.district ?? '';
      _gstin.text = c.gstNumber ?? '';
      _billingAddress.text = c.address ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  Future<void> _hydrate() async {
    setState(() => _loading = true);
    try {
      final data = await _client.get(ApiConstants.customerDetail(widget.editCustomer!.id));
      final m = (data is Map ? data : const {}).cast<String, dynamic>();
      String s(dynamic v) => (v ?? '').toString();
      String n(dynamic v) { final x = double.tryParse(s(v)); return x == null || x == 0 ? '' : (x % 1 == 0 ? x.toInt().toString() : x.toString()); }
      if (!mounted) return;
      setState(() {
        _name.text = s(m['customerName']).isNotEmpty ? s(m['customerName']) : _name.text;
        _nameTa.text = s(m['customerNameTa']);
        _email.text = s(m['email']);
        _phone.text = s(m['phone']);
        _whatsapp.text = s(m['whatsappContact']);
        _gstin.text = s(m['gstin']);
        _stateCode.text = s(m['stateCode']);
        _gstMode = _gstModes.any((g) => g.$1 == s(m['gstMode'])) ? s(m['gstMode']) : 'FULL';
        _gstValue.text = n(m['gstValue']);
        _billingAddress.text = s(m['billingAddress']);
        _billingAddressTa.text = s(m['billingAddressTa']);
        _shippingAddress.text = s(m['shippingAddress']);
        _shippingAddressTa.text = s(m['shippingAddressTa']);
        _district.text = s(m['district']);
        _city.text = s(m['city']);
        _pincode.text = s(m['pincode']);
        _discount.text = n(m['discountPercentage']);
        _paymentTerms.text = n(m['paymentTermsDays']);
        _creditLimit.text = n(m['creditLimit']);
        _openingBalance.text = n(m['openingBalance']);
        _paysTransport = m['customerPaysTransport'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _nameTa, _email, _phone, _whatsapp, _gstin, _stateCode, _gstValue, _billingAddress, _billingAddressTa, _shippingAddress, _shippingAddressTa, _district, _city, _pincode, _discount, _paymentTerms, _creditLimit, _openingBalance]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _numOrNull(TextEditingController c) => c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer name is required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'name': name,
        'customerName': name,
        'customerNameTa': _nameTa.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'whatsappContact': _whatsapp.text.trim(),
        'gstin': _gstin.text.trim(),
        'stateCode': _stateCode.text.trim(),
        'gstMode': _gstMode,
        if (_gstMode == 'FLAT' || _gstMode == 'CUSTOM') 'gstValue': _numOrNull(_gstValue) ?? 0,
        'billingAddress': _billingAddress.text.trim(),
        'billingAddressTa': _billingAddressTa.text.trim(),
        'shippingAddress': _shippingAddress.text.trim(),
        'shippingAddressTa': _shippingAddressTa.text.trim(),
        'district': _district.text.trim(),
        'city': _city.text.trim(),
        'pincode': _pincode.text.trim(),
        'discountPercentage': _numOrNull(_discount) ?? 0,
        'paymentTermsDays': _numOrNull(_paymentTerms)?.toInt() ?? 0,
        'creditLimit': _numOrNull(_creditLimit) ?? 0,
        'openingBalance': _numOrNull(_openingBalance) ?? 0,
        'customerPaysTransport': _paysTransport,
      };
      if (_isEdit) {
        await _client.put(ApiConstants.customerDetail(widget.editCustomer!.id), data: body);
      } else {
        await _client.post(ApiConstants.customers, data: body);
      }
      if (!mounted) return;
      await ref.read(customerListProvider.notifier).load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Customer updated.' : 'Customer created.')));
      context.pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Customer' : 'New Customer'),
        actions: [if (_loading) const Padding(padding: EdgeInsets.only(right: 16), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _section('Identity & contact', Icons.person_outline, [
          _field(_name, 'Customer Name (English) *'),
          _field(_nameTa, 'Customer Name (Tamil)'),
          _field(_email, 'Email', keyboard: TextInputType.emailAddress),
          Row(children: [
            Expanded(child: _field(_phone, 'Phone', keyboard: TextInputType.phone, pad: false)),
            const SizedBox(width: 10),
            Expanded(child: _field(_whatsapp, 'WhatsApp Contact', keyboard: TextInputType.phone, pad: false)),
          ]),
          const SizedBox(height: 14),
        ]),
        _section('GST', Icons.receipt_long_outlined, [
          Row(children: [
            Expanded(flex: 3, child: _field(_gstin, 'GSTIN', pad: false)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _field(_stateCode, 'GST State Code', keyboard: TextInputType.number, pad: false)),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _gstMode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'GST Mode', border: OutlineInputBorder()),
            items: _gstModes.map((g) => DropdownMenuItem(value: g.$1, child: Text(g.$2))).toList(),
            onChanged: (v) => setState(() => _gstMode = v ?? 'FULL'),
          ),
          if (_gstMode == 'FLAT' || _gstMode == 'CUSTOM') ...[
            const SizedBox(height: 14),
            _field(_gstValue, _gstMode == 'FLAT' ? 'Flat GST Amount (₹)' : 'Custom GST %', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          ] else
            const SizedBox(height: 14),
        ]),
        _section('Address', Icons.place_outlined, [
          _field(_billingAddress, 'Billing Address (English)', maxLines: 2),
          _field(_billingAddressTa, 'Billing Address (Tamil)', maxLines: 2),
          _field(_shippingAddress, 'Shipping Address (optional — defaults to billing)', maxLines: 2),
          _field(_shippingAddressTa, 'Shipping Address (Tamil)', maxLines: 2),
          Row(children: [
            Expanded(child: _field(_district, 'District', pad: false)),
            const SizedBox(width: 10),
            Expanded(child: _field(_city, 'City', pad: false)),
          ]),
          const SizedBox(height: 14),
          _field(_pincode, 'Pincode (for e-invoice)', keyboard: TextInputType.number),
        ]),
        _section('Commercials', Icons.payments_outlined, [
          Row(children: [
            Expanded(child: _field(_discount, 'Discount %', keyboard: const TextInputType.numberWithOptions(decimal: true), pad: false)),
            const SizedBox(width: 10),
            Expanded(child: _field(_paymentTerms, 'Payment Terms (Days)', keyboard: TextInputType.number, pad: false)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _field(_creditLimit, 'Credit Limit (₹)', keyboard: const TextInputType.numberWithOptions(decimal: true), pad: false)),
            const SizedBox(width: 10),
            Expanded(child: _field(_openingBalance, 'Opening Balance (₹)', keyboard: const TextInputType.numberWithOptions(decimal: true), pad: false)),
          ]),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Customer pays transport', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text("Exclude this customer's freight from company transport analytics", style: TextStyle(fontSize: 11.5)),
            value: _paysTransport,
            onChanged: (v) => setState(() => _paysTransport = v),
          ),
        ]),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 18, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Expanded(child: Text('Special product pricing rules are managed on the web portal.', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)))),
          ]),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : (_isEdit ? 'Update customer' : 'Create customer'))),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard, int maxLines = 1, bool pad = true}) => Padding(
        padding: EdgeInsets.only(bottom: pad ? 14 : 0),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), alignLabelWithHint: maxLines > 1, isDense: true),
        ),
      );
}
