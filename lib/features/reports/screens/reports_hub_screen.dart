import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import 'report_view_screen.dart';

/// Owner-grade reports hub. Each tile opens a generic [ReportViewScreen] backed by an
/// existing `/api/reports/*` endpoint.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  static const _reports = <ReportConfig>[
    ReportConfig(
      title: 'Outstanding (Receivables)',
      endpoint: '/api/reports/outstanding',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFFF59E0B),
      labelKeys: ['customerName', 'name'],
      amountKeys: ['balanceAmount', 'outstanding', 'totalAmount', 'amount'],
      subtitleKeys: ['invoiceNumber', 'agingBucket', 'dueDate'],
    ),
    ReportConfig(
      title: 'Overdue Invoices',
      endpoint: '/api/reports/overdue',
      icon: Icons.schedule_outlined,
      color: Color(0xFFEF4444),
      labelKeys: ['customerName', 'name'],
      amountKeys: ['balanceAmount', 'outstanding', 'totalAmount', 'amount'],
      subtitleKeys: ['invoiceNumber', 'dueDate', 'agingBucket'],
    ),
    ReportConfig(
      title: 'Sales by Customer',
      endpoint: '/api/reports/sales-by-customer',
      icon: Icons.people_alt_outlined,
      color: Color(0xFF1D4ED8),
      labelKeys: ['customerName', 'name'],
      subtitleKeys: ['orderCount', 'invoiceCount', 'city'],
      supportsPeriod: true,
    ),
    ReportConfig(
      title: 'Sales by Product',
      endpoint: '/api/reports/sales-by-product',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF7C3AED),
      labelKeys: ['productName', 'name'],
      subtitleKeys: ['quantity', 'unit', 'orderCount'],
      supportsPeriod: true,
    ),
    ReportConfig(
      title: 'Top Products',
      endpoint: '/api/reports/top-products',
      icon: Icons.trending_up_outlined,
      color: Color(0xFF0891B2),
      labelKeys: ['productName', 'name'],
      subtitleKeys: ['quantity', 'orderCount'],
      supportsPeriod: true,
    ),
    ReportConfig(
      title: 'Payment Collection',
      endpoint: '/api/reports/payment-collection',
      icon: Icons.payments_outlined,
      color: Color(0xFF059669),
      labelKeys: ['customerName', 'name', 'paymentMode', 'label'],
      subtitleKeys: ['paymentMode', 'count', 'invoiceNumber'],
      supportsPeriod: true,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Business Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Tap a report to view details', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: _reports.map((r) {
              return InkWell(
                onTap: () => context.push('/reports/view', extra: r),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: r.color,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: r.color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Icon(r.icon, color: Colors.white, size: 23),
                      ),
                      const SizedBox(height: 12),
                      Text(r.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
