import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/network/api_client.dart';
import '../../../widgets/common/error_state_widget.dart';
import '../../../widgets/common/loading_indicator.dart';
import '../../auth/providers/auth_provider.dart';
import 'erp_common.dart';

const _amber = Color(0xFFB45309);

/// Tender detail (read-only) — key facts, submission-deadline countdown, result and
/// documents. Bid workflow/approvals stay on web.
class TenderDetailScreen extends ConsumerStatefulWidget {
  const TenderDetailScreen({super.key, required this.tenderId});
  final int tenderId;
  @override
  ConsumerState<TenderDetailScreen> createState() => _TenderDetailScreenState();
}

class _TenderDetailScreenState extends ConsumerState<TenderDetailScreen> {
  Map<String, dynamic> _tender = const {};
  List<Map<String, dynamic>> _docs = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  ApiClient get _client => ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  String _d(dynamic v) { final s = (v ?? '').toString(); return s.length >= 10 ? s.substring(0, 10) : (s.isEmpty ? '—' : s); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final id = widget.tenderId;
      final results = await Future.wait([
        _client.get('/api/tenders/$id'),
        _client.get('/api/tenders/$id/documents').catchError((_) => const []),
      ]);
      if (!mounted) return;
      setState(() {
        _tender = results[0] is Map ? (results[0] as Map).cast<String, dynamic>() : const {};
        final d = results[1];
        _docs = (d is List ? d : (d is Map ? (d['documents'] ?? d['data'] ?? const []) : const []) as List)
            .whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int? _daysLeft() {
    final s = (_tender['submissionDeadline'] ?? '').toString();
    if (s.isEmpty) return null;
    final dl = DateTime.tryParse(s);
    if (dl == null) return null;
    return dl.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final t = _tender;
    final days = _daysLeft();
    final urgent = days != null && days <= 3;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(t['tenderCode']?.toString() ?? 'Tender')),
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
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFD97706), _amber], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                        child: Stack(children: [
                          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(t['title']?.toString() ?? '', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Colors.white))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.20), borderRadius: BorderRadius.circular(8)),
                                child: Text((t['status'] ?? '').toString().replaceAll('_', ' '), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(t['authority']?.toString() ?? '', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.82))),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Estimated value', style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8))),
                                  const SizedBox(height: 2),
                                  Text(CurrencyUtils.format(_num(t['estimatedValue'])), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                                ]),
                              ),
                              if (days != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: urgent ? 0.3 : 0.15), borderRadius: BorderRadius.circular(12)),
                                  child: Column(children: [
                                    Text(days < 0 ? 'CLOSED' : '$days', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                                    if (days >= 0) const Text('days left', style: TextStyle(fontSize: 9.5, color: Colors.white)),
                                  ]),
                                ),
                            ]),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _card('Key facts', Icons.fact_check_outlined, const Color(0xFF2563EB), [
                      _kv('NIT number', (t['nitNumber'] ?? '—').toString()),
                      _kv('Type', (t['tenderType'] ?? '—').toString()),
                      _kv('EMD', CurrencyUtils.format(_num(t['emdAmount']))),
                      if (_num(t['tenderFeeAmount']) > 0) _kv('Tender fee', CurrencyUtils.format(_num(t['tenderFeeAmount']))),
                      _kv('Submission deadline', _d(t['submissionDeadline'])),
                      if ((t['openingDate'] ?? '').toString().isNotEmpty) _kv('Opening date', _d(t['openingDate'])),
                      if ((t['prebidDate'] ?? '').toString().isNotEmpty) _kv('Pre-bid meeting', _d(t['prebidDate'])),
                    ]),
                    if ((t['resultStatus'] ?? '').toString().isNotEmpty || (t['awardedTo'] ?? '').toString().isNotEmpty)
                      _card('Result', Icons.emoji_events_outlined, const Color(0xFF16A34A), [
                        if ((t['resultStatus'] ?? '').toString().isNotEmpty) _kv('Result', t['resultStatus'].toString()),
                        if ((t['awardedTo'] ?? '').toString().isNotEmpty) _kv('Awarded to', t['awardedTo'].toString()),
                        if (_num(t['awardValue']) > 0) _kv('Award value', CurrencyUtils.format(_num(t['awardValue']))),
                      ]),
                    if ((t['scopeSummary'] ?? '').toString().isNotEmpty)
                      _card('Scope', Icons.description_outlined, const Color(0xFF7C3AED), [
                        Text(t['scopeSummary'].toString(), style: const TextStyle(fontSize: 12.5)),
                      ]),
                    _card('Documents', Icons.folder_open_outlined, const Color(0xFF0891B2),
                        _docs.isEmpty
                            ? [const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('No documents uploaded.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)))]
                            : _docs.take(10).map((d) => _kv(
                                  (d['title'] ?? d['fileName'] ?? d['docType'] ?? 'Document').toString(),
                                  _d(d['createdAt'] ?? d['uploadedAt']),
                                )).toList()),
                    if ((t['remarks'] ?? '').toString().isNotEmpty)
                      _card('Remarks', Icons.notes_outlined, ErpCard.statusColor('PENDING'), [
                        Text(t['remarks'].toString(), style: const TextStyle(fontSize: 12.5)),
                      ]),
                  ]),
                ),
    );
  }

  Widget _card(String title, IconData icon, Color color, List<Widget> children) => Container(
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
