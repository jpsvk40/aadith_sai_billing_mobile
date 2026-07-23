import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/customer_trace_model.dart';
import '../../../data/repositories/insights_repository.dart';
import '../providers/insights_providers.dart';
import '../widgets/insight_ui.dart';

/// Customer Trace — parity with the web BusinessTracePage "Customer Trace" panel.
/// Pick a customer (typeahead), pick a comparison period, then read their profile,
/// risk flags, KPI summary, service history, orders/invoices, payments, products,
/// missing usuals and returns. Gate: `business_trace` module (handled by route guard).
class CustomerTraceScreen extends ConsumerStatefulWidget {
  final String? initialCustomerId;
  final String? initialCustomerName;
  const CustomerTraceScreen({super.key, this.initialCustomerId, this.initialCustomerName});
  @override
  ConsumerState<CustomerTraceScreen> createState() => _CustomerTraceScreenState();
}

class _CustomerTraceScreenState extends ConsumerState<CustomerTraceScreen> {
  String? _customerId;
  String? _customerName;
  String _mode = 'last_30_days';
  String _orderTab = 'orders'; // 'orders' | 'invoices'

  @override
  void initState() {
    super.initState();
    _customerId = widget.initialCustomerId;
    _customerName = widget.initialCustomerName;
  }

  String _money(num v) => CurrencyUtils.format(v);
  String _date(String? v) => AppDateUtils.formatDisplay(v);
  String _pct(double v, {int digits = 0}) => '${(v * 100).toStringAsFixed(digits)}%';

