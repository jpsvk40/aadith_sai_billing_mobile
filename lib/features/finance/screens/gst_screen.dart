import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/gst_compliance_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/providers/financial_year_provider.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/gst_compliance_providers.dart';

const _teal = Color(0xFF0891B2);

/// GST summary (read-only) — GSTR-1 style outward-supply breakdown for a month:
/// B2B / B2C-Small / B2C-Large counts & values, with month navigation.
///
/// Filters (parity with the web GSTReturns page):
///  • Financial Year — server-side (`financialYearId` on /gst/summary).
///  • Legal Entity (multi-GSTIN) — server-side (`legalEntityId` on /gst/summary),
///    sourced from `/api/legal-entities` like the web dropdown.
///  • B2B / B2C section tabs — client-side split of the single summary response
///    (the endpoint has no `section` param; it always returns b2b/b2cs/b2cl).
class GstScreen extends ConsumerStatefulWidget {
  const GstScreen({super.key});
  @override
  ConsumerState<GstScreen> createState() => _GstScreenState();
}

class _GstScreenState extends ConsumerState<GstScreen> {
  late DateTime _month; // first day of the selected month
  Map<String, dynamic> _data = const {};
  bool _loading = true;
  String? _error;

  // Shared filter state — carries `financialYearId` + the chosen legal-entity label.
  ListFilterState _filter = ListFilterState();
  List<LegalEntityLite> _entities = const [];

