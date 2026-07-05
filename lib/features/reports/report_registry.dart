import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../finance/finance_reports.dart';
import 'screens/report_view_screen.dart';

/// Stable-key registry of every named report, so reports are deep-linkable by a
/// plain string route (`/reports/view/<key>`) — e.g. from the AI assistant's
/// `navigate.mobileRoute`. Keys match the backend assistant's NAV_ROUTES pages.
class ReportRegistry {
  /// The sales/owner reports shown on the Reports hub grid (order = display order).
  static const salesReports = <ReportConfig>[
    ReportConfig(
      title: 'Outstanding (Receivables)',
      endpoint: '/api/reports/outstanding',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFFF59E0B),
      totalField: 'balanceAmount',
      groupBy: 'billingName',
      groupNoun: 'invoices',
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
      groupBy: 'billingName',
      groupNoun: 'invoices',
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
      groupBy: 'customerName',
      groupNoun: 'invoices',
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

  /// key → config. Keys are the assistant's page ids (NAV_ROUTES) — keep in sync.
  static final Map<String, ReportConfig> _byKey = {
    'outstanding': salesReports[0],
    'overdue-invoices': salesReports[1],
    'sales-by-customer': salesReports[2],
    'sales-by-product': salesReports[3],
    'top-products': salesReports[4],
    'payment-collection': salesReports[5],
    'sales-by-city': salesReports[6],
    'sales-by-division': salesReports[7],
    'transport': salesReports[8],
    'misc-outstanding': salesReports[9],
    'vendor-outstanding': FinanceReports.vendorOutstanding,
    'vendor-payments': FinanceReports.vendorPayments,
    'vendor-credit-notes': FinanceReports.vendorCreditNotes,
    'customer-credit-notes': FinanceReports.customerCreditNotes,
    'inventory-valuation': FinanceReports.inventoryValuation,
  };

  /// Which licensed module a report needs (mirrors the backend PAGE_MODULE gating).
  static const Map<String, String> _moduleByKey = {
    'outstanding': 'reports',
    'overdue-invoices': 'reports',
    'sales-by-customer': 'reports',
    'sales-by-product': 'reports',
    'top-products': 'reports',
    'payment-collection': 'reports',
    'sales-by-city': 'reports',
    'sales-by-division': 'reports',
    'transport': 'reports',
    'misc-outstanding': 'reports',
    'vendor-outstanding': 'vendor_purchases',
    'vendor-payments': 'vendor_purchases',
    'vendor-credit-notes': 'vendor_purchases',
    'customer-credit-notes': 'invoices',
    'inventory-valuation': 'inventory',
  };

  static ReportConfig? forKey(String key) => _byKey[key];
  static String? moduleForKey(String key) => _moduleByKey[key];
}

/// `/reports/view/:key` — string-addressable report viewer (deep-linkable by the
/// AI assistant). Resolves the key via [ReportRegistry] and re-checks the user's
/// module access; unknown keys / missing access render a friendly page, never a crash.
class KeyedReportScreen extends ConsumerWidget {
  final String reportKey;
  const KeyedReportScreen({super.key, required this.reportKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ReportRegistry.forKey(reportKey);
    final module = ReportRegistry.moduleForKey(reportKey);
    final user = ref.watch(authProvider).user;
    if (cfg == null) {
      return _message(context, Icons.search_off_outlined,
          'Report not available', 'This report ("$reportKey") isn\'t available in this app version.');
    }
    if (module != null && user?.hasModule(module) != true) {
      return _message(context, Icons.lock_outline,
          'No access', 'Your role doesn\'t include access to this report. Ask your admin if you need it.');
    }
    return ReportViewScreen(config: cfg);
  }

  Widget _message(BuildContext context, IconData icon, String title, String body) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Report')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