  Future<void> _pickCustomer() async {
    final chosen = await showModalBottomSheet<CustomerSuggestion>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CustomerTracePicker(repo: ref.read(insightsRepositoryProvider)),
    );
    if (chosen != null) {
      setState(() {
        _customerId = chosen.id;
        _customerName = chosen.customerName;
        _orderTab = 'orders';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Customer Trace')),
      body: _customerId == null ? _prompt() : _selectedBody(),
    );
  }

  Widget _prompt() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.person_search_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Text('Select a customer to trace their buying history, payments, and patterns.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(onPressed: _pickCustomer, icon: const Icon(Icons.search), label: const Text('Select customer')),
          ]),
        ),
      );

  Widget _selectedBody() {
    return Column(
      children: [
        _controls(),
        const Divider(height: 1),
        Expanded(child: _traceBody()),
      ],
    );
  }

  Widget _controls() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_customerName ?? 'Customer',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          _periodDropdown(),
          TextButton(onPressed: _pickCustomer, child: const Text('Change')),
        ]),
      );

  Widget _periodDropdown() => DropdownButton<String>(
        value: _mode,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        items: kComparisonPeriods.map((p) => DropdownMenuItem(value: p.value, child: Text(p.label))).toList(),
        onChanged: (v) => setState(() => _mode = v ?? 'last_30_days'),
      );

  Widget _traceBody() {
    final async = ref.watch(customerTraceProvider((id: _customerId!, mode: _mode)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
        const SizedBox(height: 12),
        Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
      ]),
      data: (t) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(customerTraceProvider((id: _customerId!, mode: _mode))),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _profileCard(t),
            _riskFlags(t),
            _summary(t),
            if (t.service != null) _serviceSection(t.service!),
            _ordersInvoices(t),
            _payments(t),
            _products(t),
            _missingProducts(t),
            _returns(t),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Profile ──────────────────────────────────────────────────────────────
  Widget _profileCard(CustomerTrace t) {
    final c = t.customer;
    final title = c.customerNameTa != null && c.customerNameTa!.isNotEmpty ? '${c.customerName} / ${c.customerNameTa}' : c.customerName;
    return InsightSection(
      title: title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          _field('Code', c.customerCode ?? '—'),
          _field('Phone', c.phone ?? '—'),
          if (c.whatsappContact != null && c.whatsappContact!.isNotEmpty) _field('WhatsApp', c.whatsappContact!),
          _field('City', c.city ?? '—'),
          if (c.district != null && c.district!.isNotEmpty) _field('District', c.district!),
          _field('GSTIN', c.gstin ?? '—'),
          _field('Credit Limit', c.creditLimit > 0 ? _money(c.creditLimit) : 'None'),
          _field('Payment Terms', c.paymentTermsDays > 0 ? '${c.paymentTermsDays} days' : 'Not set'),
          _field('Status', c.isActive ? 'Active' : 'Inactive', valueColor: c.isActive ? null : AppColors.danger),
          if (t.representative != null)
            _field('Sales Rep', '${t.representative!.name}${t.representative!.phone != null ? ' · ${t.representative!.phone}' : ''}'),
        ]),
        if (t.period.periodLabel.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Period: ${t.period.periodLabel}'
            '${t.period.currentPeriodStart != null ? ' · Current ${t.period.currentPeriodStart} – ${t.period.currentPeriodEnd}' : ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ]),
    );
  }

  Widget _field(String label, String value, {Color? valueColor}) => SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary)),
        ]),
      );

  // ── Risk flags ───────────────────────────────────────────────────────────
  Widget _riskFlags(CustomerTrace t) {
    if (t.riskFlags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: t.riskFlags
            .map((rf) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.danger.withValues(alpha: 0.35))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Text(rf.message, style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w700)),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  // ── Summary KPIs ─────────────────────────────────────────────────────────
  Widget _summary(CustomerTrace t) {
    final s = t.summary;
    final cad = cadenceStyle(s.cadenceStatus);
    final everyDays = s.medianDaysBetweenOrders ?? s.avgDaysBetweenOrders;
    return InsightSection(
      title: 'Summary',
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        SummaryTile(label: 'Total Orders', value: '${s.totalOrders}', sub: '${s.currentOrders} current · ${s.priorOrders} prior'),
        SummaryTile(label: 'Revenue (Current)', value: _money(s.currentInvoiceValue)),
        SummaryTile(label: 'Revenue (Prior)', value: _money(s.priorInvoiceValue)),
        SummaryTile(label: 'Avg Order Value', value: _money(s.averageOrderValue)),
        SummaryTile(
          label: 'Outstanding',
          value: _money(s.outstandingBalance),
          sub: s.overdueBalance > 0 ? 'Overdue: ${_money(s.overdueBalance)}' : 'No overdue',
          valueColor: s.outstandingBalance > 0 ? AppColors.danger : null,
        ),
        SummaryTile(
          label: 'Buying Cadence',
          value: cad.label,
          valueColor: cad.color,
          sub: everyDays != null && everyDays > 0 ? 'Every ~${everyDays.toStringAsFixed(0)}d' : null,
        ),
        SummaryTile(
          label: 'On-Time Payments',
          value: s.onTimePaymentRatio != null ? _pct(s.onTimePaymentRatio!) : 'N/A',
          sub: s.avgPaymentDelayDays != null ? 'Avg delay ${s.avgPaymentDelayDays!.toStringAsFixed(0)}d' : null,
        ),
        SummaryTile(
          label: 'Return Ratio',
          value: _pct(s.returnOrderRatio, digits: 1),
          sub: '${s.returnTotal} return order${s.returnTotal == 1 ? '' : 's'}',
        ),
        if (s.cancelledInvoiceCount > 0)
          SummaryTile(label: 'Cancelled Invoices', value: '${s.cancelledInvoiceCount}', sub: 'Not in return ratio'),
        if (s.expectedNextOrderDate != null)
          SummaryTile(
            label: 'Expected Next Order',
            value: _date(s.expectedNextOrderDate),
            sub: s.daysOverdueForCadence > 0 ? '${s.daysOverdueForCadence}d overdue' : null,
            valueColor: s.daysOverdueForCadence > 0 ? AppColors.danger : null,
          ),
      ]),
    );
  }

  // ── Service & Maintenance ─────────────────────────────────────────────────
  Widget _serviceSection(TraceService svc) {
    final st = svc.stats;
    return InsightSection(
      title: 'Service & Maintenance',
      count: st.totalTickets,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          SummaryTile(label: 'Service Jobs', value: '${st.totalTickets}', sub: '${st.openTickets} open'),
          SummaryTile(label: 'Rework', value: '${st.reworkTickets}', sub: st.deliveredTickets > 0 ? '${_pct(st.repeatRepairRate)} rate' : 'No delivered jobs'),
          SummaryTile(label: 'Service Revenue', value: _money(st.totalServiceRevenue)),
          SummaryTile(label: 'Service Outstanding', value: _money(st.serviceOutstanding)),
          SummaryTile(label: 'Warranty Units', value: '${st.warrantyItems}', sub: '${st.activeWarrantyItems} active'),
          SummaryTile(label: 'AMC / Contracts', value: '${st.amcContracts}', sub: '${st.activeAmc} active'),
          if (st.lastServiceDate != null) SummaryTile(label: 'Last Service', value: _date(st.lastServiceDate)),
        ]),
        const SizedBox(height: 12),
        MiniTable(
          emptyText: 'No service history for this customer.',
          columns: const [
            MiniCol('Ticket', 110),
            MiniCol('Problem', 150),
            MiniCol('Status', 110),
            MiniCol('Reported', 100),
            MiniCol('Charge', 90, numeric: true),
          ],
          rows: svc.recentTickets
              .map((tk) => [
                    tcell(tk.ticketNumber ?? '—', weight: FontWeight.w700, color: AppColors.primary),
                    tcell(tk.reportedProblem ?? '—'),
                    tcell((tk.status ?? '—').replaceAll('_', ' ')),
                    tcell(_date(tk.reportedAt)),
                    tcell(tk.isChargeable ? _money(tk.totalCharge) : 'Warranty', numeric: false),
                  ])
              .toList(),
        ),
      ]),
    );
  }

  // ── Orders & Invoices (toggle) ─────────────────────────────────────────────
  Widget _ordersInvoices(CustomerTrace t) {
    final isOrders = _orderTab == 'orders';
    return InsightSection(
      title: 'Orders & Invoices',
      count: isOrders ? t.orderRows.length : t.invoiceRows.length,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _toggleBtn('Orders', isOrders, () => setState(() => _orderTab = 'orders')),
          const SizedBox(width: 8),
          _toggleBtn('Invoices', !isOrders, () => setState(() => _orderTab = 'invoices')),
        ]),
        const SizedBox(height: 10),
        if (isOrders)
          MiniTable(
            emptyText: 'No orders in this window.',
            columns: const [
              MiniCol('Order #', 110),
              MiniCol('Date', 100),
              MiniCol('Status', 100),
              MiniCol('Total', 100, numeric: true),
              MiniCol('Balance', 100, numeric: true),
              MiniCol('Payment', 100),
              MiniCol('Invoices', 130),
            ],
            rows: t.orderRows
                .map((o) => [
                      tcell(o.orderNo ?? '—', weight: FontWeight.w700),
                      tcell(_date(o.orderDate)),
                      tcell(o.orderStatus ?? '—'),
                      tcell(_money(o.grandTotal), numeric: true),
                      tcell(_money(o.balanceAmount), numeric: true, color: o.balanceAmount > 0 ? AppColors.danger : null),
                      tcell(o.paymentStatus ?? '—'),
                      tcell(o.invoiceNos.isEmpty ? '—' : o.invoiceNos.join(', ')),
                    ])
                .toList(),
          )
        else
          MiniTable(
            emptyText: 'No invoices in this window.',
            columns: const [
              MiniCol('Invoice #', 110),
              MiniCol('Date', 100),
              MiniCol('Due', 100),
              MiniCol('Status', 90),
              MiniCol('Payment', 100),
              MiniCol('Total', 100, numeric: true),
              MiniCol('Paid', 100, numeric: true),
              MiniCol('Balance', 100, numeric: true),
            ],
            rows: t.invoiceRows
                .map((inv) => [
                      tcell(inv.invoiceNo ?? '—', weight: FontWeight.w700),
                      tcell(_date(inv.invoiceDate)),
                      tcell(_date(inv.dueDate)),
                      tcell(inv.status ?? '—'),
                      tcell(inv.paymentStatus ?? '—'),
                      tcell(_money(inv.grandTotal), numeric: true),
                      tcell(_money(inv.paidAmount), numeric: true),
                      tcell(_money(inv.balanceAmount), numeric: true, color: inv.balanceAmount > 0 ? AppColors.danger : null),
                    ])
                .toList(),
          ),
      ]),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? AppColors.primary : AppColors.border),
          ),
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary)),
        ),
      );

  // ── Payments ────────────────────────────────────────────────────────────
  Widget _payments(CustomerTrace t) => InsightSection(
        title: 'Payment Behaviour',
        count: t.paymentRows.length,
        child: MiniTable(
          emptyText: 'No payment records found.',
          columns: const [
            MiniCol('Date', 100),
            MiniCol('Invoice', 120),
            MiniCol('Amount', 110, numeric: true),
            MiniCol('Mode', 110),
            MiniCol('Delay', 100, numeric: true),
          ],
          rows: t.paymentRows.map((p) {
            Widget delay;
            if (p.delayDays == null) {
              delay = tcell('—', numeric: true, color: AppColors.textMuted);
            } else if (p.delayDays! > 0) {
              delay = tcell('+${p.delayDays!.toStringAsFixed(0)}d late', numeric: true, color: AppColors.danger, weight: FontWeight.w700);
            } else {
              delay = tcell('On time', numeric: true, color: AppColors.success);
            }
            return [
              tcell(_date(p.paymentDate)),
              tcell(p.invoiceNo ?? '—'),
              tcell(_money(p.amount), numeric: true),
              tcell(p.paymentMode ?? '—'),
              delay,
            ];
          }).toList(),
        ),
      );

  // ── Products bought ───────────────────────────────────────────────────────
  Widget _products(CustomerTrace t) => InsightSection(
        title: 'Products Bought',
        count: t.productRows.length,
        child: MiniTable(
          emptyText: 'No products bought in this window.',
          columns: const [
            MiniCol('Product', 160),
            MiniCol('Unit', 70),
            MiniCol('Qty', 90, numeric: true),
            MiniCol('Revenue', 110, numeric: true),
            MiniCol('Avg Rate', 100, numeric: true),
            MiniCol('Last Bought', 110),
          ],
          rows: t.productRows
              .map((p) => [
                    tcell(p.productName, weight: FontWeight.w700),
                    tcell(p.unit ?? '—'),
                    tcell(p.quantity.toStringAsFixed(2), numeric: true),
                    tcell(_money(p.revenue), numeric: true),
                    tcell(_money(p.avgRate), numeric: true),
                    tcell(_date(p.lastBought)),
                  ])
              .toList(),
        ),
      );

  // ── Missing usual products ────────────────────────────────────────────────
  Widget _missingProducts(CustomerTrace t) {
    if (t.missingUsualProducts.isEmpty) return const SizedBox.shrink();
    final n = t.missingUsualProducts.length;
    return InsightSection(
      title: 'Missing Usual Products — $n product${n == 1 ? '' : 's'} not bought this period',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8)),
          child: const Text('Bought in the prior period but absent in the current period.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
        ),
        MiniTable(
          columns: const [
            MiniCol('Product', 180),
            MiniCol('Unit', 80),
            MiniCol('Last Bought', 120),
          ],
          rows: t.missingUsualProducts
              .map((m) => [
                    tcell(m.productName, weight: FontWeight.w700),
                    tcell(m.unit ?? '—'),
                    tcell(_date(m.lastBought)),
                  ])
              .toList(),
        ),
      ]),
    );
  }

  // ── Returns ────────────────────────────────────────────────────────────────
  Widget _returns(CustomerTrace t) => InsightSection(
        title: 'Return History',
        count: t.returnRows.length,
        child: MiniTable(
          emptyText: 'No history of returning items for this customer.',
          columns: const [
            MiniCol('Order #', 120),
            MiniCol('Date', 110),
            MiniCol('Value', 120, numeric: true),
            MiniCol('Invoices', 150),
          ],
          rows: t.returnRows
              .map((r) => [
                    tcell(r.orderNo ?? '—', weight: FontWeight.w700),
                    tcell(_date(r.orderDate)),
                    tcell(_money(r.grandTotal), numeric: true),
                    tcell(r.invoiceNos.isEmpty ? '—' : r.invoiceNos.join(', ')),
                  ])
              .toList(),
        ),
      );
}

