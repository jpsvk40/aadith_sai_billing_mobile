import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/ai_scan_repository.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/mobile_home_model.dart';
import '../../purchases/screens/purchase_create_screen.dart';
import '../providers/home_provider.dart';

// SkillTrackr-style palette
const _heroA = Color(0xFF0369A1);
const _heroB = Color(0xFF1D4ED8);
const _heroC = Color(0xFF1E1B4B);
const _purple = Color(0xFF7C3AED);
const _orange = Color(0xFFF59E0B);
const _statBlue = Color(0xFF60A5FA);
const _statPurple = Color(0xFFA78BFA);
const _statGreen = Color(0xFF4ADE80);
const _statGold = Color(0xFFFBBF24);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(homeProvider.notifier).load());
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _soon(String w) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$w — coming in the next update')));

  Future<void> _startScan() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('Scan a Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ),
            ListTile(leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary), title: const Text('Take Photo'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final XFile? file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 82);
    if (file == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Reading the bill...'),
            ]),
          ),
        ),
      ),
    );

    try {
      final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
      final scanned = await AiScanRepository(client).scanVendorBill(file.path);
      final bytes = await File(file.path).readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
      context.push('/purchases/create', extra: PurchasePrefill(scanned: scanned, imageDataUrl: dataUrl));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read the bill — enter manually. ($e)'), backgroundColor: AppColors.danger),
      );
      context.push('/purchases/create');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeProvider);
    final user = ref.watch(authProvider).user;
    final o = state.overview ?? const HomeOverview();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: state.isLoading && state.overview == null
          ? const LoadingIndicator(message: 'Loading your overview...')
          : state.error != null && state.overview == null
              ? ErrorStateWidget(message: state.error!, onRetry: () => ref.read(homeProvider.notifier).load())
              : RefreshIndicator(
                  onRefresh: () => ref.read(homeProvider.notifier).load(),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      o.isRep ? _repHero(context, o, user) : _hero(context, o, user),
                      _sheet(o.isRep ? _repBody(context, o, user) : _ownerBody(o)),
                    ],
                  ),
                ),
    );
  }

  Widget _sheet(Widget child) => Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26))),
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
          child: child,
        ),
      );

  Widget _ownerBody(HomeOverview o) => Column(
        children: [
          _scanBanner(),
          const SizedBox(height: 20),
          _quickAccess(),
          const SizedBox(height: 20),
          _plCard(o),
          const SizedBox(height: 20),
          _ordersByStatus(o),
          const SizedBox(height: 20),
          _outstandingAndCash(o),
          const SizedBox(height: 20),
          _recentActivity(o),
          const SizedBox(height: 16),
        ],
      );

  // ---------------- Rep Home ----------------
  Widget _repHero(BuildContext context, HomeOverview o, dynamic user) {
    final String name = (o.repName ?? user?.name ?? 'Welcome').toString();
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();
    final stats = _repStats(o);
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_heroA, _heroB, _heroC], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: _circle(200, Colors.white.withValues(alpha: 0.05))),
            Positioned(bottom: -30, left: -20, child: _circle(160, const Color(0xFF6366F1).withValues(alpha: 0.12))),
            Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${_greeting()} 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text("Here's your day", style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                      ]),
                    ),
                    _bell(context),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    Container(
                      width: 56, height: 56, alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2)),
                      child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                          child: Text(_repRoleLabel(o), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _heroStat(stats[i].$1, stats[i].$2, stats[i].$3),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _repRoleLabel(HomeOverview o) {
    if (o.repCanSell && o.repCanCollect) return '🧑‍💼 Sales & Collection';
    if (o.repCanCollect) return '💰 Collection Rep';
    return '🧑‍💼 Sales Rep';
  }

  List<(String, String, Color)> _repStats(HomeOverview o) {
    final list = <(String, String, Color)>[];
    if (o.repCanSell) {
      list.add((CurrencyUtils.formatCompact(o.repSales), 'Sales', _statBlue));
      list.add(('${o.repOrders}', 'Orders', _statPurple));
    }
    if (o.repCanCollect) {
      list.add((CurrencyUtils.formatCompact(o.repCollected), 'Collected', _statGreen));
      list.add((CurrencyUtils.formatCompact(o.repToCollect), 'To Collect', _statGold));
    }
    if (o.repCanSell && !o.repCanCollect) {
      list.add(('${o.repCustomers}', 'Customers', _statGreen));
      list.add((CurrencyUtils.formatCompact(o.repCommissionPending), 'Commission', _statGold));
    }
    return list.take(4).toList();
  }

  Widget _repBody(BuildContext context, HomeOverview o, dynamic user) {
    // Only surface quick links for modules this rep actually has access to.
    bool has(String m) => user?.hasModule(m) == true;
    final actions = <(IconData, String, Color, VoidCallback)>[];
    if (has('orders')) {
      actions.add((Icons.add_circle_outline, 'New Order', AppColors.primary, () => context.push('/orders/create')));
      actions.add((Icons.receipt_long, 'My Orders', _purple, () => context.go('/orders')));
    }
    if (has('customers')) {
      actions.add((Icons.people_outline, 'Customers', AppColors.success, () => context.go('/customers')));
    }
    if (has('collections')) {
      actions.add((Icons.account_balance_wallet_outlined, 'Collections', const Color(0xFF0891B2), () => context.go('/collections')));
    }
    if (has('invoices')) {
      actions.add((Icons.schedule, 'Outstanding', AppColors.danger, () => context.go('/invoices?filter=Unpaid')));
      actions.add((Icons.description_outlined, 'Invoices', const Color(0xFF6366F1), () => context.go('/invoices')));
    }
    if (has('reports')) {
      actions.add((Icons.percent, 'Commission', _orange, () => context.go('/commissions')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (o.repCanCollect && o.repPendingAssignments > 0) ...[
          _attnBanner('${o.repPendingAssignments} collection${o.repPendingAssignments > 1 ? 's' : ''} pending', () => context.go('/collections')),
          const SizedBox(height: 20),
        ],
        const Text('Quick Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.92,
          children: actions.map((a) => _qaTile(a.$1, a.$2, a.$3, a.$4)).toList(),
        ),
        if (has('reports')) ...[
          const SizedBox(height: 20),
          _repCommissionCard(context, o),
        ],
        const SizedBox(height: 20),
        _recentActivity(o),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _attnBanner(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.warning.withValues(alpha: 0.4))),
        child: Row(children: [
          const Icon(Icons.priority_high_rounded, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
        ]),
      ),
    );
  }

  Widget _repCommissionCard(BuildContext context, HomeOverview o) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader('My Commission', 'View', () => context.go('/commissions')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _miniStat('This Month', CurrencyUtils.format(o.repCommissionMonth), AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _miniStat('Pending', CurrencyUtils.format(o.repCommissionPending), _orange)),
          ]),
        ]),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _qaTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.18)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 9),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color.lerp(color, Colors.black, 0.45))),
        ]),
      ),
    );
  }

  // ---------------- Hero ----------------
  Widget _hero(BuildContext context, HomeOverview o, dynamic user) {
    final companyName = o.companyName ?? user?.companyName ?? 'Your Business';
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_heroA, _heroB, _heroC], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(
          children: [
            Positioned(top: -50, right: -40, child: _circle(200, Colors.white.withValues(alpha: 0.05))),
            Positioned(bottom: -30, left: -20, child: _circle(160, const Color(0xFF6366F1).withValues(alpha: 0.12))),
            Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // greeting + bell
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_greeting()} 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text("Here's your business snapshot", style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
                          ],
                        ),
                      ),
                      _bell(context),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // identity row
                  Row(
                    children: [
                      _logoBox(o.companyLogo),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(companyName, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15)),
                            if (user?.name != null)
                              Text(user!.name!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                  child: Text('👑 ${_roleLabel(o.role)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.trending_up, size: 13, color: o.plNet >= 0 ? _statGold : AppColors.danger),
                                const SizedBox(width: 3),
                                Text('${CurrencyUtils.formatCompact(o.plNet)} net',
                                    style: TextStyle(color: o.plNet >= 0 ? _statGold : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // glassy stat strip
                  Row(
                    children: [
                      _heroStat(CurrencyUtils.formatCompact(o.revenueThisMonth), 'Revenue', _statBlue),
                      const SizedBox(width: 8),
                      _heroStat(CurrencyUtils.formatCompact(o.collectedThisMonth), 'Collected', _statGreen),
                      const SizedBox(width: 8),
                      _heroStat('${o.ordersThisMonth}', 'Orders', _statPurple),
                      const SizedBox(width: 8),
                      _heroStat(CurrencyUtils.formatCompact(o.receivablesOutstanding), 'Outstanding', _statGold),
                    ],
                  ),
                  // attention chip
                  if (o.pendingApprovals > 0 || o.overdueInvoices > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          if (o.pendingApprovals > 0)
                            Expanded(child: _attnSegment(Icons.fact_check_outlined, '${o.pendingApprovals} to approve', () => context.go('/payments?filter=Pending'))),
                          if (o.pendingApprovals > 0 && o.overdueInvoices > 0)
                            Container(width: 1, height: 22, color: Colors.white.withValues(alpha: 0.25)),
                          if (o.overdueInvoices > 0)
                            Expanded(child: _attnSegment(Icons.schedule, '${o.overdueInvoices} overdue', () => context.go('/invoices?filter=Overdue'))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double d, Color c) =>
      Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _attnSegment(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right, size: 15, color: Colors.white.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String? role) {
    if (role == null) return 'Admin';
    final r = role.toLowerCase();
    if (r.contains('admin') || r.contains('owner')) return 'Admin';
    if (r.contains('rep')) return 'Representative';
    return role;
  }

  Widget _bell(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
            onPressed: () => context.go('/alerts'),
          ),
        ),
        Positioned(
          top: 7, right: 7,
          child: Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, border: Border.all(color: _heroB, width: 1.5))),
        ),
      ],
    );
  }

  Widget _heroStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _logoBox(String? logo) {
    final fallback = Container(
      width: 78, height: 78,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3)),
      child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 34),
    );
    if (logo == null || logo.isEmpty) return fallback;
    try {
      final b64 = logo.contains(',') ? logo.split(',').last : logo;
      final bytes = base64Decode(b64);
      return Container(
        width: 78, height: 78, padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3)),
        child: ClipRRect(borderRadius: BorderRadius.circular(14),
            child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront_outlined, color: AppColors.primary))),
      );
    } catch (_) {
      return fallback;
    }
  }

  // ---------------- Scan banner (Academy-Calendar equivalent) ----------------
  Widget _scanBanner() {
    return GestureDetector(
      onTap: _startScan,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.document_scanner_outlined, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan a Bill', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Snap a vendor bill to create a purchase', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.white.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  // ---------------- Quick Access ----------------
  Widget _quickAccess() {
    final actions = [
      (Icons.add_shopping_cart, 'New Purchase', AppColors.primary, () => context.go('/purchases')),
      (Icons.check_circle_outline, 'Approvals', _orange, () => context.go('/payments?filter=Pending')),
      (Icons.receipt_long, 'Orders', _purple, () => context.go('/orders')),
      (Icons.description_outlined, 'Invoices', const Color(0xFF6366F1), () => context.go('/invoices')),
      (Icons.account_balance_wallet_outlined, 'Collections', const Color(0xFF0891B2), () => context.go('/collections')),
      (Icons.insights_outlined, 'Reports', AppColors.danger, () => _soon('Reports')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: actions.map((a) {
            return InkWell(
              onTap: a.$4,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: a.$3,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [BoxShadow(color: a.$3.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Icon(a.$1, color: Colors.white, size: 25),
                    ),
                    const SizedBox(height: 10),
                    Text(a.$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------- P&L card with donut ----------------
  Widget _plCard(HomeOverview o) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('This Month P&L', 'View Report', () => _soon('Report')),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(width: 120, height: 120, child: _donut(o)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _plLine(Icons.account_balance_wallet, 'Revenue (Billed)', o.plIncome, AppColors.primary, AppColors.primary),
                      _plLine(Icons.shopping_cart_outlined, 'Vendor Purchases', o.plPurchases, AppColors.success, AppColors.danger),
                      _plLine(Icons.card_giftcard, 'Office Expenses', o.plExpenses, _orange, AppColors.danger),
                      _plLine(Icons.person_outline, 'Payroll', o.plPayroll, _purple, AppColors.danger),
                      const Divider(height: 16),
                      _plLine(Icons.savings_outlined, 'Net Profit', o.plNet, AppColors.success, o.plNet >= 0 ? AppColors.success : AppColors.danger, bold: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _donut(HomeOverview o) {
    final segs = <(double, Color)>[
      (o.plNet.abs(), AppColors.primary),
      (o.plPurchases, AppColors.danger),
      (o.plExpenses, _orange),
      (o.plPayroll, _purple),
    ].where((e) => e.$1 > 0).toList();
    return Stack(
      alignment: Alignment.center,
      children: [
        if (segs.isNotEmpty)
          PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: segs.map((e) => PieChartSectionData(value: e.$1, color: e.$2, radius: 16, showTitle: false)).toList(),
          )),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(CurrencyUtils.formatCompact(o.plNet), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const Text('Net Profit', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _plLine(IconData icon, String label, double value, Color iconColor, Color valueColor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: AppColors.textPrimary))),
          Text(CurrencyUtils.formatCompact(value), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  // ---------------- Orders by status ----------------
  Widget _ordersByStatus(HomeOverview o) {
    final items = [
      ('Total Orders', o.stTotal, AppColors.primary),
      ('In Production', o.stInProduction, _orange),
      ('Ready to Pack', o.stReadyToPack, _purple),
      ('Ready to Dispatch', o.stReadyToDispatch, AppColors.info),
      ('Delivered', o.stDelivered, AppColors.success),
    ];
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Orders by Status', 'View All', () => context.go('/orders')),
            const SizedBox(height: 14),
            Row(
              children: items.map((it) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        Text('${it.$2}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: it.$3)),
                        const SizedBox(height: 2),
                        Text(it.$1, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        Container(height: 4, decoration: BoxDecoration(color: it.$3, borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Outstanding + Cash flow ----------------
  Widget _outstandingAndCash(HomeOverview o) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _outstandingCard(o)),
        const SizedBox(width: 12),
        Expanded(child: _cashCard(o)),
      ],
    );
  }

  Widget _outstandingCard(HomeOverview o) {
    final rows = [
      ('0-30 Days', o.aging0_30, AppColors.success),
      ('31-60 Days', o.aging31_60, _orange),
      ('61-90 Days', o.aging61_90, _purple),
      ('90+ Days', o.aging90, AppColors.danger),
    ];
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Outstanding', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: r.$3, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))),
                      Text(CurrencyUtils.formatCompact(r.$2), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: r.$3)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _cashCard(HomeOverview o) {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cash Flow', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _cashRow(Icons.south, 'Cash Inflow', o.cashInflow, AppColors.success),
            const SizedBox(height: 12),
            _cashRow(Icons.north, 'Cash Outflow', o.cashOutflow, AppColors.danger),
            const Divider(height: 20),
            _cashRow(Icons.trending_up, 'Net Cash Flow', o.cashNet, o.cashNet >= 0 ? AppColors.primary : AppColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _cashRow(IconData icon, String label, double value, Color color) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(CurrencyUtils.formatCompact(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- Recent activity ----------------
  Widget _recentActivity(HomeOverview o) {
    if (o.recentActivity.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        _card(
          child: Column(
            children: List.generate(o.recentActivity.length.clamp(0, 6), (i) {
              final a = o.recentActivity[i];
              final meta = _activityMeta(a.type);
              final last = i == o.recentActivity.length.clamp(0, 6) - 1;
              return InkWell(
                onTap: () => _openActivity(a),
                borderRadius: BorderRadius.circular(i == 0 ? 18 : 0),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.divider, width: 0.6))),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: meta.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(meta.$1, color: meta.$2, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(a.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(CurrencyUtils.formatCompact(a.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  void _openActivity(HomeActivity a) {
    switch (a.type) {
      case 'order':
        if (a.id != null && a.id!.isNotEmpty) context.go('/orders/${a.id}');
        break;
      case 'payment':
        context.go('/payments');
        break;
      default:
        _soon('Purchase details');
    }
  }

  (IconData, Color) _activityMeta(String type) {
    switch (type) {
      case 'order':
        return (Icons.receipt_long_outlined, AppColors.primary);
      case 'purchase':
        return (Icons.shopping_bag_outlined, AppColors.success);
      case 'payment':
        return (Icons.payments_outlined, AppColors.info);
      default:
        return (Icons.circle_outlined, AppColors.textSecondary);
    }
  }

  // ---------------- shared ----------------
  Widget _sectionHeader(String title, String action, VoidCallback onAction) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const Spacer(),
        GestureDetector(onTap: onAction, child: Text(action, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );
}
