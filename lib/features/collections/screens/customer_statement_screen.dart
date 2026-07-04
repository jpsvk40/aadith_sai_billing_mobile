import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

const _teal = Color(0xFF0D9488);

/// One customer's collection statement — their outstanding invoices with totals,
/// plus Download/Share PDF and Send-on-WhatsApp (both server-rendered, same PDF).
/// Mirrors the invoice detail screen's WhatsApp send.
class CustomerStatementScreen extends ConsumerStatefulWidget {
  const CustomerStatementScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerNameTa,
    this.city,
    this.phone,
    this.items = const [],
  });

  final String customerId;
  final String customerName;
  final String? customerNameTa;
  final String? city;
  final String? phone;
  final List<Collection> items;

  @override
  ConsumerState<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends ConsumerState<CustomerStatementScreen> {
  bool _busyPdf = false;
  bool _busyWa = false;

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());

  Color _statusColor(String s) => switch (s.toLowerCase()) {
        'collected' || 'settled' || 'completed' => AppColors.success,
        'partial' => const Color(0xFFD97706),
        'failed' => AppColors.danger,
        _ => const Color(0xFF2563EB),
      };

  String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _sharePdf() async {
    if (_busyPdf) return;
    setState(() => _busyPdf = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Preparing PDF…')));
    try {
      final bytes = await _client.getBytes(
        ApiConstants.collectionStatementPdf(widget.customerId),
        timeout: const Duration(seconds: 90),
      );
      if (bytes.isEmpty) throw Exception('Empty PDF');
      final dir = await getTemporaryDirectory();
      final safe = widget.customerName.replaceAll(RegExp(r'[^\w.-]'), '_');
      final file = File('${dir.path}/Statement_$safe.pdf');
      await file.writeAsBytes(bytes, flush: true);
      messenger.hideCurrentSnackBar();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Collection statement — ${widget.customerName}',
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      final raw = (e is AppException) ? e.message : e.toString();
      messenger.showSnackBar(SnackBar(content: Text(raw.isNotEmpty ? 'Could not prepare PDF: $raw' : 'Could not prepare the PDF.')));
    } finally {
      if (mounted) setState(() => _busyPdf = false);
    }
  }

  /// Ask which number to send to — prefilled with the customer's, but editable so
  /// a whitelisted test-recipient number can be used while WhatsApp is in test mode.
  Future<String?> _promptNumber() async {
    final ctrl = TextEditingController(text: (widget.phone ?? '').replaceAll(RegExp(r'[^\d+]'), ''));
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send statement on WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statement for ${widget.customerName}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number',
                hintText: 'e.g. 9843688994',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('In test mode, only numbers on your WhatsApp test-recipient list will receive the message.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsApp() async {
    if (_busyWa) return;
    final number = await _promptNumber();
    if (number == null || number.trim().isEmpty || !mounted) return;
    setState(() => _busyWa = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Sending to $number…')));
    try {
      await _client.post(
        ApiConstants.collectionStatementWhatsapp(widget.customerId),
        data: {'to': number.trim()},
        timeout: const Duration(seconds: 90),
      );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('✓ Statement sent on WhatsApp')));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      final raw = (e is AppException) ? e.message : e.toString();
      final s = raw.toLowerCase();
      final msg = s.contains('not enabled')
          ? "WhatsApp isn't enabled for your company."
          : s.contains('not configured')
              ? "WhatsApp isn't set up on the server yet."
              : (s.contains('allowed list') || s.contains('whitelist'))
                  ? "This number isn't on your WhatsApp test-recipient list."
                  : s.contains('no valid')
                      ? 'Customer has no valid WhatsApp/phone number.'
                      : (raw.isNotEmpty ? 'Could not send: $raw' : 'Could not send on WhatsApp.');
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busyWa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    double total = 0, collected = 0, balance = 0;
    for (final c in items) {
      total += c.totalOutstanding;
      collected += c.collectedAmount ?? 0;
      balance += c.balanceAmount;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Statement'),
        actions: [
          IconButton(
            tooltip: 'Send on WhatsApp',
            icon: _busyWa
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 20),
            onPressed: _busyWa ? null : _sendWhatsApp,
          ),
          IconButton(
            tooltip: 'Download / share PDF',
            icon: _busyPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            onPressed: _busyPdf ? null : _sharePdf,
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        // ── Customer + balance hero ──
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [_teal, Color(0xFF0F766E)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.customerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
              if ((widget.customerNameTa ?? '').isNotEmpty)
                Text(widget.customerNameTa!, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
              if ((widget.city ?? '').isNotEmpty || (widget.phone ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text([if ((widget.city ?? '').isNotEmpty) widget.city!, if ((widget.phone ?? '').isNotEmpty) widget.phone!].join(' · '),
                    style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.8))),
              ],
              const SizedBox(height: 14),
              Text('Balance due', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
              Text(CurrencyUtils.format(balance), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 12),
              Row(children: [
                _heroMetric('Billed', CurrencyUtils.format(total)),
                _heroMetric('Collected', CurrencyUtils.format(collected)),
                _heroMetric('Invoices', '${items.length}'),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        // ── Action buttons (mirror invoice: WhatsApp + PDF) ──
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busyPdf ? null : _sharePdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Download PDF'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), foregroundColor: _teal, side: const BorderSide(color: _teal)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _busyWa ? null : _sendWhatsApp,
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 17),
              label: const Text('WhatsApp'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46), backgroundColor: const Color(0xFF25D366)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Text('Outstanding invoices (${items.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No outstanding invoices', style: TextStyle(color: AppColors.textSecondary)))),
        ...items.map(_invoiceRow),
      ]),
    );
  }

  Widget _heroMetric(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _invoiceRow(Collection c) {
    final sc = _statusColor(c.status);
    final overdue = c.dueDate != null && c.dueDate!.isBefore(DateTime.now()) && c.balanceAmount > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.invoiceNo ?? 'Invoice', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Text(c.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sc)),
          ),
        ]),
        if (overdue) ...[
          const SizedBox(height: 6),
          Text('Overdue · due ${_d(c.dueDate!)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          _metric('Total', CurrencyUtils.format(c.totalOutstanding)),
          _metric('Collected', CurrencyUtils.format(c.collectedAmount ?? 0)),
          _metric('Balance', CurrencyUtils.format(c.balanceAmount), color: c.balanceAmount > 0 ? AppColors.danger : AppColors.success),
        ]),
      ]),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary)),
        ]),
      );
}
