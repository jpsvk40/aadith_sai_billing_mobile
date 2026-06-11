import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/invoice_detail_provider.dart';

const _badgeColors = [
  Color(0xFF0D6EFD), Color(0xFF198754), Color(0xFFF59E0B), Color(0xFF7C3AED),
  Color(0xFFDC3545), Color(0xFF0891B2), Color(0xFF6366F1), Color(0xFFDB2777),
];

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  Color _statusColor(String s, bool overdue) {
    if (overdue) return AppColors.danger;
    switch (s) {
      case 'Paid':
        return AppColors.success;
      case 'Partial':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  Future<void> _sendWhatsApp(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Sending on WhatsApp…')));
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      await InvoiceRepository(client).sendWhatsApp(invoiceId);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('✓ Sent on WhatsApp')));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      final s = e.toString().toLowerCase();
      final msg = (s.contains('403') || s.contains('not enabled'))
          ? "WhatsApp invoicing isn't enabled for your company."
          : (s.contains('503') || s.contains('not configured'))
              ? "WhatsApp isn't set up on the server yet."
              : (s.contains('400') || s.contains('no valid'))
                  ? 'Customer has no valid WhatsApp/phone number.'
                  : 'Could not send on WhatsApp. Please try again.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/invoices')),
        title: const Text('Invoice Detail'),
        actions: [
          IconButton(
            tooltip: 'Send on WhatsApp',
            icon: const Icon(Icons.chat, color: AppColors.white),
            onPressed: () => _sendWhatsApp(context, ref),
          ),
          TextButton.icon(
            onPressed: () => context.go('/payments/record?invoiceId=$invoiceId'),
            icon: const Icon(Icons.payment, color: AppColors.white, size: 18),
            label: const Text('Pay', style: TextStyle(color: AppColors.white)),
          ),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.refresh(invoiceDetailProvider(invoiceId))),
        data: (inv) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.refresh(invoiceDetailProvider(invoiceId)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                  children: [
                    _headerCard(context, inv),
                    const SizedBox(height: 14),
                    _amountBoxes(inv),
                    const SizedBox(height: 18),
                    if (inv.items.isNotEmpty) _itemsSection(inv),
                    const SizedBox(height: 14),
                    _totalsCard(inv),
                    if (inv.splitInvoices.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _splitSection(context, inv),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context, Invoice inv) {
    final overdue = inv.isOverdue;
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(inv.invoiceNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                _pill(overdue ? 'OVERDUE' : inv.status.toUpperCase(), _statusColor(inv.status, overdue)),
              ],
            ),
            const SizedBox(height: 14),
            _kv('Customer', inv.customerName ?? '-'),
            const SizedBox(height: 8),
            _kv('Date', AppDateUtils.formatDisplay(inv.invoiceDate)),
            if (inv.dueDate != null) ...[
              const SizedBox(height: 8),
              _kv('Due Date', AppDateUtils.formatDisplay(inv.dueDate)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(k, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
      ],
    );
  }

  Widget _amountBoxes(Invoice inv) {
    return Row(
      children: [
        Expanded(child: _amountBox('Total Amount', inv.totalAmount, AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(child: _amountBox('Paid Amount', inv.paidAmount ?? 0, AppColors.success)),
        const SizedBox(width: 10),
        Expanded(child: _amountBox('Balance', inv.outstandingAmount ?? 0, AppColors.danger)),
      ],
    );
  }

  Widget _amountBox(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(CurrencyUtils.formatCompact(value), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _itemsSection(Invoice inv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Items (${inv.items.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        _card(
          child: Column(
            children: List.generate(inv.items.length, (i) {
              final item = inv.items[i];
              final c = _badgeColors[i % _badgeColors.length];
              final last = i == inv.items.length - 1;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.divider, width: 0.6))),
                child: Row(
                  children: [
                    Container(
                      width: 26, height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                      child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName ?? 'Item', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('${_qty(item.quantity)} × ${CurrencyUtils.format(item.price)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(CurrencyUtils.format(item.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _totalsCard(Invoice inv) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _totalRow('Sub Total', CurrencyUtils.format(inv.subtotal)),
            if ((inv.cgst ?? 0) > 0) _totalRow('CGST', CurrencyUtils.format(inv.cgst)),
            if ((inv.sgst ?? 0) > 0) _totalRow('SGST', CurrencyUtils.format(inv.sgst)),
            if ((inv.igst ?? 0) > 0) _totalRow('IGST', CurrencyUtils.format(inv.igst)),
            if (inv.roundOff != 0) _totalRow('Round Off', CurrencyUtils.format(inv.roundOff)),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
            _totalRow('Total Amount', CurrencyUtils.format(inv.totalAmount), bold: true),
            const SizedBox(height: 4),
            _totalRow('Balance Amount', CurrencyUtils.format(inv.outstandingAmount ?? 0), bold: true, color: AppColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: AppColors.textPrimary)),
          Text(value, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _splitSection(BuildContext context, Invoice inv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Split Invoices (${inv.splitInvoices.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        _card(
          child: Column(
            children: List.generate(inv.splitInvoices.length, (i) {
              final sp = inv.splitInvoices[i];
              final last = i == inv.splitInvoices.length - 1;
              final sc = _statusColor(sp.status, false);
              return InkWell(
                onTap: () => context.go('/invoices/${sp.id}'),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.divider, width: 0.6))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sp.invoiceNo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary)),
                            if (sp.paymentMode != null) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(4)),
                                child: Text(sp.paymentMode!, style: const TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(CurrencyUtils.format(sp.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 3),
                          _pill(sp.status.toUpperCase(), sc),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
      );

  String _qty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
