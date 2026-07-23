import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Shared building blocks for the three AI/insight read screens (Customer Trace,
/// Sales Advisor, Inventory Advisor). Card + section + compact scrollable table +
/// classification badge + comparison-period options, all in the app's card style.

/// Comparison periods offered by the customer-trace / sales-advisor period dropdown.
/// (Web also has "custom" with a date range — omitted on mobile.)
class ComparisonPeriod {
  final String value;
  final String label;
  const ComparisonPeriod(this.value, this.label);
}

const kComparisonPeriods = <ComparisonPeriod>[
  ComparisonPeriod('last_30_days', 'Last 30 Days'),
  ComparisonPeriod('last_4_weeks', 'Last 4 Weeks'),
  ComparisonPeriod('this_month_vs_last_month', 'This Month vs Last Month'),
  ComparisonPeriod('this_quarter_vs_last_quarter', 'This Quarter vs Last Quarter'),
];

// ─── Classification badge styles (hex mirrors the web) ─────────────────────────

class ClassStyle {
  final String label;
  final Color bg;
  final Color fg;
  const ClassStyle(this.label, this.bg, this.fg);
}

const Map<String, ClassStyle> kClassStyles = {
  // Sales — customer health
  'HIGH_RISK_DEBT': ClassStyle('High Risk Debt', Color(0xFFFEE2E2), Color(0xFFB91C1C)),
  'CREDIT_WARNING': ClassStyle('Credit Warning', Color(0xFFFFEDD5), Color(0xFFC2410C)),
  'CHURNING': ClassStyle('Churning', Color(0xFFFEF3C7), Color(0xFFB45309)),
  'DECLINING': ClassStyle('Declining', Color(0xFFFEF9C3), Color(0xFF854D0E)),
  'NEW': ClassStyle('New', Color(0xFFF3E8FF), Color(0xFF7E22CE)),
  'SLOW_PAYER': ClassStyle('Slow Payer', Color(0xFFF1F5F9), Color(0xFF475569)),
  'CHAMPION': ClassStyle('Champion', Color(0xFFDCFCE7), Color(0xFF15803D)),
  'LOYAL': ClassStyle('Loyal', Color(0xFFECFDF5), Color(0xFF047857)),
  'INACTIVE': ClassStyle('Inactive', Color(0xFFF8FAFC), Color(0xFF64748B)),
  'HEALTHY': ClassStyle('Healthy', Color(0xFFEFF6FF), Color(0xFF1D4ED8)),
  // Sales — product performance
  'STAR': ClassStyle('Star', Color(0xFFFEF3C7), Color(0xFFB45309)),
  'RISING': ClassStyle('Rising', Color(0xFFDCFCE7), Color(0xFF15803D)),
  'WORKHORSE': ClassStyle('Workhorse', Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
  'STALLED': ClassStyle('Stalled', Color(0xFFFEF3C7), Color(0xFFB45309)),
  'FADING': ClassStyle('Fading', Color(0xFFFFEDD5), Color(0xFFC2410C)),
  'NICHE': ClassStyle('Niche', Color(0xFFF3E8FF), Color(0xFF7E22CE)),
  // Inventory
  'HOT_LOW_STOCK': ClassStyle('Hot — Low Stock', Color(0xFFFEE2E2), Color(0xFFDC2626)),
  'REORDER_SOON': ClassStyle('Reorder Soon', Color(0xFFFFEDD5), Color(0xFFC2410C)),
  'LOW_STOCK_ONLY': ClassStyle('Low Stock', Color(0xFFFFEDD5), Color(0xFFC2410C)),
  'HOT_OVERSTOCKED': ClassStyle('Hot — Overstocked', Color(0xFFFEF3C7), Color(0xFFB45309)),
  'HOT_OK': ClassStyle('Hot & Healthy', Color(0xFFDCFCE7), Color(0xFF15803D)),
  'SLOW_OVERSTOCKED': ClassStyle('Slow — Overstocked', Color(0xFFFEF9C3), Color(0xFF854D0E)),
  'DEADSTOCK': ClassStyle('Deadstock', Color(0xFFF1F5F9), Color(0xFF475569)),
};

ClassStyle classStyleOf(String cls) =>
    kClassStyles[cls] ?? ClassStyle(cls, const Color(0xFFF1F5F9), const Color(0xFF334155));

Widget classBadge(String cls) {
  final s = classStyleOf(cls);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(999)),
    child: Text(s.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: s.fg)),
  );
}

/// Buying-cadence label + colour (customer trace summary).
({String label, Color color}) cadenceStyle(String? status) {
  switch (status) {
    case 'NO_HISTORY':
      return (label: 'No history', color: const Color(0xFF94A3B8));
    case 'NEW':
      return (label: 'New customer', color: const Color(0xFF0891B2));
    case 'ON_TRACK':
      return (label: 'On track', color: const Color(0xFF16A34A));
    case 'DUE_SOON':
      return (label: 'Due soon', color: const Color(0xFFD97706));
    case 'OVERDUE':
      return (label: 'Overdue', color: const Color(0xFFDC2626));
    case 'INACTIVE':
      return (label: 'Inactive (6m+)', color: const Color(0xFF7C3AED));
    default:
      return (label: status ?? '—', color: AppColors.textSecondary);
  }
}

// ─── Section card ──────────────────────────────────────────────────────────────

class InsightSection extends StatelessWidget {
  final String title;
  final int? count;
  final Widget child;
  const InsightSection({super.key, required this.title, this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ),
            if (count != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(999)),
                child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
              ),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ─── Summary / KPI tile ────────────────────────────────────────────────────────

class SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;
  final double width;
  const SummaryTile({super.key, required this.label, required this.value, this.sub, this.valueColor, this.width = 150});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: valueColor ?? AppColors.textPrimary)),
          if (sub != null && sub!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sub!, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Small coloured stat chip for the advisor count bars.
Widget statChip(String label, String value, {Color? bg, Color? fg}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg ?? AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: fg ?? AppColors.textPrimary)),
      ]),
    );

// ─── Compact horizontally-scrollable table ─────────────────────────────────────

class MiniCol {
  final String label;
  final double width;
  final bool numeric;
  const MiniCol(this.label, this.width, {this.numeric = false});
}

/// A cell helper — most cells are just styled text. `numeric` right-aligns the text
/// to line up with a numeric [MiniCol] (column alignment is also applied by MiniTable).
Widget tcell(String text, {Color? color, FontWeight? weight, double size = 11.5, bool numeric = false}) => Text(
      text,
      textAlign: numeric ? TextAlign.right : TextAlign.left,
      style: TextStyle(fontSize: size, color: color ?? AppColors.textPrimary, fontWeight: weight ?? FontWeight.w500),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

class MiniTable extends StatelessWidget {
  final List<MiniCol> columns;
  final List<List<Widget>> rows; // each inner list length must equal columns.length
  final String emptyText;
  const MiniTable({super.key, required this.columns, required this.rows, this.emptyText = 'No records found.'});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(emptyText, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: columns
                  .map((c) => SizedBox(
                        width: c.width,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            c.label.toUpperCase(),
                            textAlign: c.numeric ? TextAlign.right : TextAlign.left,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.2),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          // Rows
          ...rows.map((r) => Container(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(columns.length, (i) {
                    final c = columns[i];
                    return SizedBox(
                      width: c.width,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Align(
                          alignment: c.numeric ? Alignment.centerRight : Alignment.centerLeft,
                          child: i < r.length ? r[i] : const SizedBox.shrink(),
                        ),
                      ),
                    );
                  }),
                ),
              )),
        ],
      ),
    );
  }
}
