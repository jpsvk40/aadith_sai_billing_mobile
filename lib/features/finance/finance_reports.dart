import 'package:flutter/material.dart';
import '../reports/screens/report_view_screen.dart';

/// Declarative configs for the shared-spine READ surfaces that render through the generic
/// [ReportViewScreen] (list + total header). Key lists are matched to the real backend
/// response shapes (curl-verified 2026-07-03); complex statements (P&L/BS/TB, GST,
/// payables, payroll) have bespoke screens instead.
class FinanceReports {
  // ── Purchasing / Payables (grouped by party · date filter · PDF + WhatsApp) ──
  static const vendorOutstanding = ReportConfig(
    title: 'Vendor Outstanding',
    endpoint: '/api/vendor-reports/outstanding',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFFEF4444),
    supportsPeriod: true,
    totalField: 'outstandingAmount',
    groupBy: 'vendor.vendorName',
    groupNoun: 'bills',
    groupLabel: 'vendor',
    columns: [
      ReportColumn('Vendor', 'vendor.vendorName', primary: true),
      ReportColumn('Invoice', 'invoiceNumber'),
      ReportColumn('Bill', 'totalAmount', currency: true),
      ReportColumn('Paid', 'paidAmount', currency: true),
      ReportColumn('Balance', 'outstandingAmount', currency: true),
      ReportColumn('Due', 'dueDate', isDate: true),
      ReportColumn('Days', 'daysDiff', numeric: true),
    ],
  );
  static const vendorPayments = ReportConfig(
    title: 'Vendor Payments',
    endpoint: '/api/vendor-payments',
    icon: Icons.payments_outlined,
    color: Color(0xFF059669),
    supportsPeriod: true,
    totalField: 'amount',
    groupBy: 'vendor.vendorName',
    groupNoun: 'payments',
    groupLabel: 'vendor',
    columns: [
      ReportColumn('Vendor', 'vendor.vendorName', primary: true),
      ReportColumn('Invoice', 'vendorPurchase.invoiceNumber'),
      ReportColumn('Date', 'paymentDate', isDate: true),
      ReportColumn('Mode', 'paymentMode'),
      ReportColumn('Ref', 'referenceNo'),
      ReportColumn('Amount', 'amount', currency: true),
    ],
  );
  static const vendorCreditNotes = ReportConfig(
    title: 'Vendor Credit Notes',
    endpoint: '/api/vendor-credit-notes',
    icon: Icons.assignment_return_outlined,
    color: Color(0xFFD97706),
    supportsPeriod: true,
    totalField: 'totalAmount',
    groupBy: 'vendor.vendorName',
    groupNoun: 'notes',
    groupLabel: 'vendor',
    columns: [
      ReportColumn('Vendor', 'vendor.vendorName', primary: true),
      ReportColumn('CN No', 'creditNoteNumber'),
      ReportColumn('Invoice', 'vendorPurchase.invoiceNumber'),
      ReportColumn('Date', 'creditNoteDate', isDate: true),
      ReportColumn('Reason', 'reason'),
      ReportColumn('Amount', 'totalAmount', currency: true),
    ],
  );
  static const customerCreditNotes = ReportConfig(
    title: 'Customer Credit Notes',
    endpoint: '/api/customer-credit-notes',
    icon: Icons.assignment_returned_outlined,
    color: Color(0xFF7C3AED),
    supportsPeriod: true,
    totalField: 'totalAmount',
    groupBy: 'customerName',
    groupNoun: 'notes',
    columns: [
      ReportColumn('Customer', 'customerName', primary: true),
      ReportColumn('CN No', 'creditNoteNumber'),
      ReportColumn('Date', 'creditNoteDate', isDate: true),
      ReportColumn('Reason', 'reason'),
      ReportColumn('Amount', 'totalAmount', currency: true),
    ],
  );

  // ── Inventory (shape: {items:[{itemName,unit,totalQty,totalValueWAC,…}]}) ──
  static const inventoryValuation = ReportConfig(
    title: 'Stock Valuation',
    endpoint: '/api/inventory-reports/stock-valuation',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF0891B2),
    labelKeys: ['itemName', 'productName', 'name'],
    amountKeys: ['totalValueWAC', 'totalValueLPP', 'stockValue', 'value'],
    subtitleKeys: ['itemCode', 'totalQty', 'unit', 'category'],
  );

  // ── GL Day Book (shape: {days:[{date,count,total,memoTotal}]}) ──
  static const glDayBook = ReportConfig(
    title: 'Day Book',
    endpoint: '/api/gl/day-book',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF475569),
    labelKeys: ['date'],
    amountKeys: ['total', 'memoTotal'],
    subtitleKeys: ['count'],
  );
}
