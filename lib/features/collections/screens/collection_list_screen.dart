import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/collection_list_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/collection_model.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../../widgets/common/error_state_widget.dart';

const _cOrange = Color(0xFFF59E0B);

class CollectionListScreen extends ConsumerStatefulWidget {
  const CollectionListScreen({super.key});
  @override
  ConsumerState<CollectionListScreen> createState() => _CollectionListScreenState();
}

class _CollectionListScreenState extends ConsumerState<CollectionListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _status = 'All';
  final _statuses = ['All', 'Pending', 'Partial', 'Settled'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(collectionListProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Collection> _filtered(List<Collection> all) {
    final q = _search.trim().toLowerCase();
    return all.where((c) {
      if (_status != 'All' && (c.status.toLowerCase() != _status.toLowerCase())) return false;
      if (q.isEmpty) return true;
      return (c.customerName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'settled':
      case 'completed':
        return AppColors.success;
      case 'partial':
        return AppColors.info;
      default:
        return _cOrange; // Pending
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collectionListProvider);
    final visible = _filtered(state.collections);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Collections')),
      body: state.isLoading && state.collections.isEmpty
          ? const LoadingIndicator()
          : state.error != null && state.collections.isEmpty
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(collectionListProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () => ref.read(collectionListProvider.notifier).load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: visible.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(state, visible.length);
                      return _collectionCard(visible[i - 1]);
                    },
                  ),
                ),
    );
  }

  Widget _header(CollectionListState s, int shown) {
    final toCollect = s.collections.fold<double>(0, (a, c) => a + c.balanceAmount);
    final collected = s.collections.fold<double>(0, (a, c) => a + (c.collectedAmount ?? 0));
    final pending = s.collections.where((c) => c.status.toLowerCase() != 'settled' && c.status.toLowerCase() != 'completed').length;

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
              _summaryCard('TO COLLECT', CurrencyUtils.format(toCollect), AppColors.danger, Icons.account_balance_wallet_outlined),
              _summaryCard('PENDING', '$pending', _cOrange, Icons.hourglass_empty),
              _summaryCard('COLLECTED', CurrencyUtils.format(collected), AppColors.success, Icons.verified_outlined),
              _summaryCard('BILLS', '${s.collections.length}', AppColors.primary, Icons.list_alt_outlined),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search customer...',
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
                final sel = _status == f;
                final c = f == 'All' ? AppColors.primary : _statusColor(f);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: sel,
                    onSelected: (_) => setState(() => _status = f),
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
          if (shown == 0 && !s.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('No collections found', style: TextStyle(color: AppColors.textMuted))),
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

  Widget _collectionCard(Collection c) {
    final sc = _statusColor(c.status);
    final overdue = c.dueDate != null && c.dueDate!.isBefore(DateTime.now()) && c.status.toLowerCase() != 'settled';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () => context.go('/collections/${c.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.account_balance_wallet_outlined, color: sc, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(c.customerName ?? 'Customer', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                        _pill(c.status, sc),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text('To collect ', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        Text(CurrencyUtils.format(c.balanceAmount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.danger)),
                        if ((c.collectedAmount ?? 0) > 0) ...[
                          const Text('  ·  collected ', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                          Text(CurrencyUtils.formatCompact(c.collectedAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                        ],
                      ],
                    ),
                    if (c.dueDate != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(overdue ? Icons.warning_amber_rounded : Icons.calendar_today_outlined, size: 12, color: overdue ? AppColors.danger : AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text('Due ${AppDateUtils.formatDisplay(c.dueDate)}', style: TextStyle(fontSize: 11, color: overdue ? AppColors.danger : AppColors.textMuted, fontWeight: overdue ? FontWeight.w600 : FontWeight.normal)),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
      );
}
