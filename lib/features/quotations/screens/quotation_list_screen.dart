import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/quotation_model.dart';
import '../providers/quotation_providers.dart';

/// Quotations list — parity with the web QuotationsPage: title + subtitle,
/// status filter pills, and rows showing quote #, party, date, valid-until, total, status.
class QuotationListScreen extends ConsumerStatefulWidget {
  const QuotationListScreen({super.key});
  @override
  ConsumerState<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends ConsumerState<QuotationListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(quotationListProvider.notifier).load());
  }

  String _shortDate(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quotationListProvider);
    final filters = ['All', ...QuotationStatus.all];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Quotations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/quotations/create');
          if (mounted) ref.read(quotationListProvider.notifier).load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Quotation'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Send quotes to customers, then convert an accepted one straight into a GST invoice.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final f = filters[i];
                final active = state.statusFilter == f;
                return InkWell(
                  onTap: () => ref.read(quotationListProvider.notifier).setFilter(f),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.textPrimary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? AppColors.textPrimary : AppColors.border),
                    ),
                    child: Text(
                      f == 'All' ? 'All' : f,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _error(state.error!)
                    : state.quotations.isEmpty
                        ? _empty()
                        : RefreshIndicator(
                            onRefresh: () => ref.read(quotationListProvider.notifier).load(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: state.quotations.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) => _row(state.quotations[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _row(Quotation q) {
    final c = QuotationStatus.color(q.status);
    return InkWell(
      onTap: () async {
        await context.push('/quotations/${q.id}');
        if (mounted) ref.read(quotationListProvider.notifier).load();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(q.quoteNumber, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    _chip(q.status, c),
                  ]),
                  const SizedBox(height: 4),
                  Text(q.partyLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    'Quote ${_shortDate(q.quoteDate)}${q.validUntil != null ? '  ·  valid till ${_shortDate(q.validUntil)}' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(CurrencyUtils.format(q.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
      );

  Widget _empty() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.request_quote_outlined, size: 46, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(child: Text('No quotations yet.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );

  Widget _error(String e) => ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
          const SizedBox(height: 12),
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
        ],
      );
}
