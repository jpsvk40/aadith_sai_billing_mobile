// Service ticket + its nested parts, status-history events, and attachments.
// Mirrors backend GET /api/service-tickets and /:id (helpers/warranty + service-tickets route).

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class ServiceParty {
  final int? id;
  final String name;
  final String? phone;
  const ServiceParty({this.id, required this.name, this.phone});
  factory ServiceParty.fromJson(Map<String, dynamic>? j) => ServiceParty(
        id: j?['id'] as int?,
        name: (j?['customerName'] ?? j?['fullName'] ?? j?['name'] ?? '').toString(),
        phone: j?['phone']?.toString(),
      );
}

class ServiceItemRef {
  final int? id;
  final String? itemCode;
  final String? serialNumber;
  final String? brand;
  final String? modelName;
  final String? category;
  final DateTime? warrantyEndDate;
  final String? warrantyType;
  const ServiceItemRef({this.id, this.itemCode, this.serialNumber, this.brand, this.modelName, this.category, this.warrantyEndDate, this.warrantyType});
  factory ServiceItemRef.fromJson(Map<String, dynamic>? j) => ServiceItemRef(
        id: j?['id'] as int?,
        itemCode: j?['itemCode']?.toString(),
        serialNumber: j?['serialNumber']?.toString(),
        brand: j?['brand']?.toString(),
        modelName: j?['modelName']?.toString(),
        category: j?['category']?.toString(),
        warrantyEndDate: j?['warrantyEndDate'] != null ? DateTime.tryParse(j!['warrantyEndDate'].toString()) : null,
        warrantyType: j?['warrantyType']?.toString(),
      );
  String get label => [brand, modelName].where((e) => (e ?? '').isNotEmpty).join(' ').trim();
}

class ServiceTicketPart {
  final int id;
  final int inventoryItemId;
  final String itemName;
  final String? itemCode;
  final String? unit;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final bool chargeable;
  final bool posted; // inventoryTxnId present → depleted from stock, can't delete
  const ServiceTicketPart({
    required this.id,
    required this.inventoryItemId,
    required this.itemName,
    this.itemCode,
    this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.chargeable,
    required this.posted,
  });
  factory ServiceTicketPart.fromJson(Map<String, dynamic> j) {
    final item = j['item'] as Map<String, dynamic>?;
    return ServiceTicketPart(
      id: j['id'] as int,
      inventoryItemId: j['inventoryItemId'] as int,
      itemName: (item?['itemName'] ?? 'Part').toString(),
      itemCode: item?['itemCode']?.toString(),
      unit: item?['unit']?.toString(),
      quantity: _toD(j['quantity']),
      unitPrice: _toD(j['unitPrice']),
      lineTotal: _toD(j['lineTotal']),
      chargeable: j['chargeable'] != false,
      posted: j['inventoryTxnId'] != null,
    );
  }
}

class ServiceTicketEvent {
  final String? fromStatus;
  final String toStatus;
  final String? note;
  final DateTime? createdAt;
  const ServiceTicketEvent({this.fromStatus, required this.toStatus, this.note, this.createdAt});
  factory ServiceTicketEvent.fromJson(Map<String, dynamic> j) => ServiceTicketEvent(
        fromStatus: j['fromStatus']?.toString(),
        toStatus: (j['toStatus'] ?? '').toString(),
        note: j['note']?.toString(),
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      );
}

class ServiceAttachment {
  final int id;
  final String kind; // INTAKE | REPAIR | HANDOVER | OTHER
  final String? filename;
  final String? mimetype;
  final String? note;
  final String? url; // short-lived presigned GET
  final DateTime? createdAt;
  const ServiceAttachment({required this.id, required this.kind, this.filename, this.mimetype, this.note, this.url, this.createdAt});
  factory ServiceAttachment.fromJson(Map<String, dynamic> j) => ServiceAttachment(
        id: j['id'] as int,
        kind: (j['kind'] ?? 'OTHER').toString(),
        filename: j['filename']?.toString(),
        mimetype: j['mimetype']?.toString(),
        note: j['note']?.toString(),
        url: j['url']?.toString(),
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      );
}

