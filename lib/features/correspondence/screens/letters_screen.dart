import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/letter_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../erp/screens/erp_common.dart';
import '../providers/letters_provider.dart';

const _accent = Color(0xFF0284C7);

/// Correspondence — Letters. Gradient hero, Awaiting/All scope, direction filters,
/// search, and status-accented cards. Tap a letter to view + resolve it.
class LettersScreen extends ConsumerStatefulWidget {
  final String? initialScope;
  const LettersScreen({super.key, this.initialScope});
  @override
  ConsumerState<LettersScreen> createState() => _LettersScreenState();
}

class _LettersScreenState extends ConsumerState<LettersScreen> {
  String _direction = 'all'; // all | INWARD | OUTWARD
  String _q = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = ref.read(lettersProvider.notifier);
      if (widget.initialScope != null && widget.initialScope != ref.read(lettersProvider).scope) {
        n.setScope(widget.initialScope!);
      } else {
        n.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lettersProvider);
    final n = ref.read(lettersProvider.notifier);
    final rows = state.letters;
    final overdue = rows.where((l) => (l.daysOverdue ?? -1) >= 0).length;

    final filtered = rows.where((l) {
      if (_direction != 'all' && l.direction != _direction) return false;
      if (_q.isEmpty) return true;
      final s = _q.toLowerCase();
      return l.subject.toLowerCase().contains(s) || l.letterCode.toLowerCase().contains(s) || (l.partyName ?? '').toLowerCase().contains(s) || (l.refNumber ?? '').toLowerCase().contains(s);
    }).toList();

    final dirOptions = <(String, String, int)>[
      ('All', 'all', rows.length),
      ('Inward', 'INWARD', rows.where((l) => !l.isOutward).length),
      ('Outward', 'OUTWARD', rows.where((l) => l.isOutward).length),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Correspondence')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(children: [
              ErpHero(gradient: const [_accent, Color(0xFF0369A1)], icon: Icons.mail, stats: [
                (state.scope == 'awaiting' ? 'Awaiting' : 'Letters', '${rows.length}'),
                ('Overdue', '$overdue'),
                ('Inward', '${rows.where((l) => !l.isOutward).length}'),
              ]),
              const SizedBox(height: 12),
              // Scope segmented control (server-driven: awaiting queue vs all letters).
              Row(children: [
                _scope('Awaiting reply', 'awaiting', state.scope, n),
                const SizedBox(width: 10),
                _scope('All letters', 'all', state.scope, n),
              ]),
              const SizedBox(height: 10),
              ErpSearchField(hint: 'Search subject, party, ref…', onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 10),
              ErpFilterChips(options: dirOptions, selected: _direction, accent: _accent, onSelect: (v) => setState(() => _direction = v)),
            ]),
          ),
          Expanded(
            child: state.isLoading && rows.isEmpty
                ? const LoadingIndicator(message: 'Loading letters…')
                : state.error != null && rows.isEmpty
                    ? ErrorStateWidget(message: state.error!, onRetry: n.load)
                    : RefreshIndicator(
                        onRefresh: n.load,
                        child: filtered.isEmpty
                            ? ListView(children: [
                                ErpEmpty(
                                  icon: state.scope == 'awaiting' ? Icons.mark_email_read_outlined : Icons.mail_outline,
                                  text: state.scope == 'awaiting' ? 'Nothing awaiting reply 🎉' : 'No matching letters',
                                ),
                              ])
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                                children: filtered.map(_letterCard).toList(),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _scope(String label, String scope, String active, LettersNotifier n) {
    final on = scope == active;
    return Expanded(
      child: GestureDetector(
        onTap: () => n.setScope(scope),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? _accent : AppColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: on ? Colors.transparent : AppColors.border),
            boxShadow: on ? [BoxShadow(color: _accent.withValues(alpha: 0.28), blurRadius: 6, offset: const Offset(0, 2))] : null,
          ),
          child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _letterCard(Letter l) {
    final inward = !l.isOutward;
    final overdue = l.daysOverdue;
    final accent = overdue != null && overdue >= 0 ? AppColors.danger : ErpCard.statusColor(l.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: accent),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/correspondence/${l.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: (inward ? _accent : const Color(0xFF7C3AED)).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                      child: Icon(inward ? Icons.call_received : Icons.call_made, size: 19, color: inward ? _accent : const Color(0xFF7C3AED)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.subject, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
                        const SizedBox(height: 3),
                        Text([l.partyName, l.category].where((e) => e != null && e.isNotEmpty).join(' · ').replaceAll('_', ' '),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 7),
                        Row(children: [
                          _chip(l.status.replaceAll('_', ' '), ErpCard.statusColor(l.status)),
                          if (l.priority == 'HIGH' || l.priority == 'URGENT') ...[
                            const SizedBox(width: 6),
                            _chip(l.priority, AppColors.danger),
                          ],
                          const Spacer(),
                          if (overdue != null && overdue >= 0)
                            Text(overdue == 0 ? 'due today' : '${overdue}d overdue', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
      );
}
