import 'package:flutter/material.dart';

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int? _toInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));

/// One line echoed back by the customer credit-note `/suggest` prefill. Amounts are
/// server-authoritative; on mobile we prefill the lump-sum totals rather than an
/// editable grid, but the parsed lines let us show "N lines from invoice X".
class CreditNoteItem {
  final String description;
  final String? hsnCode;
  final double quantity;
  final String? uom;
  final double rate;
  final double discount;
  final double taxPercent;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double lineTotal;

  const CreditNoteItem({
    required this.description,
    this.hsnCode,
    this.quantity = 0,
    this.uom,
    this.rate = 0,
    this.discount = 0,
    this.taxPercent = 0,
    this.taxableValue = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.lineTotal = 0,
  });

  factory CreditNoteItem.fromJson(Map<String, dynamic> j) => CreditNoteItem(
        description: (j['description'] ?? '').toString(),
        hsnCode: j['hsnCode']?.toString(),
        quantity: _toD(j['quantity']),
        uom: j['uom']?.toString(),
        rate: _toD(j['rate']),
        discount: _toD(j['discount']),
        taxPercent: _toD(j['taxPercent']),
        taxableValue: _toD(j['taxableValue']),
        cgstAmount: _toD(j['cgstAmount']),
        sgstAmount: _toD(j['sgstAmount']),
        igstAmount: _toD(j['igstAmount']),
        lineTotal: _toD(j['lineTotal']),
      );
}

/// Prefill payload for a customer credit note built from a source invoice
/// (`GET /api/customer-credit-notes/suggest?invoiceId=`).
class CreditNoteSuggestion {
  final int? customerId;
  final String? customerName;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double roundOff;
  final double totalAmount;
  final double balanceAmount;
  final List<CreditNoteItem> items;

  const CreditNoteSuggestion({
    this.customerId,
    this.customerName,
    this.taxableAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.roundOff = 0,
    this.totalAmount = 0,
    this.balanceAmount = 0,
    this.items = const [],
  });

  factory CreditNoteSuggestion.fromJson(Map<String, dynamic> j) => CreditNoteSuggestion(
        customerId: _toInt(j['customerId']),
        customerName: j['customerName']?.toString(),
        taxableAmount: _toD(j['taxableAmount']),
        cgstAmount: _toD(j['cgstAmount']),
        sgstAmount: _toD(j['sgstAmount']),
        igstAmount: _toD(j['igstAmount']),
        roundOff: _toD(j['roundOff']),
        totalAmount: _toD(j['totalAmount']),
        balanceAmount: _toD(j['balanceAmount']),
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => CreditNoteItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// The invoice was inter-state (IGST) rather than intra-state (CGST+SGST).
  bool get isInterState => igstAmount > 0 && (cgstAmount + sgstAmount) <= 0;

  /// Back-computed single GST% (so the mobile lump-sum editor's Taxable + GST%
  /// stays consistent with the prefilled amounts). 0 when nothing to compute.
  double get gstPercent {
    if (taxableAmount <= 0) return 0;
    final tax = isInterState ? igstAmount : (cgstAmount + sgstAmount);
    if (tax <= 0) return 0;
    return double.parse((tax / taxableAmount * 100).toStringAsFixed(2));
  }
}

/// A row in the Customer Credit Notes list (`GET /api/customer-credit-notes`).
class CustomerCreditNote {
  final int id;
  final String creditNoteNumber;
  final String? creditNoteDate;
  final String? customerName;
  final String? reason;
  final double totalAmount;
  final double balanceAmount;
  final String status; // OPEN | PARTIALLY_APPLIED | APPLIED | CANCELLED
  final int? invoiceId;
  final int? customerId;

  const CustomerCreditNote({
    required this.id,
    required this.creditNoteNumber,
    required this.status,
    this.creditNoteDate,
    this.customerName,
    this.reason,
    this.totalAmount = 0,
    this.balanceAmount = 0,
    this.invoiceId,
    this.customerId,
  });

  factory CustomerCreditNote.fromJson(Map<String, dynamic> j) {
    final cust = j['customer'];
    return CustomerCreditNote(
      id: _toInt(j['id']) ?? 0,
      creditNoteNumber: (j['creditNoteNumber'] ?? '').toString(),
      creditNoteDate: j['creditNoteDate']?.toString(),
      customerName: cust is Map ? cust['customerName']?.toString() : j['customerName']?.toString(),
      reason: j['reason']?.toString(),
      totalAmount: _toD(j['totalAmount']),
      balanceAmount: _toD(j['balanceAmount']),
      status: (j['status'] ?? 'OPEN').toString(),
      invoiceId: _toInt(j['invoiceId']),
      customerId: _toInt(j['customerId']),
    );
  }
}

/// A row in the Vendor Credit Notes list (`GET /api/vendor-credit-notes`) — always
/// against one specific vendor purchase.
class VendorCreditNote {
  final int id;
  final String creditNoteNumber;
  final String? creditNoteDate;
  final String? reason;
  final double totalAmount;
  final String? status;
  final String vendorName;
  final String? purchaseNumber;
  final String? invoiceNumber;
  final int? vendorPurchaseId;

  const VendorCreditNote({
    required this.id,
    required this.creditNoteNumber,
    required this.vendorName,
    this.creditNoteDate,
    this.reason,
    this.totalAmount = 0,
    this.status,
    this.purchaseNumber,
    this.invoiceNumber,
    this.vendorPurchaseId,
  });

  factory VendorCreditNote.fromJson(Map<String, dynamic> j) {
    final v = j['vendor'];
    final vp = j['vendorPurchase'];
    return VendorCreditNote(
      id: _toInt(j['id']) ?? 0,
      creditNoteNumber: (j['creditNoteNumber'] ?? '').toString(),
      creditNoteDate: j['creditNoteDate']?.toString(),
      reason: j['reason']?.toString(),
      totalAmount: _toD(j['totalAmount']),
      status: j['status']?.toString(),
      vendorName: v is Map ? (v['vendorName']?.toString() ?? '—') : (j['vendorName']?.toString() ?? '—'),
      purchaseNumber: vp is Map ? vp['purchaseNumber']?.toString() : j['purchaseNumber']?.toString(),
      invoiceNumber: vp is Map ? vp['invoiceNumber']?.toString() : j['invoiceNumber']?.toString(),
      vendorPurchaseId: _toInt(j['vendorPurchaseId']),
    );
  }

  /// Best available label for the source bill.
  String get billLabel => purchaseNumber ?? invoiceNumber ?? 'Bill';
}

/// Customer credit-note statuses + web-matched colours.
class CustomerCreditNoteStatus {
  static const all = ['OPEN', 'PARTIALLY_APPLIED', 'APPLIED', 'CANCELLED'];

  /// Reason placeholder mirrors the web free-text field.
  static const reasonHint = 'Sales return / Rate difference / Shortage';

  static String pretty(String s) {
    switch (s) {
      case 'PARTIALLY_APPLIED':
        return 'Partial';
      case 'OPEN':
        return 'Open';
      case 'APPLIED':
        return 'Applied';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return s;
    }
  }

  static Color color(String s) {
    switch (s) {
      case 'OPEN':
        return const Color(0xFF0EA5E9);
      case 'PARTIALLY_APPLIED':
        return const Color(0xFFF59E0B);
      case 'APPLIED':
        return const Color(0xFF059669);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }
}

/// The five vendor credit-note reasons (web uses a fixed SELECT).
const kVendorCreditNoteReasons = ['Damage', 'Price discount', 'Shortage', 'Rate difference', 'Other'];
