import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/vendor_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/vendor_list_provider.dart';

class VendorListScreen extends ConsumerStatefulWidget {
  const VendorListScreen({super.key});
  @override
  ConsumerState<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends ConsumerState<VendorListScreen> {
  final _searchCtrl = TextEditingController();
  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(vendorListProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Client-side filter + search + sort — mirrors the web VendorList page,
  /// which filters over the full loaded list rather than re-querying.
  List<Vendor> _filtered(VendorListState s) {
    var list = s.vendors;

    // Active / Inactive select (null = All).
    final status = _filters.select('status');
    if (status == 'Active') {
      list = list.where((v) => v.isActive).toList();
    } else if (status == 'Inactive') {
      list = list.where((v) => !v.isActive).toList();
    }

    // Free-text search across name, code, phone, email, contact, city, rep.
    final q = s.search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((v) {
        return v.vendorName.toLowerCase().contains(q) ||
            (v.vendorCode ?? '').toLowerCase().contains(q) ||
            (v.phone ?? '').toLowerCase().contains(q) ||
            (v.email ?? '').toLowerCase().contains(q) ||
            (v.contactPerson ?? '').toLowerCase().contains(q) ||
            (v.city ?? '').toLowerCase().contains(q) ||
            (v.assignedRepName ?? '').toLowerCase().contains(q);
      }).toList();
    }

    if (_sort != null) {
      list = applySort<Vendor>(list, _sort!, (v, key) {
        switch (key) {
          case 'name':
            return v.vendorName.toLowerCase();
          case 'city':
            return v.city?.toLowerCase();
          case 'openingBalance':
            return v.openingBalance;
        }
        return null;
      });
    }
    return list;
  }

  Future<void> _openFilters() async {
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      showPeriods: false,
      showDateRange: false,
      selects: const [
        SelectFilter(key: 'status', label: 'Status', options: ['Active', 'Inactive']),
      ],
    );
    if (res != null) setState(() => _filters = res);
  }

  Color _avatarColor(String name) {
    const palette = [Color(0xFF0D6EFD), Color(0xFF198754), Color(0xFFF59E0B), Color(0xFF7C3AED), Color(0xFF0891B2), Color(0xFFDB2777)];
    return palette[name.isEmpty ? 0 : name.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vendorListProvider);
    final visible = _filtered(state);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vendors')),
      body: state.isLoading && state.vendors.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.vendors.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(vendorListProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () => ref.read(vendorListProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: visible.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(state, visible);
                      final v = visible[i - 1];
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showDetail(v),
                        child: _vendorCard(v),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _header(VendorListState s, List<Vendor> visible) {
    // KPIs react to the currently filtered set.
    final active = visible.where((v) => v.isActive).length;
    final withEmail = visible.where((v) => (v.email ?? '').isNotEmpty).length;
    final withRep = visible.where((v) => (v.assignedRepName ?? '').isNotEmpty).length;
    final totalBal = visible.fold<double>(0, (sum, v) => sum + v.openingBalance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI cards.
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 6),
            children: [
              _kpiCard('Total', '${visible.length}', AppColors.textPrimary),
              _kpiCard('Active', '$active', AppColors.success),
              _kpiCard('With Email', '$withEmail', AppColors.primary),
              _kpiCard('With Rep', '$withRep', const Color(0xFF0F766E)),
              _kpiCard('Opening Bal.', CurrencyUtils.formatCompact(totalBal), const Color(0xFF7C3AED)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => ref.read(vendorListProvider.notifier).setSearch(v),
            decoration: InputDecoration(
              hintText: 'Search name, code, phone, email, city, rep...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              suffixIcon: s.search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(vendorListProvider.notifier).setSearch('');
                      })
                  : null,
            ),
          ),
        ),
        FilterSortButtons(
          activeFilterCount: _filters.activeCount,
          onFilterTap: _openFilters,
          sortOptions: const [
            SortSpec('name', 'Name'),
            SortSpec('city', 'City'),
            SortSpec('openingBalance', 'Opening Bal.'),
          ],
          currentSort: _sort,
          onSortChanged: (sp) => setState(() => _sort = sp),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
          child: Text('${visible.length} vendor${visible.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, String value, Color valueColor) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: valueColor)),
        ],
      ),
    );
  }

  Widget _vendorCard(Vendor v) {
    final color = _avatarColor(v.vendorName);
    final initials = v.vendorName.trim().isEmpty
        ? '?'
        : v.vendorName.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    final place = [v.city, v.state].where((e) => e != null && e.isNotEmpty).join(', ');
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
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
              child: Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(v.vendorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      if (!v.isActive) _pill('Inactive', AppColors.danger),
                    ],
                  ),
                  if ((v.vendorCode ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(v.vendorCode!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ],
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Flexible(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    ]),
                  ],
                  if ((v.assignedRepName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.badge_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Flexible(child: Text(v.assignedRepName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    ]),
                  ],
                ],
              ),
            ),
            if (v.phone != null && v.phone!.isNotEmpty)
              InkWell(
                onTap: () => launchUrl(Uri.parse('tel:${v.phone}')),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(19)),
                  child: const Icon(Icons.call, color: AppColors.primary, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  void _showDetail(Vendor v) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Text(v.vendorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                    _pill(v.isActive ? 'Active' : 'Inactive', v.isActive ? AppColors.success : AppColors.danger),
                  ],
                ),
                if ((v.vendorCode ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(v.vendorCode!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 16),
                _detailRow(Icons.person_outline, 'Contact Person', v.contactPerson),
                _detailRow(Icons.call_outlined, 'Phone', v.phone),
                _detailRow(Icons.email_outlined, 'Email', v.email),
                _detailRow(Icons.receipt_long_outlined, 'GSTIN', v.gstin),
                _detailRow(Icons.location_on_outlined, 'Location', [v.city, v.state].where((e) => e != null && e.isNotEmpty).join(', ')),
                _detailRow(Icons.badge_outlined, 'Assigned Rep', v.assignedRepName),
                if (v.paymentTermsDays != null) _detailRow(Icons.schedule_outlined, 'Payment Terms', '${v.paymentTermsDays} days'),
                _detailRow(Icons.account_balance_wallet_outlined, 'Opening Balance', CurrencyUtils.format(v.openingBalance)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String? value) {
    final v = (value ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.textMuted),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(v.isEmpty ? '—' : v,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: v.isEmpty ? AppColors.textMuted : AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