/// Searchable customer typeahead (min 2 chars) backed by /customer-suggestions.
class _CustomerTracePicker extends StatefulWidget {
  final InsightsRepository repo;
  const _CustomerTracePicker({required this.repo});
  @override
  State<_CustomerTracePicker> createState() => _CustomerTracePickerState();
}

class _CustomerTracePickerState extends State<_CustomerTracePicker> {
  List<CustomerSuggestion> _items = [];
  bool _loading = false;
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _query = q);
    if (q.trim().length < 2) {
      setState(() => _items = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final items = await widget.repo.customerSuggestions(q);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // keep last results
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const Text('Select customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name, code, phone, or city',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _query.trim().length < 2
                      ? const Center(child: Text('Type at least 2 characters to search.', style: TextStyle(color: AppColors.textMuted)))
                      : _items.isEmpty
                          ? const Center(child: Text('No customers found.', style: TextStyle(color: AppColors.textMuted)))
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (ctx, i) {
                                final c = _items[i];
                                return ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: Row(children: [
                                    Expanded(child: Text(c.customerName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    if (!c.isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('Inactive', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                      ),
                                  ]),
                                  subtitle: c.subtitle.isNotEmpty ? Text(c.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                                  trailing: c.outstandingBalance > 0
                                      ? Text(CurrencyUtils.formatCompact(c.outstandingBalance), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger))
                                      : null,
                                  onTap: () => Navigator.pop(context, c),
                                );
                              },
                            ),
            ),
          ]),
        ),
      ),
    );
  }
}
