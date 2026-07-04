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
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

/// One column of a detailed report row.
class ReportColumn {
  final String header;
  final String field;
  final bool currency;
  final bool isDate;
  final bool numeric;
  final bool primary; // the row's headline label
  const ReportColumn(this.header, this.field, {this.currency = false, this.isDate = false, this.numeric = false, this.primary = false});

  String get align => (currency || numeric) ? 'right' : 'left';
}

/// Declarative config for a single report rendered by [ReportViewScreen].
class ReportConfig {
  final String title;
  final String endpoint;
  final IconData icon;
  final Color color;
  final List<ReportColumn> columns;
  final String? totalField; // currency field summed for the hero + Total row
  final bool supportsPeriod;

  // Legacy fallback (used only when [columns] is empty).
  final List<String> labelKeys;
  final List<String> amountKeys;
  final List<String> subtitleKeys;

  const ReportConfig({
    required this.title,
    required this.endpoint,
    required this.icon,
    required this.color,
    this.columns = const [],
    this.totalField,
    this.supportsPeriod = false,
    this.labelKeys = const ['customerName', 'productName', 'name', 'label', 'title', 'invoiceNumber'],
    this.amountKeys = const ['balanceAmount', 'totalSales', 'salesTotal', 'netSales', 'totalAmount', 'netAmount', 'grandTotal', 'total', 'amount', 'outstanding', 'value'],
    this.subtitleKeys = const ['invoiceNumber', 'dueDate', 'orderCount', 'quantity', 'phone', 'agingBucket'],
  });
}

const _periods = <(String, String)>[
  ('', 'All Time'),
  ('thisMonth', 'This Month'),
  ('lastMonth', 'Last Month'),
  ('last90days', 'Last 90 Days'),
  ('thisYear', 'This Year'),
];

class ReportViewScreen extends ConsumerStatefulWidget {
  const ReportViewScreen({super.key, required this.config});
  final ReportConfig config;
  @override
  ConsumerState<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends ConsumerState<ReportViewScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;
  String _period = '';
  bool _busyPdf = false;
  bool _busyWa = false;

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _client.get(widget.config.endpoint,
          queryParams: widget.config.supportsPeriod && _period.isNotEmpty ? {'period': _period} : null);
      final list = _asList(data);
      if (!mounted) return;
      setState(() { _rows = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    dynamic list = data;
    if (data is Map) {
      list = data['data'] ?? data['rows'] ?? data['items'] ?? data['customers'] ?? data['products'] ?? data['invoices'] ?? data['results'];
      list ??= data.values.firstWhere((v) => v is List, orElse: () => const []);
    }
    if (list is List) return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    return const [];
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  String? _first(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  String _cell(Map<String, dynamic> r, ReportColumn c) {
    final v = r[c.field];
    if (c.currency) return CurrencyUtils.format(_num(v));
    if (c.isDate) {
      final s = v?.toString() ?? '';
      return s.length >= 10 ? s.substring(0, 10) : s;
    }
    if (c.numeric) {
      final d = _num(v);
      return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
    }
    return v?.toString() ?? '';
  }

  ReportColumn? get _totalColumn {
    final cfg = widget.config;
    if (cfg.columns.isEmpty) return null;
    if (cfg.totalField != null) {
      for (final c in cfg.columns) {
        if (c.field == cfg.totalField) return c;
      }
    }
    for (final c in cfg.columns) {
      if (c.currency) return c;
    }
    return null;
  }

  double get _total {
    final tc = _totalColumn;
    if (tc != null) return _rows.fold<double>(0, (a, r) => a + _num(r[tc.field]));
    // legacy fallback
    for (final k in widget.config.amountKeys) {
      if (_rows.isNotEmpty && _rows.first.containsKey(k)) {
        return _rows.fold<double>(0, (a, r) => a + _num(r[k]));
      }
    }
    return 0;
  }

  // ── Build the print payload (columns + formatted rows + Total footer) ──
  Map<String, dynamic> _payload() {
    final cfg = widget.config;
    final cols = cfg.columns;
    final columns = cols.map((c) => {'header': c.header, 'align': c.align}).toList();
    final rows = _rows.map((r) => cols.map((c) => _cell(r, c)).toList()).toList();
    final tc = _totalColumn;
    List<String>? totals;
    if (tc != null) {
      totals = cols.map((c) {
        if (c.primary) return 'Total';
        if (c.field == tc.field) return CurrencyUtils.format(_total);
        return '';
      }).toList();
      // ensure the first column reads "Total" even if none marked primary
      if (!cols.any((c) => c.primary) && totals.isNotEmpty) totals[0] = 'Total';
    }
    final periodLabel = _periods.firstWhere((p) => p.$1 == _period, orElse: () => ('', 'All Time')).$2;
    return {
      'title': cfg.title,
      'subtitle': cfg.supportsPeriod ? periodLabel : '',
      'columns': columns,
      'rows': rows,
      if (totals != null) 'totals': totals,
      if (tc != null) 'total': CurrencyUtils.format(_total),
    };
  }

  Future<void> _sharePdf() async {
    if (_busyPdf || _rows.isEmpty) return;
    setState(() => _busyPdf = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Preparing PDF…')));
    try {
      final bytes = await _client.postBytes(ApiConstants.reportRenderPdf, data: _payload(), timeout: const Duration(seconds: 90));
      if (bytes.isEmpty) throw Exception('Empty PDF');
      final dir = await getTemporaryDirectory();
      final safe = widget.config.title.replaceAll(RegExp(r'[^\w.-]'), '_');
      final file = File('${dir.path}/Report_$safe.pdf');
      await file.writeAsBytes(bytes, flush: true);
      messenger.hideCurrentSnackBar();
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')], text: '${widget.config.title} report');
    } catch (e) {
      messenger.hideCurrentSnackBar();
      final raw = (e is AppException) ? e.message : e.toString();
      messenger.showSnackBar(SnackBar(content: Text(raw.isNotEmpty ? 'Could not prepare PDF: $raw' : 'Could not prepare the PDF.')));
    } finally {
      if (mounted) setState(() => _busyPdf = false);
    }
  }

  Future<String?> _promptNumber() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send report on WhatsApp'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.config.title, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'WhatsApp number', hintText: 'e.g. 9843688994', prefixIcon: Icon(Icons.phone_outlined, size: 20), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          const Text('In test mode, only numbers on your WhatsApp test-recipient list will receive the message.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { final v = ctrl.text.trim(); if (v.isNotEmpty) Navigator.pop(ctx, v); },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWhatsApp() async {
    if (_busyWa || _rows.isEmpty) return;
    final number = await _promptNumber();
    if (number == null || number.trim().isEmpty || !mounted) return;
    setState(() => _busyWa = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Sending to $number…')));
    try {
      await _client.post(ApiConstants.reportWhatsapp, data: {..._payload(), 'to': number.trim()}, timeout: const Duration(seconds: 90));
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('✓ Report sent on WhatsApp')));
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
                  : (raw.isNotEmpty ? 'Could not send: $raw' : 'Could not send on WhatsApp.');
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busyWa = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(cfg.title),
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
      body: _loading && _rows.isEmpty
          ? const LoadingIndicator()
          : _error != null && _rows.isEmpty
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: _rows.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(cfg, _total);
                      return _row(_rows[i - 1], cfg);
                    },
                  ),
                ),
    );
  }

