import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/order_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../widgets/common/app_text_field.dart';

class _OrderLineItem {
  String productId = '';
  double quantity = 1;
  double rate = 0;
  String discountType = 'percent';
  double discountValue = 0;
  double taxPercent = 0;

  Map<String, dynamic> toJson() => {
        'productId': int.parse(productId),
        'quantity': quantity,
        'rate': rate,
        'discountType': discountType,
        'discountValue': discountValue,
        'taxPercent': taxPercent,
      };
}

class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({super.key});

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerIdController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _deliveryDate;
  bool _isLoading = false;
  final List<_OrderLineItem> _items = [_OrderLineItem()];

  @override
  void dispose() {
    _customerIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _lineTotal(_OrderLineItem item) {
    final subtotal = item.rate * item.quantity;
    final discount = item.discountType == 'amount'
        ? item.discountValue
        : subtotal * (item.discountValue / 100);
    final taxable = subtotal - discount;
    return taxable + (taxable * item.taxPercent / 100);
  }

  double get _totalAmount => _items.fold(0, (sum, item) => sum + _lineTotal(item));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deliveryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery date is required'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_items.any((item) => item.productId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all product IDs'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final repo = OrderRepository(client);
      final order = await repo.createOrder({
        'customerId': int.parse(_customerIdController.text.trim()),
        'expectedDeliveryDate': _deliveryDate!.toIso8601String(),
        'notes': _notesController.text.trim(),
        'items': _items.map((item) => item.toJson()).toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order created successfully'), backgroundColor: AppColors.success),
      );
      context.go('/orders/${order.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Order')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Customer', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Customer ID',
              controller: _customerIdController,
              validator: (v) => Validators.required(v, 'Customer ID'),
              hint: 'Enter numeric customer ID',
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Items', style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_OrderLineItem())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) => _buildItemCard(entry.key, entry.value)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    'Rs.${_totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _deliveryDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Delivery Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _deliveryDate == null
                      ? 'Select delivery date'
                      : '${_deliveryDate!.day}/${_deliveryDate!.month}/${_deliveryDate!.year}',
                  style: TextStyle(color: _deliveryDate == null ? AppColors.textMuted : AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Notes (Optional)',
              controller: _notesController,
              maxLines: 3,
              hint: 'Any special instructions...',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                  : const Text('Place Order'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index, _OrderLineItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                    onPressed: () => setState(() => _items.removeAt(index)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: item.productId,
              decoration: const InputDecoration(labelText: 'Product ID', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onChanged: (v) => item.productId = v,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(labelText: 'Qty', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onChanged: (v) {
                      item.quantity = double.tryParse(v) ?? 1;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: item.rate.toString(),
                    decoration: const InputDecoration(labelText: 'Rate', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onChanged: (v) {
                      item.rate = double.tryParse(v) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: item.discountType,
                    decoration: const InputDecoration(labelText: 'Discount Type', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: const [
                      DropdownMenuItem(value: 'percent', child: Text('Percent')),
                      DropdownMenuItem(value: 'amount', child: Text('Amount')),
                    ],
                    onChanged: (v) => setState(() => item.discountType = v ?? 'percent'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: item.discountValue.toString(),
                    decoration: const InputDecoration(labelText: 'Discount', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onChanged: (v) {
                      item.discountValue = double.tryParse(v) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    initialValue: item.taxPercent.toString(),
                    decoration: const InputDecoration(labelText: 'Tax %', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onChanged: (v) {
                      item.taxPercent = double.tryParse(v) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Line Total: Rs.${_lineTotal(item).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
