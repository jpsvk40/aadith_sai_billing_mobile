import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/payment_list_provider.dart';

class PaymentListScreen extends ConsumerStatefulWidget {
  const PaymentListScreen({super.key});

  @override
  ConsumerState<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends ConsumerState<PaymentListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(paymentListProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentListProvider);
    final canRecordPayment = ref.watch(authProvider).user?.hasModule('payments') == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        actions: canRecordPayment
            ? [
                IconButton(icon: const Icon(Icons.add), onPressed: () => context.go('/payments/record')),
              ]
            : null,
      ),
      body: state.isLoading && state.payments.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.payments.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(paymentListProvider.notifier).load())
              : state.payments.isEmpty
                  ? const EmptyStateWidget(message: 'No payments found', icon: Icons.payment_outlined)
                  : RefreshIndicator(
                      onRefresh: () => ref.read(paymentListProvider.notifier).load(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.payments.length,
                        itemBuilder: (ctx, i) {
                          final payment = state.payments[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.successLight,
                                child: const Icon(Icons.payment, color: AppColors.success, size: 20),
                              ),
                              title: Text(payment.customerName ?? 'Payment', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (payment.invoiceNumber != null)
                                    Text('Invoice: ${payment.invoiceNumber}', style: const TextStyle(fontSize: 12)),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(4)),
                                        child: Text(
                                          payment.paymentMode,
                                          style: const TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppDateUtils.formatDisplay(payment.paymentDate ?? payment.createdAt),
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Text(
                                CurrencyUtils.format(payment.amount),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 14),
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
