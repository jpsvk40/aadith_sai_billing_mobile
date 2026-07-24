import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/legal_case_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../erp/screens/erp_common.dart';
import '../providers/legal_cases_provider.dart';
import '../providers/letters_provider.dart';

const _accent = Color(0xFF6366F1); // indigo — matches the web Legal Cases tab

/// Correspondence — Legal Cases. Gradient hero with open/hearing totals, a status
/// filter, a type/sort filter sheet, search, and status-accented cards. Tap a
/// case to view it; the FAB opens the New Case form.
class LegalCasesScreen extends ConsumerStatefulWidget {
  const LegalCasesScreen({super.key});
  @override
  ConsumerState<LegalCasesScreen> createState() => _LegalCasesScreenState();
}

class _LegalCasesScreenState extends ConsumerState<LegalCasesScreen> {
  String _status = 'all'; // 'all' | one of kCaseStatuses
  String _q = '';
  final _filter = ListFilterState();
  SortSpec? _sort;

  static const _sortOptions = <SortSpec>[
    SortSpec('hearing', 'Next Hearing', ascending: true),
    SortSpec('claim', 'Claim Amount'),
    SortSpec('code', 'Case Code'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(legalCasesProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(legalCasesProvider);
    final n = ref.read(legalCasesProvider.notifier);
    final rows = state.cases;
    final typeFilter = _filter.select('caseType');

    var filtered = rows.where((c) {
      if (_status != 'all' && c.status != _status) return false;
      if (typeFilter != null && typeFilter.isNotEmpty && c.caseType != typeFilter) return false;
      if (_q.isEmpty) return true;
      final s = _q.toLowerCase();
      return c.title.toLowerCase().contains(s) ||
          c.caseCode.toLowerCase().contains(s) ||
          (c.opposingParty ?? '').toLowerCase().contains(s) ||
          (c.forum ?? '').toLowerCase().contains(s) ||
          (c.caseNumber ?? '').toLowerCase().contains(s);
    }).toList();

    if (_sort != null) {
      filtered = applySort<LegalCase>(filtered, _sort!, (c, key) {
        switch (key) {
          case 'hearing':
            return c.nextHearingDate;
          case 'claim':
            return c.claimAmount;
          case 'code':
            return c.caseCode;
        }
        return null;
      });
    }

    final statusOptions = buildFixedStatusOptions(kCaseStatuses, rows.map((c) => c.status));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Legal Cases')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewCase,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Case'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(children: [
              ErpHero(gradient: const [_accent, Color(0xFF4F46E5)], icon: Icons.gavel, stats: [
                ('Cases', '${rows.length}'),
                ('Open', '${state.openCount}'),
                ('Hearings ≤30d', '${state.upcomingHearings}'),
              ]),
              const SizedBox(height: 12),
              ErpSearchField(hint: 'Search title, party, forum, no…', onChanged: (v) => setState(() => _q = v)),
              const SizedBox(height: 10),
              FilterSortButtons(
                activeFilterCount: _filter.activeCount,
                onFilterTap: _openFilters,
                sortOptions: _sortOptions,
                currentSort: _sort,
                onSortChanged: (s) => setState(() => _sort = s),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              ErpFilterChips(options: statusOptions, selected: _status, accent: _accent, onSelect: (v) => setState(() => _status = v)),
            ]),
          ),
          Expanded(
            child: state.isLoading && rows.isEmpty
                ? const LoadingIndicator(message: 'Loading cases…')
                : state.error != null && rows.isEmpty
                    ? ErrorStateWidget(message: state.error!, onRetry: n.load)
                    : RefreshIndicator(
                        onRefresh: n.load,
                        child: filtered.isEmpty
                            ? ListView(children: const [
                                ErpEmpty(icon: Icons.gavel_outlined, text: 'No matching cases'),
                              ])
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                                children: filtered.map(_caseCard).toList(),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _caseCard(LegalCase c) {
    final d = c.daysToHearing;
    String? badge;
    if (d != null && d >= 0 && d <= 30) badge = d == 0 ? 'hearing today' : 'hearing ${d}d';
    return GestureDetector(
      onTap: () => context.push('/correspondence/cases/${c.id}'),
      child: ErpCard(
        icon: Icons.gavel,
        color: _accent,
        title: c.title,
        code: c.caseCode,
        status: c.status,
        badge: badge,
        badgeColor: (d != null && d <= 3) ? AppColors.danger : _accent,
        rows: [
          ('Type', c.caseType.replaceAll('_', ' ')),
          if (c.opposingParty != null && c.opposingParty!.isNotEmpty) ('Opposing', c.opposingParty!),
          if (c.claimAmount != null) ('Claim', CurrencyUtils.formatCompact(c.claimAmount)),
          if (c.nextHearingDate != null) ('Next Hearing', _fmtDate(c.nextHearingDate)),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final result = await showListFilterSheet(
      context,
      initial: _filter,
      showPeriods: false,
      showDateRange: false,
      selects: const [
        SelectFilter(key: 'caseType', label: 'Case Type', options: kCaseTypes),
      ],
    );
    if (result != null && mounted) {
      setState(() {
        _filter
          ..selects.clear()
          ..selects.addAll(result.selects);
      });
    }
  }

  Future<void> _openNewCase() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const NewCaseSheet(),
    );
    if (created == true) ref.read(legalCasesProvider.notifier).load();
  }
}

String _fmtDate(DateTime? dt) => dt == null
    ? '—'
    : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

/// Bottom-sheet form to create a new case. Only Title is required by the backend;
/// everything else is optional and mirrors the web CaseForm.
class NewCaseSheet extends ConsumerStatefulWidget {
  const NewCaseSheet({super.key});
  @override
  ConsumerState<NewCaseSheet> createState() => _NewCaseSheetState();
}

class _NewCaseSheetState extends ConsumerState<NewCaseSheet> {
  final _title = TextEditingController();
  final _opposing = TextEditingController();
  final _forum = TextEditingController();
  final _caseNo = TextEditingController();
  final _claim = TextEditingController();
  final _advocate = TextEditingController();
  final _notes = TextEditingController();

  String _type = 'ARBITRATION';
  String _role = 'CLAIMANT';
  String _status = 'NOTICE';
  DateTime? _nextHearing;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _opposing.dispose();
    _forum.dispose();
    _caseNo.dispose();
    _claim.dispose();
    _advocate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(correspondenceRepositoryProvider).createCase({
        'title': _title.text.trim(),
        'caseType': _type,
        'ourRole': _role,
        'status': _status,
        if (_opposing.text.trim().isNotEmpty) 'opposingParty': _opposing.text.trim(),
        if (_forum.text.trim().isNotEmpty) 'forum': _forum.text.trim(),
        if (_caseNo.text.trim().isNotEmpty) 'caseNumber': _caseNo.text.trim(),
        if (_claim.text.trim().isNotEmpty) 'claimAmount': _claim.text.trim(),
        if (_advocate.text.trim().isNotEmpty) 'advocateName': _advocate.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (_nextHearing != null) 'nextHearingDate': _nextHearing!.toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickHearing() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextHearing ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _nextHearing = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('New Legal Case', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(10)),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _field('Title *', _title, hint: 'e.g. Fabicon vs XYZ — RA bill dispute'),
                  const SizedBox(height: 14),
                  _dropdown('Type', _type, kCaseTypes, (v) => setState(() => _type = v)),
                  const SizedBox(height: 14),
                  _field('Opposing Party', _opposing),
                  const SizedBox(height: 14),
                  _dropdown('Our Role', _role, kCaseRoles, (v) => setState(() => _role = v)),
                  const SizedBox(height: 14),
                  _field('Forum / Tribunal', _forum),
                  const SizedBox(height: 14),
                  _field('Case No.', _caseNo),
                  const SizedBox(height: 14),
                  _field('Claim (₹)', _claim, keyboard: TextInputType.number),
                  const SizedBox(height: 14),
                  _field('Advocate', _advocate),
                  const SizedBox(height: 14),
                  _dropdown('Status', _status, kCaseStatuses, (v) => setState(() => _status = v)),
                  const SizedBox(height: 14),
                  _dateBox('Next Hearing', _nextHearing, _pickHearing),
                  const SizedBox(height: 14),
                  _field('Notes', _notes, maxLines: 3),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Case', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textSecondary)),
      );

  Widget _field(String label, TextEditingController c, {String? hint, TextInputType? keyboard, int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
    ]);
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: options.map((o) => DropdownMenuItem<String>(value: o, child: Text(o.replaceAll('_', ' ')))).toList(),
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    ]);
  }

  Widget _dateBox(String label, DateTime? value, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Text(value == null ? 'Not set' : _fmtDate(value),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: value == null ? AppColors.textMuted : AppColors.textPrimary)),
          ]),
        ),
      ),
    ]);
  }
}
