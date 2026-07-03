import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/customer_list_provider.dart';

/// Create / edit a customer (POST or PUT /api/customers). Refreshes the list on success.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.editCustomer});
  final Customer? editCustomer;
  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _gstin;
  late final TextEditingController _address;
  bool _saving = false;

  bool get _isEdit => widget.editCustomer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.editCustomer;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _city = TextEditingController(text: c?.city ?? '');
    _district = TextEditingController(text: c?.district ?? '');
    _gstin = TextEditingController(text: c?.gstNumber ?? '');
    _address = TextEditingController(text: c?.address ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _city, _district, _gstin, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer name is required.'))); return; }
    setState(() => _saving = true);
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final body = {
        'name': name,
        'customerName': name,
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'city': _city.text.trim(),
        'district': _district.text.trim(),
        'gstin': _gstin.text.trim(),
        'billingAddress': _address.text.trim(),
      };
      if (_isEdit) {
        await client.put(ApiConstants.customerDetail(widget.editCustomer!.id), data: body);
      } else {
        await client.post(ApiConstants.customers, data: body);
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit Customer' : 'New Customer')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _field(_name, 'Name *'),
        _field(_phone, 'Phone', keyboard: TextInputType.phone),
        _field(_email, 'Email', keyboard: TextInputType.emailAddress),
        _field(_city, 'City'),
        _field(_district, 'District'),
        _field(_gstin, 'GSTIN'),
        _field(_address, 'Billing address', maxLines: 3),
        const SizedBox(height: 22),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : (_isEdit ? 'Update customer' : 'Create customer'))),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType? keyboard, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), alignLabelWithHint: maxLines > 1),
        ),
      );
}
