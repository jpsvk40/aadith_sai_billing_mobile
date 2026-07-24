import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// ───────────────────────────────────────────────────────────────────────────
/// Super Admin design kit — the shared visual language for every platform screen.
/// The palette intentionally leans "mission control" (deep navy hero, indigo
/// accent) so the operator always knows they are running the PLATFORM, not a
/// tenant business. Surfaces/text reuse the app's AppColors for consistency.
/// ───────────────────────────────────────────────────────────────────────────

// Accents
const saIndigo = Color(0xFF6366F1);
const saIndigoDark = Color(0xFF4F46E5);
const saAmber = Color(0xFFF59E0B);
const saEmerald = Color(0xFF22C55E);
const saRose = Color(0xFFEF4444);
const saSky = Color(0xFF38BDF8);
const saBlue = Color(0xFF0D6EFD);
const saPurple = Color(0xFF7C3AED);
const saSlateGrey = Color(0xFF94A3B8);

// Surfaces / text (reuse app ramp)
const saInk = AppColors.textPrimary;
const saSlate = AppColors.textSecondary;
const saMuted = AppColors.textMuted;
const saSurface = AppColors.surface;
const saBg = AppColors.background;
const saBorder = AppColors.border;
const saLine = AppColors.divider;

/// Deep "mission control" hero gradient — distinct from the bright tenant hero.
const saHeroGradient = LinearGradient(
  colors: [Color(0xFF0B1220), Color(0xFF16204A), Color(0xFF1D2E77)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─── Status vocabulary ───────────────────────────────────────────────────────

Color saStatusColor(String status) {
  switch (status) {
    case 'active':
      return saEmerald;
    case 'trial_active':
      return saSky;
    case 'pending_review':
      return saAmber;
    case 'trial_expired':
      return saRose;
    case 'suspended':
      return saSlateGrey;
    case 'cancelled':
      return saSlateGrey;
    default:
      return saSlate;
  }
}

String saStatusLabel(String status) {
  switch (status) {
    case 'active':
      return 'Active';
    case 'trial_active':
      return 'Trial';
    case 'pending_review':
      return 'Pending';
    case 'trial_expired':
      return 'Expired';
    case 'suspended':
      return 'Suspended';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

String saMarketFlag(String market) {
  switch (market.toLowerCase()) {
    case 'india':
      return '🇮🇳';
    case 'us':
      return '🇺🇸';
    default:
      return '🌐';
  }
}

String saMarketLabel(String market) {
  switch (market.toLowerCase()) {
    case 'india':
      return 'India';
    case 'us':
      return 'United States';
    default:
      return 'Other';
  }
}

String saEditionLabel(String? edition) {
  switch (edition) {
    case 'billing':
      return 'Billing';
    case 'billing_books':
      return 'Billing + Books';
    case 'erp':
      return 'ERP';
    case null:
    case '':
      return 'Custom';
    default:
      return edition;
  }
}

/// Two-letter monogram for a company logo tile.
String saInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '–';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// A stable accent colour derived from the company name (for logo tiles).
Color saAvatarColor(String seed) {
  const palette = [saBlue, saIndigo, saEmerald, saPurple, saSky, Color(0xFF0891B2), Color(0xFFDB2777), Color(0xFFEA580C)];
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

// ─── Date helpers ────────────────────────────────────────────────────────────

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String saShortDate(DateTime? d) =>
    d == null ? '—' : "${d.day} ${_months[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}";

/// Whole-day delta from today: "today", "in 3d", "5d ago".
String saRelativeDays(DateTime? d) {
  if (d == null) return '—';
  final now = DateTime.now();
  final diff = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  if (diff == -1) return 'yesterday';
  return diff > 0 ? 'in ${diff}d' : '${-diff}d ago';
}

/// Signed day count (negative = past). Handy for "ends in 3 days" copy.
int? saDaysFromNow(DateTime? d) {
  if (d == null) return null;
  final now = DateTime.now();
  return DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
}

// ─── Shared widgets ──────────────────────────────────────────────────────────

/// The standard platform card — white surface, hairline border, soft shadow.
class SaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  const SaCard({super.key, required this.child, this.padding, this.onTap, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding ?? const EdgeInsets.all(16), child: child);
    return Container(
      decoration: BoxDecoration(
        color: saSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? saBorder, width: borderColor != null ? 1 : 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A coloured status pill (Active / Trial / Pending / …).
class SaStatusPill extends StatelessWidget {
  final String status;
  const SaStatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) => SaPill(label: saStatusLabel(status), color: saStatusColor(status));
}

/// A generic tinted pill.
class SaPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const SaPill({super.key, required this.label, required this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: _shade(color)), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _shade(color))),
      ]),
    );
  }

  // Darken the accent a touch so text stays legible on its own tint.
  static Color _shade(Color c) => Color.lerp(c, Colors.black, 0.28)!;
}

/// A section title with an optional trailing action ("See all ›").
class SaSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SaSectionHeader(this.title, {super.key, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: saInk))),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: saBlue)),
          ),
      ]),
    );
  }
}

/// Square company monogram tile.
class SaLogo extends StatelessWidget {
  final String name;
  final double size;
  const SaLogo(this.name, {super.key, this.size = 42});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: saAvatarColor(name), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Text(saInitials(name),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

/// Full-bleed page background for the light platform screens.
BoxDecoration get saPageBg => const BoxDecoration(color: saBg);
