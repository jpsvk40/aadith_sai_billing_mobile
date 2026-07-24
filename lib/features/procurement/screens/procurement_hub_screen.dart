import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/procurement_models.dart';
import '../../../widgets/common/list_controls.dart';
import '../providers/procurement_providers.dart';
import '../widgets/procurement_list_view.dart';

/// Procurement hub — parity with the web `Procurement.jsx`:
/// Requisitions · RFQs & Quotes · Purchase Orders · Payment Requests, each a
/// list with a per-tab count. Requisitions can be created (New Requisition);
/// Payment Requests can be approved / held / rejected inline.
class ProcurementHubScreen extends ConsumerStatefulWidget {
  const ProcurementHubScreen({super.key});

  @override
  ConsumerState<ProcurementHubScreen> createState() => _ProcurementHubScreenState();
}

class _ProcurementHubScreenState extends ConsumerState<ProcurementHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() => ref.read(procurementHubProvider.notifier).load();

  Future<void> _openAndReload(String path) async {
    await context.push(path);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(procurementHubProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Procurement'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            _tab('Requisitions', state.requisitions?.length),
            _tab('RFQs & Quotes', state.rfqs?.length),
            _tab('Purchase Orders', state.purchaseOrders?.length),
            _tab('Payment Requests', state.paymentRequests?.length),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openAndReload('/procurement/requisitions/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Requisition'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _requisitionsTab(state),
          _rfqsTab(state),
          _purchaseOrdersTab(state),
          _paymentsTab(state),
        ],
      ),
    );
  }

  Widget _tab(String label, int? count) => Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ],
        ),
      );

  // ─────────────────────────── Requisitions ───────────────────────────
  Widget _requisitionsTab(ProcurementHubState s) {
    return ProcurementListView<Requisition>(
      items: s.requisitions,
      loading: s.isLoading,
      error: s.error,
      onRefresh: _reload,
      statusOf: (r) => r.status,
      searchMatches: (r, q) =>
          r.mrNumber.toLowerCase().contains(q) || (r.department ?? '').toLowerCase().contains(q),
      dateOf: (r) => r.requisitionDate,
      statusOptions: const ['DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'RFQ_CREATED', 'CLOSED'],
      sortOptions: const [SortSpec('date', 'Date'), SortSpec('mr', 'MR #')],
      sortValueOf: (r, key) => key == 'mr' ? r.mrNumber.toLowerCase() : r.requisitionDate,
      searchHint: 'Search MR #, department...',
      emptyText: 'No requisitions yet — tap New Requisition.',
      rowBuilder: (ctx, r) => _rowCard(
        icon: Icons.assignment_outlined,
        color: procStatusColor(r.status),
        title: r.mrNumber.isEmpty ? 'Requisition' : r.mrNumber,
        subtitle: [
          AppDateUtils.formatDisplay(r.requisitionDate),
          if ((r.department ?? '').isNotEmpty) r.department!,
          'Priority ${r.priority}',
        ].join('  ·  '),
        meta: '${r.items.length} item${r.items.length == 1 ? '' : 's'}',
        status: r.status,
        onTap: () => _openAndReload('/procurement/requisitions/${r.id}'),
      ),
    );
  }

  // ─────────────────────────── RFQs ───────────────────────────
  Widget _rfqsTab(ProcurementHubState s) {
    return ProcurementListView<Rfq>(
      items: s.rfqs,
      loading: s.isLoading,
      error: s.error,
      onRefresh: _reload,
      statusOf: (r) => r.status,
      searchMatches: (r, q) => r.rfqNumber.toLowerCase().contains(q),
      dateOf: (r) => r.rfqDate,
      statusOptions: const ['DRAFT', 'SENT', 'QUOTED', 'COMPARED', 'CLOSED', 'CANCELLED'],
      sortOptions: const [SortSpec('date', 'Date'), SortSpec('rfq', 'RFQ #')],
      sortValueOf: (r, key) => key == 'rfq' ? r.rfqNumber.toLowerCase() : r.rfqDate,
      searchHint: 'Search RFQ #...',
      emptyText: 'No RFQs yet — create one from an approved requisition on the web.',
      rowBuilder: (ctx, r) => _rowCard(
        icon: Icons.mark_email_read_outlined,
        color: procStatusColor(r.status),
        title: r.rfqNumber.isEmpty ? 'RFQ' : r.rfqNumber,
        subtitle: AppDateUtils.formatDisplay(r.rfqDate),
        meta: '${r.items.length} item·${r.vendors.length} vendor·${r.quotations.length} quote',
        status: r.status,
        onTap: () => context.push('/procurement/rfqs/${r.id}'),
      ),
    );
  }

  // ─────────────────────────── Purchase Orders ───────────────────────────
  Widget _purchaseOrdersTab(ProcurementHubState s) {
    return ProcurementListView<PurchaseOrder>(
      items: s.purchaseOrders,
      loading: s.isLoading,
      error: s.error,
      onRefresh: _reload,
      statusOf: (o) => o.status,
      searchMatches: (o, q) => o.poNumber.toLowerCase().contains(q),
      dateOf: (o) => o.poDate,
      statusOptions: const ['PENDING_APPROVAL', 'APPROVED', 'HOLD', 'REJECTED', 'SENT', 'CLOSED', 'CANCELLED'],
      sortOptions: const [SortSpec('date', 'Date'), SortSpec('amount', 'Amount')],
      sortValueOf: (o, key) => key == 'amount' ? o.totalAmount : o.poDate,
      searchHint: 'Search PO #...',
      emptyText: 'No purchase orders yet.',
      summaryBuilder: (rows) => _totalSummary(rows.length, 'order', rows.fold<double>(0, (a, o) => a + o.totalAmount)),
      rowBuilder: (ctx, o) => _rowCard(
        icon: Icons.inventory_2_outlined,
        color: procStatusColor(o.status),
        title: o.poNumber.isEmpty ? 'Purchase Order' : o.poNumber,
        subtitle: '${AppDateUtils.formatDisplay(o.poDate)}  ·  ${o.items.length} item${o.items.length == 1 ? '' : 's'}',
        meta: CurrencyUtils.format(o.totalAmount),
        status: o.status,
        onTap: () => context.push('/procurement/po/${o.id}'),
      ),
    );
  }

  // ─────────────────────────── Payment Requests ───────────────────────────
  Widget _paymentsTab(ProcurementHubState s) {
    return ProcurementListView<PaymentRequest>(
      items: s.paymentRequests,
      loading: s.isLoading,
      error: s.error,
      onRefresh: _reload,
      statusOf: (p) => p.status,
      searchMatches: (p, q) =>
          p.requestNumber.toLowerCase().contains(q) || p.paymentMode.toLowerCase().contains(q),
      dateOf: (p) => p.createdAt,
      statusOptions: const ['PENDING', 'APPROVED', 'HOLD', 'REJECTED', 'PAID'],
      sortOptions: const [SortSpec('date', 'Date'), SortSpec('amount', 'Amount')],
      sortValueOf: (p, key) => key == 'amount' ? p.amount : p.createdAt,
      searchHint: 'Search request #, mode...',
      emptyText: 'No payment requests yet.',
      summaryBuilder: (rows) => _totalSummary(rows.length, 'request', rows.fold<double>(0, (a, p) => a + p.amount)),
      rowBuilder: (ctx, p) => _paymentCard(p),
    );
  }

  // ─────────────────────────── shared row cards ───────────────────────────

  Widget _rowCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String meta,
    required String status,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary))),
                        ProcStatusPill(status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 3),
                    Text(meta, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentCard(PaymentRequest p) {
    final c = procStatusColor(p.status);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.requestNumber.isEmpty ? 'Payment Request' : p.requestNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Text('${AppDateUtils.formatDisplay(p.createdAt)}  ·  ${p.paymentMode}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyUtils.format(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    ProcStatusPill(p.status),
                  ],
                ),
              ],
            ),
            if (p.status == 'HOLD' && (p.holdReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('On hold: ${p.holdReason}', style: TextStyle(fontSize: 11.5, color: c, fontStyle: FontStyle.italic)),
            ],
            if (p.isActionable) ...[
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _prBtn('Approve & Pay', AppColors.success, () => _confirmPayment(p, 'approve')),
                  if (p.status == 'PENDING') ...[
                    const SizedBox(width: 8),
                    _prBtn('Hold', const Color(0xFF7C3AED), () => _confirmPayment(p, 'hold')),
                  ],
                  const SizedBox(width: 8),
                  _prBtn('Reject', AppColors.danger, () => _confirmPayment(p, 'reject')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _prBtn(String label, Color color, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  Widget _totalSummary(int count, String noun, double total) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
        child: Text(
          '$count $noun${count == 1 ? '' : 's'}  ·  ${CurrencyUtils.format(total)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      );

  Future<void> _confirmPayment(PaymentRequest p, String action) async {
    final label = action == 'approve'
        ? 'Approve & Pay'
        : action == 'hold'
            ? 'Hold'
            : 'Reject';
    final desc = action == 'approve'
        ? 'This disburses ${CurrencyUtils.format(p.amount)} to the vendor and settles the bill.'
        : action == 'hold'
            ? 'Put this payment request on hold.'
            : 'Reject this payment request.';
    final color = action == 'approve'
        ? AppColors.success
        : action == 'hold'
            ? const Color(0xFF7C3AED)
            : AppColors.danger;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label — ${p.requestNumber}'),
        content: Text(desc),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: color),
            child: Text(label),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(procurementHubProvider.notifier).paymentAction(p.id, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label done for ${p.requestNumber}.'), backgroundColor: color),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_msg(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  String _msg(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }
}