  Widget _header(ReportConfig cfg, double total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [cfg.color, Color.lerp(cfg.color, Colors.black, 0.22)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: cfg.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
              child: Icon(cfg.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 3),
              Text(CurrencyUtils.format(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            ])),
            Text('${_rows.length} rows', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
          ]),
        ),
        if (cfg.supportsPeriod) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _period,
                  items: _periods.map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) { setState(() => _period = v ?? ''); _load(); },
                ),
              )),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          const Expanded(child: Text('Download or WhatsApp this report from the top-right', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
        ]),
        const SizedBox(height: 8),
        if (_rows.isEmpty && !_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No data for this report', style: TextStyle(color: AppColors.textSecondary)))),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> r, ReportConfig cfg) {
    // Legacy 2-field rendering when no columns are declared.
    if (cfg.columns.isEmpty) {
      final label = _first(r, cfg.labelKeys) ?? '—';
      final subtitle = _first(r, cfg.subtitleKeys);
      double amount = 0;
      for (final k in cfg.amountKeys) {
        if (r.containsKey(k)) { amount = _num(r[k]); if (amount != 0) break; }
      }
      return _shell(child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          if (subtitle != null) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ])),
        if (amount != 0) Text(CurrencyUtils.format(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ]));
    }

    final cols = cfg.columns;
    final primary = cols.firstWhere((c) => c.primary, orElse: () => cols.first);
    final rest = cols.where((c) => c != primary).toList();

    return _shell(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_cell(r, primary).isEmpty ? '—' : _cell(r, primary),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 8, children: rest.map((c) {
        final val = _cell(r, c);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(c.header, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 1),
          Text(val.isEmpty ? '—' : val,
              style: TextStyle(fontSize: 12.5, fontWeight: c.currency ? FontWeight.w800 : FontWeight.w600,
                  color: c.currency ? AppColors.textPrimary : AppColors.textSecondary)),
        ]);
      }).toList()),
    ]));
  }

  Widget _shell({required Widget child}) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: child,
      );
}
