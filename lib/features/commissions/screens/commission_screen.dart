import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/commission_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/status_badge.dart';

class CommissionScreen extends ConsumerStatefulWidget {
  const CommissionScreen({super.key});

  @override
  ConsumerState<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends ConsumerState<CommissionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(commissionProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commissionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Commissions')),
      body: state.isLoading && state.commissions.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.commissions.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(commissionProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () => ref.read(commissionProvider.notifier).load(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary card
                      if (state.summary != null) ...[
                        _SummaryCard(summary: state.summary!),
                        const SizedBox(height: 20),
                      ],

                      Text('Commission History', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),

                      if (state.commissions.isEmpty)
                        const EmptyStateWidget(message: 'No commission records', icon: Icons.percent_outlined)
                      else
                        ...state.commissions.map((c) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(c.repInvoiceNumber ?? c.period, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                    StatusBadge(status: c.status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Sales', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        Text(CurrencyUtils.format(c.totalSales), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Commission', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        Text(CurrencyUtils.format(c.totalCommission),
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)),
                                      ],
                                    ),
                                  ],
                                ),
                                if (c.periodStart != null) ...[
                                  const SizedBox(height: 6),
                                  Text('${AppDateUtils.formatDisplay(c.periodStart)} – ${AppDateUtils.formatDisplay(c.periodEnd)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                ],
                              ],
                            ),
                          ),
                        )),
                    ],
                  ),
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final dynamic summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Commissions', style: TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(CurrencyUtils.format(summary.totalCommission),
              style: const TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SumItem(label: 'Pending', value: CurrencyUtils.format(summary.pendingCommission), color: AppColors.warningLight)),
              Expanded(child: _SumItem(label: 'Paid', value: CurrencyUtils.format(summary.paidCommission), color: AppColors.successLight)),
              Expanded(child: _SumItem(label: 'Invoices', value: summary.totalInvoices.toString(), color: AppColors.infoLight)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SumItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
    child: Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(color: AppColors.white.withValues(alpha: 0.8), fontSize: 10)),
      ],
    ),
  );
}
