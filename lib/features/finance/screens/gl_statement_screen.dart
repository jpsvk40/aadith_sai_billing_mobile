import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

enum GlStatement { profitLoss, balanceSheet, trialBalance }

/// Read-only GL statements — P&L, Balance Sheet, Trial Balance. Renders the backend's
/// sectioned shape ({section:{groups:[{group,accounts,total}],total}}) as a modern
/// statement: gradient hero with the headline figure + collapsible section cards.
class GlStatementScreen extends ConsumerStatefulWidget {
  const GlStatementScreen({super.key, required this.statement});
  final GlStatement statement;
  @override
  ConsumerState<GlStatementScreen> createState() => _GlStatementScreenState();
}

class _GlStatementScreenState extends ConsumerState<GlStatementScreen> {
  Map<String, dynamic> _data = const {};
  bool _loading = true;
  String? _error;

  // Multi-entity filter: companies with >1 legal entity (GSTIN) can scope the report to one entity.
  // null = all entities (consolidated, the default). Only shown when the company is multi-entity.
  List<Map<String, dynamic>> _entities = const [];
  bool _multiEntity = false;
  int? _entityId;

  String get _url => _entityId != null ? '$_endpoint?legalEntityId=$_entityId' : _endpoint;

  String get _title => switch (widget.statement) {
        GlStatement.profitLoss => 'Profit & Loss',
        GlStatement.balanceSheet => 'Balance Sheet',
        GlStatement.trialBalance => 'Trial Balance',
      };

