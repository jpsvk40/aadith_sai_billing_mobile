import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

/// Office expenses / petty cash — list + add. Create-capable spine surface.
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get(ApiConstants.officeExpenses);
      dynamic list = data;
      if (data is Map) list = data['data'] ?? data['expenses'] ?? data['rows'] ?? data.values.firstWhere((v) => v is List, orElse: () => const []);
      if (!mounted) return;
      setState(() { _rows = (list is List ? list : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  String? _first(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      final v = r[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final total = _rows.fold<double>(0, (a, r) => a + _num(r['amount'] ?? r['totalAmount']));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await context.push<bool>('/finance/expenses/new');
          if (added == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: _loading && _rows.isEmpty
          ? const LoadingIndicator()
          : _error != null && _rows.isEmpty
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
                    itemCount: _rows.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return Container(
                          margin: const EdgeInsets.all(14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFB45309)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(children: [
                            const Icon(Icons.request_quote_outlined, color: Colors.white, size: 26),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Total expenses', style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(CurrencyUtils.format(total), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                            ])),
                            Text('${_rows.length} rows', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                          ]),
                        );
                      }
                      final r = _rows[i - 1];
                      final label = _first(r, ['category', 'categoryName', 'description', 'notes', 'name']) ?? 'Expense';
                      final rawDate = _first(r, ['expenseDate', 'date']);
                      final date = rawDate != null && rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
                      final mode = _first(r, ['paymentMode', 'mode']);
                      final subtitle = [date, mode].whereType<String>().join(' · ');
                      return Container(
                        margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                            ],
                          ])),
                          const SizedBox(width: 10),
                          Text(CurrencyUtils.format(_num(r['amount'] ?? r['totalAmount'])), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
