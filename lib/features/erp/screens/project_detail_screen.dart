import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';

const _blue = Color(0xFF1D4ED8);

/// Project detail (read-only) — master info, billing/collection summary, physical
/// progress, milestones and recent DPRs. Heavy entry (estimates/BOQ/DPR) stays on web.
class ProjectDetailScreen extends ConsumerStatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final int projectId;
  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  Map<String, dynamic> _project = const {};
  Map<String, dynamic> _billing = const {};
  Map<String, dynamic> _progress = const {};
  List<Map<String, dynamic>> _dprs = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  Map<String, dynamic> _map(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};
  String _d(dynamic v) { final s = (v ?? '').toString(); return s.length >= 10 ? s.substring(0, 10) : s; }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final id = widget.projectId;
      final results = await Future.wait([
        _client.get('/api/projects/$id'),
        _client.get('/api/projects/$id/billing').catchError((_) => const {}),
        _client.get('/api/projects/$id/progress').catchError((_) => const {}),
        _client.get('/api/projects/$id/dpr').catchError((_) => const []),
      ]);
      if (!mounted) return;
      setState(() {
        _project = _map(results[0]);
        _billing = _map(results[1]);
        _progress = _map(results[2]);
        final d = results[3];
        _dprs = (d is List ? d : const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _project;
    final summary = _map(_billing['summary']);
    final milestones = ((_billing['milestones'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    final overallPct = _num(_progress['overallPct']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(p['projectCode']?.toString() ?? 'Project'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final saved = await context.push<bool>('/projects/${widget.projectId}/edit');
              if (saved == true) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    // Hero
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_blue, Color(0xFF1E40AF)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                        child: Stack(children: [
                          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(p['projectName']?.toString() ?? '', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Colors.white))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(8)),
                                child: Text((p['status'] ?? '').toString().replaceAll('_', ' '), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text([_map(p['customer'])['customerName'], p['city']].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.82))),
                            const SizedBox(height: 14),
                            Row(children: [
                              _heroStat('Contract', CurrencyUtils.format(_num(p['contractValue']))),
                              _heroStat('Billed', CurrencyUtils.format(_num(summary['billed']))),
                              _heroStat('Collected', CurrencyUtils.format(_num(summary['collected']))),
                            ]),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Physical progress
                    _sectionCard('Physical progress', Icons.stacked_line_chart, const Color(0xFF16A34A), [
                      Row(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(value: (overallPct / 100).clamp(0.0, 1.0), minHeight: 10, backgroundColor: AppColors.border, color: const Color(0xFF16A34A)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${overallPct.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      ]),
                      const SizedBox(height: 8),
                      _kv('Planned value', CurrencyUtils.format(_num(_progress['plannedValue']))),
                      _kv('Achieved value', CurrencyUtils.format(_num(_progress['achievedValue']))),
                    ]),
                    // Money
                    _sectionCard('Billing & collection', Icons.receipt_long_outlined, const Color(0xFFD97706), [
                      _kv('Outstanding', CurrencyUtils.format(_num(summary['outstanding']))),
                      _kv('Retention held', CurrencyUtils.format(_num(summary['retentionHeld']))),
                      if ((p['workOrderNo'] ?? '').toString().isNotEmpty) _kv('Work order', '${p['workOrderNo']} · ${_d(p['workOrderDate'])}'),
                    ]),
                    // Milestones
                    if (milestones.isNotEmpty)
                      _sectionCard('Milestones', Icons.flag_outlined, _blue,
                          milestones.take(8).map((m) => _kv(
                                m['name']?.toString() ?? m['title']?.toString() ?? 'Milestone',
                                '${CurrencyUtils.format(_num(m['amount'] ?? m['value']))}${(m['status'] ?? '').toString().isNotEmpty ? ' · ${m['status']}' : ''}',
                              )).toList()),
                    // DPRs
                    _sectionCard('Recent DPRs', Icons.today_outlined, const Color(0xFF7C3AED),
                        _dprs.isEmpty
                            ? [const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No daily progress reports yet.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)))]
                            : _dprs.take(6).map((d) => _kv(_d(d['reportDate'] ?? d['date'] ?? d['createdAt']), (d['summary'] ?? d['notes'] ?? d['weather'] ?? '—').toString())).toList()),
                    // Site
                    if ((p['siteAddress'] ?? '').toString().isNotEmpty)
                      _sectionCard('Site', Icons.place_outlined, const Color(0xFF0891B2), [
                        Text(p['siteAddress'].toString(), style: const TextStyle(fontSize: 12.5)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => context.push('/site-logistics'),
                          child: const Text('Open Site Logistics →', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0891B2))),
                        ),
                      ]),
                  ]),
                ),
    );
  }

  Widget _heroStat(String l, String v) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
            const SizedBox(height: 2),
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
      );

  Widget _sectionCard(String title, IconData icon, Color color, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          ]),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.5),
        child: Row(children: [
          Expanded(child: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
          const SizedBox(width: 10),
          Flexible(child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
        ]),
      );
}
