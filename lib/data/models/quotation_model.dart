import 'package:flutter/material.dart';

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

/// One quotation line. Amounts are server-authoritative; on create we only send
/// description / quantity / rate / taxPercent (single GST% per line, matching web).
class QuotationLine {
  final String description;
  final double quantity;
  final double rate;
  final double taxPercent;
  final double lineSubtotal;
  final double lineTax;
  final double lineTotal;

  const QuotationLine({
    required this.description,
    required this.quantity,
    required this.rate,
    required this.taxPercent,
    this.lineSubtotal = 0,
    this.lineTax = 0,
    this.lineTotal = 0,
  });

  factory QuotationLine.fromJson(Map<String, dynamic> j) => QuotationLine(
        description: (j['description'] ?? '').toString(),
        quantity: _toD(j['quantity']),
        rate: _toD(j['rate']),
        taxPercent: _toD(j['taxPercent']),
        lineSubtotal: _toD(j['lineSubtotal']),
        lineTax: _toD(j['lineTax']),
        lineTotal: _toD(j['lineTotal']),
      );
}

class Quotation {
  final int id;
  final String quoteNumber;
  final int? customerId;
  final int? leadId;
  final String? contactName;
  final String? customerName;
  final String? quoteDate;
  final String? validUntil;
  final String status;
  final String? notes;
  final String? terms;
  final double subtotal;
  final double taxAmount;
  final double total;
  final int? convertedInvoiceId;
  final List<QuotationLine> lines;

  const Quotation({
    required this.id,
    required this.quoteNumber,
    required this.status,
    this.customerId,
    this.leadId,
    this.contactName,
    this.customerName,
    this.quoteDate,
    this.validUntil,
    this.notes,
    this.terms,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.total = 0,
    this.convertedInvoiceId,
    this.lines = const [],
  });

  factory Quotation.fromJson(Map<String, dynamic> j) {
    final cust = j['customer'];
    return Quotation(
      id: j['id'] as int,
      quoteNumber: (j['quoteNumber'] ?? '').toString(),
      customerId: j['customerId'] as int?,
      leadId: j['leadId'] as int?,
      contactName: j['contactName']?.toString(),
      customerName: cust is Map ? cust['customerName']?.toString() : j['customerName']?.toString(),
      quoteDate: j['quoteDate']?.toString(),
      validUntil: j['validUntil']?.toString(),
      status: (j['status'] ?? 'DRAFT').toString(),
      notes: j['notes']?.toString(),
      terms: j['terms']?.toString(),
      subtotal: _toD(j['subtotal']),
      taxAmount: _toD(j['taxAmount']),
      total: _toD(j['total']),
      convertedInvoiceId: j['convertedInvoiceId'] as int?,
      lines: (j['lines'] as List<dynamic>?)
              ?.map((e) => QuotationLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// The party a quote is addressed to (customer, else free-text contact).
  String get partyLabel =>
      (customerName != null && customerName!.isNotEmpty) ? customerName! : (contactName?.isNotEmpty == true ? contactName! : '—');

  bool get isConverted => status == 'CONVERTED' || convertedInvoiceId != null;
  bool get canConvert => status == 'ACCEPTED' && convertedInvoiceId == null;
  bool get isLocked => status == 'CONVERTED';
}

/// Statuses + web-matched colours (QuotationsPage.jsx:8).
class QuotationStatus {
  static const all = ['DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CONVERTED'];

  /// User-settable transitions (excludes system-only CONVERTED).
  static const settable = ['SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED'];

  static Color color(String s) {
    switch (s) {
      case 'DRAFT':
        return const Color(0xFF64748B);
      case 'SENT':
        return const Color(0xFF0EA5E9);
      case 'ACCEPTED':
        return const Color(0xFF059669);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      case 'EXPIRED':
        return const Color(0xFFF59E0B);
      case 'CONVERTED':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF64748B);
    }
  }
}
