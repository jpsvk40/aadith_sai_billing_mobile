import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/models/collection_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/providers/financial_year_provider.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/list_controls.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _teal = Color(0xFF0D9488);

/// How the assignment list is grouped into collapsible sections. Mirrors the
/// web CollectionPage group tabs (byRep / byDistrict / byCustomer). "Area" maps
/// to district (falling back to city).
enum _GroupBy { none, rep, area, customer }

/// Collections — role-aware. A collection rep sees only their own assignments
/// (backend self-scopes); an admin/manager sees the whole book.
///
/// Server-side filters (rep, status, period/date range, financial year) are
/// threaded to `GET /collections`. Client-side controls (search, district,
/// sort, group-by) run over the loaded list — mirroring the web portal.
class CollectionListScreen extends ConsumerStatefulWidget {
  const CollectionListScreen({super.key});

  @override
  ConsumerState<CollectionListScreen> createState() => _CollectionListScreenState();
}

class _CollectionListScreenState extends ConsumerState<CollectionListScreen> {
  List<Collection> _all = const [];
  List<Map<String, dynamic>> _reps = const [];
  bool _loading = true;
  String? _error;

  // ── Server-side filters ──
  int? _repId; // null = all reps (admin only)
  String _status = 'All'; // sent as `status` when != 'All'
  ListFilterState _filter = ListFilterState(); // period / date range / FY / district(client)

  // ── Client-side controls ──
  String _search = '';
  SortSpec? _sort; // null = server order (createdAt desc)
  _GroupBy _group = _GroupBy.none;
  final Set<String> _collapsed = {}; // collapsed group keys

  static const _statuses = ['All', 'Pending', 'Partial', 'Collected'];

  static const _sortOptions = [
    SortSpec('customer', 'Customer', ascending: true),
    SortSpec('balance', 'Balance'),
    SortSpec('date', 'Date'),
  ];

