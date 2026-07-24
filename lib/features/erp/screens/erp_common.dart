import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

const _orange = Color(0xFFF59E0B);

/// A gradient "hero" band at the top of an ERP list — gives each module its own
/// identity and surfaces the key totals.
class ErpHero extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final List<(String label, String value)> stats;
  const ErpHero({super.key, required this.gradient, required this.icon, required this.stats});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Stack(children: [
          Positioned(right: -24, top: -24, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)))),
          Positioned(right: 30, bottom: -30, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
          Row(
            children: List.generate(stats.length, (i) {
              return Expanded(
                child: Row(children: [
                  if (i > 0) Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.22), margin: const EdgeInsets.only(right: 12)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stats[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(stats[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
                    ]),
                  ),
                ]),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

/// Horizontally-scrolling filter pills with live counts.
class ErpFilterChips extends StatelessWidget {
  final List<(String label, String value, int count)> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color accent;
  const ErpFilterChips({super.key, required this.options, required this.selected, required this.onSelect, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final o = options[i];
          final on = o.$2 == selected;
          return GestureDetector(
            onTap: () => onSelect(o.$2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? accent : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? Colors.transparent : AppColors.border),
                boxShadow: on ? [BoxShadow(color: accent.withValues(alpha: 0.30), blurRadius: 6, offset: const Offset(0, 2))] : null,
              ),
              child: Row(children: [
                Text(o.$1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.textSecondary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: on ? Colors.white.withValues(alpha: 0.25) : AppColors.background, borderRadius: BorderRadius.circular(10)),
                  child: Text('${o.$3}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: on ? Colors.white : AppColors.textMuted)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class ErpSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hint;
  const ErpSearchField({super.key, required this.onChanged, this.hint = 'Search…'});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      ),
    );
  }
}

/// A read-only ERP list card with a status-coloured left accent stripe.
class ErpCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String code;
  final String status;
  final List<(String, String)> rows;
  final String? badge;
  final Color? badgeColor;

  const ErpCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.code,
    required this.status,
    required this.rows,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = status.isNotEmpty ? statusColor(status) : color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                      child: Icon(icon, size: 19, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
                        const SizedBox(height: 3),
                        Row(children: [
                          Text(code, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          const Spacer(),
                          if (status.isNotEmpty) _chip(status.replaceAll('_', ' '), accent),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            _chip(badge!, badgeColor ?? _orange),
                          ],
                        ]),
                      ]),
                    ),
                  ]),
                  if (rows.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...rows.map((r) => Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Row(children: [
                            Text('${r.$1}  ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            const Spacer(),
                            Flexible(child: Text(r.$2, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                          ]),
                        )),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
      );

  static Color statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'WON':
      case 'ACTIVE':
      case 'APPROVED_TO_BID':
      case 'CLOSED':
        return AppColors.success;
      case 'LOST':
      case 'DROPPED':
      case 'SCRAPPED':
        return AppColors.danger;
      case 'UNDER_MAINTENANCE':
      case 'NEGOTIATION':
      case 'SUBMITTED':
      case 'QUOTED':
      case 'PENDING_APPROVAL':
        return _orange;
      case 'HIRED_OUT':
      case 'ON_HOLD':
      case 'IDLE':
      case 'RECEIVED':
        return const Color(0xFF0891B2);
      default:
        return AppColors.textMuted;
    }
  }
}

/// Build "All + each distinct value" filter options with counts, sorted by frequency.
List<(String, String, int)> buildStatusOptions(Iterable<String> values, {String allLabel = 'All'}) {
  final counts = <String, int>{};
  var total = 0;
  for (final v in values) {
    if (v.isEmpty) continue;
    counts[v] = (counts[v] ?? 0) + 1;
    total++;
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value - a.value);
  return [
    (allLabel, 'all', total),
    ...sorted.map((e) => (_pretty(e.key), e.key, e.value)),
  ];
}

/// Build "All + every status in [statuses]" filter options with live counts from
/// [values]. Unlike [buildStatusOptions] the stage list is FIXED, so stages with
/// zero rows still show up (they never silently disappear). Counts come from the
/// currently-loaded rows; a missing status simply renders as 0.
List<(String, String, int)> buildFixedStatusOptions(
  List<String> statuses,
  Iterable<String> values, {
  String allLabel = 'All',
}) {
  final counts = <String, int>{};
  var total = 0;
  for (final v in values) {
    if (v.isEmpty) continue;
    counts[v] = (counts[v] ?? 0) + 1;
    total++;
  }
  return [
    (allLabel, 'all', total),
    for (final s in statuses) (_pretty(s), s, counts[s] ?? 0),
  ];
}

String _pretty(String k) => k.isEmpty ? k : k.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');

class ErpEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  const ErpEmpty({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 70),
        child: Column(children: [
          Icon(icon, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ]),
      );
}
