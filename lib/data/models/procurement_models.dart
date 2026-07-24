// Procurement models — mirrors the web portal's front-funnel:
// Material Requisition → RFQ / Vendor Quotations → Purchase Order → Payment Request.
// All tolerant fromJson (Prisma returns Decimals as strings, ids as ints).

int _i(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);
double _d(dynamic v) => v == null ? 0 : (double.tryParse(v.toString()) ?? 0);
String _s(dynamic v) => v?.toString() ?? '';
String? _sn(dynamic v) => v == null ? null : (v.toString().trim().isEmpty ? null : v.toString());
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

/// Formats a quantity dropping a trailing `.0` (5.0 → "5", 5.5 → "5.5").
String fmtQty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

// ─────────────────────────── Material Requisition ───────────────────────────

class RequisitionItem {
  final int id;
  final String itemDescription;
  final String unit;
  final double quantity;
  final String? notes;

  const RequisitionItem({
    required this.id,
    required this.itemDescription,
    required this.unit,
    required this.quantity,
    this.notes,
  });

  factory RequisitionItem.fromJson(Map<String, dynamic> j) => RequisitionItem(
        id: _i(j['id']),
        itemDescription: _s(j['itemDescription']),
        unit: _s(j['unit']).isEmpty ? 'nos' : _s(j['unit']),
        quantity: _d(j['quantity']),
        notes: _sn(j['notes']),
      );
}

class Requisition {
  final int id;
  final String mrNumber;
  final DateTime? requisitionDate;
  final DateTime? requiredByDate;
  final String? department;
  final String priority;
  final String status;
  final String? notes;
  final String? rejectionReason;
  final List<RequisitionItem> items;

  const Requisition({
    required this.id,
    required this.mrNumber,
    this.requisitionDate,
    this.requiredByDate,
    this.department,
    this.priority = 'NORMAL',
    this.status = 'DRAFT',
    this.notes,
    this.rejectionReason,
    this.items = const [],
  });

