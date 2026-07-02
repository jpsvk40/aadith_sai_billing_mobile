import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/letter_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/letters_provider.dart';

const _orange = Color(0xFFF59E0B);

/// A single letter — full content, reply thread, and resolve actions
/// (Mark Closed / Mark Sent / Approve). Read + act; composing stays on web.
class LetterDetailScreen extends ConsumerStatefulWidget {
  final int letterId;
  const LetterDetailScreen({super.key, required this.letterId});
  @override
  ConsumerState<LetterDetailScreen> createState() => _LetterDetailScreenState();
}

class _LetterDetailScreenState extends ConsumerState<LetterDetailScreen> {
  Letter? _letter;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final l = await ref.read(correspondenceRepositoryProvider).getLetter(widget.letterId);
      if (mounted) {
        setState(() {
          _letter = l;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _act(Future<Letter> Function() op, String done) async {
    setState(() => _busy = true);
    try {
      final l = await op();
      if (!mounted) return;
      setState(() {
        _letter = l;
        _busy = false;
      });
      // Refresh the list behind us so the resolved item drops off the queue.
      ref.read(lettersProvider.notifier).load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _letter;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l?.letterCode ?? 'Letter')),
      body: _loading
          ? const LoadingIndicator(message: 'Loading letter…')
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : l == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _header(l),
                        const SizedBox(height: 14),
                        _metaCard(l),
                        if (l.body != null && l.body!.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _section('Letter', l.body!.trim()),
                        ],
                        if (l.remarks != null && l.remarks!.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _section('Remarks', l.remarks!.trim()),
                        ],
                        if (l.replies.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _repliesCard(l),
                        ],
                      ],
                    ),
      bottomNavigationBar: l == null ? null : _actionBar(l),
    );
  }

  Widget _header(Letter l) {
    final inward = !l.isOutward;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: (inward ? AppColors.primary : const Color(0xFF7C3AED)).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(inward ? Icons.call_received : Icons.call_made, color: inward ? AppColors.primary : const Color(0xFF7C3AED)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.subject, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(inward ? 'Inward' : 'Outward', inward ? AppColors.primary : const Color(0xFF7C3AED)),
            _chip(l.status.replaceAll('_', ' '), _statusColor(l.status)),
            if (l.priority == 'HIGH' || l.priority == 'URGENT') _chip(l.priority, AppColors.danger),
            if (l.daysOverdue != null && l.daysOverdue! >= 0)
              _chip(l.daysOverdue == 0 ? 'due today' : '${l.daysOverdue}d overdue', l.daysOverdue! > 0 ? AppColors.danger : _orange),
          ]),
        ]),
      ),
    ]);
  }

  Widget _metaCard(Letter l) {
    String? d(DateTime? dt) => dt == null ? null : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final rows = <(String, String?)>[
      ('Party', [l.partyName, l.partyType == 'OTHER' ? null : l.partyType.replaceAll('_', ' ')].where((e) => e != null && e.isNotEmpty).join(' · ')),
      ('Category', l.category?.replaceAll('_', ' ')),
      ('Reference', l.refNumber),
      ('Letter date', d(l.letterDate)),
      (l.isOutward ? 'Sent date' : 'Received date', d(l.receivedOrSentDate)),
      ('Due date', d(l.dueDate)),
    ].where((r) => r.$2 != null && r.$2!.isNotEmpty).toList();
    return _card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: List.generate(rows.length, (i) => Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(rows[i].$1, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
              Expanded(child: Text(rows[i].$2!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            ]),
          ))),
    ));
  }

  Widget _section(String title, String body) => _card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.textPrimary)),
        ]),
      ));

  Widget _repliesCard(Letter l) => _card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Thread (${l.replies.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          ...l.replies.map((r) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(r.isOutward ? Icons.call_made : Icons.call_received, size: 15, color: r.isOutward ? const Color(0xFF7C3AED) : AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.subject, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text('${r.letterCode} · ${r.status.replaceAll('_', ' ')}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ])),
                ]),
              )),
        ]),
      ));

  Widget _actionBar(Letter l) {
    final actions = <Widget>[];
    if (l.isPendingApproval) {
      actions.add(_btn('Approve', AppColors.primary, () => _act(() => ref.read(correspondenceRepositoryProvider).approve(l.id), 'Letter approved')));
    }
    if (l.canSend) {
      actions.add(_btn('Mark Sent', const Color(0xFF7C3AED), () => _act(() => ref.read(correspondenceRepositoryProvider).setStatus(l.id, 'SENT'), 'Marked as sent')));
    }
    if (!l.isClosed) {
      actions.add(_btn('Mark Closed', AppColors.success, () => _act(() => ref.read(correspondenceRepositoryProvider).setStatus(l.id, 'CLOSED'), 'Letter closed'), outlined: actions.isNotEmpty));
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: actions[i]),
        ],
      ]),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap, {bool outlined = false}) {
    return SizedBox(
      height: 48,
      child: outlined
          ? OutlinedButton(
              onPressed: _busy ? null : onTap,
              style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            )
          : ElevatedButton(
              onPressed: _busy ? null : onTap,
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  Color _statusColor(String s) {
    switch (s) {
      case 'CLOSED':
        return AppColors.success;
      case 'SENT':
      case 'APPROVED':
        return AppColors.primary;
      case 'PENDING_APPROVAL':
        return _orange;
      case 'RECEIVED':
        return const Color(0xFF0891B2);
      default:
        return AppColors.textMuted;
    }
  }
}
