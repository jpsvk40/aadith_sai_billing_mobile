import 'package:flutter/material.dart';
import '../reports/screens/report_view_screen.dart';

/// Declarative configs for the shared-spine READ surfaces that render through the generic
/// [ReportViewScreen] (list + total header). Key lists are matched to the real backend
/// response shapes (curl-verified 2026-07-03); complex statements (P&L/BS/TB, GST,
/// payables, payroll) have bespoke screens instead.
class FinanceReports {
  // ── Payables quick links ──
  static const vendorPayments = ReportConfig(
    title: 'Vendor Payments',
    endpoint: '/api/vendor-payments',
    icon: Icons.payments_outlined,
    color: Color(0xFF059669),
    labelKeys: ['vendorName', 'name', 'partyName', 'paymentNumber'],
    amountKeys: ['amount', 'paidAmount', 'totalAmount', 'total'],
    subtitleKeys: ['paymentNumber', 'paymentDate', 'date', 'mode', 'reference'],
  );
  static const vendorCreditNotes = ReportConfig(
    title: 'Vendor Credit Notes',
    endpoint: '/api/vendor-credit-notes',
    icon: Icons.assignment_return_outlined,
    color: Color(0xFFD97706),
    labelKeys: ['vendorName', 'name', 'partyName', 'creditNoteNumber'],
    amountKeys: ['amount', 'creditAmount', 'totalAmount', 'total'],
    subtitleKeys: ['creditNoteNumber', 'noteNumber', 'date', 'reason'],
  );
  static const customerCreditNotes = ReportConfig(
    title: 'Customer Credit Notes',
    endpoint: '/api/customer-credit-notes',
    icon: Icons.assignment_returned_outlined,
    color: Color(0xFF7C3AED),
    labelKeys: ['customerName', 'name', 'partyName', 'creditNoteNumber'],
    amountKeys: ['amount', 'creditAmount', 'totalAmount', 'total'],
    subtitleKeys: ['creditNoteNumber', 'noteNumber', 'date', 'reason'],
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
