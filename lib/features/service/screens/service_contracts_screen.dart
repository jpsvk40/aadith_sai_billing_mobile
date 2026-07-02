import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/service_contract_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/app_card.dart';
import '../providers/service_providers.dart';

/// AMC / service contracts list (admin). Shows visit usage + expiry.
class ServiceContractsScreen extends ConsumerWidget {
  const ServiceContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(serviceContractsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('AMC Contracts')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(serviceContractsProvider)),
        data: (contracts) => contracts.isEmpty
            ? const EmptyStateWidget(message: 'No contracts', icon: Icons.assignment_outlined)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(serviceContractsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: contracts.length,
                  itemBuilder: (ctx, i) => _card(contracts[i]),
                ),
              ),
      ),
    );
  }

  Widget _card(ServiceContract c) {
    final expiryColor = c.isExpired ? AppColors.danger : (c.isExpiringSoon ? AppColors.warning : AppColors.textSecondary);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c.contractNumber} · ${c.customer?.name ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
            child: Text(c.contractType, style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _stat('Value', CurrencyUtils.format(c.contractValue))),
          Expanded(child: _stat('Visits', '${c.visitsUsed}/${c.visitsIncluded}')),
          Expanded(child: _stat('Status', c.status)),
        ]),
        const SizedBox(height: 6),
        Text(
          c.endDate != null ? 'Expires ${AppDateUtils.formatDisplay(c.endDate)}${c.daysToExpiry != null ? ' (${c.daysToExpiry}d)' : ''}' : '',
          style: TextStyle(fontSize: 12, color: expiryColor, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]);
}
