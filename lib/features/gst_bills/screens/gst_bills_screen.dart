import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/pdf_share.dart';
import '../../../data/models/gst_bill_model.dart';
import '../../../data/providers/financial_year_provider.dart';
import '../../../widgets/common/empty_state_widget.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/gst_bills_provider.dart';

const _amber = Color(0xFFF59E0B);
const _cyan = Color(0xFF0891B2);

/// GST Bills — mobile parity with the web GstBillsPage. GST split invoices /
/// standalone GST invoices with status chips, a filter sheet (period / date /
/// financial year / legal entity), summary KPIs over the filtered set, a
/// by-entity grouped view, and per-bill actions (void / restore, assign GST #,
/// e-Invoice & e-Way JSON export). Tapping a bill opens the shared invoice detail.
class GstBillsScreen extends ConsumerStatefulWidget {
  const GstBillsScreen({super.key});

  @override
  ConsumerState<GstBillsScreen> createState() => _GstBillsScreenState();
}

class _GstBillsScreenState extends ConsumerState<GstBillsScreen> {
  String? _selectedStatus; // null = All; else Unpaid | Partial | Paid | Cancelled
  String _search = '';
  final _searchCtrl = TextEditingController();

  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;
  bool _groupByEntity = false;
  bool _sandbox = true;
  bool _busy = false;
  final Set<String> _collapsed = {}; // entity group keys currently collapsed