  // Active section tab: 'b2b' (registered) or 'b2c' (b2cs + b2cl consumer sales).
  String _section = 'b2b';

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadEntities();
      _load();
    });
  }

  String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Legal entities are optional — preload quietly so the picker is ready on first open.
  Future<void> _preloadEntities() async {
    try {
      final list = await ref.read(legalEntitiesProvider.future);
      if (!mounted || list.isEmpty) return;
      setState(() => _entities = list);
    } catch (_) {/* single-entity company or no access — filter simply hides */}
  }

  /// Maps the chosen dropdown label back to the server `legalEntityId`.
  String? get _legalEntityId {
    final label = _filter.selects['legalEntity'];
    if (label == null || label.isEmpty) return null;
    for (final e in _entities) {
      if (e.filterLabel == label) return e.id;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final from = _month;
      final to = DateTime(_month.year, _month.month + 1, 0); // last day of month
      final qp = <String, dynamic>{'fromDate': _d(from), 'toDate': _d(to)};
      final fyId = _filter.financialYearId;
      if (fyId != null && fyId.isNotEmpty) qp['financialYearId'] = fyId;
      final leId = _legalEntityId;
      if (leId != null && leId.isNotEmpty) qp['legalEntityId'] = leId;
      final data = await client.get(ApiConstants.gstSummary, queryParams: qp);
      if (!mounted) return;
      setState(() { _data = data is Map ? data.cast<String, dynamic>() : const {}; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  // Opens the shared filter sheet with only Financial Year + Legal Entity (the
  // month navigator already owns the date window, so periods/date-range are hidden).
  Future<void> _openFilters() async {
    final fy = await ref.read(financialYearsProvider.future);
    var entities = _entities;
    if (entities.isEmpty) {
      try {
        entities = await ref.read(legalEntitiesProvider.future);
      } catch (_) {/* keep empty */}
    }
    if (!mounted) return;
    if (entities.isNotEmpty && _entities.isEmpty) setState(() => _entities = entities);

    final result = await showListFilterSheet(
      context,
      initial: _filter,
      showPeriods: false,
      showDateRange: false,
      financialYears: fy.years,
      selects: entities.isEmpty
          ? const []
          : [
              SelectFilter(
                key: 'legalEntity',
                label: 'GST Registration',
                allLabel: 'All GST registrations',
                options: entities.map((e) => e.filterLabel).toList(),
              ),
            ],
      title: 'GST filters',
    );
    if (result != null) {
      setState(() => _filter = result);
      _load();
    }
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  Map<String, dynamic> _bucket(String key) => (_data[key] is Map) ? (_data[key] as Map).cast<String, dynamic>() : const {};

  @override
  Widget build(BuildContext context) {
    final b2b = _bucket('b2b');
    final b2cs = _bucket('b2cs');
    final b2cl = _bucket('b2cl');
    final b2bCount = _num(b2b['count']).toInt();
    final b2bValue = _num(b2b['value']);
    final b2cCount = _num(b2cs['count']).toInt() + _num(b2cl['count']).toInt();
    final b2cValue = _num(b2cs['value']) + _num(b2cl['value']);
    final totalValue = b2bValue + b2cValue;
    final gstin = (_data['supplierGstin']?.toString().isNotEmpty == true)
        ? _data['supplierGstin'].toString()
        : (_data['companyGstin']?.toString() ?? '');
    final selectedEntity = (_data['selectedLegalEntity'] is Map)
        ? (_data['selectedLegalEntity'] as Map)['name']?.toString()
        : null;
    final isCurrentMonth = _month.year == DateTime.now().year && _month.month == DateTime.now().month;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('GST')),
      body: Column(children: [
        // Month navigator
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _loading ? null : () => _shiftMonth(-1)),
            Expanded(child: Center(child: Text('${_monthNames[_month.month - 1]} ${_month.year}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: _loading || isCurrentMonth ? null : () => _shiftMonth(1)),
          ]),
        ),
        // Filters (Financial Year + Legal Entity) — server-side.
        FilterSortButtons(
          activeFilterCount: _filter.activeCount,
          onFilterTap: _openFilters,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        ),
        Expanded(
          child: _loading
              ? const LoadingIndicator()
              : _error != null
                  ? ErrorStateWidget(message: _error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(14), children: [
                        // Hero — outward supplies for the month
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(gradient: LinearGradient(colors: [_teal, Color(0xFF0E7490)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                            child: Stack(children: [
                              Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Outward supplies (GSTR-1)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                                const SizedBox(height: 4),
                                Text(CurrencyUtils.format(totalValue), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                                const SizedBox(height: 12),
                                Row(children: [
                                  const Icon(Icons.receipt_long_outlined, size: 14, color: Colors.white70),
                                  const SizedBox(width: 5),
                                  Text('${_data['totalInvoices'] ?? 0} invoices', style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  if (gstin.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                                      child: Text(gstin, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                    ),
                                ]),
                                if (selectedEntity != null && selectedEntity.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text('Legal entity: $selectedEntity', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                                ],
                              ]),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Supply breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const SizedBox(height: 10),
                        _sectionTabs(),
                        const SizedBox(height: 12),
                        if (_section == 'b2b') ...[
                          _bucketCard('B2B', 'Registered buyers (with GSTIN)', b2b, const Color(0xFF2563EB), Icons.business_outlined),
                          _sectionTotal('B2B total', b2bCount, b2bValue, const Color(0xFF2563EB)),
                        ] else ...[
                          _bucketCard('B2C Small', 'Consumer sales (intra-state / ≤ ₹2.5L)', b2cs, const Color(0xFF16A34A), Icons.people_outline),
                          _bucketCard('B2C Large', 'Inter-state consumer > ₹2.5L', b2cl, const Color(0xFF9333EA), Icons.local_shipping_outlined),
                          _sectionTotal('B2C total', b2cCount, b2cValue, const Color(0xFF16A34A)),
                        ],
                        const SizedBox(height: 16),
                        const Text('Registers & returns', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const SizedBox(height: 10),
                        _linkTile(context, Icons.receipt_long_outlined, 'e-Invoice Register', 'IRNs · Ack no · status', const Color(0xFF2563EB), '/finance/gst/einvoice'),
                        _linkTile(context, Icons.local_shipping_outlined, 'e-Way Bill Register', 'EWB no · validity · vehicle', const Color(0xFF0EA5E9), '/finance/gst/eway'),
                        _linkTile(context, Icons.fact_check_outlined, 'GST Returns Review', 'GSTR-1 summary · validations', const Color(0xFF16A34A), '/finance/gst/returns'),
                        _linkTile(context, Icons.splitscreen_outlined, 'GST Bills', 'Split invoices · void · assign GST #', const Color(0xFF7C3AED), '/gst-bills'),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBFDBFE))),
                          child: const Row(children: [
                            Icon(Icons.info_outline, size: 18, color: Color(0xFF2563EB)),
                            SizedBox(width: 10),
                            Expanded(child: Text('Filing to the GST portal is completed on the web portal.', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF)))),
                          ]),
                        ),
                      ]),
                    ),
        ),
      ]),
    );
  }

  // Segmented B2B / B2C control — client-side section split of the summary response.
  Widget _sectionTabs() {
    Widget tab(String id, String label) {
      final active = _section == id;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _section = id),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: active ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [tab('b2b', 'B2B'), const SizedBox(width: 4), tab('b2c', 'B2C')]),
    );
  }

  Widget _sectionTotal(String label, int count, double value, Color color) => Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.30))),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color))),
          Text('$count invoice${count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text(CurrencyUtils.format(value), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        ]),
      );

  Widget _linkTile(BuildContext context, IconData icon, String title, String subtitle, Color color, String route) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: ListTile(
          onTap: () => context.push(route),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ),
      );

  Widget _bucketCard(String title, String subtitle, Map<String, dynamic> bucket, Color color, IconData icon) {
    final count = _num(bucket['count']).toInt();
    final value = _num(bucket['value']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(CurrencyUtils.format(value), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
          const SizedBox(height: 2),
          Text('$count invoice${count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}