  factory Requisition.fromJson(Map<String, dynamic> j) => Requisition(
        id: _i(j['id']),
        mrNumber: _s(j['mrNumber']),
        requisitionDate: _dt(j['requisitionDate']),
        requiredByDate: _dt(j['requiredByDate']),
        department: _sn(j['department']),
        priority: _s(j['priority']).isEmpty ? 'NORMAL' : _s(j['priority']),
        status: _s(j['status']).isEmpty ? 'DRAFT' : _s(j['status']),
        notes: _sn(j['notes']),
        rejectionReason: _sn(j['rejectionReason']),
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => RequisitionItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

// ─────────────────────────── RFQ / Vendor Quotations ───────────────────────────

class RfqItem {
  final int id;
  final String itemDescription;
  final String unit;
  final double quantity;

  const RfqItem({required this.id, required this.itemDescription, required this.unit, required this.quantity});

  factory RfqItem.fromJson(Map<String, dynamic> j) => RfqItem(
        id: _i(j['id']),
        itemDescription: _s(j['itemDescription']),
        unit: _s(j['unit']).isEmpty ? 'nos' : _s(j['unit']),
        quantity: _d(j['quantity']),
      );
}

class RfqVendor {
  final int id;
  final int vendorId;
  const RfqVendor({required this.id, required this.vendorId});

  factory RfqVendor.fromJson(Map<String, dynamic> j) =>
      RfqVendor(id: _i(j['id']), vendorId: _i(j['vendorId']));
}

class RfqQuotation {
  final int id;
  final int vendorId;
  final double totalAmount;
  final String status;
  final int? deliveryDays;

  const RfqQuotation({
    required this.id,
    required this.vendorId,
    required this.totalAmount,
    this.status = 'RECEIVED',
    this.deliveryDays,
  });

  factory RfqQuotation.fromJson(Map<String, dynamic> j) => RfqQuotation(
        id: _i(j['id']),
        vendorId: _i(j['vendorId']),
        totalAmount: _d(j['totalAmount']),
        status: _s(j['status']).isEmpty ? 'RECEIVED' : _s(j['status']),
        deliveryDays: j['deliveryDays'] == null ? null : _i(j['deliveryDays']),
      );
}

class Rfq {
  final int id;
  final String rfqNumber;
  final DateTime? rfqDate;
  final DateTime? dueDate;
  final String status;
  final String? notes;
  final int? selectedQuotationId;
  final List<RfqItem> items;
  final List<RfqVendor> vendors;
  final List<RfqQuotation> quotations;

  const Rfq({
    required this.id,
    required this.rfqNumber,
    this.rfqDate,
    this.dueDate,
    this.status = 'DRAFT',
    this.notes,
    this.selectedQuotationId,
    this.items = const [],
    this.vendors = const [],
    this.quotations = const [],
  });

  factory Rfq.fromJson(Map<String, dynamic> j) => Rfq(
        id: _i(j['id']),
        rfqNumber: _s(j['rfqNumber']),
        rfqDate: _dt(j['rfqDate']),
        dueDate: _dt(j['dueDate']),
        status: _s(j['status']).isEmpty ? 'DRAFT' : _s(j['status']),
        notes: _sn(j['notes']),
        selectedQuotationId: j['selectedQuotationId'] == null ? null : _i(j['selectedQuotationId']),
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => RfqItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        vendors: (j['vendors'] as List<dynamic>?)
                ?.map((e) => RfqVendor.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        quotations: (j['quotations'] as List<dynamic>?)
                ?.map((e) => RfqQuotation.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

// ─────────────────────────── Purchase Order ───────────────────────────

class PurchaseOrderItem {
  final int id;
  final String description;
  final String unit;
  final double quantity;
  final double rate;
  final double taxPercent;
  final double amount;

  const PurchaseOrderItem({
    required this.id,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.rate,
    required this.taxPercent,
    required this.amount,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> j) => PurchaseOrderItem(
        id: _i(j['id']),
        description: _s(j['description']),
        unit: _s(j['unit']).isEmpty ? 'nos' : _s(j['unit']),
        quantity: _d(j['quantity']),
        rate: _d(j['rate']),
        taxPercent: _d(j['taxPercent']),
        amount: _d(j['amount']),
      );
}

class PurchaseOrder {
  final int id;
  final String poNumber;
  final DateTime? poDate;
  final String status;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final String? notes;
  final String? holdReason;
  final List<PurchaseOrderItem> items;

  const PurchaseOrder({
    required this.id,
    required this.poNumber,
    this.poDate,
    this.status = 'PENDING_APPROVAL',
    this.subtotal = 0,
    this.gstAmount = 0,
    this.totalAmount = 0,
    this.notes,
    this.holdReason,
    this.items = const [],
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> j) => PurchaseOrder(
        id: _i(j['id']),
        poNumber: _s(j['poNumber']),
        poDate: _dt(j['poDate']),
        status: _s(j['status']).isEmpty ? 'PENDING_APPROVAL' : _s(j['status']),
        subtotal: _d(j['subtotal']),
        gstAmount: _d(j['gstAmount']),
        totalAmount: _d(j['totalAmount']),
        notes: _sn(j['notes']),
        holdReason: _sn(j['holdReason']),
        items: (j['items'] as List<dynamic>?)
                ?.map((e) => PurchaseOrderItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

// ─────────────────────────── Payment Request ───────────────────────────

class PaymentRequest {
  final int id;
  final String requestNumber;
  final int vendorId;
  final int vendorPurchaseId;
  final double amount;
  final String paymentMode;
  final String status;
  final String? holdReason;
  final DateTime? createdAt;

  const PaymentRequest({
    required this.id,
    required this.requestNumber,
    this.vendorId = 0,
    this.vendorPurchaseId = 0,
    this.amount = 0,
    this.paymentMode = 'Bank Transfer',
    this.status = 'PENDING',
    this.holdReason,
    this.createdAt,
  });

  factory PaymentRequest.fromJson(Map<String, dynamic> j) => PaymentRequest(
        id: _i(j['id']),
        requestNumber: _s(j['requestNumber']),
        vendorId: _i(j['vendorId']),
        vendorPurchaseId: _i(j['vendorPurchaseId']),
        amount: _d(j['amount']),
        paymentMode: _s(j['paymentMode']).isEmpty ? 'Bank Transfer' : _s(j['paymentMode']),
        status: _s(j['status']).isEmpty ? 'PENDING' : _s(j['status']),
        holdReason: _sn(j['holdReason']),
        createdAt: _dt(j['createdAt']),
      );

  PaymentRequest copyWith({String? status, String? holdReason}) => PaymentRequest(
        id: id,
        requestNumber: requestNumber,
        vendorId: vendorId,
        vendorPurchaseId: vendorPurchaseId,
        amount: amount,
        paymentMode: paymentMode,
        status: status ?? this.status,
        holdReason: holdReason ?? this.holdReason,
        createdAt: createdAt,
      );

  bool get isActionable => status == 'PENDING' || status == 'HOLD';
}

// ─────────────────────────── Project (for the requisition form dropdown) ───────────────────────────

class ProcProject {
  final int id;
  final String code;
  final String name;
  const ProcProject({required this.id, required this.code, required this.name});

  factory ProcProject.fromJson(Map<String, dynamic> j) => ProcProject(
        id: _i(j['id']),
        code: _s(j['projectCode']),
        name: _s(j['projectName']),
      );

  String get label => code.isEmpty ? name : (name.isEmpty ? code : '$code · $name');
}
