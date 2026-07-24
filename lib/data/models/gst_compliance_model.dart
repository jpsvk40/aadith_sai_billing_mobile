import 'package:flutter/material.dart';

// Tolerant JSON coercers — the compliance/returns endpoints return numbers as
// either num or string, and includes may be missing, so read defensively.
double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String? _str(dynamic v) => v?.toString();

/// The customer sub-object on a compliance doc's `invoice` include.
/// e-Invoice docs include `gstin`; e-Way docs typically only send id + name.
class ComplianceCustomer {
  final String? id;
  final String? customerName;
  final String? gstin;

  const ComplianceCustomer({this.id, this.customerName, this.gstin});

  factory ComplianceCustomer.fromJson(Map<String, dynamic> j) => ComplianceCustomer(
        id: _str(j['id']),
        customerName: _str(j['customerName']),
        gstin: _str(j['gstin']),
      );
}

/// The `invoice` include shared by e-Invoice + e-Way docs. Note the server sends
/// `invoiceNo` (NOT `invoiceNumber`) and nests the party under `customer`.
class ComplianceInvoice {
  final String? id;
  final String? invoiceNo;
  final String? gstInvoiceNo;
  final String? invoiceDate;
  final double grandTotal;
  final ComplianceCustomer? customer;

  const ComplianceInvoice({
    this.id,
    this.invoiceNo,
    this.gstInvoiceNo,
    this.invoiceDate,
    this.grandTotal = 0,
    this.customer,
  });

  factory ComplianceInvoice.fromJson(Map<String, dynamic> j) {
    final cust = j['customer'];
    return ComplianceInvoice(
      id: _str(j['id']),
      invoiceNo: _str(j['invoiceNo']),
      gstInvoiceNo: _str(j['gstInvoiceNo']),
      invoiceDate: _str(j['invoiceDate']),
      grandTotal: _toD(j['grandTotal']),
      customer: cust is Map ? ComplianceCustomer.fromJson(cust.cast<String, dynamic>()) : null,
    );
  }

  /// Prefer the running invoice no; fall back to the GST invoice no.
  String get displayNo => (invoiceNo?.isNotEmpty == true) ? invoiceNo! : (gstInvoiceNo?.isNotEmpty == true ? gstInvoiceNo! : '—');

  String get customerName =>
      (customer?.customerName?.isNotEmpty == true) ? customer!.customerName! : '—';
}

/// One e-Invoice (IRN) register row.
class EinvoiceDoc {
  final String? id;
  final String status; // PENDING | GENERATED | CANCELLED | FAILED
  final String? irn;
  final String? ackNumber;
  final String? ackDate;
  final String? signedQrCode;
  final String? errorDetails;
  final String? createdAt;
  final ComplianceInvoice? invoice;

  const EinvoiceDoc({
    required this.status,
    this.id,
    this.irn,
    this.ackNumber,
    this.ackDate,
    this.signedQrCode,
    this.errorDetails,
    this.createdAt,
    this.invoice,
  });

  factory EinvoiceDoc.fromJson(Map<String, dynamic> j) {
    final inv = j['invoice'];
    return EinvoiceDoc(
      id: _str(j['id']),
      status: (j['status'] ?? 'PENDING').toString(),
      irn: _str(j['irn']),
      ackNumber: _str(j['ackNumber']),
      ackDate: _str(j['ackDate']),
      signedQrCode: _str(j['signedQrCode']),
      errorDetails: _str(j['errorDetails']),
      createdAt: _str(j['createdAt']),
      invoice: inv is Map ? ComplianceInvoice.fromJson(inv.cast<String, dynamic>()) : null,
    );
  }
}

/// e-Invoice status palette (parity with the web register badges).
class EinvoiceStatus {
  static const all = ['GENERATED', 'PENDING', 'FAILED', 'CANCELLED'];

  static Color color(String s) {
    switch (s) {
      case 'GENERATED':
        return const Color(0xFF16A34A); // green
      case 'PENDING':
        return const Color(0xFFF59E0B); // amber
      case 'CANCELLED':
        return const Color(0xFF64748B); // slate
      case 'FAILED':
        return const Color(0xFFDC2626); // red
      default:
        return const Color(0xFF64748B);
    }
  }
}