  static const _statuses = ['All', 'Unpaid', 'Partial', 'Paid', 'Cancelled'];
  static const _sortOptions = <SortSpec>[
    SortSpec('date', 'Date'),
    SortSpec('total', 'Total'),
    SortSpec('gst', 'GST'),
    SortSpec('balance', 'Balance'),
    SortSpec('customer', 'Customer'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ──

  String? get _statusParam {
    switch (_selectedStatus) {
      case null:
        return null;
      case 'Cancelled':
        return 'Voided'; // server key for cancelled bills
      default:
        return _selectedStatus;
    }
  }

  Future<void> _reload() {
    final f = _filters;
    final hasPeriod = f.period != null;
    return ref.read(gstBillsProvider.notifier).load(
          status: _statusParam,
          period: f.period,
          dateFrom: hasPeriod ? null : f.dateFromParam,
          dateTo: hasPeriod ? null : f.dateToParam,
          financialYearId: f.financialYearId,
        );
  }

  Future<void> _openFilters() async {
    final loaded = ref.read(gstBillsProvider).bills;
    final entityOptions = loaded.map((b) => b.entityLabel).toSet().toList()..sort();
    final fy = await ref.read(financialYearsProvider.future);
    if (!mounted) return;
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      financialYears: fy.years,
      selects: entityOptions.length > 1
          ? [SelectFilter(key: 'entity', label: 'Legal Entity', options: entityOptions)]
          : const [],
    );
    if (res != null) {
      setState(() => _filters = res);
      _reload();
    }
  }

  Comparable? _sortValue(GstBill b, String key) {
    switch (key) {
      case 'date':
        return b.invoiceDate ?? '';
      case 'total':
        return b.grandTotal;
      case 'gst':
        return b.gstTotal;
      case 'balance':
        return b.balanceAmount;
      case 'customer':
        return (b.customerName ?? '').toLowerCase();
    }
    return null;
  }

  List<GstBill> _visible(List<GstBill> all) {
    var list = all;
    final entity = _filters.select('entity');
    if (entity != null && entity.isNotEmpty) {
      list = list.where((b) => b.entityLabel == entity).toList();
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((b) =>
              (b.displayInvoiceNo ?? '').toLowerCase().contains(q) ||
              (b.customerName ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (_sort != null) list = applySort(list, _sort!, _sortValue);
    return list;
  }

  bool _canAssignGst() {
    final role = ref.read(authProvider).user?.effectiveRole ?? '';
    return const {'admin', 'super_admin', 'super_user'}.contains(role);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    ref.watch(financialYearsProvider); // warm + cache FY list for the filter sheet
    final state = ref.watch(gstBillsProvider);
    final visible = _visible(state.bills);
    final canAssign = _canAssignGst();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('GST Bills'),
        actions: [
          IconButton(
            tooltip: _groupByEntity ? 'Flat list' : 'Group by entity',
            icon: Icon(_groupByEntity ? Icons.view_list_outlined : Icons.apartment_outlined),
            onPressed: () => setState(() => _groupByEntity = !_groupByEntity),
          ),
        ],
      ),
      body: state.isLoading && state.bills.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.bills.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: _reload)
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 28),
                    children: [
                      _header(state.summary, visible),
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 36),
                          child: EmptyStateWidget(
                            message: 'No GST bills found',
                            icon: Icons.receipt_long_outlined,
                          ),
                        )
                      else if (_groupByEntity)
                        ..._buildGroups(visible, canAssign)
                      else
                        ...visible.map((b) => _billCard(b, canAssign)),
                    ],
                  ),
                ),
    );
  }

  Widget _header(GstBillSummary? summary, List<GstBill> visible) {
    final count = visible.length;
    final taxable = visible.fold<double>(0, (a, b) => a + b.taxable);
    final gst = visible.fold<double>(0, (a, b) => a + b.gstTotal);
    final total = visible.fold<double>(0, (a, b) => a + b.grandTotal);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
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
              _summaryCard('BILLS', '$count', AppColors.primary, Icons.receipt_long_outlined),
              _summaryCard('TAXABLE', CurrencyUtils.formatCompact(taxable), _cyan, Icons.request_quote_outlined),
              _summaryCard('GST', CurrencyUtils.formatCompact(gst), _amber, Icons.account_balance_outlined),
              _summaryCard('TOTAL', CurrencyUtils.formatCompact(total), AppColors.success, Icons.summarize_outlined),
            ],
          ),
          const SizedBox(height: 14),
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
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    )
                  : null,
            ),
          ),
          FilterSortButtons(
            activeFilterCount: _filters.activeCount,
            onFilterTap: _openFilters,
            sortOptions: _sortOptions,
            currentSort: _sort,
            onSortChanged: (s) => setState(() => _sort = s),
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _statuses.map((f) {
                final sel = (f == 'All' && _selectedStatus == null) || f == _selectedStatus;
                final c = _chipColor(f);
                final n = _chipCount(f, summary);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(n == null ? f : '$f · $n'),
                    selected: sel,
                    onSelected: (_) {
                      setState(() => _selectedStatus = f == 'All' ? null : f);
                      _reload();
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
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Sandbox GSTINs for JSON export', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              Switch.adaptive(value: _sandbox, onChanged: (v) => setState(() => _sandbox = v)),
            ],
          ),
        ],
      ),
    );
  }

  int? _chipCount(String f, GstBillSummary? s) {
    if (s == null) return null;
    switch (f) {
      case 'All':
        return s.totalCount;
      case 'Unpaid':
        return s.unpaidCount;
      case 'Partial':
        return s.partialCount;
      case 'Paid':
        return s.paidCount;
      case 'Cancelled':
        return s.voidedCount;
    }
    return null;
  }

  Color _chipColor(String f) {
    switch (f) {
      case 'Paid':
        return AppColors.success;
      case 'Unpaid':
        return AppColors.danger;
      case 'Partial':
        return _amber;
      case 'Cancelled':
        return AppColors.textMuted;
      default:
        return AppColors.primary;
    }
  }

  Color _statusPillColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'Paid':
        return AppColors.success;
      case 'Partial':
        return _amber;
      case 'Unpaid':
        return AppColors.danger;
      default:
        return AppColors.info;
    }
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

  // ── Bill card ──

  Widget _billCard(GstBill b, bool canAssign, {EdgeInsets? margin}) {
    final sc = _statusPillColor(b.paymentStatus);
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Opacity(
        opacity: b.isVoided ? 0.62 : 1,
        child: InkWell(
          onTap: b.id == null ? null : () => context.go('/invoices/${b.id}'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 6, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.displayInvoiceNo ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _pill(b.paymentStatus, sc),
                    _actionsMenu(b, canAssign),
                  ],
                ),
                if (b.isVoided)
                  const Padding(
                    padding: EdgeInsets.only(right: 7, bottom: 2),
                    child: Text('CANCELLED · excluded from GST returns', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (b.customerName != null)
                        Text(
                          (b.customerCity != null && b.customerCity!.isNotEmpty) ? '${b.customerName}  ·  ${b.customerCity}' : b.customerName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      if (b.legalEntityName != null) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.apartment_outlined, size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                (b.legalEntityGstin != null && b.legalEntityGstin!.isNotEmpty) ? '${b.legalEntityName}  ·  ${b.legalEntityGstin}' : b.legalEntityName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 9),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _metric('GST', CurrencyUtils.format(b.gstTotal), AppColors.textSecondary),
                          const SizedBox(width: 16),
                          _metric('TOTAL', CurrencyUtils.format(b.grandTotal), AppColors.textPrimary, bold: true),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('BALANCE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: AppColors.textMuted)),
                              Text(
                                CurrencyUtils.format(b.balanceAmount),
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: b.balanceAmount > 0 ? AppColors.danger : AppColors.success),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(AppDateUtils.formatDisplay(b.invoiceDate), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                          if (b.displayParentInvoiceNo != null && b.displayParentInvoiceNo!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Collection: ${b.displayParentInvoiceNo}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: AppColors.textMuted)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _actionsMenu(GstBill b, bool canAssign) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
      onSelected: (v) => _onAction(v, b),
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'einvoice', child: _menuChild(Icons.download_outlined, 'e-Invoice JSON')),
        PopupMenuItem(
          value: 'eway',
          enabled: b.ewayEligible && !b.isVoided,
          child: _menuChild(Icons.local_shipping_outlined, b.ewayEligible ? 'e-Way Bill JSON' : 'e-Way JSON (≥ ₹50k)'),
        ),
        if (canAssign && b.gstNumberAssignable)
          PopupMenuItem(value: 'assign', child: _menuChild(Icons.confirmation_number_outlined, 'Assign GST #')),
        if (b.isVoided)
          PopupMenuItem(value: 'unvoid', child: _menuChild(Icons.restore, 'Restore'))
        else
          PopupMenuItem(value: 'void', child: _menuChild(Icons.cancel_outlined, 'Void', danger: true)),
      ],
    );
  }

  Widget _menuChild(IconData icon, String label, {bool danger = false}) {
    final c = danger ? AppColors.danger : AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: danger ? AppColors.danger : AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13.5, color: c)),
      ],
    );
  }

  // ── By-entity grouped view ──

  List<Widget> _buildGroups(List<GstBill> bills, bool canAssign) {
    final Map<String, List<GstBill>> groups = {};
    for (final b in bills) {
      groups.putIfAbsent(b.entityLabel, () => []).add(b);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) {
        final ta = a.value.fold<double>(0, (s, x) => s + x.grandTotal);
        final tb = b.value.fold<double>(0, (s, x) => s + x.grandTotal);
        return tb.compareTo(ta);
      });
    return entries.map((e) => _entityGroup(e.key, e.value, canAssign)).toList();
  }

  Widget _entityGroup(String name, List<GstBill> items, bool canAssign) {
    final gstin = items.first.legalEntityGstin;
    final total = items.fold<double>(0, (s, x) => s + x.grandTotal);
    final balance = items.fold<double>(0, (s, x) => s + x.balanceAmount);
    final collapsed = _collapsed.contains(name);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => collapsed ? _collapsed.remove(name) : _collapsed.add(name)),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _cyan)),
                        if (gstin != null && gstin.isNotEmpty) Text(gstin, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(CurrencyUtils.format(total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      if (balance > 0) Text('Bal ${CurrencyUtils.formatCompact(balance)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                      Text('${items.length} bill${items.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed) ...[
            const Divider(height: 1),
            ...items.map((b) => _billCard(b, canAssign, margin: const EdgeInsets.fromLTRB(8, 8, 8, 4))),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  // ── Actions ──

  void _onAction(String action, GstBill b) {
    switch (action) {
      case 'einvoice':
        _export(b, eway: false);
        break;
      case 'eway':
        _export(b, eway: true);
        break;
      case 'assign':
        _confirmAssign(b);
        break;
      case 'void':
        _confirmVoid(b);
        break;
      case 'unvoid':
        _confirmUnvoid(b);
        break;
    }
  }

  Future<void> _confirmVoid(GstBill b) async {
    if (b.id == null) return;
    final ok = await _confirm('Void GST bill?', 'It will be excluded from GST returns.', 'Void', danger: true);
    if (!ok) return;
    await _runMutation(() => ref.read(gstBillsProvider.notifier).voidBill(b.id!), success: 'Bill voided');
  }

  Future<void> _confirmUnvoid(GstBill b) async {
    if (b.id == null) return;
    final ok = await _confirm('Restore GST bill?', 'It will be included in GST returns again.', 'Restore');
    if (!ok) return;
    await _runMutation(() => ref.read(gstBillsProvider.notifier).unvoidBill(b.id!), success: 'Bill restored');
  }

  Future<void> _confirmAssign(GstBill b) async {
    if (b.id == null) return;
    final ok = await _confirm(
      'Assign GST number?',
      'Takes the next number in the series, which may be out of date order for an earlier-period bill.',
      'Assign',
    );
    if (!ok || _busy || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final no = await ref.read(gstBillsProvider.notifier).assignGstNumber(b.id!);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(no != null ? 'GST number assigned: $no' : 'GST number assigned')));
      await _reload();
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(_errText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runMutation(Future<void> Function() op, {required String success}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(success)));
      await _reload();
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(_errText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(GstBill b, {required bool eway}) async {
    if (_busy || b.id == null) return;
    setState(() => _busy = true);
    final origin = shareOriginFor(context); // capture before await (iOS anchor)
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(gstBillRepositoryProvider);
      final res = eway
          ? await repo.exportEwayBill(b.id!, sandbox: _sandbox)
          : await repo.exportEinvoice(b.id!, sandbox: _sandbox);
      if (!mounted) return;
      final label = eway ? 'e-Way Bill' : 'e-Invoice';
      final base = eway ? 'eway-bill' : 'einvoice';
      final msg = res.warnings.isEmpty
          ? '$label JSON ready · ${res.docNo}'
          : '$label JSON ready · ${res.warnings.length} warning(s)';
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () {
            Share.share(
              const JsonEncoder.withIndent('  ').convert(res.payload),
              subject: '$base-${_sandbox ? 'sandbox-' : ''}${res.docNo}.json',
              sharePositionOrigin: origin,
            );
          },
        ),
      ));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(_errText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String confirmLabel, {bool danger = false}) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: danger ? AppColors.danger : AppColors.primary),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  String _errText(Object e) => e is AppException ? e.message : e.toString();
}
