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
      totalField: 'balanceAmount',
      columns: [
        ReportColumn('Customer', 'billingName', primary: true),
        ReportColumn('Invoice', 'invoiceNo'),
        ReportColumn('Bill', 'grandTotal', currency: true),
        ReportColumn('Paid', 'paidAmount', currency: true),
        ReportColumn('Balance', 'balanceAmount', currency: true),
        ReportColumn('Aging', 'agingBucket'),
        ReportColumn('Due', 'dueDate', isDate: true),
      ],
    ),
    ReportConfig(
      title: 'Overdue Invoices',
      endpoint: '/api/reports/overdue',
      icon: Icons.schedule_outlined,
      color: Color(0xFFEF4444),
      totalField: 'balanceAmount',
      columns: [
        ReportColumn('Customer', 'billingName', primary: true),
        ReportColumn('Invoice', 'invoiceNo'),
        ReportColumn('Bill', 'grandTotal', currency: true),
        ReportColumn('Paid', 'paidAmount', currency: true),
        ReportColumn('Balance', 'balanceAmount', currency: true),
        ReportColumn('Due', 'dueDate', isDate: true),
        ReportColumn('Aging', 'agingBucket'),
      ],
    ),
    ReportConfig(
      title: 'Sales by Customer',
      endpoint: '/api/reports/sales-by-customer',
      icon: Icons.people_alt_outlined,
      color: Color(0xFF1D4ED8),
      supportsPeriod: true,
      totalField: 'totalAmount',
      columns: [
        ReportColumn('Customer', 'customerName', primary: true),
        ReportColumn('Orders', 'totalOrders', numeric: true),
        ReportColumn('Sales', 'totalAmount', currency: true),
      ],
    ),
    ReportConfig(
      title: 'Sales by Product',
      endpoint: '/api/reports/sales-by-product',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF7C3AED),
      supportsPeriod: true,
      totalField: 'totalRevenue',
      columns: [
        ReportColumn('Product', 'productName', primary: true),
        ReportColumn('Qty', 'totalQuantity', numeric: true),
        ReportColumn('Unit', 'unit'),
        ReportColumn('Revenue', 'totalRevenue', currency: true),
      ],
    ),
    ReportConfig(
      title: 'Top Products',
      endpoint: '/api/reports/top-products',
      icon: Icons.trending_up_outlined,
      color: Color(0xFF0891B2),
      supportsPeriod: true,
      totalField: 'totalRevenue',
      columns: [
        ReportColumn('Product', 'productName', primary: true),
        ReportColumn('Category', 'category'),
        ReportColumn('Qty', 'totalQuantity', numeric: true),
        ReportColumn('Revenue', 'totalRevenue', currency: true),
      ],
    ),
    ReportConfig(
      title: 'Payment Collection',
      endpoint: '/api/reports/payment-collection',
      icon: Icons.payments_outlined,
      color: Color(0xFF059669),
      totalField: 'collected',
      drill: 'payment',
      columns: [
        ReportColumn('Period', 'label', primary: true),
        ReportColumn('Billed', 'billed', currency: true),
        ReportColumn('Collected', 'collected', currency: true),
      ],
    ),
    ReportConfig(
      title: 'Sales by City',
      endpoint: '/api/reports/sales-by-city',
      icon: Icons.location_city_outlined,
      color: Color(0xFF0EA5E9),
      supportsPeriod: true,
      totalField: 'totalAmount',
      columns: [
        ReportColumn('City', 'city', primary: true),
        ReportColumn('Orders', 'totalOrders', numeric: true),
        ReportColumn('Sales', 'totalAmount', currency: true),
      ],
    ),
    ReportConfig(
      title: 'Sales by Division',
      endpoint: '/api/reports/sales-by-division',
      icon: Icons.hub_outlined,
      color: Color(0xFF8B5CF6),
      supportsPeriod: true,
      totalField: 'totalAmount',
      columns: [
        ReportColumn('Division', 'division', primary: true),
        ReportColumn('Orders', 'totalOrders', numeric: true),
        ReportColumn('Sales', 'totalAmount', currency: true),
      ],
    ),
    ReportConfig(
      title: 'Transport / Freight',
      endpoint: '/api/reports/transport-summary',
      icon: Icons.local_shipping_outlined,
      color: Color(0xFFD97706),
      totalField: 'grossFreight',
      drill: 'transport',
      columns: [
        ReportColumn('Transporter', 'transporterName', primary: true),
        ReportColumn('Dispatch', 'dispatches', numeric: true),
        ReportColumn('Delivered', 'delivered', numeric: true),
        ReportColumn('Boxes', 'boxes', numeric: true),
        ReportColumn('Freight', 'grossFreight', currency: true),
      ],
    ),
    ReportConfig(
      title: 'Misc Outstanding',
      endpoint: '/api/reports/misc-outstanding',
      icon: Icons.request_quote_outlined,
      color: Color(0xFFEF4444),
      totalField: 'balanceAmount',
      columns: [
        ReportColumn('Customer', 'customerName', primary: true),
        ReportColumn('Invoice', 'invoiceNo'),
        ReportColumn('Bill', 'grandTotal', currency: true),
        ReportColumn('Balance', 'balanceAmount', currency: true),
        ReportColumn('Aging', 'agingBucket'),
        ReportColumn('Due', 'dueDate', isDate: true),
      ],
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
