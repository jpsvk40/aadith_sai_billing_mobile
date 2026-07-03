import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../finance_reports.dart';

/// General Ledger hub (read-only) — Trial Balance / P&L / Balance Sheet open the bespoke
/// statement renderer; Day Book opens the generic report view.
class GlHubScreen extends StatelessWidget {
  const GlHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <(IconData, String, String, Color, VoidCallback)>[
      (Icons.balance_outlined, 'Trial Balance', 'All ledgers · Dr = Cr check', const Color(0xFF0D9488), () => context.push('/finance/gl/tb')),
      (Icons.trending_up_outlined, 'Profit & Loss', 'Income · expenses · net profit', const Color(0xFF16A34A), () => context.push('/finance/gl/pnl')),
      (Icons.account_balance_wallet_outlined, 'Balance Sheet', 'Assets · liabilities · equity', const Color(0xFF9333EA), () => context.push('/finance/gl/bs')),
      (Icons.menu_book_outlined, 'Day Book', 'Daily voucher activity', const Color(0xFF475569), () => context.push('/reports/view', extra: FinanceReports.glDayBook)),
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('General Ledger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFC7D2FE))),
            child: const Row(children: [
              Icon(Icons.lock_outline, size: 18, color: Color(0xFF6366F1)),
              SizedBox(width: 10),
              Expanded(child: Text('Read-only on mobile — vouchers, sync and period locks are managed on the web portal.', style: TextStyle(fontSize: 12, color: Color(0xFF3730A3)))),
            ]),
          ),
          const SizedBox(height: 14),
          ...tiles.map((t) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 0.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  onTap: t.$5,
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: t.$4,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: t.$4.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Icon(t.$1, color: Colors.white, size: 21),
                  ),
                  title: Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: Text(t.$3, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ),
              )),
        ],
      ),
    );
  }
}
