import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/vendor_purchase_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../purchase_bill_scan.dart';
import '../providers/purchase_list_provider.dart';

const _pOrange = Color(0xFFF59E0B);
const _pPurple = Color(0xFF7C3AED);

const _statuses = <(String, String)>[
  ('All', 'All'),
  ('PENDING', 'Pending'),
  ('PARTIALLY_PAID', 'Partial'),
  ('PAID', 'Paid'),
  ('CANCELLED', 'Cancelled'),
];

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});
  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(purchaseListProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<VendorPurchase> _filtered(PurchaseListState s) {
    final q = s.search.trim().toLowerCase();
    return s.purchases.where((p) {
      if (s.statusFilter != 'All' && p.status != s.statusFilter) return false;
      if (q.isEmpty) return true;
      return p.purchaseNumber.toLowerCase().contains(q) ||
          (p.vendorName ?? '').toLowerCase().contains(q) ||
          (p.invoiceNumber ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'PAID':
        return AppColors.success;
      case 'PARTIALLY_PAID':
        return _pOrange;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return const Color(0xFFEAB308); // PENDING
    }
  }

  String _statusLabel(String s) => s.replaceAll('_', ' ');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseListProvider);
    final visible = _filtered(state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          IconButton(
            tooltip: 'Scan bill (AI)',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => launchBillScan(context, ref),
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: () => context.push('/purchases/create')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'newPurchase',
        onPressed: () => context.push('/purchases/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Purchase'),
        backgroundColor: AppColors.primary,
      ),
      body: state.isLoading && state.purchases.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.purchases.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(purchaseListProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () => ref.read(purchaseListProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: visible.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(state, visible);
                      return _purchaseCard(visible[i - 1]);
                    },
                  ),
                ),
    );
  }

  Widget _header(PurchaseListState s, List<VendorPurchase> visible) {
    final total = s.purchases.fold<double>(0, (a, p) => a + p.totalAmount);
    final paid = s.purchases.fold<double>(0, (a, p) => a + p.paidAmount);
    final outstanding = s.purchases.fold<double>(0, (a, p) => a + p.outstandingAmount);

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
              _summaryCard('TOTAL PURCHASES', '${s.purchases.length}', AppColors.primary, Icons.shopping_bag_outlined),
              _summaryCard('TOTAL AMOUNT', CurrencyUtils.formatCompact(total), _pPurple, Icons.receipt_long_outlined),
              _summaryCard('TOTAL PAID', CurrencyUtils.formatCompact(paid), AppColors.success, Icons.verified_outlined),
              _summaryCard('OUTSTANDING', CurrencyUtils.formatCompact(outstanding), AppColors.danger, Icons.account_balance_wallet_outlined),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(purchaseListProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              hintText: 'Purchase #, invoice #, vendor...',
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
                      ref.read(purchaseListProvider.notifier).setSearch('');
                    })
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _statuses.map((f) {
                final sel = s.statusFilter == f.$1;
                final c = f.$1 == 'All' ? AppColors.primary : _statusColor(f.$1);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: sel,
                    onSelected: (_) => ref.read(purchaseListProvider.notifier).setStatus(f.$1),
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
          if (visible.isEmpty && !s.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('No purchases found', style: TextStyle(color: AppColors.textMuted))),
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

  Widget _purchaseCard(VendorPurchase p) {
    final sc = _statusColor(p.status);
    final due = p.outstandingAmount;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.shopping_bag_outlined, color: sc, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(p.purchaseNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      _pill(_statusLabel(p.status), sc),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (p.vendorName != null)
                    Text(p.vendorName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (p.invoiceNumber != null) ...[
                        const Icon(Icons.receipt_long_outlined, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Flexible(child: Text(p.invoiceNumber!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
                        const SizedBox(width: 8),
                      ],
                      Text(AppDateUtils.formatDisplay(p.purchaseDate ?? p.invoiceDate), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyUtils.format(p.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                if (due > 0)
                  Text('Due ${CurrencyUtils.formatCompact(due)}', style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
      );
}
