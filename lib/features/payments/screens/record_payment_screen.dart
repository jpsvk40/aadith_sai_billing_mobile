import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../widgets/common/app_text_field.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String? initialInvoiceId;

  const RecordPaymentScreen({super.key, this.initialInvoiceId});

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarksController = TextEditingController();
  String _paymentMode = 'Cash';
  bool _isLoading = false;

  final _paymentModes = ['Cash', 'Bank Transfer', 'Cheque', 'UPI'];

  @override
  void initState() {
    super.initState();
    _invoiceIdController.text = widget.initialInvoiceId ?? '';
    _paymentDateController.text = DateTime.now().toIso8601String().split('T').first;
  }

  @override
  void dispose() {
    _invoiceIdController.dispose();
    _amountController.dispose();
    _paymentDateController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final repo = PaymentRepository(client);
      await repo.recordPayment({
        'invoiceId': int.parse(_invoiceIdController.text.trim()),
        'paymentDate': _paymentDateController.text.trim(),
        'amount': double.parse(_amountController.text.trim()),
        'paymentMode': _paymentMode,
        'referenceNo': _referenceController.text.trim(),
        'remarks': _remarksController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully'), backgroundColor: AppColors.success),
      );
      context.go('/payments');
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
      appBar: AppBar(title: const Text('Record Payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppTextField(
              label: 'Invoice ID',
              controller: _invoiceIdController,
              validator: (v) => Validators.required(v, 'Invoice ID'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Amount (Rs.)',
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => Validators.positiveNumber(v, 'Amount'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Payment Date',
              controller: _paymentDateController,
              hint: 'YYYY-MM-DD',
              validator: (v) => Validators.required(v, 'Payment date'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMode,
              decoration: const InputDecoration(labelText: 'Payment Mode'),
              items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _paymentMode = v ?? 'Cash'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Reference No. (Optional)',
              controller: _referenceController,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Remarks (Optional)',
              controller: _remarksController,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                  : const Text('Record Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
