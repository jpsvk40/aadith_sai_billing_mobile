import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/payment_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/payment_list_provider.dart';

const _periods = <(String, String)>[
  ('', 'All Time'),
  ('thisMonth', 'This Month'),
  ('lastMonth', 'Last Month'),
  ('last30days', 'Last 30 Days'),
  ('last90days', 'Last 90 Days'),
  ('thisYear', 'This Year'),
  ('lastYear', 'Last Year'),
];

class PaymentListScreen extends ConsumerStatefulWidget {
  const PaymentListScreen({super.key, this.initialFilter});
  final String? initialFilter;
  @override
  ConsumerState<PaymentListScreen> createState() => _PaymentListScreenState();
}

class _PaymentListScreenState extends ConsumerState<PaymentListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final f = widget.initialFilter;
      if (f != null && f.isNotEmpty) ref.read(paymentListProvider.notifier).setApprovalFilter(f);
      ref.read(paymentListProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Payment> _filtered(PaymentListState s) {
    final q = s.search.trim().toLowerCase();
    return s.payments.where((p) {
      if (s.approvalFilter != 'All' && p.approvalStatus != s.approvalFilter) return false;
      if (q.isEmpty) return true;
      return (p.customerName ?? '').toLowerCase().contains(q) ||
          (p.invoiceNumber ?? '').toLowerCase().contains(q) ||
          (p.referenceNo ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Pending':
        return AppColors.warning;
      case 'Rejected':
        return AppColors.danger;
      default:
        return AppColors.success;
    }
  }

  Future<void> _approve(Payment p) async {
    final err = await ref.read(paymentListProvider.notifier).approve(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Payment approved'),
      backgroundColor: err == null ? AppColors.success : AppColors.danger,
    ));
  }

  Future<void> _reject(Payment p) async {
    final remarks = await _askRemarks();
    if (remarks == null) return; // cancelled
    final err = await ref.read(paymentListProvider.notifier).reject(p.id, remarks.isEmpty ? null : remarks);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Payment rejected'),
      backgroundColor: err == null ? AppColors.danger : AppColors.danger,
    ));
  }

  Future<String?> _askRemarks() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Payment'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Reason (optional)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _openInvoice(Payment p) {
    if (p.invoiceId != null && p.invoiceId!.isNotEmpty) {
      context.go('/invoices/${p.invoiceId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No invoice linked to this payment')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentListProvider);
    final canRecord = ref.watch(authProvider).user?.hasModule('payments') == true;
    final visible = _filtered(state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments'),
        actions: canRecord
            ? [IconButton(icon: const Icon(Icons.add), onPressed: () => context.go('/payments/record'))]
            : null,
      ),
      body: state.isLoading && state.payments.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.payments.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(paymentListProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () => ref.read(paymentListProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: visible.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(state, visible.length);
                      return _paymentCard(visible[i - 1], state);
                    },
                  ),
                ),
    );
  }

  // ---------------- header: cards + filters ----------------
  Widget _header(PaymentListState s, int shown) {
    final approved = s.payments.where((p) => p.approvalStatus == 'Approved').fold<double>(0, (a, p) => a + p.amount);
    final pending = s.payments.where((p) => p.approvalStatus == 'Pending').length;
    final rejected = s.payments.where((p) => p.approvalStatus == 'Rejected').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
            children: [
              _summaryCard('APPROVED AMOUNT', CurrencyUtils.format(approved), AppColors.success, Icons.verified_outlined),
              _summaryCard('PENDING APPROVAL', '$pending', AppColors.warning, Icons.hourglass_empty),
              _summaryCard('REJECTED', '$rejected', AppColors.danger, Icons.cancel_outlined),
              _summaryCard('ENTRIES SHOWN', '$shown', AppColors.primary, Icons.list_alt_outlined),
            ],
          ),
          const SizedBox(height: 16),
          // search
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(paymentListProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              hintText: 'Search invoice, customer, reference...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              suffixIcon: s.search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                      _searchCtrl.clear();
                      ref.read(paymentListProvider.notifier).setSearch('');
                    })
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          // period
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: s.period,
                      items: _periods.map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (v) => ref.read(paymentListProvider.notifier).setPeriod(v ?? ''),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // approval chips
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['All', 'Pending', 'Approved', 'Rejected'].map((f) {
                final sel = s.approvalFilter == f;
                final c = f == 'All' ? AppColors.primary : _statusColor(f);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: sel,
                    onSelected: (_) => ref.read(paymentListProvider.notifier).setApprovalFilter(f),
                    labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? c : AppColors.textSecondary),
                    selectedColor: c.withValues(alpha: 0.14),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: sel ? c : AppColors.border),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.22)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 5),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ---------------- payment card ----------------
  Widget _paymentCard(Payment p, PaymentListState s) {
    final sc = _statusColor(p.approvalStatus);
    final isPending = p.approvalStatus == 'Pending';
    final acting = s.actioningId == p.id;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _openInvoice(p),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                    child: Icon(Icons.payments_outlined, color: sc, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(p.customerName ?? 'Payment', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                            _statusPill(p.approvalStatus, sc),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (p.invoiceNumber != null) ...[
                              const Icon(Icons.receipt_long_outlined, size: 12, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Flexible(child: Text(p.invoiceNumber!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(4)),
                              child: Text(p.paymentMode, style: const TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(AppDateUtils.formatDisplay(p.paymentDate ?? p.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(CurrencyUtils.format(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: acting ? null : () => _reject(p),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: acting ? null : () => _approve(p),
                      icon: acting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusPill(String status, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}
