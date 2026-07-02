import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

/// Declarative config for a single owner report rendered by [ReportViewScreen].
class ReportConfig {
  final String title;
  final String endpoint;
  final IconData icon;
  final Color color;
  final List<String> labelKeys;
  final List<String> amountKeys;
  final List<String> subtitleKeys;
  final bool supportsPeriod;

  const ReportConfig({
    required this.title,
    required this.endpoint,
    required this.icon,
    required this.color,
    this.labelKeys = const ['customerName', 'productName', 'name', 'label', 'title', 'invoiceNumber'],
    this.amountKeys = const ['balanceAmount', 'totalSales', 'salesTotal', 'netSales', 'totalAmount', 'netAmount', 'grandTotal', 'total', 'amount', 'outstanding', 'value'],
    this.subtitleKeys = const ['invoiceNumber', 'dueDate', 'orderCount', 'quantity', 'phone', 'agingBucket'],
    this.supportsPeriod = false,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get(widget.config.endpoint,
          queryParams: widget.config.supportsPeriod && _period.isNotEmpty ? {'period': _period} : null);
      final list = _asList(data);
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    dynamic list = data;
    if (data is Map) {
      list = data['data'] ?? data['rows'] ?? data['items'] ?? data['customers'] ?? data['products'] ?? data['invoices'] ?? data['results'];
      list ??= data.values.firstWhere((v) => v is List, orElse: () => const []);
    }
    if (list is List) {
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
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

  double _amountOf(Map<String, dynamic> r) {
    for (final k in widget.config.amountKeys) {
      if (r.containsKey(k) && _num(r[k]) != 0) return _num(r[k]);
    }
    // fall back to the first numeric value if nothing matched
    for (final k in widget.config.amountKeys) {
      if (r.containsKey(k)) return _num(r[k]);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final total = _rows.fold<double>(0, (a, r) => a + _amountOf(r));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(cfg.title)),
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
                      if (i == 0) return _header(cfg, total);
                      return _row(_rows[i - 1], cfg);
                    },
                  ),
                ),
    );
  }

  Widget _header(ReportConfig cfg, double total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cfg.color, Color.lerp(cfg.color, Colors.black, 0.22)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: cfg.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
                  child: Icon(cfg.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 3),
                      Text(CurrencyUtils.format(total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                ),
                Text('${_rows.length} rows', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          if (cfg.supportsPeriod) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _period,
                      items: _periods.map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (v) {
                        setState(() => _period = v ?? '');
                        _load();
                      },
                    ),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          if (_rows.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No data for this report', style: TextStyle(color: AppColors.textSecondary))),
            ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> r, ReportConfig cfg) {
    final label = _first(r, cfg.labelKeys) ?? '—';
    final subtitle = _first(r, cfg.subtitleKeys);
    final amount = _amountOf(r);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (amount != 0)
            Text(CurrencyUtils.format(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
