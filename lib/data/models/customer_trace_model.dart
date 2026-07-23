// Customer Trace DTOs — mirror the web BusinessTracePage "Customer Trace" panel.
// Backend: GET /api/business-trace/customer/:customerId?comparisonMode=...
// All fromJson are tolerant (strings/nums interchangeable, missing keys default).

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? _toDN(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
int _toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
String? _str(dynamic v) => v?.toString();

List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

/// A customer typeahead suggestion (GET /api/business-trace/customer-suggestions?q=).
class CustomerSuggestion {
  final String id;
  final String? customerCode;
  final String customerName;
  final String? phone;
  final String? city;
  final String? gstin;
  final double outstandingBalance;
  final String? lastOrderDate;
  final bool isActive;

  const CustomerSuggestion({
    required this.id,
    required this.customerName,
    this.customerCode,
    this.phone,
    this.city,
    this.gstin,
    this.outstandingBalance = 0,
    this.lastOrderDate,
    this.isActive = true,
  });

  factory CustomerSuggestion.fromJson(Map<String, dynamic> j) => CustomerSuggestion(
        id: (j['id'] ?? '').toString(),
        customerName: (j['customerName'] ?? j['name'] ?? '').toString(),
        customerCode: _str(j['customerCode']),
        phone: _str(j['phone']),
        city: _str(j['city']),
        gstin: _str(j['gstin']),
        outstandingBalance: _toD(j['outstandingBalance']),
        lastOrderDate: _str(j['lastOrderDate']),
        isActive: j['isActive'] as bool? ?? true,
      );

  /// "CODE · City · Phone" — matches the web suggestion subtitle.
  String get subtitle => [customerCode, city, phone].where((e) => e != null && e.isNotEmpty).join(' · ');
}

class TraceCustomer {
  final String id;
  final String? customerCode;
  final String customerName;
  final String? customerNameTa;
  final String? phone;
  final String? whatsappContact;
  final String? city;
  final String? district;
  final String? gstin;
  final double creditLimit;
  final int paymentTermsDays;
  final bool isActive;
  final String? billingAddress;

  const TraceCustomer({
    required this.id,
    required this.customerName,
    this.customerCode,
    this.customerNameTa,
    this.phone,
    this.whatsappContact,
    this.city,
    this.district,
    this.gstin,
    this.creditLimit = 0,
    this.paymentTermsDays = 0,
    this.isActive = true,
    this.billingAddress,
  });

  factory TraceCustomer.fromJson(Map<String, dynamic> j) => TraceCustomer(
        id: (j['id'] ?? '').toString(),
        customerName: (j['customerName'] ?? '').toString(),
        customerCode: _str(j['customerCode']),
        customerNameTa: _str(j['customerNameTa']),
        phone: _str(j['phone']),
        whatsappContact: _str(j['whatsappContact']),
        city: _str(j['city']),
        district: _str(j['district']),
        gstin: _str(j['gstin']),
        creditLimit: _toD(j['creditLimit']),
        paymentTermsDays: _toI(j['paymentTermsDays']),
        isActive: j['isActive'] as bool? ?? true,
        billingAddress: _str(j['billingAddress']),
      );
}

class TraceRepresentative {
  final String? id;
  final String name;
  final String? phone;
  const TraceRepresentative({required this.name, this.id, this.phone});
  factory TraceRepresentative.fromJson(Map<String, dynamic> j) => TraceRepresentative(
        id: _str(j['id']),
        name: (j['name'] ?? '').toString(),
        phone: _str(j['phone']),
      );
}

class TracePeriod {
  final String periodLabel;
  final String? currentPeriodStart;
  final String? currentPeriodEnd;
  final String? priorPeriodStart;
  final String? priorPeriodEnd;
  const TracePeriod({
    this.periodLabel = '',
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.priorPeriodStart,
    this.priorPeriodEnd,
  });
  factory TracePeriod.fromJson(Map<String, dynamic> j) => TracePeriod(
        periodLabel: (j['periodLabel'] ?? '').toString(),
        currentPeriodStart: _str(j['currentPeriodStart']),
        currentPeriodEnd: _str(j['currentPeriodEnd']),
        priorPeriodStart: _str(j['priorPeriodStart']),
        priorPeriodEnd: _str(j['priorPeriodEnd']),
      );
}

class TraceSummary {
  final int totalOrders;
  final int currentOrders;
  final int priorOrders;
  final double totalInvoiceValue;
  final double currentInvoiceValue;
  final double priorInvoiceValue;
  final double averageOrderValue;
  final int invoiceCount;
  final int paidInvoiceCount;
  final double outstandingBalance;
  final double overdueBalance;
  final String? lastInvoiceDate;
  final String? cadenceStatus;
  final String? lastOrderDate;
  final double? avgDaysBetweenOrders;
  final double? medianDaysBetweenOrders;
  final String? expectedNextOrderDate;
  final int daysOverdueForCadence;
  final double? avgPaymentDelayDays;
  final double? onTimePaymentRatio; // 0..1
  final double returnOrderRatio; // 0..1
  final double returnValueRatio; // 0..1
  final int returnTotal;
  final int cancelledInvoiceCount;

  const TraceSummary({
    this.totalOrders = 0,
    this.currentOrders = 0,
    this.priorOrders = 0,
    this.totalInvoiceValue = 0,
    this.currentInvoiceValue = 0,
    this.priorInvoiceValue = 0,
    this.averageOrderValue = 0,
    this.invoiceCount = 0,
    this.paidInvoiceCount = 0,
    this.outstandingBalance = 0,
    this.overdueBalance = 0,
    this.lastInvoiceDate,
    this.cadenceStatus,
    this.lastOrderDate,
    this.avgDaysBetweenOrders,
    this.medianDaysBetweenOrders,
    this.expectedNextOrderDate,
    this.daysOverdueForCadence = 0,
    this.avgPaymentDelayDays,
    this.onTimePaymentRatio,
    this.returnOrderRatio = 0,
    this.returnValueRatio = 0,
    this.returnTotal = 0,
    this.cancelledInvoiceCount = 0,
  });

  factory TraceSummary.fromJson(Map<String, dynamic> j) => TraceSummary(
        totalOrders: _toI(j['totalOrders']),
        currentOrders: _toI(j['currentOrders']),
        priorOrders: _toI(j['priorOrders']),
        totalInvoiceValue: _toD(j['totalInvoiceValue']),
        currentInvoiceValue: _toD(j['currentInvoiceValue']),
        priorInvoiceValue: _toD(j['priorInvoiceValue']),
        averageOrderValue: _toD(j['averageOrderValue']),
        invoiceCount: _toI(j['invoiceCount']),
        paidInvoiceCount: _toI(j['paidInvoiceCount']),
        outstandingBalance: _toD(j['outstandingBalance']),
        overdueBalance: _toD(j['overdueBalance']),
        lastInvoiceDate: _str(j['lastInvoiceDate']),
        cadenceStatus: _str(j['cadenceStatus']),
        lastOrderDate: _str(j['lastOrderDate']),
        avgDaysBetweenOrders: _toDN(j['avgDaysBetweenOrders']),
        medianDaysBetweenOrders: _toDN(j['medianDaysBetweenOrders']),
        expectedNextOrderDate: _str(j['expectedNextOrderDate']),
        daysOverdueForCadence: _toI(j['daysOverdueForCadence']),
        avgPaymentDelayDays: _toDN(j['avgPaymentDelayDays']),
        onTimePaymentRatio: _toDN(j['onTimePaymentRatio']),
        returnOrderRatio: _toD(j['returnOrderRatio']),
        returnValueRatio: _toD(j['returnValueRatio']),
        returnTotal: _toI(j['returnTotal']),
        cancelledInvoiceCount: _toI(j['cancelledInvoiceCount']),
      );
}

class TraceOrderRow {
  final String? orderId;
  final String? orderNo;
  final String? orderDate;
  final String? orderStatus;
  final double grandTotal;
  final double balanceAmount;
  final List<String> invoiceNos;
  final String? paymentStatus;

  const TraceOrderRow({
    this.orderId,
    this.orderNo,
    this.orderDate,
    this.orderStatus,
    this.grandTotal = 0,
    this.balanceAmount = 0,
    this.invoiceNos = const [],
    this.paymentStatus,
  });

  factory TraceOrderRow.fromJson(Map<String, dynamic> j) => TraceOrderRow(
        orderId: _str(j['orderId']),
        orderNo: _str(j['orderNo']),
        orderDate: _str(j['orderDate']),
        orderStatus: _str(j['orderStatus']),
        grandTotal: _toD(j['grandTotal']),
        balanceAmount: _toD(j['balanceAmount']),
        invoiceNos: _strList(j['invoiceNos']),
        paymentStatus: _str(j['paymentStatus']),
      );
}

class TraceInvoiceRow {
  final String? invoiceId;
  final String? invoiceNo;
  final String? invoiceDate;
  final String? dueDate;
  final String? status;
  final String? paymentStatus;
  final double grandTotal;
  final double paidAmount;
  final double balanceAmount;

  const TraceInvoiceRow({
    this.invoiceId,
    this.invoiceNo,
    this.invoiceDate,
    this.dueDate,
    this.status,
    this.paymentStatus,
    this.grandTotal = 0,
    this.paidAmount = 0,
    this.balanceAmount = 0,
  });

  factory TraceInvoiceRow.fromJson(Map<String, dynamic> j) => TraceInvoiceRow(
        invoiceId: _str(j['invoiceId']),
        invoiceNo: _str(j['invoiceNo']),
        invoiceDate: _str(j['invoiceDate']),
        dueDate: _str(j['dueDate']),
        status: _str(j['status']),
        paymentStatus: _str(j['paymentStatus']),
        grandTotal: _toD(j['grandTotal']),
        paidAmount: _toD(j['paidAmount']),
        balanceAmount: _toD(j['balanceAmount']),
      );
}

class TracePaymentRow {
  final String? id;
  final String? paymentDate;
  final String? invoiceNo;
  final double amount;
  final String? paymentMode;
  final double? delayDays;

  const TracePaymentRow({
    this.id,
    this.paymentDate,
    this.invoiceNo,
    this.amount = 0,
    this.paymentMode,
    this.delayDays,
  });

  factory TracePaymentRow.fromJson(Map<String, dynamic> j) => TracePaymentRow(
        id: _str(j['id']),
        paymentDate: _str(j['paymentDate']),
        invoiceNo: _str(j['invoiceNo']),
        amount: _toD(j['amount']),
        paymentMode: _str(j['paymentMode']),
        delayDays: _toDN(j['delayDays']),
      );
}

class TraceProductRow {
  final String? productId;
  final String productName;
  final String? unit;
  final double quantity;
  final double revenue;
  final double avgRate;
  final String? lastBought;

  const TraceProductRow({
    this.productId,
    required this.productName,
    this.unit,
    this.quantity = 0,
    this.revenue = 0,
    this.avgRate = 0,
    this.lastBought,
  });

  factory TraceProductRow.fromJson(Map<String, dynamic> j) => TraceProductRow(
        productId: _str(j['productId']),
        productName: (j['productName'] ?? '').toString(),
        unit: _str(j['unit']),
        quantity: _toD(j['quantity']),
        revenue: _toD(j['revenue']),
        avgRate: _toD(j['avgRate']),
        lastBought: _str(j['lastBought']),
      );
}

class TraceMissingProduct {
  final String productName;
  final String? unit;
  final String? lastBought;
  const TraceMissingProduct({required this.productName, this.unit, this.lastBought});
  factory TraceMissingProduct.fromJson(Map<String, dynamic> j) => TraceMissingProduct(
        productName: (j['productName'] ?? '').toString(),
        unit: _str(j['unit']),
        lastBought: _str(j['lastBought']),
      );
}

class TraceReturnRow {
  final String? orderNo;
  final String? orderDate;
  final double grandTotal;
  final List<String> invoiceNos;
  const TraceReturnRow({this.orderNo, this.orderDate, this.grandTotal = 0, this.invoiceNos = const []});
  factory TraceReturnRow.fromJson(Map<String, dynamic> j) => TraceReturnRow(
        orderNo: _str(j['orderNo']),
        orderDate: _str(j['orderDate']),
        grandTotal: _toD(j['grandTotal']),
        invoiceNos: _strList(j['invoiceNos']),
      );
}

class TraceRiskFlag {
  final String flag;
  final String message;
  const TraceRiskFlag({required this.flag, required this.message});
  factory TraceRiskFlag.fromJson(Map<String, dynamic> j) => TraceRiskFlag(
        flag: (j['flag'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
      );
}

class TraceServiceStats {
  final int totalTickets;
  final int openTickets;
  final int reworkTickets;
  final int deliveredTickets;
  final double repeatRepairRate; // 0..1
  final double totalServiceRevenue;
  final double serviceOutstanding;
  final int warrantyItems;
  final int activeWarrantyItems;
  final int amcContracts;
  final int activeAmc;
  final String? lastServiceDate;

  const TraceServiceStats({
    this.totalTickets = 0,
    this.openTickets = 0,
    this.reworkTickets = 0,
    this.deliveredTickets = 0,
    this.repeatRepairRate = 0,
    this.totalServiceRevenue = 0,
    this.serviceOutstanding = 0,
    this.warrantyItems = 0,
    this.activeWarrantyItems = 0,
    this.amcContracts = 0,
    this.activeAmc = 0,
    this.lastServiceDate,
  });

  factory TraceServiceStats.fromJson(Map<String, dynamic> j) => TraceServiceStats(
        totalTickets: _toI(j['totalTickets']),
        openTickets: _toI(j['openTickets']),
        reworkTickets: _toI(j['reworkTickets']),
        deliveredTickets: _toI(j['deliveredTickets']),
        repeatRepairRate: _toD(j['repeatRepairRate']),
        totalServiceRevenue: _toD(j['totalServiceRevenue']),
        serviceOutstanding: _toD(j['serviceOutstanding']),
        warrantyItems: _toI(j['warrantyItems']),
        activeWarrantyItems: _toI(j['activeWarrantyItems']),
        amcContracts: _toI(j['amcContracts']),
        activeAmc: _toI(j['activeAmc']),
        lastServiceDate: _str(j['lastServiceDate']),
      );
}

class TraceServiceTicket {
  final String? id;
  final String? ticketNumber;
  final bool isRework;
  final String? reportedProblem;
  final String? status;
  final String? reportedAt;
  final bool isChargeable;
  final double totalCharge;

  const TraceServiceTicket({
    this.id,
    this.ticketNumber,
    this.isRework = false,
    this.reportedProblem,
    this.status,
    this.reportedAt,
    this.isChargeable = false,
    this.totalCharge = 0,
  });

  factory TraceServiceTicket.fromJson(Map<String, dynamic> j) => TraceServiceTicket(
        id: _str(j['id']),
        ticketNumber: _str(j['ticketNumber']),
        isRework: j['isRework'] as bool? ?? false,
        reportedProblem: _str(j['reportedProblem']),
        status: _str(j['status']),
        reportedAt: _str(j['reportedAt']),
        isChargeable: j['isChargeable'] as bool? ?? false,
        totalCharge: _toD(j['totalCharge']),
      );
}

class TraceService {
  final TraceServiceStats stats;
  final List<TraceServiceTicket> recentTickets;
  const TraceService({required this.stats, this.recentTickets = const []});
  factory TraceService.fromJson(Map<String, dynamic> j) => TraceService(
        stats: TraceServiceStats.fromJson((j['stats'] as Map?)?.cast<String, dynamic>() ?? const {}),
        recentTickets: (j['recentTickets'] as List<dynamic>?)
                ?.map((e) => TraceServiceTicket.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

/// Root of the customer trace response.
class CustomerTrace {
  final TraceCustomer customer;
  final TraceRepresentative? representative;
  final TracePeriod period;
  final TraceSummary summary;
  final List<TraceOrderRow> orderRows;
  final List<TraceInvoiceRow> invoiceRows;
  final List<TracePaymentRow> paymentRows;
  final List<TraceProductRow> productRows;
  final List<TraceMissingProduct> missingUsualProducts;
  final List<TraceReturnRow> returnRows;
  final List<TraceRiskFlag> riskFlags;
  final TraceService? service;

  const CustomerTrace({
    required this.customer,
    required this.period,
    required this.summary,
    this.representative,
    this.orderRows = const [],
    this.invoiceRows = const [],
    this.paymentRows = const [],
    this.productRows = const [],
    this.missingUsualProducts = const [],
    this.returnRows = const [],
    this.riskFlags = const [],
    this.service,
  });

  static List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) =>
      v is List ? v.map((e) => fromJson((e as Map).cast<String, dynamic>())).toList() : const [];

  factory CustomerTrace.fromJson(Map<String, dynamic> j) {
    final rep = j['representative'];
    final svc = j['service'];
    return CustomerTrace(
      customer: TraceCustomer.fromJson((j['customer'] as Map?)?.cast<String, dynamic>() ?? const {}),
      representative: rep is Map ? TraceRepresentative.fromJson(rep.cast<String, dynamic>()) : null,
      period: TracePeriod.fromJson((j['period'] as Map?)?.cast<String, dynamic>() ?? const {}),
      summary: TraceSummary.fromJson((j['summary'] as Map?)?.cast<String, dynamic>() ?? const {}),
      orderRows: _list(j['orderRows'], TraceOrderRow.fromJson),
      invoiceRows: _list(j['invoiceRows'], TraceInvoiceRow.fromJson),
      paymentRows: _list(j['paymentRows'], TracePaymentRow.fromJson),
      productRows: _list(j['productRows'], TraceProductRow.fromJson),
      missingUsualProducts: _list(j['missingUsualProducts'], TraceMissingProduct.fromJson),
      returnRows: _list(j['returnRows'], TraceReturnRow.fromJson),
      riskFlags: _list(j['riskFlags'], TraceRiskFlag.fromJson),
      service: svc is Map ? TraceService.fromJson(svc.cast<String, dynamic>()) : null,
    );
  }
}
