import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/stocktake_model.dart';
import '../providers/stocktake_providers.dart';

/// Physical stock-take list — status filter pills + rows showing location, status
/// and the count/variance summary. FAB starts a new count (pick a location → DRAFT).
class StocktakeListScreen extends ConsumerStatefulWidget {
  const StocktakeListScreen({super.key});
  @override
  ConsumerState<StocktakeListScreen> createState() => _StocktakeListScreenState();
}

class _StocktakeListScreenState extends ConsumerState<StocktakeListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(stocktakeListProvider.notifier).load());
  }

  String _shortDate(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);

  Future<void> _newCount() async {
    final created = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => const _NewCountSheet(),
    );
    if (!mounted) return;
    if (created != null) {
      await context.push('/inventory/stocktake/$created');
      if (mounted) ref.read(stocktakeListProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stocktakeListProvider);
    final filters = ['All', ...StocktakeStatus.all];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Stock-take')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newCount,
        icon: const Icon(Icons.add),
        label: const Text('New count'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Count physical stock per location, then post the variances as adjustments.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final f = filters[i];
                final active = state.statusFilter == f;
                return InkWell(
                  onTap: () => ref.read(stocktakeListProvider.notifier).setFilter(f),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.textPrimary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? AppColors.textPrimary : AppColors.border),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.textSecondary),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _error(state.error!)
                    : state.stocktakes.isEmpty
                        ? _empty()
                        : RefreshIndicator(
                            onRefresh: () => ref.read(stocktakeListProvider.notifier).load(),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: state.stocktakes.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) => _row(state.stocktakes[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _row(Stocktake s) {
    final c = StocktakeStatus.color(s.status);
    final sm = s.summary;
    return InkWell(
      onTap: () async {
        await context.push('/inventory/stocktake/${s.id}');
        if (mounted) ref.read(stocktakeListProvider.notifier).load();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('#${s.id}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              _chip(s.status, c),
              const Spacer(),
              Text(_shortDate(s.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ]),
            const SizedBox(height: 4),
            Text(s.locationName ?? (s.locationId != null ? 'Location #${s.locationId}' : '—'),
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sm != null) ...[
              const SizedBox(height: 6),
              Text(
                '${sm.counted}/${sm.totalLines} counted  ·  ${sm.variances} variance${sm.variances == 1 ? '' : 's'}  ·  net ${sm.netUnits >= 0 ? '+' : ''}${sm.netUnits.toStringAsFixed(sm.netUnits == sm.netUnits.roundToDouble() ? 0 : 2)}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
      );

  Widget _empty() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.fact_check_outlined, size: 46, color: AppColors.textMuted),
          SizedBox(height: 12),
          Center(child: Text('No stock-takes yet.', style: TextStyle(color: AppColors.textMuted))),
        ],
      );

  Widget _error(String e) => ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
          const SizedBox(height: 12),
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
        ],
      );
}

/// Pick a location (+ optional note) and create a DRAFT stock-take. Pops the new id.
class _NewCountSheet extends ConsumerStatefulWidget {
  const _NewCountSheet();
  @override
  ConsumerState<_NewCountSheet> createState() => _NewCountSheetState();
}

class _NewCountSheetState extends ConsumerState<_NewCountSheet> {
  List<StocktakeLocation> _locations = [];
  bool _loading = true;
  String? _error;
  int? _locationId;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final locs = await ref.read(stocktakeRepositoryProvider).getLocations();
      if (!mounted) return;
      setState(() {
        _locations = locs;
        _locationId = locs.isNotEmpty ? locs.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _create() async {
    if (_locationId == null) return;
    setState(() => _saving = true);
    try {
      final st = await ref.read(stocktakeRepositoryProvider).createStocktake(locationId: _locationId!, notes: _notesCtrl.text);
      if (mounted) Navigator.pop(context, st.id);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger, duration: const Duration(seconds: 5)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            const Text('New stock-take', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Choose the location to count. Freeze it next to snapshot book stock.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Text('Could not load locations: $_error', style: const TextStyle(color: AppColors.danger))
            else ...[
              const Text('Location', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: _locationId,
                isExpanded: true,
                decoration: _dec('Godown / store'),
                items: _locations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _locationId = v),
              ),
              const SizedBox(height: 14),
              const Text('Notes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _notesCtrl, decoration: _dec('Optional reference'), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_saving || _locationId == null) ? null : _create,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Creating…' : 'Create draft'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      );
}
