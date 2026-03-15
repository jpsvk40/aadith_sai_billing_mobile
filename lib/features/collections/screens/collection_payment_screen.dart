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
  final bool isCorrection;
  const CollectionPaymentScreen({
    super.key,
    required this.collectionId,
    this.isCorrection = false,
  });

  @override
  ConsumerState<CollectionPaymentScreen> createState() =>
      _CollectionPaymentScreenState();
}

class _CollectionPaymentScreenState
    extends ConsumerState<CollectionPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarksController = TextEditingController();
  final _correctionForController = TextEditingController();
  String _paymentMode = 'Cash';
  bool _isLoading = false;

  final _paymentModes = ['Cash', 'Bank Transfer', 'Cheque', 'UPI'];

  @override
  void initState() {
    super.initState();
    _paymentDateController.text = DateTime.now()
        .toIso8601String()
        .split('T')
        .first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _paymentDateController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    _correctionForController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final client = ApiClient.getInstance(
        onUnauthorized: () => ref.read(authProvider.notifier).logout(),
      );
      final repository = CollectionRepository(client);
      final payload = {
        'amount': double.parse(_amountController.text.trim()),
        'receivedDate': _paymentDateController.text.trim(),
        'paymentMode': _paymentMode,
        'referenceNo': _referenceController.text.trim(),
        'remarks': _remarksController.text.trim(),
        if (_correctionForController.text.trim().isNotEmpty)
          'correctionForId': int.tryParse(_correctionForController.text.trim()),
      };
      if (widget.isCorrection) {
        await repository.recordCollectionCorrection(
          widget.collectionId,
          payload,
        );
      } else {
        await repository.recordCollectionPayment(widget.collectionId, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isCorrection
                ? 'Correction saved successfully'
                : 'Payment recorded successfully',
          ),
          backgroundColor: widget.isCorrection
              ? AppColors.warning
              : AppColors.success,
        ),
      );
      context.go('/collections/${widget.collectionId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isCorrection
              ? 'Add Collection Correction'
              : 'Record Collection',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.isCorrection)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Enter the correction amount as a normal positive value. The app will send it as a negative correction entry in the backend.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            AppTextField(
              label: widget.isCorrection
                  ? 'Correction Amount (Rs.)'
                  : 'Amount Collected (Rs.)',
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final base = Validators.positiveNumber(v, 'Amount');
                if (base != null) return base;
                if (widget.isCorrection &&
                    _remarksController.text.trim().isEmpty) {
                  return 'Remarks are required for corrections';
                }
                return null;
              },
            ),
            if (widget.isCorrection) ...[
              const SizedBox(height: 16),
              AppTextField(
                label: 'Original Payment Entry ID (Optional)',
                controller: _correctionForController,
                keyboardType: TextInputType.number,
              ),
            ],
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
              items: _paymentModes
                  .map(
                    (mode) => DropdownMenuItem(value: mode, child: Text(mode)),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _paymentMode = value ?? 'Cash'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Reference No. (Optional)',
              controller: _referenceController,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: widget.isCorrection
                  ? 'Correction Remarks *'
                  : 'Remarks (Optional)',
              controller: _remarksController,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.isCorrection
                          ? 'Save Correction'
                          : 'Record Collection',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
