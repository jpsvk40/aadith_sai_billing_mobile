import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/status_badge.dart';
import '../providers/invoice_list_provider.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String? _selectedStatus;
  final _statuses = ['All', 'Unpaid', 'Partial', 'Paid', 'Overdue'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(invoiceListProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final status = _statuses[i];
                final isSelected = (status == 'All' && _selectedStatus == null) || status == _selectedStatus;
                return FilterChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedStatus = status == 'All' ? null : status);
                    ref.read(invoiceListProvider.notifier).load(status: _selectedStatus);
                  },
                  selectedColor: AppColors.primaryLight,
                  checkmarkColor: AppColors.primary,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: state.isLoading && state.invoices.isEmpty
                ? const LoadingIndicator()
                : state.error != null && state.invoices.isEmpty
                    ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(invoiceListProvider.notifier).load())
                    : state.invoices.isEmpty
                        ? const EmptyStateWidget(message: 'No invoices found', icon: Icons.description_outlined)
                        : RefreshIndicator(
                            onRefresh: () => ref.read(invoiceListProvider.notifier).load(status: _selectedStatus),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: state.invoices.length,
                              itemBuilder: (ctx, i) {
                                final invoice = state.invoices[i];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                  child: InkWell(
                                    onTap: () => context.go('/invoices/${invoice.id}'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  invoice.invoiceNumber,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                              ),
                                              StatusBadge(status: invoice.isOverdue ? 'Overdue' : invoice.status),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          if (invoice.customerName != null)
                                            Text(invoice.customerName!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                AppDateUtils.formatDisplay(invoice.invoiceDate),
                                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(CurrencyUtils.format(invoice.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                  if ((invoice.outstandingAmount ?? 0) > 0)
                                                    Text(
                                                      'Due: ${CurrencyUtils.format(invoice.outstandingAmount)}',
                                                      style: const TextStyle(fontSize: 11, color: AppColors.danger),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
