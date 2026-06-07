import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/order_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

class _OrderLineItem {
  Product? product;
  bool customerPriced = false;
  final qtyCtrl = TextEditingController(text: '1');
  final rateCtrl = TextEditingController(text: '0');
  final discCtrl = TextEditingController(text: '0');
  final taxCtrl = TextEditingController(text: '0');
  String discountType = 'percent';

  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get rate => double.tryParse(rateCtrl.text.trim()) ?? 0;
  double get discountValue => double.tryParse(discCtrl.text.trim()) ?? 0;
  double get taxPercent => double.tryParse(taxCtrl.text.trim()) ?? 0;

  Map<String, dynamic> toJson() => {
        'productId': int.parse(product!.id),
        'quantity': quantity,
        'rate': rate,
        'discountType': discountType,
        'discountValue': discountValue,
        'taxPercent': taxPercent,
      };

  void dispose() {
    qtyCtrl.dispose();
    rateCtrl.dispose();
    discCtrl.dispose();
    taxCtrl.dispose();
  }
}

class OrderCreateScreen extends ConsumerStatefulWidget {
  final Order? editOrder;
  const OrderCreateScreen({super.key, this.editOrder});
  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final _notesController = TextEditingController();
  final _deliveryAddressCtrl = TextEditingController();
  DateTime? _deliveryDate;
  Customer? _customer;
  Map<String, double> _pricing = {}; // customer-specific product prices
  final List<_OrderLineItem> _items = [_OrderLineItem()];

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  List<Customer> _customers = [];
  List<Product> _products = [];
  bool _loading = true;
  bool _isSaving = false;
  String? _loadError;

  late final ApiClient _client;

