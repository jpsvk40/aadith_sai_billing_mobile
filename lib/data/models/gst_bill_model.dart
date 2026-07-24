// GST Bills — mobile parity with the web GstBillsPage + backend routes/gst-bills.js.
// A "GST bill" is an invoice row the GST-visible query returns: split GST/entity
// children plus standalone STANDARD invoices carrying GST (or pure zero-rated).

// Tolerant coercers — the endpoint returns numbers as num OR string, and the
// nested includes (customer / legalEntity / parentInvoice / order) may be absent.
double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int? _toI(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));
String? _str(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// E-Way bill is normally required only at/above this consignment value.
const double kEwayBillThreshold = 50000;

class GstBill {
  final int? id;
  final String? invoiceNo;
  final String? gstInvoiceNo;
  final String? displayInvoiceNo; // server-computed: gstInvoiceNo || invoiceNo
  final String? displayParentInvoiceNo; // collection (split-parent) bill number
  final String? invoiceDate;
  final String? customerName;
  final String? customerCity;
  final int? legalEntityId;
  final String? legalEntityName;
  final String? legalEntityGstin;
  final int? parentInvoiceId;
  final int? orderId;
  final String? orderNo;
  final double gstTotal;
  final double grandTotal;
  final double balanceAmount;
  final String paymentStatus; // Unpaid | Partial | Paid
  final String status; // Active | Cancelled
  final String? invoiceRole; // STANDARD | SPLIT_CHILD | SPLIT_PARENT
  final String? splitType; // GST_CHILD | ENTITY_CHILD | CASH_CHILD | …
  final String? splitPaymentMode; // Cash | Card | …

  const GstBill({
    this.id,
    this.invoiceNo,
    this.gstInvoiceNo,
    this.displayInvoiceNo,
    this.displayParentInvoiceNo,
    this.invoiceDate,
    this.customerName,
    this.customerCity,
    this.legalEntityId,
    this.legalEntityName,
    this.legalEntityGstin,
    this.parentInvoiceId,
    this.orderId,
    this.orderNo,
    this.gstTotal = 0,
    this.grandTotal = 0,
    this.balanceAmount = 0,
    this.paymentStatus = 'Unpaid',
    this.status = 'Active',
    this.invoiceRole,
    this.splitType,
    this.splitPaymentMode,
  });

  factory GstBill.fromJson(Map<String, dynamic> j) {
    final cust = j['customer'];
    final ent = j['legalEntity'];
    final order = j['order'];
    return GstBill(
      id: _toI(j['id']),
      invoiceNo: _str(j['invoiceNo']),
      gstInvoiceNo: _str(j['gstInvoiceNo']),
      displayInvoiceNo:
          _str(j['displayInvoiceNo']) ?? _str(j['gstInvoiceNo']) ?? _str(j['invoiceNo']),
      displayParentInvoiceNo: _str(j['displayParentInvoiceNo']),
      invoiceDate: _str(j['invoiceDate']),
      customerName: cust is Map ? _str(cust['customerName']) : _str(j['billingName']),
      customerCity: cust is Map ? _str(cust['city']) : null,
      legalEntityId: ent is Map ? _toI(ent['id']) : _toI(j['legalEntityId']),
      legalEntityName: ent is Map ? _str(ent['name']) : null,
      legalEntityGstin: ent is Map ? _str(ent['gstNumber']) : null,
      parentInvoiceId: _toI(j['parentInvoiceId']),
      orderId: order is Map ? _toI(order['id']) : null,
      orderNo: order is Map ? _str(order['orderNo']) : null,
      gstTotal: _toD(j['gstTotal']),
      grandTotal: _toD(j['grandTotal']),
      balanceAmount: _toD(j['balanceAmount']),
      paymentStatus: (j['paymentStatus'] ?? 'Unpaid').toString(),
      status: (j['status'] ?? 'Active').toString(),
      invoiceRole: _str(j['invoiceRole']),
      splitType: _str(j['splitType']),
      splitPaymentMode: _str(j['splitPaymentMode']),
    );
  }

  bool get isVoided => status == 'Cancelled';

  /// Taxable value net of tax — a round-off-agnostic KPI approximation.
  double get taxable {
    final t = grandTotal - gstTotal;
    return t > 0 ? t : 0;
  }

  bool get ewayEligible => grandTotal >= kEwayBillThreshold;

  /// Mirrors the web's Assign-GST-# eligibility gate (the admin ROLE check is
  /// applied separately by the caller). A bill can be numbered only if it has no
  /// GST number yet, is active, isn't a cash/collection bill, and is either a
  /// standalone STANDARD invoice or a legal-entity child.
  bool get gstNumberAssignable =>
      (gstInvoiceNo == null || gstInvoiceNo!.isEmpty) &&
      status != 'Cancelled' &&
      splitType != 'CASH_CHILD' &&
      splitPaymentMode != 'Cash' &&
      invoiceRole != 'SPLIT_PARENT' &&
      ((invoiceRole == 'STANDARD' && parentInvoiceId == null) || splitType == 'ENTITY_CHILD');

  String get entityLabel => legalEntityName ?? 'No Entity';
}

/// GET /api/gst-bills/summary — dashboard totals for the filter window.
class GstBillSummary {
  final int totalCount;
  final double totalAmount;
  final int unpaidCount;
  final double unpaidAmount;
  final int partialCount;
  final double partialAmount;
  final int voidedCount;
  final double voidedAmount;

  const GstBillSummary({
    this.totalCount = 0,
    this.totalAmount = 0,
    this.unpaidCount = 0,
    this.unpaidAmount = 0,
    this.partialCount = 0,
    this.partialAmount = 0,
    this.voidedCount = 0,
    this.voidedAmount = 0,
  });

  factory GstBillSummary.fromJson(Map<String, dynamic> j) => GstBillSummary(
        totalCount: _toD(j['totalCount']).toInt(),
        totalAmount: _toD(j['totalAmount']),
        unpaidCount: _toD(j['unpaidCount']).toInt(),
        unpaidAmount: _toD(j['unpaidAmount']),
        partialCount: _toD(j['partialCount']).toInt(),
        partialAmount: _toD(j['partialAmount']),
        voidedCount: _toD(j['voidedCount']).toInt(),
        voidedAmount: _toD(j['voidedAmount']),
      );

  int get paidCount {
    final v = totalCount - unpaidCount - partialCount;
    return v < 0 ? 0 : v;
  }

  double get paidAmount => totalAmount - unpaidAmount - partialAmount;
}

class GstBillListResult {
  final List<GstBill> bills;
  final int total;
  const GstBillListResult({this.bills = const [], this.total = 0});
}

/// Result of a portal-assisted JSON export (e-Invoice / e-Way Bill).
class GstExportResult {
  final String docNo; // invoice number the JSON is for (for the share filename)
  final dynamic payload; // the GSTN/e-Way JSON body
  final List<String> warnings;
  const GstExportResult({required this.docNo, this.payload, this.warnings = const []});
}
