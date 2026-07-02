// Registered warranty unit. Mirrors GET /api/service-items, /lookup, /:id (decorate()).
import 'service_ticket_model.dart' show ServiceParty;

class ServiceItem {
  final int id;
  final String? itemCode;
  final String serialNumber;
  final String? imei;
  final String? brand;
  final String? modelName;
  final String? category;
  final String warrantyType;
  final int warrantyMonths;
  final DateTime? warrantyStartDate;
  final DateTime? warrantyEndDate;
  final String derivedStatus; // ACTIVE | EXPIRED | REPLACED | SCRAPPED
  final bool underWarranty;
  final ServiceParty? customer;

  const ServiceItem({
    required this.id,
    this.itemCode,
    required this.serialNumber,
    this.imei,
    this.brand,
    this.modelName,
    this.category,
    this.warrantyType = 'NONE',
    this.warrantyMonths = 0,
    this.warrantyStartDate,
    this.warrantyEndDate,
    this.derivedStatus = 'ACTIVE',
    this.underWarranty = false,
    this.customer,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
        id: j['id'] as int,
        itemCode: j['itemCode']?.toString(),
        serialNumber: (j['serialNumber'] ?? '').toString(),
        imei: j['imei']?.toString(),
        brand: j['brand']?.toString(),
        modelName: j['modelName']?.toString(),
        category: j['category']?.toString(),
        warrantyType: (j['warrantyType'] ?? 'NONE').toString(),
        warrantyMonths: (j['warrantyMonths'] as int?) ?? 0,
        warrantyStartDate: j['warrantyStartDate'] != null ? DateTime.tryParse(j['warrantyStartDate'].toString()) : null,
        warrantyEndDate: j['warrantyEndDate'] != null ? DateTime.tryParse(j['warrantyEndDate'].toString()) : null,
        derivedStatus: (j['derivedStatus'] ?? 'ACTIVE').toString(),
        underWarranty: j['underWarranty'] == true,
        customer: j['customer'] != null ? ServiceParty.fromJson(j['customer'] as Map<String, dynamic>) : null,
      );

  String get label => [brand, modelName].where((e) => (e ?? '').isNotEmpty).join(' ').trim();
}

/// Assignable technician (active employee) for the assign picker.
class TechnicianRef {
  final int id;
  final String fullName;
  final String? employeeCode;
  final String? designation;
  const TechnicianRef({required this.id, required this.fullName, this.employeeCode, this.designation});
  factory TechnicianRef.fromJson(Map<String, dynamic> j) => TechnicianRef(
        id: j['id'] as int,
        fullName: (j['fullName'] ?? '').toString(),
        employeeCode: j['employeeCode']?.toString(),
        designation: j['designation']?.toString(),
      );
}

/// AI triage suggestion for a reported problem (read-only) from POST /service-tickets/ai-triage.
class ServiceTriage {
  final String priority; // LOW | NORMAL | HIGH | URGENT
  final String faultCategory;
  final List<String> probableCauses;
  final List<String> suggestedParts;
  final int estimatedLabour;
  final int? estimatedTurnaroundDays;
  final String cleanedProblem;
  final List<String> diagnosticChecklist;

  const ServiceTriage({
    this.priority = 'NORMAL',
    this.faultCategory = '',
    this.probableCauses = const [],
    this.suggestedParts = const [],
    this.estimatedLabour = 0,
    this.estimatedTurnaroundDays,
    this.cleanedProblem = '',
    this.diagnosticChecklist = const [],
  });

  static List<String> _strList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

  factory ServiceTriage.fromJson(Map<String, dynamic> j) => ServiceTriage(
        priority: (j['priority'] ?? 'NORMAL').toString(),
        faultCategory: (j['faultCategory'] ?? '').toString(),
        probableCauses: _strList(j['probableCauses']),
        suggestedParts: _strList(j['suggestedParts']),
        estimatedLabour: (j['estimatedLabour'] is num) ? (j['estimatedLabour'] as num).round() : 0,
        estimatedTurnaroundDays: j['estimatedTurnaroundDays'] is num ? (j['estimatedTurnaroundDays'] as num).round() : null,
        cleanedProblem: (j['cleanedProblem'] ?? '').toString(),
        diagnosticChecklist: _strList(j['diagnosticChecklist']),
      );
}

/// Lean inventory item from /service-items/parts-catalog (spare-part picker).
class PartCatalogItem {
  final int id;
  final String itemName;
  final String? itemCode;
  final String? unit;
  final double defaultUnitCost;
  const PartCatalogItem({required this.id, required this.itemName, this.itemCode, this.unit, this.defaultUnitCost = 0});
  factory PartCatalogItem.fromJson(Map<String, dynamic> j) => PartCatalogItem(
        id: j['id'] as int,
        itemName: (j['itemName'] ?? '').toString(),
        itemCode: j['itemCode']?.toString(),
        unit: j['unit']?.toString(),
        defaultUnitCost: j['defaultUnitCost'] == null ? 0 : (j['defaultUnitCost'] as num).toDouble(),
      );
}
