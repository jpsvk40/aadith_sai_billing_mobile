import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/erp_list_models.dart';
import '../../../data/models/machine_detail_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/erp_providers.dart';
import '../providers/machinery_providers.dart';
import 'erp_common.dart';

const _accent = Color(0xFF7C3AED);
const _accentDark = Color(0xFF6D28D9);

/// Fleet-wide Machine Logbook (GET /machinery/logs) — daily working hours, fuel &
/// deployment across the whole fleet. Mirrors the web MachineryLogbook page: a
/// machine + from/to filter (server-backed) with per-entry cards.
class MachineryLogbookScreen extends ConsumerStatefulWidget {
  const MachineryLogbookScreen({super.key});
  @override
  ConsumerState<MachineryLogbookScreen> createState() => _MachineryLogbookScreenState();
}

class _MachineryLogbookScreenState extends ConsumerState<MachineryLogbookScreen> {
  ListFilterState _filters = ListFilterState();
  SortSpec? _sort;

  /// Resolve the current filter selections into the server query the provider runs.
  LogbookQuery _query(List<Machine> machines) {
    final label = _filters.select('machine');
    int? machineId;
    if (label != null && label.isNotEmpty) {
      final match = machines.where((m) => _machineLabel(m) == label);
      if (match.isNotEmpty) machineId = match.first.id;
    }
    return (machineId: machineId, from: _filters.dateFromParam, to: _filters.dateToParam);
  }

  static String _machineLabel(Machine m) => '${m.machineCode} — ${m.name}';

  Future<void> _openFilters(List<Machine> machines) async {
    final res = await showListFilterSheet(
      context,
      initial: _filters,
      title: 'Filter Logbook',
      showPeriods: true,
      showDateRange: true,
      selects: [
        SelectFilter(
          key: 'machine',
          label: 'Machine',
          allLabel: 'All machines',
          options: machines.map(_machineLabel).toList(),
        ),
      ],
    );
    if (res != null) setState(() => _filters = res);
  }

  List<MachineLog> _sorted(List<MachineLog> rows) {
    if (_sort == null) return rows;
    return applySort<MachineLog>(rows, _sort!, (l, key) {
      switch (key) {
        case 'date':
          return l.logDate;
        case 'hours':
          return l.workingHours;
        case 'fuel':
          return l.fuelCost;
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Machines power the filter dropdown + the code/name fallback if a row lacks its embed.
    final machines = ref.watch(machineryListProvider).valueOrNull ?? const <Machine>[];
    final query = _query(machines);
    final async = ref.watch(machineryLogbookProvider(query));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Machine Logbook')),
      body: async.when(
        loading: () => const LoadingIndicator(message: 'Loading logbook…'),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(machineryLogbookProvider(query))),
        data: (rows) {
          final sorted = _sorted(rows);
          final totHrs = rows.fold<double>(0, (s, l) => s + (l.workingHours ?? 0));
          final totFuel = rows.fold<double>(0, (s, l) => s + (l.fuelCost ?? 0));
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(children: [
                ErpHero(gradient: const [_accent, _accentDark], icon: Icons.menu_book, stats: [
                  ('Entries', '${rows.length}'),
                  ('Working hrs', _num(totHrs)),
                  ('Fuel cost', '₹${_num(totFuel)}'),
                ]),
                const SizedBox(height: 12),
                FilterSortButtons(
                  padding: EdgeInsets.zero,
                  activeFilterCount: _filters.activeCount,
                  onFilterTap: () => _openFilters(machines),
                  sortOptions: const [
                    SortSpec('date', 'Date'),
                    SortSpec('hours', 'Hours'),
                    SortSpec('fuel', 'Fuel'),
                  ],
                  currentSort: _sort,
                  onSortChanged: (s) => setState(() => _sort = s),
                ),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(machineryLogbookProvider(query)),
                child: sorted.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 40),
                        ErpEmpty(icon: Icons.menu_book_outlined, text: 'No log entries.\nAdjust the filters or add usage from a machine.'),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: sorted.length,
                        itemBuilder: (_, i) => _LogCard(log: sorted[i]),
                      ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  static String _num(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _LogCard extends StatelessWidget {
  final MachineLog log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final l = log;
    final machineTitle = [l.machineCode, l.machineName].where((e) => e != null && e.isNotEmpty).join(' · ');
    final deployment = l.projectName ?? l.location;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.menu_book_outlined, size: 18, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(machineTitle.isEmpty ? 'Machine' : machineTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Row(children: [
                Text(_fmtDate(l.logDate), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                if ((l.shift ?? '').isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _pill(l.shift!),
                ],
              ]),
            ]),
          ),
          if (l.workingHours != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text(_fmtNum(l.workingHours), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _accent)),
              const Text('hrs', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if ((l.operatorName ?? '').isNotEmpty) _tag(Icons.person_outline, l.operatorName!),
          if ((deployment ?? '').isNotEmpty) _tag(Icons.place_outlined, deployment!),
          if (l.distanceKm != null && l.distanceKm! > 0) _tag(Icons.route_outlined, '${_fmtNum(l.distanceKm)} km'),
          if (l.idleHours != null && l.idleHours! > 0) _tag(Icons.pause_circle_outline, 'Idle ${_fmtNum(l.idleHours)}'),
          if (l.fuelQty != null && l.fuelQty! > 0) _tag(Icons.local_gas_station_outlined, '${_fmtNum(l.fuelQty)} L'),
          if (l.fuelCost != null && l.fuelCost! > 0) _tag(Icons.payments_outlined, '₹${_fmtNum(l.fuelCost)}'),
        ]),
        if ((l.remarks ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l.remarks!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }

  static Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      );

  static Widget _tag(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ]),
      );

  static String _fmtNum(double? v) {
    if (v == null) return '—';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }
}
