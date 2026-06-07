import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/invoice_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/invoice_list_provider.dart';

const _invOrange = Color(0xFFF59E0B);

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key, this.initialStatus});
  final String? initialStatus;

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String? _selectedStatus;
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _statuses = ['All', 'Unpaid', 'Partial', 'Paid', 'Overdue'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(invoiceListProvider.notifier).load(status: _selectedStatus));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Invoice> _filtered(List<Invoice> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((i) =>
        i.invoiceNumber.toLowerCase().contains(q) || (i.customerName ?? '').toLowerCase().contains(q)).toList();
  }

  Color _statusColor(Invoice i) {
    if (i.isOverdue) return AppColors.danger;
    switch (i.status) {
      case 'Paid':
        return AppColors.success;
      case 'Partial':
        return _invOrange;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceListProvider);
    final visible = _filtered(state.invoices);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Invoices')),
      body: state.isLoading && state.invoices.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.invoices.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(invoiceListProvider.notifier).load(status: _selectedStatus))
              : RefreshIndicator(
                  onRefresh: () => ref.read(invoiceListProvider.notifier).load(status: _selectedStatus),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: visible.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(state, visible.length);
                      return _invoiceCard(visible[i - 1]);
                    },
                  ),
                ),
    );
  }

  Widget _header(InvoiceListState s, int shown) {
    final outstanding = s.invoices.fold<double>(0, (a, i) => a + (i.outstandingAmount ?? 0));
    final overdue = s.invoices.where((i) => i.isOverdue).length;
    final paid = s.invoices.where((i) => i.status == 'Paid').length;

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
              _summaryCard('OUTSTANDING', CurrencyUtils.format(outstanding), _invOrange, Icons.account_balance_wallet_outlined),
              _summaryCard('OVERDUE', '$overdue', AppColors.danger, Icons.schedule),
              _summaryCard('PAID', '$paid', AppColors.success, Icons.verified_outlined),
              _summaryCard('ENTRIES SHOWN', '$shown', AppColors.primary, Icons.list_alt_outlined),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search invoice, customer...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
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
                final sel = (f == 'All' && _selectedStatus == null) || f == _selectedStatus;
                final c = f == 'All'
                    ? AppColors.primary
                    : f == 'Paid'
                        ? AppColors.success
                        : f == 'Overdue'
                            ? AppColors.danger
                            : f == 'Partial'
                                ? _invOrange
                                : AppColors.info;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: sel,
                    onSelected: (_) {
                      setState(() => _selectedStatus = f == 'All' ? null : f);
                      ref.read(invoiceListProvider.notifier).load(status: _selectedStatus);
                    },
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

  Widget _invoiceCard(Invoice inv) {
    final sc = _statusColor(inv);
    final label = inv.isOverdue ? 'OVERDUE' : inv.status.toUpperCase();
    final due = inv.outstandingAmount ?? 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () => context.go('/invoices/${inv.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.description_outlined, color: sc, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(inv.invoiceNumber, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                        _pill(label, sc),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (inv.customerName != null)
                      Text(inv.customerName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 3),
                    Text(AppDateUtils.formatDisplay(inv.invoiceDate), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyUtils.format(inv.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                  if (due > 0)
                    Text('Due ${CurrencyUtils.formatCompact(due)}', style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
    );
  }
}
