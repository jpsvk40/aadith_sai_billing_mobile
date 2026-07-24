import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/platform_company_model.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../providers/super_admin_providers.dart';
import '../widgets/sa_kit.dart';

/// Super Admin · Companies — the tenant directory.
///
/// A searchable, filterable roster of every tenant company. Search matches on
/// name / primary-admin email / GSTIN; status chips carry live counts and a
/// small market segmented control scopes to India / US. Everything is filtered
/// client-side from the single `companiesProvider` pull; tapping a card routes
/// to the full-screen lifecycle manager.
class CompaniesScreen extends ConsumerStatefulWidget {
  const CompaniesScreen({super.key});

  @override
  ConsumerState<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends ConsumerState<CompaniesScreen> {
  final _searchCtrl = TextEditingController();

  String? _status; // null == "All"
  String _market = 'all'; // all | india | us

  // (label, status-value) — value null == show everything.
  static const _statusFilters = <(String, String?)>[
    ('All', null),
    ('Pending', 'pending_review'),
    ('Trial', 'trial_active'),
    ('Active', 'active'),
    ('Expired', 'trial_expired'),
    ('Suspended', 'suspended'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _marketMatches(PlatformCompany c) => _market == 'all' || c.market.toLowerCase() == _market;

  int _countFor(List<PlatformCompany> scoped, String? status) =>
      status == null ? scoped.length : scoped.where((c) => c.status == status).length;

  List<PlatformCompany> _filtered(List<PlatformCompany> all) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return all.where((c) {
      if (!_marketMatches(c)) return false;
      if (_status != null && c.status != _status) return false;
      if (q.isNotEmpty) {
        final hay = [
          c.name,
          c.primaryAdmin?.email ?? '',
          c.billingEmail ?? '',
          c.gstNumber ?? '',
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(companiesProvider);
    final all = async.asData?.value ?? const <PlatformCompany>[];
    final marketScoped = all.where(_marketMatches).toList();

    return Scaffold(
      backgroundColor: saBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(marketScoped),
            Expanded(
              child: async.when(
                data: (list) => _list(context, list),
                loading: () => const LoadingIndicator(),
                error: (e, _) => ErrorStateWidget(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(companiesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header (title · market toggle · search · status chips) ───

  Widget _header(List<PlatformCompany> marketScoped) {
    return Container(
      decoration: const BoxDecoration(
        color: saSurface,
        border: Border(bottom: BorderSide(color: saBorder)),
      ),
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Companies',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: saInk, letterSpacing: -0.3)),
                ),
                _marketToggle(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: saInk),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search name, admin email, GSTIN…',
                hintStyle: const TextStyle(fontSize: 13.5, color: saMuted),
                prefixIcon: const Icon(Icons.search, size: 20, color: saMuted),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: saMuted),
                        onPressed: () => setState(_searchCtrl.clear),
                      ),
                filled: true,
                fillColor: saBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: saBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: saBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: saIndigo, width: 1.4)),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (label, value) = _statusFilters[i];
                return _statusChip(label, value, _countFor(marketScoped, value));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String? value, int count) {
    final selected = _status == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? saInk : saSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? saInk : saBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : saSlate)),
            const SizedBox(width: 5),
            Text('$count',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: (selected ? Colors.white : saSlate).withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _marketToggle() {
    Widget seg(String label, String value) {
      final selected = _market == value;
      return GestureDetector(
        onTap: () => setState(() => _market = value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? saInk : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : saSlate)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: saBg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: saBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('All', 'all'), seg('🇮🇳', 'india'), seg('🇺🇸', 'us')],
      ),
    );
  }

  // ─── Body list ───

  Widget _list(BuildContext context, List<PlatformCompany> all) {
    final visible = _filtered(all);
    return RefreshIndicator(
      color: saIndigo,
      onRefresh: () async => ref.invalidate(companiesProvider),
      child: visible.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [const SizedBox(height: 90), _emptyState(all.isEmpty)],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 28),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 11),
              itemBuilder: (_, i) => _companyCard(context, visible[i]),
            ),
    );
  }

  Widget _emptyState(bool noneAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(noneAtAll ? Icons.apartment_outlined : Icons.search_off_rounded, size: 58, color: saMuted),
            const SizedBox(height: 14),
            Text(
              noneAtAll ? 'No companies yet' : 'No companies match your filters',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: saInk),
            ),
            const SizedBox(height: 6),
            Text(
              noneAtAll
                  ? 'Tenant companies will appear here as they register.'
                  : 'Try a different search term, status, or market.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: saMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _companyCard(BuildContext context, PlatformCompany c) {
    final admin = c.primaryAdmin?.email ?? c.billingEmail ?? '—';
    return SaCard(
      onTap: () => context.push('/superadmin/companies/${c.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SaLogo(c.name, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: saInk)),
                    const SizedBox(height: 2),
                    Text('$admin · ${saMarketFlag(c.market)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: saMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SaStatusPill(c.status),
                  if (c.adminNeedsReset) ...[
                    const SizedBox(height: 6),
                    const SaPill(label: 'Reset', color: saRose, icon: Icons.lock_outline),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 11),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: saLine))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _metaItem('${c.usersCount}', 'users'),
                const SizedBox(width: 20),
                _metaItem('${c.ordersCount}', 'orders'),
                const Spacer(),
                _deadlineBlock(c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: saInk)),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(fontSize: 11, color: saMuted)),
      ],
    );
  }

  Widget _deadlineBlock(PlatformCompany c) {
    final caption = c.trialEndsAt != null
        ? 'trial left'
        : c.subscriptionEndsAt != null
            ? 'renews'
            : c.status == 'pending_review'
                ? 'awaiting'
                : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(saRelativeDays(c.deadline),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: saInk)),
        const SizedBox(height: 1),
        Text(caption, style: const TextStyle(fontSize: 11, color: saMuted)),
      ],
    );
  }
}
