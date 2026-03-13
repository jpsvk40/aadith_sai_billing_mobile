import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/collection_list_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/status_badge.dart';

class CollectionListScreen extends ConsumerStatefulWidget {
  const CollectionListScreen({super.key});

  @override
  ConsumerState<CollectionListScreen> createState() => _CollectionListScreenState();
}

class _CollectionListScreenState extends ConsumerState<CollectionListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(collectionListProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      body: state.isLoading && state.collections.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.collections.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(collectionListProvider.notifier).load())
              : state.collections.isEmpty
                  ? const EmptyStateWidget(message: 'No collections assigned', icon: Icons.account_balance_wallet_outlined)
                  : RefreshIndicator(
                      onRefresh: () => ref.read(collectionListProvider.notifier).load(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.collections.length,
                        itemBuilder: (ctx, i) {
                          final c = state.collections[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            child: InkWell(
                              onTap: () => context.go('/collections/${c.id}'),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(c.customerName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                        StatusBadge(status: c.status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Outstanding', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                            Text(CurrencyUtils.format(c.totalOutstanding), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 14)),
                                          ],
                                        ),
                                        if ((c.collectedAmount ?? 0) > 0)
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text('Collected', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                              Text(CurrencyUtils.format(c.collectedAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 14)),
                                            ],
                                          ),
                                      ],
                                    ),
                                    if (c.dueDate != null) ...[
                                      const SizedBox(height: 4),
                                      Text('Due: ${AppDateUtils.formatDisplay(c.dueDate)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
