import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/status_badge.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/collection_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/collection_detail_provider.dart';

class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;
  const CollectionDetailScreen({super.key, required this.collectionId});

  Widget _waActions(BuildContext context, WidgetRef ref, Collection c) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 6),
        child: Row(children: [
          FaIcon(FontAwesomeIcons.whatsapp, size: 16, color: Color(0xFF25D366)),
          SizedBox(width: 6),
          Text('Send on WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF128C7E))),
        ]),
      ),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: c.invoiceId == null ? null : () => _sendInvoice(context, ref, c),
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Color(0xFF25D366)),
            label: const Text('Invoice'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: c.payments.isEmpty ? null : () => _sendReceipt(context, ref, c),
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Color(0xFF25D366)),
            label: const Text('Receipt'),
          ),
        ),
      ]),
    ]);
  }

  Future<String?> _promptNumber(BuildContext context, String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'WhatsApp number', hintText: '91XXXXXXXXXX'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Send')),
        ],
      ),
    );
  }

  String _waErr(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('403') || s.contains('not enabled')) return "WhatsApp invoicing isn't enabled for your company.";
    if (s.contains('503') || s.contains('not configured')) return "WhatsApp isn't set up on the server yet.";
    if (s.contains('400') || s.contains('no valid')) return 'No valid WhatsApp/phone number.';
    return 'Could not send on WhatsApp. Please try again.';
  }

  Future<void> _doSend(BuildContext context, WidgetRef ref, String label, String initialTo, Future<void> Function(CollectionRepository repo, String to) action) async {
    final to = await _promptNumber(context, 'Send $label on WhatsApp', initialTo);
    if (to == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Sending $label…')));
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      await action(CollectionRepository(client), to);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('✓ $label sent on WhatsApp')));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(_waErr(e))));
    }
  }

  Future<void> _sendInvoice(BuildContext context, WidgetRef ref, Collection c) =>
      _doSend(context, ref, 'Invoice', c.customerPhone ?? '', (repo, to) => repo.sendInvoiceWhatsApp(c.invoiceId!, to: to));

  Future<void> _sendReceipt(BuildContext context, WidgetRef ref, Collection c) =>
      _doSend(context, ref, 'Receipt', c.customerPhone ?? '', (repo, to) => repo.sendReceiptWhatsApp(c.payments.last.id, to: to));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionAsync = ref.watch(collectionDetailProvider(collectionId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/collections'),
        ),
        title: const Text('Collection Detail'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/collections/$collectionId/payment'),
            icon: const Icon(Icons.payment, color: AppColors.white, size: 18),
            label: const Text(
              'Collect',
              style: TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
      body: collectionAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(
          message: e.toString(),
          onRetry: () => ref.refresh(collectionDetailProvider(collectionId)),
        ),
        data: (collection) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _waActions(context, ref, collection),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          collection.customerName ?? 'Customer',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        StatusBadge(status: collection.status),
                      ],
                    ),
                    const Divider(height: 24),
                    _Row(
                      label: 'Total to Collect',
                      value: CurrencyUtils.format(collection.totalOutstanding),
                      valueColor: AppColors.textPrimary,
                    ),
                    if ((collection.collectedAmount ?? 0) > 0)
                      _Row(
                        label: 'Collected',
                        value: CurrencyUtils.format(collection.collectedAmount),
                        valueColor: AppColors.success,
                      ),
                    _Row(
                      label: 'Balance',
                      value: CurrencyUtils.format(collection.balanceAmount),
                      valueColor: collection.balanceAmount > 0
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                    if (collection.assignedDate != null)
                      _Row(
                        label: 'Assigned',
                        value: AppDateUtils.formatDisplay(
                          collection.assignedDate,
                        ),
                      ),
                    if (collection.dueDate != null)
                      _Row(
                        label: 'Due Date',
                        value: AppDateUtils.formatDisplay(collection.dueDate),
                      ),
                    if (collection.representativeName != null)
                      _Row(
                        label: 'Assigned To',
                        value: collection.representativeName!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (collection.payments.any((p) => p.isPending))
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top, color: Color(0xFFB45309), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment of ${CurrencyUtils.format(collection.payments.where((p) => p.isPending).fold<double>(0, (a, p) => a + p.amount))} submitted — awaiting admin approval.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (collection.payments.isNotEmpty) ...[
              Text(
                'Payment History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...collection.payments.map((payment) {
                final isCorr = payment.entryType == 'correction';
                final statusColor = payment.isPending
                    ? const Color(0xFFF59E0B)
                    : payment.isRejected
                        ? AppColors.danger
                        : AppColors.success;
                final statusLabel = payment.isPending
                    ? 'PENDING APPROVAL'
                    : payment.isRejected
                        ? 'REJECTED'
                        : 'APPROVED';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(isCorr ? Icons.remove_circle_outline : Icons.payments_outlined,
                            color: isCorr ? AppColors.danger : statusColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(CurrencyUtils.format(payment.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('${isCorr ? 'Correction' : 'Payment'} · ${payment.paymentMode} · ${AppDateUtils.formatDisplay(payment.paymentDate)}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
                          child: Text(statusLabel, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: statusColor)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/collections/$collectionId/payment'),
                icon: const Icon(Icons.payment),
                label: const Text('Record Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
