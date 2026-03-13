import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../widgets/common/app_text_field.dart';

class CollectionPaymentScreen extends ConsumerStatefulWidget {
  final String collectionId;
  const CollectionPaymentScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionPaymentScreen> createState() => _CollectionPaymentScreenState();
}

class _CollectionPaymentScreenState extends ConsumerState<CollectionPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
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
    _paymentDateController.text = DateTime.now().toIso8601String().split('T').first;
  }

  @override
  void dispose() {
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
      await CollectionRepository(client).recordCollectionPayment(widget.collectionId, {
        'amount': double.parse(_amountController.text.trim()),
        'receivedDate': _paymentDateController.text.trim(),
        'paymentMode': _paymentMode,
        'referenceNo': _referenceController.text.trim(),
        'remarks': _remarksController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully'), backgroundColor: AppColors.success),
      );
      context.go('/collections/${widget.collectionId}');
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
      appBar: AppBar(title: const Text('Record Collection')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppTextField(
              label: 'Amount Collected (Rs.)',
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => Validators.positiveNumber(v, 'Amount'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Received Date',
              controller: _paymentDateController,
              hint: 'YYYY-MM-DD',
              validator: (v) => Validators.required(v, 'Received date'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paymentMode,
              decoration: const InputDecoration(labelText: 'Payment Mode'),
              items: _paymentModes.map((mode) => DropdownMenuItem(value: mode, child: Text(mode))).toList(),
              onChanged: (value) => setState(() => _paymentMode = value ?? 'Cash'),
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
                  : const Text('Record Collection'),
            ),
          ],
        ),
      ),
    );
  }
}
