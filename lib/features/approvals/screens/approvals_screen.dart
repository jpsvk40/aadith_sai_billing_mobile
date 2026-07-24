import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/approval_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/approvals_provider.dart';

class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});
  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(approvalsProvider.notifier).load());
  }

  Future<void> _approve(ApprovalItem r) async {
    final err = await ref.read(approvalsProvider.notifier).approve(r);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Approved ${r.title}'),
      backgroundColor: err == null ? AppColors.success : AppColors.danger,
    ));
  }

  Future<void> _reject(ApprovalItem r) async {
    final comment = await _askComment('Reject ${r.docLabel}', 'Reason (optional)');
    if (comment == null) return;
    final err = await ref.read(approvalsProvider.notifier).reject(r, comment: comment.isEmpty ? null : comment);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? 'Rejected ${r.title}'),
      backgroundColor: AppColors.danger,
    ));
  }

  Future<String?> _askComment(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(approvalsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Approvals')),
      body: state.isLoading && state.items.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.items.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(approvalsProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () => ref.read(approvalsProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: state.items.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(state);
                      return _card(state.items[i - 1], state);
                    },
                  ),
                ),
    );
  }

  Widget _header(ApprovalsState s) {
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
              _summaryCard('AWAITING ME', '${s.awaitingMe}', AppColors.warning, Icons.fact_check_outlined),
              _summaryCard('PENDING', '${s.pending}', AppColors.primary, Icons.hourglass_empty),
              _summaryCard('ON HOLD', '${s.hold}', const Color(0xFF7C3AED), Icons.pause_circle_outline),
              _summaryCard('MY REQUESTS', '${s.mine}', AppColors.success, Icons.outbox_outlined),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                ('inbox', 'For Me'),
                ('all', 'All Open'),
                ('mine', 'My Requests'),
              ].map((f) {
                final sel = s.scope == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: sel,
                    onSelected: (_) => ref.read(approvalsProvider.notifier).setScope(f.$1),
                    labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? AppColors.primary : AppColors.textSecondary),
                    selectedColor: AppColors.primary.withValues(alpha: 0.14),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: sel ? AppColors.primary : AppColors.border),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const <(String?, String)>[
                (null, 'All'),
                ('PENDING', 'Pending'),
                ('HOLD', 'On Hold'),
                ('APPROVED', 'Approved'),
                ('REJECTED', 'Rejected'),
              ].map((f) {
                final sel = s.statusFilter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: sel,
                    onSelected: (_) => ref.read(approvalsProvider.notifier).setStatus(f.$1),
                    labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? AppColors.primaryDark : AppColors.textSecondary),
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: sel ? AppColors.primary : AppColors.border),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          if (s.items.isEmpty && !s.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(children: [
                  Icon(Icons.verified_outlined, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text('Nothing waiting for approval', style: TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.22)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
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

  IconData _docIcon(String docType) {
    switch (docType.toUpperCase()) {
      case 'PAYMENT':
        return Icons.payments_outlined;
      case 'PO':
      case 'PURCHASE_ORDER':
        return Icons.shopping_cart_outlined;
      case 'VOUCHER':
        return Icons.receipt_outlined;
      case 'ORDER':
        return Icons.receipt_long_outlined;
      case 'INVOICE':
        return Icons.description_outlined;
      default:
        return Icons.fact_check_outlined;
    }
  }

  Color _docColor(String docType) => docType.toUpperCase() == 'PAYMENT' ? AppColors.success : AppColors.warning;

  Widget _card(ApprovalItem r, ApprovalsState s) {
    final sc = _docColor(r.docLabel);
    final acting = s.actioningId == r.id;
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
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                  child: Icon(_docIcon(r.docLabel), color: sc, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(4)),
                          child: Text(r.docLabel, style: const TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w600)),
                        ),
                        if (r.subtitle != null && r.subtitle!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(child: Text(r.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                        ],
                      ]),
                      if (r.by != null && r.by!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text('by ${r.by}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (r.amount > 0)
                  Text(CurrencyUtils.format(r.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: acting ? null : () => _reject(r),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger), padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: acting ? null : () => _approve(r),
                    icon: acting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
