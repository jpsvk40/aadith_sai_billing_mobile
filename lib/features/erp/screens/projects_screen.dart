import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/erp_list_models.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/erp_providers.dart';
import 'erp_common.dart';

const _accent = Color(0xFF2563EB);

/// Read-only Projects list (manage on web) — gradient hero, status filters, search.
class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});
  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _filter = 'all';
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(projectsListProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await context.push<bool>('/projects/create');
          if (saved == true) ref.invalidate(projectsListProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: async.when(
        loading: () => const LoadingIndicator(message: 'Loading projects…'),
        error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(projectsListProvider)),
        data: (rows) {
          final won = rows.where((p) => p.status == 'WON').fold<double>(0, (s, p) => s + p.contractValue);
          final filtered = rows.where((p) {
            if (_filter != 'all' && p.status != _filter) return false;
            if (_q.isEmpty) return true;
            final s = _q.toLowerCase();
            return p.projectName.toLowerCase().contains(s) || p.projectCode.toLowerCase().contains(s) || (p.customerName ?? '').toLowerCase().contains(s);
          }).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(children: [
                ErpHero(gradient: const [_accent, Color(0xFF4F46E5)], icon: Icons.apartment, stats: [
                  ('Projects', '${rows.length}'),
                  ('Won', '${rows.where((p) => p.status == 'WON').length}'),
                  ('WON value', CurrencyUtils.formatCompact(won)),
                ]),
                const SizedBox(height: 12),
                ErpSearchField(hint: 'Search project, customer, code…', onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: 10),
                ErpFilterChips(options: buildStatusOptions(rows.map((p) => p.status)), selected: _filter, accent: _accent, onSelect: (v) => setState(() => _filter = v)),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(projectsListProvider),
                child: filtered.isEmpty
                    ? ListView(children: const [ErpEmpty(icon: Icons.apartment_outlined, text: 'No matching projects')])
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: filtered.map(_card).toList()),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _card(Project p) => GestureDetector(
        onTap: () => context.push('/projects/${p.id}'),
        child: ErpCard(
          icon: Icons.apartment_outlined,
          color: _accent,
          title: p.projectName,
          code: p.projectCode,
          status: p.status,
          rows: [
            if ((p.customerName ?? '').isNotEmpty) ('Customer', p.customerName!),
            if (p.contractValue > 0) ('Contract', CurrencyUtils.formatCompact(p.contractValue)),
            if ((p.workOrderNo ?? '').isNotEmpty) ('Work order', p.workOrderNo!),
            if ((p.city ?? '').isNotEmpty) ('City', p.city!),
          ],
        ),
      );
}
