import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/service_item_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/app_card.dart';
import '../providers/service_providers.dart';

/// Warranty register — registered units + warranty status. Searchable.
class ServiceItemsScreen extends ConsumerStatefulWidget {
  const ServiceItemsScreen({super.key});
  @override
  ConsumerState<ServiceItemsScreen> createState() => _ServiceItemsScreenState();
}

class _ServiceItemsScreenState extends ConsumerState<ServiceItemsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(serviceItemsProvider(_search));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Warranty Register')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search serial / brand / model', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(serviceItemsProvider(_search))),
            data: (items) => items.isEmpty
                ? const EmptyStateWidget(message: 'No registered units', icon: Icons.devices_other)
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(serviceItemsProvider(_search)),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) => _card(items[i]),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _card(ServiceItem item) {
    final color = item.underWarranty ? AppColors.success : AppColors.danger;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.label.isEmpty ? (item.category ?? 'Unit') : item.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(item.underWarranty ? 'In warranty' : 'Expired', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Serial: ${item.serialNumber}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        Text('Owner: ${item.customer?.name ?? '—'}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        if (item.warrantyEndDate != null)
          Text('Warranty till ${AppDateUtils.formatDisplay(item.warrantyEndDate)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
      ]),
    );
  }
}
