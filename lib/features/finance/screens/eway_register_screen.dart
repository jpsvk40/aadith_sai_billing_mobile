import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/gst_compliance_model.dart';
import '../providers/gst_compliance_providers.dart';

/// Company-wide e-Way bill register — parity with the web EwayBillRegister page.
/// The status filter is a dropdown (server-side); KPIs (Total / Generated / Pending /
/// Expired / Expiring Today) are computed over the fetched set.
class EwayRegisterScreen extends ConsumerStatefulWidget {
  const EwayRegisterScreen({super.key});
  @override
  ConsumerState<EwayRegisterScreen> createState() => _EwayRegisterScreenState();
}

class _EwayRegisterScreenState extends ConsumerState<EwayRegisterScreen> {
  String _status = 'All';

  String _shortDate(String? d) => (d == null || d.length < 10) ? (d ?? '—') : d.substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ewayRegisterProvider(_status));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('e-Way Bill Register')),
      body: Column(children: [
        // Status filter (server-side)
        Container(
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            const Icon(Icons.filter_list, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const Spacer(),
            DropdownButton<String>(
              value: _status,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              items: EwayStatus.filterOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All' : s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? 'All'),
            ),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _error('$e'),
            data: (docs) {
              final total = docs.length;
              final generated = docs.where((d) => d.status == 'GENERATED').length;
              final pending = docs.where((d) => d.status == 'PENDING').length;
              final expired = docs.where((d) => d.status == 'EXPIRED' || d.isExpired).length;
              final expiringToday = docs.where((d) => d.isExpiringSoon).length;
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(ewayRegisterProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  children: [
                    SizedBox(
                      height: 82,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _kpi('Total EWBs', total, AppColors.primary),
                          _kpi('Generated', generated, EwayStatus.color('GENERATED')),
                          _kpi('Pending', pending, EwayStatus.color('PENDING')),
                          _kpi('Expired', expired, EwayStatus.color('EXPIRED')),
                          _kpi('Expiring Today', expiringToday, const Color(0xFFF59E0B)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            _status == 'All' ? 'No e-Way bills yet.' : 'No ${_status.toLowerCase()} e-Way bills.',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...docs.map(_row),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _kpi(String label, int count, Color color) => Container(
        width: 118,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _row(EwayBillDoc d) {
    final inv = d.invoice;
    final c = EwayStatus.color(d.status);
    // Valid-upto colour: red if expired, amber if <24h, green otherwise.
    final Color validColor = d.isExpired
        ? const Color(0xFFDC2626)
        : d.isExpiringSoon
            ? const Color(0xFFF59E0B)
            : const Color(0xFF16A34A);
    final vehicleLine = [
      if (d.vehicleNumber != null && d.vehicleNumber!.isNotEmpty) d.vehicleNumber!,
      if (d.transporterName != null && d.transporterName!.isNotEmpty) d.transporterName!,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(inv?.displayNo ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
          const SizedBox(width: 8),
          _chip(d.status, c),
        ]),
        const SizedBox(height: 4),
        Text(inv?.customerName ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text(
              'EWB ${d.ewbNumber?.isNotEmpty == true ? d.ewbNumber : '—'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text(_shortDate(d.ewbDate), style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          // Valid upto pill (coloured by expiry proximity)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: validColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule, size: 12, color: validColor),
              const SizedBox(width: 4),
              Text('Valid ${_shortDate(d.validUpto)}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: validColor)),
            ]),
          ),
          const Spacer(),
          // Transport mode chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_shipping_outlined, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(d.modeLabel, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
        if (vehicleLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(vehicleLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ]),
    );
  }

  Widget _chip(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: c)),
      );

  Widget _error(String e) => ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.error_outline, size: 42, color: AppColors.danger),
          const SizedBox(height: 12),
          Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)))),
          Center(child: TextButton(onPressed: () => ref.invalidate(ewayRegisterProvider), child: const Text('Retry'))),
        ],
      );
}
