import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/legal_case_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/legal_cases_provider.dart';
import '../providers/letters_provider.dart';

const _accent = Color(0xFF6366F1);

/// A single legal case — full details, tap-to-advance status, a proceedings
/// timeline, and an inline "Add Proceeding" form. Mirrors web LegalCaseDetail.jsx.
class LegalCaseDetailScreen extends ConsumerStatefulWidget {
  final int caseId;
  const LegalCaseDetailScreen({super.key, required this.caseId});
  @override
  ConsumerState<LegalCaseDetailScreen> createState() => _LegalCaseDetailScreenState();
}

class _LegalCaseDetailScreenState extends ConsumerState<LegalCaseDetailScreen> {
  LegalCase? _case;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  // Add-proceeding form
  DateTime _procDate = DateTime.now();
  String _stage = 'HEARING';
  DateTime? _nextDate;
  final _summary = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await ref.read(correspondenceRepositoryProvider).getCase(widget.caseId);
      if (mounted) {
        setState(() {
          _case = c;
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

  Future<void> _setStatus(String status) async {
    if (_busy || _case?.status == status) return;
    setState(() => _busy = true);
    try {
      await ref.read(correspondenceRepositoryProvider).updateCase(widget.caseId, {'status': status});
      ref.read(legalCasesProvider.notifier).load(); // keep the list in sync
      await _load();
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addProceeding() async {
    if (_summary.text.trim().isEmpty && _nextDate == null) {
      _snack('Add a summary or a next date.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(correspondenceRepositoryProvider).addProceeding(widget.caseId, {
        'proceedingDate': _procDate.toIso8601String(),
        'stage': _stage,
        if (_summary.text.trim().isNotEmpty) 'summary': _summary.text.trim(),
        if (_nextDate != null) 'nextDate': _nextDate!.toIso8601String(),
      });
      _summary.clear();
      setState(() {
        _procDate = DateTime.now();
        _stage = 'HEARING';
        _nextDate = null;
      });
      ref.read(legalCasesProvider.notifier).load(); // nextHearingDate may have changed
      await _load();
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProceeding(int id) async {
    setState(() => _busy = true);
    try {
      await ref.read(correspondenceRepositoryProvider).deleteProceeding(id);
      await _load();
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final c = _case;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(c?.caseCode ?? 'Case')),
      body: _loading
          ? const LoadingIndicator(message: 'Loading case…')
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : c == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        _header(c),
                        const SizedBox(height: 14),
                        _statusChips(c),
                        const SizedBox(height: 14),
                        _metaCard(c),
                        if (c.notes != null && c.notes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _section('Notes', c.notes!.trim()),
                        ],
                        const SizedBox(height: 14),
                        _addProceedingCard(),
                        const SizedBox(height: 14),
                        _proceedingsCard(c),
                      ],
                    ),
    );
  }

  Widget _header(LegalCase c) {
    final sub = [
      c.caseType.replaceAll('_', ' '),
      if (c.forum != null && c.forum!.isNotEmpty) c.forum,
      if (c.caseNumber != null && c.caseNumber!.isNotEmpty) c.caseNumber,
    ].whereType<String>().join(' · ');
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
        child: const Icon(Icons.gavel, color: _accent),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _chip(c.status.replaceAll('_', ' '), _statusColor(c.status)),
        ]),
      ),
    ]);
  }

  Widget _statusChips(LegalCase c) => _card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: kCaseStatuses.map((s) {
              final on = c.status == s;
              return GestureDetector(
                onTap: _busy ? null : () => _setStatus(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: on ? _accent : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: on ? Colors.transparent : AppColors.border),
                  ),
                  child: Text(s.replaceAll('_', ' '),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.textSecondary)),
                ),
              );
            }).toList()),
          ]),
        ),
      );

  Widget _metaCard(LegalCase c) {
    final rows = <(String, String?)>[
      ('Opposing Party', c.opposingParty),
      ('Our Role', c.ourRole.replaceAll('_', ' ')),
      ('Forum / Tribunal', c.forum),
      ('Case Number', c.caseNumber),
      ('Filing Date', _fmtDate(c.filingDate)),
      ('Claim Amount', c.claimAmount != null ? CurrencyUtils.format(c.claimAmount) : null),
      ('Counter-claim', c.counterClaimAmount != null ? CurrencyUtils.format(c.counterClaimAmount) : null),
      ('Advocate', c.advocateName),
      ('Advocate Contact', c.advocateContact),
      ('Next Hearing', _fmtDate(c.nextHearingDate)),
      ('Award Amount', c.awardAmount != null ? CurrencyUtils.format(c.awardAmount) : null),
      ('Outcome', c.outcome),
    ].where((r) => r.$2 != null && r.$2!.isNotEmpty).toList();
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(rows.length, (i) => Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 11),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 130, child: Text(rows[i].$1, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
                  Expanded(child: Text(rows[i].$2!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                ]),
              )),
        ),
      ),
    );
  }

  Widget _addProceedingCard() => _card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Proceeding', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dateBox('Date', _procDate, () => _pickDate(true))),
              const SizedBox(width: 10),
              Expanded(child: _dateBox('Next Date', _nextDate, () => _pickDate(false))),
            ]),
            const SizedBox(height: 12),
            _label('Stage'),
            DropdownButtonFormField<String>(
              initialValue: _stage,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: kProceedingStages.map((s) => DropdownMenuItem<String>(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
              onChanged: (v) => v == null ? null : setState(() => _stage = v),
            ),
            const SizedBox(height: 12),
            _label('Summary'),
            TextField(
              controller: _summary,
              maxLines: 3,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _addProceeding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Proceeding', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      );

  Widget _proceedingsCard(LegalCase c) {
    final ps = c.proceedings;
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Proceedings Timeline (${ps.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          if (ps.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No proceedings recorded yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
          ...ps.map((pr) => Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 78, child: Text(_fmtDate(pr.proceedingDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(pr.stage.replaceAll('_', ' '), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        if (pr.nextDate != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('· next ${_fmtDate(pr.nextDate)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          ),
                      ]),
                      if (pr.summary != null && pr.summary!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(pr.summary!.trim(), style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary)),
                        ),
                    ]),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => _deleteProceeding(pr.id),
                    icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.danger),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(left: 8),
                  ),
                ]),
              )),
        ]),
      ),
    );
  }

  Future<void> _pickDate(bool proceeding) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (proceeding ? _procDate : _nextDate) ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (proceeding) {
          _procDate = picked;
        } else {
          _nextDate = picked;
        }
      });
    }
  }

  Widget _section(String title, String body) => _card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.textPrimary)),
          ]),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textSecondary)),
      );

  Widget _dateBox(String label, DateTime? value, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(value == null ? 'Any' : _fmtDate(value),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value == null ? AppColors.textMuted : AppColors.textPrimary)),
            ),
          ]),
        ),
      ),
    ]);
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
      case 'SETTLED':
      case 'CLOSED':
        return AppColors.success;
      case 'AWARD':
        return AppColors.primary;
      case 'IN_PROGRESS':
      case 'APPEAL':
        return const Color(0xFFF59E0B);
      case 'FILED':
        return const Color(0xFF0891B2);
      default: // NOTICE
        return AppColors.textMuted;
    }
  }
}

String _fmtDate(DateTime? dt) => dt == null
    ? '—'
    : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