  @override
  void initState() {
    super.initState();
    _client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _deliveryAddressCtrl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        CustomerRepository(_client).getCustomers(),
        ProductRepository(_client).getProducts(),
      ]);
      setState(() {
        _customers = results[0] as List<Customer>;
        _products = results[1] as List<Product>;
        _loading = false;
      });
      if (widget.editOrder != null) await _prefillFromOrder(widget.editOrder!);
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _prefillFromOrder(Order eo) async {
    Customer? cust;
    for (final c in _customers) {
      if (c.id == eo.customerId) {
        cust = c;
        break;
      }
    }
    cust ??= Customer(id: eo.customerId ?? '', name: eo.customerName ?? 'Customer');
    Map<String, double> pricing = {};
    try {
      if (eo.customerId != null && eo.customerId!.isNotEmpty) {
        pricing = await CustomerRepository(_client).getProductPricing(eo.customerId!);
      }
    } catch (_) {}
    final items = <_OrderLineItem>[];
    for (final oi in eo.items) {
      final it = _OrderLineItem();
      Product? prod;
      for (final p in _products) {
        if (p.id == oi.productId) {
          prod = p;
          break;
        }
      }
      it.product = prod ?? Product(id: oi.productId ?? '', name: oi.productName ?? 'Product', sellingPrice: oi.rate, taxPercent: oi.taxPercent ?? 0, unit: oi.unit);
      it.qtyCtrl.text = _fmt(oi.quantity);
      it.rateCtrl.text = _fmt(oi.rate);
      it.discountType = oi.discountType ?? 'percent';
      it.discCtrl.text = _fmt(oi.discountValue ?? 0);
      it.taxCtrl.text = _fmt(oi.taxPercent ?? 0);
      items.add(it);
    }
    if (!mounted) return;
    setState(() {
      _customer = cust;
      _pricing = pricing;
      _deliveryDate = eo.deliveryDate;
      _deliveryAddressCtrl.text = eo.deliveryAddress ?? '';
      _notesController.text = eo.notes ?? '';
      if (items.isNotEmpty) {
        for (final old in _items) {
          old.dispose();
        }
        _items
          ..clear()
          ..addAll(items);
      }
    });
  }

  double _lineTotal(_OrderLineItem item) {
    final subtotal = item.rate * item.quantity;
    final discount = item.discountType == 'amount' ? item.discountValue : subtotal * (item.discountValue / 100);
    final taxable = subtotal - discount;
    return taxable + (taxable * item.taxPercent / 100);
  }

  double get _totalAmount => _items.fold(0, (sum, item) => sum + _lineTotal(item));

  Future<T?> _pickFromList<T>({required String title, required List<T> items, required String Function(T) label, String Function(T)? subtitle}) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(builder: (ctx, setSheet) {
          final q = query.trim().toLowerCase();
          final filtered = q.isEmpty
              ? items
              : items.where((e) => label(e).toLowerCase().contains(q) || (subtitle?.call(e) ?? '').toLowerCase().contains(q)).toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                      child: Row(children: [
                        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setSheet(() => query = v),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No matches', style: TextStyle(color: AppColors.textMuted)))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final e = filtered[i];
                                return ListTile(
                                  title: Text(label(e), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  subtitle: subtitle != null ? Text(subtitle(e), style: const TextStyle(fontSize: 12)) : null,
                                  onTap: () => Navigator.pop(ctx, e),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _pickCustomer() async {
    final c = await _pickFromList<Customer>(
      title: 'Select Customer',
      items: _customers,
      label: (c) => c.name,
      subtitle: (c) => [c.city, c.phone].where((x) => x != null && x.isNotEmpty).join('  ·  '),
    );
    if (c != null) {
      setState(() => _customer = c);
      await _applyCustomerPricing(c);
    }
  }

  /// Pull the customer's special product prices + default discount onto the line items.
  Future<void> _applyCustomerPricing(Customer c) async {
    Map<String, double> pricing = {};
    try {
      pricing = await CustomerRepository(_client).getProductPricing(c.id);
    } catch (_) {}
    if (!mounted) return;
    final disc = c.discountPercent ?? 0;
    setState(() {
      _pricing = pricing;
      _deliveryAddressCtrl.text = c.shippingAddress ?? c.address ?? '';
      for (final item in _items) {
        item.discountType = 'percent';
        item.discCtrl.text = _fmt(disc);
        if (item.product != null) {
          final special = pricing[item.product!.id];
          item.customerPriced = special != null;
          item.rateCtrl.text = _fmt(special ?? item.product!.sellingPrice);
        }
      }
    });
  }

  Future<void> _pickProduct(_OrderLineItem item) async {
    final p = await _pickFromList<Product>(
      title: 'Select Product',
      items: _products,
      label: (p) => p.displayName,
      subtitle: (p) => 'Rs.${p.sellingPrice.toStringAsFixed(2)}${p.unit != null && p.unit!.isNotEmpty ? ' per ${p.unit}' : ''}',
    );
    if (p != null) {
      setState(() {
        item.product = p;
        final special = _pricing[p.id];
        item.customerPriced = special != null;
        item.rateCtrl.text = _fmt(special ?? p.sellingPrice);
        item.taxCtrl.text = _fmt(p.taxPercent);
        if (_customer != null) {
          item.discountType = 'percent';
          item.discCtrl.text = _fmt(_customer!.discountPercent ?? 0);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_customer == null) return _snack('Please select a customer');
    if (_deliveryDate == null) return _snack('Delivery date is required');
    if (_items.any((i) => i.product == null)) return _snack('Please select a product for each item');
    setState(() => _isSaving = true);
    try {
      final addr = _deliveryAddressCtrl.text.trim();
      final payload = {
        'customerId': int.parse(_customer!.id),
        'expectedDeliveryDate': _deliveryDate!.toIso8601String(),
        'deliveryAddress': addr.isEmpty ? 'N/A' : addr,
        'notes': _notesController.text.trim(),
        'items': _items.map((i) => i.toJson()).toList(),
      };
      final repo = OrderRepository(_client);
      final order = widget.editOrder != null
          ? await repo.updateOrder(widget.editOrder!.id, payload)
          : await repo.createOrder(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.editOrder != null ? 'Order updated' : 'Order created successfully'), backgroundColor: AppColors.success),
      );
      context.go('/orders/${order.id}');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String m, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: error ? AppColors.danger : null),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.editOrder != null ? 'Edit Order' : 'New Order')),
      body: _loading
          ? const LoadingIndicator(message: 'Loading customers & products...')
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_loadError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(10)),
                          child: Text(_loadError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                        ),
                      _label('Customer *'),
                      _pickerField(value: _customer?.name, hint: 'Select customer', icon: Icons.person_outline, onTap: widget.editOrder != null ? () => _snack('Customer cannot be changed when editing') : _pickCustomer),
                      const SizedBox(height: 20),
                      Row(children: [
                        const Text('Order Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            final it = _OrderLineItem();
                            it.discCtrl.text = _fmt(_customer?.discountPercent ?? 0);
                            _items.add(it);
                          }),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      ..._items.asMap().entries.map((e) => _itemCard(e.key, e.value)),
                      const SizedBox(height: 12),
                      _label('Delivery Date *'),
                      _pickerField(
                        value: _deliveryDate != null ? '${_deliveryDate!.day}/${_deliveryDate!.month}/${_deliveryDate!.year}' : null,
                        hint: 'Select delivery date',
                        icon: Icons.calendar_today_outlined,
                        onTap: () async {
                          final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (picked != null) setState(() => _deliveryDate = picked);
                        },
                      ),
                      const SizedBox(height: 16),
                      _label('Delivery Address'),
                      TextField(controller: _deliveryAddressCtrl, maxLines: 2, decoration: _dec('Auto-filled from customer; edit if needed')),
                      const SizedBox(height: 16),
                      _label('Notes'),
                      TextField(controller: _notesController, maxLines: 3, decoration: _dec('Any special instructions...')),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                _bottomBar(),
              ],
            ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2))]),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Total', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(CurrencyUtils.format(_totalAmount), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _submit,
            icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
            label: Text(_isSaving ? 'Placing...' : 'Place Order'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14)),
          ),
        ]),
      ),
    );
  }

  Widget _itemCard(int index, _OrderLineItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 0.5)),
      child: Column(
        children: [
          Row(children: [
            Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            if (_items.length > 1)
              InkWell(onTap: () => setState(() => _items.removeAt(index).dispose()), child: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20)),
          ]),
          const SizedBox(height: 8),
          _pickerField(value: item.product?.displayName, hint: 'Select product', icon: Icons.inventory_2_outlined, onTap: () => _pickProduct(item)),
          if (item.customerPriced)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: const [
                Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
                SizedBox(width: 4),
                Text('Special customer price applied', style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
              ]),
            ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _numField(item.qtyCtrl, 'Qty')),
            const SizedBox(width: 10),
            Expanded(child: _numField(item.rateCtrl, 'Rate')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: item.discountType,
                isExpanded: true,
                decoration: _dec('Disc Type'),
                items: const [DropdownMenuItem(value: 'percent', child: Text('Percent')), DropdownMenuItem(value: 'amount', child: Text('Amount'))],
                onChanged: (v) => setState(() => item.discountType = v ?? 'percent'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _numField(item.discCtrl, 'Disc')),
            const SizedBox(width: 10),
            Expanded(child: _numField(item.taxCtrl, 'Tax %')),
          ]),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: Text('Line: ${CurrencyUtils.format(_lineTotal(item))}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)));

  Widget _pickerField({String? value, required String hint, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(value ?? hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: value != null ? AppColors.textPrimary : AppColors.textMuted, fontWeight: value != null ? FontWeight.w600 : FontWeight.normal))),
          const Icon(Icons.expand_more, size: 20, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      decoration: _dec(label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => setState(() {}),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );
}