  bool get _isRep {
    final u = ref.read(authProvider).user;
    return u?.isSalesRep == true || u?.isCollectionRep == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      if (!_isRep) _loadReps();
    });
  }

  String _d(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Signature of the server-relevant filter fields — used to decide whether an
  /// edited filter needs a re-fetch (period/date/FY) or just a client re-render
  /// (district is applied locally).
  String _serverSig(ListFilterState f) =>
      '${f.period}|${f.dateFromParam}|${f.dateToParam}|${f.financialYearId}';

  Future<void> _loadReps() async {
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final data = await client.get(ApiConstants.collectionReps);
      if (!mounted) return;
      setState(() => _reps = (data is List ? data : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList());
    } catch (_) {/* rep filter just stays hidden */}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final f = _filter;
      final hasPeriod = f.period != null && f.period!.isNotEmpty;
      final data = await client.get(ApiConstants.collections, queryParams: {
        if (_repId != null) 'repId': '$_repId',
        if (_status != 'All') 'status': _status,
        if (f.financialYearId != null && f.financialYearId!.isNotEmpty) 'financialYearId': f.financialYearId!,
        if (hasPeriod) 'period': f.period!,
        if (!hasPeriod && f.dateFromParam != null) 'dateFrom': f.dateFromParam!,
        if (!hasPeriod && f.dateToParam != null) 'dateTo': f.dateToParam!,
      });
      if (!mounted) return;
      setState(() {
        _all = (data is List ? data : const [])
            .whereType<Map>()
            .map((e) => Collection.fromJson(e.cast<String, dynamic>()))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Distinct districts across the loaded book — feeds the client-side District
  /// filter in the sheet.
  List<String> _distinctDistricts() {
    final set = <String>{};
    for (final c in _all) {
      final d = (c.district ?? '').trim();
      if (d.isNotEmpty) set.add(d);
    }
    final list = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Search + client District filter, then optional sort.
  List<Collection> get _visible {
    final q = _search.trim().toLowerCase();
    final district = _filter.select('district');
    var list = _all.where((c) {
      if (district != null && district.isNotEmpty && (c.district ?? '') != district) return false;
      if (q.isEmpty) return true;
      return (c.customerName ?? '').toLowerCase().contains(q) ||
          (c.invoiceNo ?? '').toLowerCase().contains(q) ||
          (c.representativeName ?? '').toLowerCase().contains(q) ||
          (c.city ?? '').toLowerCase().contains(q) ||
          (c.district ?? '').toLowerCase().contains(q);
    }).toList();

    final sort = _sort;
    if (sort != null) {
      list = applySort<Collection>(list, sort, (c, key) {
        switch (key) {
          case 'customer':
            return (c.customerName ?? '').toLowerCase();
          case 'balance':
            return c.balanceAmount;
          case 'date':
            return c.assignedDate;
        }
        return null;
      });
    }
    return list;
  }

  (String, String) _groupKeyLabel(Collection c) {
    switch (_group) {
      case _GroupBy.rep:
        final n = (c.representativeName ?? '').trim();
        return n.isEmpty ? ('__none', 'Unassigned') : (n, n);
      case _GroupBy.area:
        final d = (c.district ?? '').trim();
        final v = d.isNotEmpty ? d : (c.city ?? '').trim();
        return v.isEmpty ? ('__none', 'No area') : (v, v);
      case _GroupBy.customer:
        final n = (c.customerName ?? '').trim();
        return n.isEmpty ? ('__none', 'Customer') : (n, n);
      case _GroupBy.none:
        return ('', '');
    }
  }

  List<_Group> _buildGroups(List<Collection> items) {
    final map = <String, _Group>{};
    for (final c in items) {
      final (key, label) = _groupKeyLabel(c);
      final g = map.putIfAbsent(key, () => _Group(key, label));
      g.items.add(c);
      g.bill += c.totalOutstanding;
      g.collected += c.collectedAmount ?? 0;
      g.balance += c.balanceAmount;
    }
    return map.values.toList()..sort((a, b) => b.balance.compareTo(a.balance));
  }

  Color _statusColor(String s) => switch (s.toLowerCase()) {
        'collected' || 'settled' || 'completed' => AppColors.success,
        'partial' => const Color(0xFFD97706),
        'failed' => AppColors.danger,
        _ => const Color(0xFF2563EB), // Pending
      };

  Future<void> _openFilters() async {
    final fyData = await ref.read(financialYearsProvider.future);
    if (!mounted) return;
    final districts = _distinctDistricts();
    final before = _serverSig(_filter);
    final result = await showListFilterSheet(
      context,
      initial: _filter,
      financialYears: fyData.years,
      selects: [
        if (districts.isNotEmpty)
          SelectFilter(key: 'district', label: 'District', options: districts),
      ],
    );
    if (result == null || !mounted) return;
    final serverChanged = before != _serverSig(result);
    setState(() => _filter = result);
    if (serverChanged) _load();
  }

  // Distinct customers in the loaded book → pick one for a PDF / WhatsApp statement.
  void _openStatementPicker() {
    final map = <String, _CustStmt>{};
    for (final c in _all) {
      final id = c.customerId;
      if (id == null || id.isEmpty) continue;
      final e = map.putIfAbsent(id, () => _CustStmt(id, c.customerName ?? 'Customer', c.city, c.customerPhone));
      e.items.add(c);
      e.balance += c.balanceAmount;
    }
    final customers = map.values.toList()..sort((a, b) => b.balance.compareTo(a.balance));
    String q = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = q.isEmpty
              ? customers
              : customers.where((e) => e.name.toLowerCase().contains(q) || (e.city ?? '').toLowerCase().contains(q)).toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            builder: (ctx, scrollCtrl) => Column(children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(children: [
                  const Icon(Icons.description_outlined, color: _teal, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Pick a customer for a statement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
                  Text('${customers.length}', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setSheet(() => q = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search customer or city…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final e = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _teal.withValues(alpha: 0.12),
                        child: Text(e.name.isNotEmpty ? e.name[0].toUpperCase() : '?', style: const TextStyle(color: _teal, fontWeight: FontWeight.w800)),
                      ),
                      title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      subtitle: Text('${e.items.length} invoice${e.items.length == 1 ? '' : 's'}${(e.city ?? '').isNotEmpty ? ' · ${e.city}' : ''}', style: const TextStyle(fontSize: 11.5)),
                      trailing: Text(CurrencyUtils.format(e.balance), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: e.balance > 0 ? AppColors.danger : AppColors.success)),
                      onTap: () {
                        Navigator.pop(ctx);
                        context.push('/collections/statement/${e.id}', extra: {
                          'customerName': e.name,
                          'city': e.city,
                          'phone': e.phone,
                          'items': e.items,
                        });
                      },
                    );
                  },
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final isRep = _isRep;

    // Flatten into renderable entries so grouped sections stay lazy in the builder.
    final entries = <_Entry>[];
    if (_group == _GroupBy.none) {
      for (final c in visible) {
        entries.add(_Entry.card(c));
      }
    } else {
      for (final g in _buildGroups(visible)) {
        entries.add(_Entry.header(g));
        if (!_collapsed.contains(g.key)) {
          for (final c in g.items) {
            entries.add(_Entry.card(c));
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            tooltip: 'Customer statement (PDF / WhatsApp)',
            icon: const Icon(Icons.description_outlined),
            onPressed: _all.isEmpty ? null : _openStatementPicker,
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    itemCount: entries.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) return _header(visible, isRep);
                      final e = entries[i - 1];
                      if (e.isHeader) return _groupHeader(e.group!);
                      return _card(e.card!, showRep: !isRep && _group != _GroupBy.rep);
                    },
                  ),
                ),
    );
  }

  Widget _header(List<Collection> visible, bool isRep) {
    double toCollect = 0, collected = 0;
    int pending = 0, partial = 0, done = 0;
    for (final c in visible) {
      toCollect += c.balanceAmount;
      collected += c.collectedAmount ?? 0;
      switch (c.status.toLowerCase()) {
        case 'partial':
          partial++;
        case 'collected' || 'settled' || 'completed':
          done++;
        default:
          pending++;
      }
    }
    final total = toCollect + collected;
    final pct = total > 0 ? (collected / total).clamp(0.0, 1.0) : 0.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Hero ──
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_teal, Color(0xFF0F766E)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Stack(children: [
            Positioned(right: -22, top: -22, child: Container(width: 105, height: 105, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Outstanding to collect', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 4),
              Text(CurrencyUtils.format(toCollect), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 7),
              Text('${CurrencyUtils.format(collected)} collected · ${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                _heroCount('Pending', pending),
                _heroCount('Partial', partial),
                _heroCount('Collected', done),
              ]),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      // ── Rep filter (admin only) ──
      if (!isRep && _reps.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _repId,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 20),
              hint: const Text('All reps'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All reps', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                ..._reps.map((r) => DropdownMenuItem<int?>(
                      value: r['id'] as int?,
                      child: Text(r['name']?.toString() ?? '', style: const TextStyle(fontSize: 13.5)),
                    )),
              ],
              onChanged: (v) { setState(() => _repId = v); _load(); },
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      // ── Status chips (server-side) ──
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _statuses.map((s) {
          final sel = _status == s;
          final c = s == 'All' ? AppColors.primary : _statusColor(s);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s),
              selected: sel,
              onSelected: (_) { if (_status == s) return; setState(() => _status = s); _load(); },
              selectedColor: c.withValues(alpha: 0.15),
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? c : AppColors.textSecondary),
            ),
          );
        }).toList()),
      ),
      const SizedBox(height: 8),
      // ── Search ──
      TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search customer, invoice, rep, city or district…',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        ),
      ),
      const SizedBox(height: 10),
      // ── Filters + Sort ──
      FilterSortButtons(
        activeFilterCount: _filter.activeCount,
        onFilterTap: _openFilters,
        sortOptions: _sortOptions,
        currentSort: _sort,
        onSortChanged: (s) => setState(() => _sort = s),
        padding: const EdgeInsets.only(bottom: 10),
      ),
      // ── Group-by ──
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.workspaces_outline, size: 16, color: AppColors.textMuted)),
          _groupChip('No grouping', _GroupBy.none),
          _groupChip('By rep', _GroupBy.rep),
          _groupChip('By area', _GroupBy.area),
          _groupChip('By customer', _GroupBy.customer),
        ]),
      ),
      const SizedBox(height: 12),
      Text('${visible.length} assignment${visible.length == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      if (visible.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No collections match these filters', style: TextStyle(color: AppColors.textSecondary)))),
    ]);
  }

  Widget _groupChip(String label, _GroupBy g) {
    final sel = _group == g;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() { _group = g; _collapsed.clear(); }),
        selectedColor: _teal.withValues(alpha: 0.15),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? _teal : AppColors.textSecondary),
      ),
    );
  }

  Widget _groupHeader(_Group g) {
    final open = !_collapsed.contains(g.key);
    final pct = g.bill > 0 ? (g.collected / g.bill).clamp(0.0, 1.0) : 0.0;
    return InkWell(
      onTap: () => setState(() {
        if (open) {
          _collapsed.add(g.key);
        } else {
          _collapsed.remove(g.key);
        }
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(open ? Icons.keyboard_arrow_down : Icons.chevron_right, size: 22, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(g.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _teal))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                  child: Text('${g.items.length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ]),
              const SizedBox(height: 2),
              Text('${(pct * 100).toStringAsFixed(0)}% collected', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(CurrencyUtils.format(g.balance), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: g.balance > 0 ? AppColors.danger : AppColors.success)),
            Text('of ${CurrencyUtils.format(g.bill)}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCount(String label, int n) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$n', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _card(Collection c, {required bool showRep}) {
    final sc = _statusColor(c.status);
    final overdue = c.dueDate != null && c.dueDate!.isBefore(DateTime.now()) && c.balanceAmount > 0;
    final bill = c.totalOutstanding;
    final got = c.collectedAmount ?? 0;
    final pct = bill > 0 ? (got / bill).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      onTap: () => context.push('/collections/${c.id}').then((_) => _load()),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: overdue ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border, width: overdue ? 1 : 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.customerName ?? 'Customer', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((c.invoiceNo ?? '').isNotEmpty) c.invoiceNo!,
                    if ((c.city ?? '').isNotEmpty) c.city!,
                  ].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: Text(c.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sc)),
            ),
          ]),
          if ((showRep && (c.representativeName ?? '').isNotEmpty) || overdue) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (showRep && (c.representativeName ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _teal.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_outline, size: 12, color: _teal),
                    const SizedBox(width: 3),
                    Text(c.representativeName!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _teal)),
                  ]),
                ),
              if (overdue)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(7)),
                  child: Text('Overdue · due ${_d(c.dueDate!)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                ),
            ]),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 5,
              backgroundColor: AppColors.border.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(pct >= 1 ? AppColors.success : _teal),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _metric('Bill', CurrencyUtils.format(bill)),
            _metric('Collected', CurrencyUtils.format(got)),
            _metric('Balance', CurrencyUtils.format(c.balanceAmount), color: c.balanceAmount > 0 ? AppColors.danger : AppColors.success),
          ]),
        ]),
      ),
    );
  }

  Widget _metric(String label, String value, {Color? color}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary)),
        ]),
      );
}

/// One collapsible group section (rep / area / customer) with running subtotals.
class _Group {
  _Group(this.key, this.label);
  final String key;
  final String label;
  final List<Collection> items = [];
  double bill = 0;
  double collected = 0;
  double balance = 0;
}

/// A flattened list entry — either a group header or a collection card — so the
/// grouped list stays lazy inside a single ListView.builder.
class _Entry {
  final _Group? group;
  final Collection? card;
  _Entry.header(this.group) : card = null;
  _Entry.card(this.card) : group = null;
  bool get isHeader => group != null;
}

/// One customer's aggregated collection line for the statement picker.
class _CustStmt {
  _CustStmt(this.id, this.name, this.city, this.phone);
  final String id;
  final String name;
  final String? city;
  final String? phone;
  final List<Collection> items = [];
  double balance = 0;
}
