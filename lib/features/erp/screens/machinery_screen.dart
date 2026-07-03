import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/erp_list_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/erp_providers.dart';
import '../providers/machinery_providers.dart';
import 'erp_common.dart';
import 'machine_transfers_section.dart';

const _accent = Color(0xFF7C3AED);

/// Read-only Machinery/fleet list (manage on web) — gradient hero, status filters, search.
class MachineryScreen extends ConsumerStatefulWidget {
  const MachineryScreen({super.key});
  @override
  ConsumerState<MachineryScreen> createState() => _MachineryScreenState();
}

class _MachineryScreenState extends ConsumerState<MachineryScreen> {
  String _filter = 'all';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(machineryListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Machinery')),
      body: async.when(
        loading: () => const LoadingIndicator(message: 'Loading machinery…'),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(machineryListProvider)),
        data: (rows) {
          final docs = rows.fold<int>(0, (s, m) => s + m.docsExpiring);
          final filtered = rows.where((m) {
            if (_filter != 'all' && m.status != _filter) return false;
            if (_q.isEmpty) return true;
            final s = _q.toLowerCase();
            return m.name.toLowerCase().contains(s) || m.machineCode.toLowerCase().contains(s) || m.category.toLowerCase().contains(s) || (m.make ?? '').toLowerCase().contains(s);
          }).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(children: [
                ErpHero(gradient: const [_accent, Color(0xFF6D28D9)], icon: Icons.agriculture, stats: [
                  ('Fleet', '${rows.length}'),
                  ('Under maint.', '${rows.where((m) => m.status == 'UNDER_MAINTENANCE').length}'),
                  ('Docs expiring', '$docs'),
                ]),
                const SizedBox(height: 12),
                ErpSearchField(hint: 'Search machine, category, make…', onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: 10),
                ErpFilterChips(options: buildStatusOptions(rows.map((m) => m.status)), selected: _filter, accent: _accent, onSelect: (v) => setState(() => _filter = v)),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(machineryListProvider);
                  if (ref.read(authProvider).user?.isOperator != true) ref.invalidate(machineTransfersProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  children: [
                    // Supervisors+ receive incoming machine transfers right from the fleet list.
                    if (ref.watch(authProvider).user?.isOperator != true) const MachineTransfersSection(),
                    if (filtered.isEmpty)
                      const ErpEmpty(icon: Icons.agriculture_outlined, text: 'No matching machines')
                    else
                      ...filtered.map(_card),
                  ],
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _card(Machine m) => GestureDetector(
        onTap: () => context.push('/machinery/${m.id}'),
        child: _cardBody(m),
      );

  Widget _cardBody(Machine m) => ErpCard(
        icon: Icons.agriculture_outlined,
        color: _accent,
        title: m.name,
        code: m.machineCode,
        status: m.status,
        badge: m.docsExpiring > 0 ? '${m.docsExpiring} doc${m.docsExpiring == 1 ? '' : 's'} expiring' : null,
        badgeColor: AppColors.danger,
        rows: [
          if (m.category.isNotEmpty) ('Category', m.category.replaceAll('_', ' ')),
          if ((m.make ?? '').isNotEmpty || (m.model ?? '').isNotEmpty) ('Make / model', [m.make, m.model].where((e) => e != null && e.isNotEmpty).join(' · ')),
          if ((m.projectName ?? '').isNotEmpty) ('Deployed', m.projectName!),
          if ((m.currentLocation ?? '').isNotEmpty) ('Location', m.currentLocation!),
        ],
      );
}