  String get _endpoint => switch (widget.statement) {
        GlStatement.profitLoss => ApiConstants.glProfitLoss,
        GlStatement.balanceSheet => ApiConstants.glBalanceSheet,
        GlStatement.trialBalance => ApiConstants.glTrialBalance,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _loadEntities(); _load(); });
  }

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());

  // Load the company's legal entities once — if it is multi-entity, the entity picker appears.
  Future<void> _loadEntities() async {
    try {
      final data = await _client.get(ApiConstants.legalEntitiesSummary);
      if (!mounted || data is! Map) return;
      final list = ((data['entities'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      setState(() { _entities = list; _multiEntity = data['mode'] == 'multi'; });
    } catch (_) {/* entity picker is optional — ignore and stay consolidated */}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _client.get(_url);
      if (!mounted) return;
      setState(() { _data = data is Map ? data.cast<String, dynamic>() : const {}; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_title)),
      body: Column(
        children: [
          if (_multiEntity) _entitySelector(),
          Expanded(
            child: _loading
                ? const LoadingIndicator()
                : _error != null
                    ? ErrorStateWidget(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                          children: switch (widget.statement) {
                            GlStatement.profitLoss => _buildPnl(),
                            GlStatement.balanceSheet => _buildBalanceSheet(),
                            GlStatement.trialBalance => _buildTrialBalance(),
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // Horizontal entity picker (All + one chip per legal entity). Passes ?legalEntityId to the report.
  Widget _entitySelector() {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _entityChip('All entities', null),
            ..._entities.map((e) => _entityChip(
                  e['name']?.toString() ?? 'Entity',
                  int.tryParse(e['id']?.toString() ?? ''),
                )),
          ],
        ),
      ),
    );
  }

  Widget _entityChip(String label, int? id) {
    final selected = _entityId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.background,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        onSelected: (_) {
          if (_entityId != id) { setState(() => _entityId = id); _load(); }
        },
      ),
    );
  }

  // ── Profit & Loss ──
  List<Widget> _buildPnl() {
    final netProfit = _num(_data['netProfit']);
    final positive = netProfit >= 0;
    return [
      _hero(
        label: positive ? 'Net Profit' : 'Net Loss',
        value: CurrencyUtils.format(netProfit.abs()),
        colors: positive ? const [Color(0xFF16A34A), Color(0xFF15803D)] : const [Color(0xFFDC2626), Color(0xFFB91C1C)],
        icon: positive ? Icons.trending_up : Icons.trending_down,
        chips: [
          ('Income', CurrencyUtils.format(_num(_data['totalIncome']))),
          ('Gross Profit', CurrencyUtils.format(_num(_data['grossProfit']))),
        ],
      ),
      const SizedBox(height: 14),
      _sectionCard('Trading Income', _data['tradingIncome'], const Color(0xFF16A34A)),
      _sectionCard('Direct Expenses', _data['directExpenses'], const Color(0xFFDC2626)),
      _totalBanner('Gross Profit', _num(_data['grossProfit'])),
      _sectionCard('Indirect Income', _data['indirectIncome'], const Color(0xFF0891B2)),
      _sectionCard('Indirect Expenses', _data['indirectExpenses'], const Color(0xFFD97706)),
      _totalBanner(positive ? 'Net Profit' : 'Net Loss', netProfit),
    ];
  }

  // ── Balance Sheet ──
  List<Widget> _buildBalanceSheet() {
    final assets = _num((_data['assets'] as Map?)?['total']);
    final liabilities = _num((_data['liabilities'] as Map?)?['total']);
    final equity = _num((_data['equity'] as Map?)?['total']);
    return [
      _hero(
        label: 'Total Assets',
        value: CurrencyUtils.format(assets),
        colors: const [Color(0xFF9333EA), Color(0xFF7E22CE)],
        icon: Icons.account_balance_wallet_outlined,
        chips: [
          ('Liabilities', CurrencyUtils.format(liabilities)),
          ('Equity', CurrencyUtils.format(equity)),
        ],
      ),
      const SizedBox(height: 14),
      _sectionCard('Assets', _data['assets'], const Color(0xFF9333EA)),
      _sectionCard('Liabilities', _data['liabilities'], const Color(0xFFDC2626)),
      _sectionCard('Equity', _data['equity'], const Color(0xFF0891B2)),
    ];
  }

  // ── Trial Balance ──
  List<Widget> _buildTrialBalance() {
    final rows = ((_data['rows'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    final totalDr = rows.fold<double>(0, (a, r) => a + _num(r['debit']));
    final totalCr = rows.fold<double>(0, (a, r) => a + _num(r['credit']));
    final balanced = (totalDr - totalCr).abs() < 0.01;
    return [
      _hero(
        label: balanced ? 'Balanced ✓' : 'Out of balance',
        value: CurrencyUtils.format(totalDr),
        colors: balanced ? const [Color(0xFF0D9488), Color(0xFF0F766E)] : const [Color(0xFFDC2626), Color(0xFFB91C1C)],
        icon: Icons.balance_outlined,
        chips: [
          ('Debit', CurrencyUtils.format(totalDr)),
          ('Credit', CurrencyUtils.format(totalCr)),
        ],
      ),
      const SizedBox(height: 14),
      // Column headers
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: const [
          Expanded(flex: 5, child: Text('Ledger', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
          Expanded(flex: 3, child: Text('Debit', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
          Expanded(flex: 3, child: Text('Credit', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
        ]),
      ),
      ...rows.map((r) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 0.5)),
            child: Row(children: [
              Expanded(
                flex: 5,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['name']?.toString() ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  Text(r['group']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                ]),
              ),
              Expanded(flex: 3, child: Text(_num(r['debit']) == 0 ? '–' : CurrencyUtils.format(_num(r['debit'])), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              Expanded(flex: 3, child: Text(_num(r['credit']) == 0 ? '–' : CurrencyUtils.format(_num(r['credit'])), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)))),
            ]),
          )),
      if (rows.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No ledgers yet', style: TextStyle(color: AppColors.textSecondary)))),
    ];
  }

  // ── Shared pieces ──
  Widget _hero({required String label, required String value, required List<Color> colors, required IconData icon, List<(String, String)> chips = const []}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(children: [
          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              ]),
            ]),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: chips.map((c) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: c == chips.last ? 0 : 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 2),
                    Text(c.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ),
              )).toList()),
            ],
          ]),
        ]),
      ),
    );
  }

  /// One statement section ({groups:[{group,accounts:[{name,amount}],total}],total}).
  Widget _sectionCard(String title, dynamic section, Color color) {
    final map = section is Map ? section.cast<String, dynamic>() : const <String, dynamic>{};
    final groups = ((map['groups'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    final total = _num(map['total']);
    if (groups.isEmpty && total == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 0.5)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.folder_outlined, color: color, size: 19),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          trailing: Text(CurrencyUtils.format(total), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: color)),
          children: groups.expand((g) {
            final accounts = ((g['accounts'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
            return [
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(children: [
                  Expanded(child: Text(g['group']?.toString() ?? '', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
                  Text(CurrencyUtils.format(_num(g['total'])), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ]),
              ),
              ...accounts.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      const SizedBox(width: 10),
                      Expanded(child: Text(a['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
                      Text(CurrencyUtils.format(_num(a['amount'])), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                  )),
            ];
          }).toList(),
        ),
      ),
    );
  }

  Widget _totalBanner(String label, double value) {
    final positive = value >= 0;
    final color = positive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(children: [
        Icon(positive ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color))),
        Text(CurrencyUtils.format(value.abs()), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: color)),
      ]),
    );
  }
}