class ServiceTicket {
  final int id;
  final String ticketNumber;
  final String status;
  final String priority;
  final String serviceType;
  final String location;
  final String reportedProblem;
  final String? diagnosis;
  final String? resolution;
  final String? intakeCondition;
  final String? devicePassword;
  final List<String> accessories;
  final int? assignedTechnicianId;
  final bool slaBreached;
  final bool isChargeable;
  final double labourCharge;
  final double partsCharge;
  final double taxPercent;
  final double totalCharge;
  final double paidAmount;
  final double advanceAmount;
  final double balanceAmount;
  final String paymentStatus;
  final String estimateStatus;
  final double? estimateAmount;
  final int? invoiceId;
  final DateTime? reportedAt;
  final DateTime? promisedAt;
  final ServiceParty? customer;
  final ServiceItemRef? serviceItem;
  final ServiceParty? technician;
  final List<ServiceTicketPart> parts;
  final List<ServiceTicketEvent> events;

  const ServiceTicket({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.priority,
    required this.serviceType,
    required this.location,
    required this.reportedProblem,
    this.diagnosis,
    this.resolution,
    this.intakeCondition,
    this.devicePassword,
    this.accessories = const [],
    this.assignedTechnicianId,
    this.slaBreached = false,
    this.isChargeable = true,
    this.labourCharge = 0,
    this.partsCharge = 0,
    this.taxPercent = 0,
    this.totalCharge = 0,
    this.paidAmount = 0,
    this.advanceAmount = 0,
    this.balanceAmount = 0,
    this.paymentStatus = 'Unpaid',
    this.estimateStatus = 'NONE',
    this.estimateAmount,
    this.invoiceId,
    this.reportedAt,
    this.promisedAt,
    this.customer,
    this.serviceItem,
    this.technician,
    this.parts = const [],
    this.events = const [],
  });

  factory ServiceTicket.fromJson(Map<String, dynamic> j) {
    List<String> acc = const [];
    final raw = j['accessories'];
    if (raw is List) acc = raw.map((e) => e.toString()).toList();
    return ServiceTicket(
      id: j['id'] as int,
      ticketNumber: (j['ticketNumber'] ?? '').toString(),
      status: (j['status'] ?? 'OPEN').toString(),
      priority: (j['priority'] ?? 'NORMAL').toString(),
      serviceType: (j['serviceType'] ?? 'PAID_REPAIR').toString(),
      location: (j['location'] ?? 'IN_SHOP').toString(),
      reportedProblem: (j['reportedProblem'] ?? '').toString(),
      diagnosis: j['diagnosis']?.toString(),
      resolution: j['resolution']?.toString(),
      intakeCondition: j['intakeCondition']?.toString(),
      devicePassword: j['devicePassword']?.toString(),
      accessories: acc,
      assignedTechnicianId: j['assignedTechnicianId'] as int?,
      slaBreached: j['slaBreached'] == true,
      isChargeable: j['isChargeable'] != false,
      labourCharge: _toD(j['labourCharge']),
      partsCharge: _toD(j['partsCharge']),
      taxPercent: _toD(j['taxPercent']),
      totalCharge: _toD(j['totalCharge']),
      paidAmount: _toD(j['paidAmount']),
      advanceAmount: _toD(j['advanceAmount']),
      balanceAmount: _toD(j['balanceAmount']),
      paymentStatus: (j['paymentStatus'] ?? 'Unpaid').toString(),
      estimateStatus: (j['estimateStatus'] ?? 'NONE').toString(),
      estimateAmount: j['estimateAmount'] != null ? _toD(j['estimateAmount']) : null,
      invoiceId: j['invoiceId'] as int?,
      reportedAt: j['reportedAt'] != null ? DateTime.tryParse(j['reportedAt'].toString()) : null,
      promisedAt: j['promisedAt'] != null ? DateTime.tryParse(j['promisedAt'].toString()) : null,
      customer: j['customer'] != null ? ServiceParty.fromJson(j['customer'] as Map<String, dynamic>) : null,
      serviceItem: j['serviceItem'] != null ? ServiceItemRef.fromJson(j['serviceItem'] as Map<String, dynamic>) : null,
      technician: j['technician'] != null ? ServiceParty.fromJson(j['technician'] as Map<String, dynamic>) : null,
      parts: (j['parts'] as List<dynamic>?)?.map((e) => ServiceTicketPart.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      events: (j['events'] as List<dynamic>?)?.map((e) => ServiceTicketEvent.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    );
  }

  bool get isOpen => !['DELIVERED', 'CLOSED', 'CANCELLED'].contains(status);
  String get customerName => customer?.name ?? '—';
}