/// One e-Way bill register row.
class EwayBillDoc {
  final String? id;
  final String status; // PENDING | GENERATED | CANCELLED | EXPIRED | FAILED
  final String? ewbNumber;
  final String? ewbDate;
  final String? validUpto;
  final String? vehicleNumber;
  final String? transporterName;
  final String? transportMode; // '1' Road | '2' Rail | '3' Air | '4' Ship
  final double? distanceKm;
  final ComplianceInvoice? invoice;

  const EwayBillDoc({
    required this.status,
    this.id,
    this.ewbNumber,
    this.ewbDate,
    this.validUpto,
    this.vehicleNumber,
    this.transporterName,
    this.transportMode,
    this.distanceKm,
    this.invoice,
  });

  factory EwayBillDoc.fromJson(Map<String, dynamic> j) {
    final inv = j['invoice'];
    return EwayBillDoc(
      id: _str(j['id']),
      status: (j['status'] ?? 'PENDING').toString(),
      ewbNumber: _str(j['ewbNumber']),
      ewbDate: _str(j['ewbDate']),
      validUpto: _str(j['validUpto']),
      vehicleNumber: _str(j['vehicleNumber']),
      transporterName: _str(j['transporterName']),
      transportMode: _str(j['transportMode']),
      distanceKm: j['distanceKm'] == null ? null : _toD(j['distanceKm']),
      invoice: inv is Map ? ComplianceInvoice.fromJson(inv.cast<String, dynamic>()) : null,
    );
  }

  static const _modes = {'1': 'Road', '2': 'Rail', '3': 'Air', '4': 'Ship'};
  String get modeLabel => (transportMode == null || transportMode!.isEmpty)
      ? '—'
      : (_modes[transportMode] ?? 'Mode $transportMode');

  DateTime? get _validDt => (validUpto == null || validUpto!.isEmpty) ? null : DateTime.tryParse(validUpto!);

  bool get isExpired {
    final d = _validDt;
    return d != null && d.isBefore(DateTime.now());
  }

  /// validUpto is in the future but within the next 24h.
  bool get isExpiringSoon {
    final d = _validDt;
    if (d == null) return false;
    final now = DateTime.now();
    return d.isAfter(now) && d.isBefore(now.add(const Duration(hours: 24)));
  }
}

/// e-Way status palette + dropdown options (All + the 5 statuses, server-filtered).
class EwayStatus {
  static const all = ['PENDING', 'GENERATED', 'CANCELLED', 'EXPIRED', 'FAILED'];
  static const filterOptions = ['All', 'PENDING', 'GENERATED', 'CANCELLED', 'EXPIRED', 'FAILED'];

  static Color color(String s) {
    switch (s) {
      case 'GENERATED':
        return const Color(0xFF16A34A); // green
      case 'PENDING':
        return const Color(0xFFF59E0B); // amber
      case 'CANCELLED':
        return const Color(0xFF64748B); // slate
      case 'EXPIRED':
        return const Color(0xFFEA580C); // orange-red
      case 'FAILED':
        return const Color(0xFFDC2626); // red
      default:
        return const Color(0xFF64748B);
    }
  }
}

// ─────────────────────────── Legal entities (multi-GSTIN filter) ───────────────────────────

/// A lightweight legal-entity row for the "GST registration" filter. Sourced from
/// the same `/api/legal-entities` list the web GST page uses, so the label carries
/// the GSTIN (`name · gstNumber`) exactly like the web dropdown.
class LegalEntityLite {
  final String id;
  final String name;
  final String? gstNumber;

  const LegalEntityLite({required this.id, required this.name, this.gstNumber});

  factory LegalEntityLite.fromJson(Map<String, dynamic> j) => LegalEntityLite(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        gstNumber: _str(j['gstNumber']),
      );

  /// Dropdown label — mirrors the web: "Name · GSTIN" when a GSTIN exists.
  String get filterLabel =>
      (gstNumber != null && gstNumber!.isNotEmpty) ? '$name · $gstNumber' : name;

  bool get isValid => id.isNotEmpty && id != 'null' && name.isNotEmpty;
}

// ─────────────────────────── GST Returns (GSTR-1 / Tally) review ───────────────────────────

/// A section bucket with a count + rupee value (e.g. b2b, b2c).
class GstSection {
  final int count;
  final double value;
  const GstSection({this.count = 0, this.value = 0});

  factory GstSection.fromJson(Map<String, dynamic> j) => GstSection(
        count: _toD(j['count']).toInt(),
        value: _toD(j['value']),
      );
}

/// One GSTR-1 export row. The server keys carry spaces (e.g. 'Taxable Value').
class GstReturnRow {
  final String section;
  final String state;
  final double taxableValue;
  final String taxPercent; // display as-received (may be '', '5', '18' …)
  final double igst;
  final double cgst;
  final double sgst;
  final double total;

  const GstReturnRow({
    this.section = '',
    this.state = '',
    this.taxableValue = 0,
    this.taxPercent = '',
    this.igst = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.total = 0,
  });

  factory GstReturnRow.fromJson(Map<String, dynamic> j) => GstReturnRow(
        section: _str(j['Section']) ?? '',
        state: _str(j['State']) ?? '',
        taxableValue: _toD(j['Taxable Value']),
        taxPercent: _str(j['Tax %']) ?? '',
        igst: _toD(j['IGST']),
        cgst: _toD(j['CGST']),
        sgst: _toD(j['SGST']),
        total: _toD(j['Total']),
      );
}

/// A validation finding for the period — a blocker or a warning tied to an invoice.
class GstValidation {
  final String severity; // 'blocker' | 'warning'
  final String? code; // missing_customer_gstin | invalid_customer_gstin | tax_total_mismatch | missing_hsn | missing_uqc
  final String? invoiceNumber;
  final String? invoiceDate;
  final String message;

  const GstValidation({
    required this.severity,
    this.code,
    this.invoiceNumber,
    this.invoiceDate,
    this.message = '',
  });

  factory GstValidation.fromJson(Map<String, dynamic> j) => GstValidation(
        severity: (j['severity'] ?? 'warning').toString(),
        code: _str(j['code']),
        invoiceNumber: _str(j['invoiceNumber']),
        invoiceDate: _str(j['invoiceDate']),
        message: _str(j['message']) ?? '',
      );

  bool get isBlocker => severity == 'blocker';
}

/// The full GSTR-1 (Tally) review payload for a date window.
class GstReturnsReview {
  final String? period;
  final String? companyGstin;
  final String? supplierGstin;
  final int totalInvoices;
  final GstSection b2b;
  final GstSection b2c;
  final int b2csCount;
  final int b2clCount;
  final int hsnB2bCount;
  final int hsnB2cCount;
  final List<GstReturnRow> finalRows;
  final int blockers;
  final int warnings;
  final List<GstValidation> validations;

  const GstReturnsReview({
    this.period,
    this.companyGstin,
    this.supplierGstin,
    this.totalInvoices = 0,
    this.b2b = const GstSection(),
    this.b2c = const GstSection(),
    this.b2csCount = 0,
    this.b2clCount = 0,
    this.hsnB2bCount = 0,
    this.hsnB2cCount = 0,
    this.finalRows = const [],
    this.blockers = 0,
    this.warnings = 0,
    this.validations = const [],
  });

  factory GstReturnsReview.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(dynamic v) => v is Map ? v.cast<String, dynamic>() : const {};
    final hsn = m(j['hsn']);
    final vs = m(j['validationSummary']);
    return GstReturnsReview(
      period: _str(j['period']),
      companyGstin: _str(j['companyGstin']),
      supplierGstin: _str(j['supplierGstin']),
      totalInvoices: _toD(j['totalInvoices']).toInt(),
      b2b: GstSection.fromJson(m(j['b2b'])),
      b2c: GstSection.fromJson(m(j['b2c'])),
      b2csCount: _toD(m(j['b2cs'])['count']).toInt(),
      b2clCount: _toD(m(j['b2cl'])['count']).toInt(),
      hsnB2bCount: _toD(hsn['b2bCount']).toInt(),
      hsnB2cCount: _toD(hsn['b2cCount']).toInt(),
      finalRows: (j['finalRows'] as List?)
              ?.map((e) => GstReturnRow.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      blockers: _toD(vs['blockers']).toInt(),
      warnings: _toD(vs['warnings']).toInt(),
      validations: (j['validations'] as List?)
              ?.map((e) => GstValidation.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
    );
  }
}
