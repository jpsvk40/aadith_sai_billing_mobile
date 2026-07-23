// Customer service/maintenance history bundle (F1) — mirrors
// GET /api/service-tickets/customer/:customerId/history.

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class ServiceHistoryStats {
  final int totalTickets;
  final int openTickets;
  final int deliveredTickets;
  final int reworkTickets;
  final double repeatRepairRate; // 0..1
  final double totalServiceRevenue;
  final double serviceOutstanding;
  final DateTime? lastServiceDate;
  final int activeWarrantyItems;
  final int activeAmc;
  final int warrantyItems;
  final int amcContracts;
  const ServiceHistoryStats({
    this.totalTickets = 0,
    this.openTickets = 0,
    this.deliveredTickets = 0,
    this.reworkTickets = 0,
    this.repeatRepairRate = 0,
    this.totalServiceRevenue = 0,
    this.serviceOutstanding = 0,
    this.lastServiceDate,
    this.activeWarrantyItems = 0,
    this.activeAmc = 0,
    this.warrantyItems = 0,
    this.amcContracts = 0,
  });
  factory ServiceHistoryStats.fromJson(Map<String, dynamic>? j) => ServiceHistoryStats(
        totalTickets: (j?['totalTickets'] ?? 0) as int,
        openTickets: (j?['openTickets'] ?? 0) as int,
        deliveredTickets: (j?['deliveredTickets'] ?? 0) as int,
        reworkTickets: (j?['reworkTickets'] ?? 0) as int,
        repeatRepairRate: _toD(j?['repeatRepairRate']),
        totalServiceRevenue: _toD(j?['totalServiceRevenue']),
        serviceOutstanding: _toD(j?['serviceOutstanding']),
        lastServiceDate: j?['lastServiceDate'] != null ? DateTime.tryParse(j!['lastServiceDate'].toString()) : null,
        activeWarrantyItems: (j?['activeWarrantyItems'] ?? 0) as int,
        activeAmc: (j?['activeAmc'] ?? 0) as int,
        warrantyItems: (j?['warrantyItems'] ?? 0) as int,
        amcContracts: (j?['amcContracts'] ?? 0) as int,
      );
}

class ServiceHistoryTicket {
  final int id;
  final String ticketNumber;
  final String status;
  final String? serviceType;
  final String? reportedProblem;
  final DateTime? reportedAt;
  final double totalCharge;
  final double balanceAmount;
  final bool isChargeable;
  final bool isRework;
  const ServiceHistoryTicket({
    required this.id,
    required this.ticketNumber,
    required this.status,
    this.serviceType,
    this.reportedProblem,
    this.reportedAt,
    this.totalCharge = 0,
    this.balanceAmount = 0,
    this.isChargeable = false,
    this.isRework = false,
  });
  factory ServiceHistoryTicket.fromJson(Map<String, dynamic> j) => ServiceHistoryTicket(
        id: j['id'] as int,
        ticketNumber: (j['ticketNumber'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        serviceType: j['serviceType']?.toString(),
        reportedProblem: j['reportedProblem']?.toString(),
        reportedAt: j['reportedAt'] != null ? DateTime.tryParse(j['reportedAt'].toString()) : null,
        totalCharge: _toD(j['totalCharge']),
        balanceAmount: _toD(j['balanceAmount']),
        isChargeable: j['isChargeable'] == true,
        isRework: j['isRework'] == true,
      );
}

class ServiceHistoryUnit {
  final int id;
  final String? serialNumber;
  final String? brand;
  final String? modelName;
  final String? category;
  final String warrantyStatus; // ACTIVE | EXPIRED | REPLACED | SCRAPPED
  const ServiceHistoryUnit({required this.id, this.serialNumber, this.brand, this.modelName, this.category, this.warrantyStatus = 'ACTIVE'});
  factory ServiceHistoryUnit.fromJson(Map<String, dynamic> j) => ServiceHistoryUnit(
        id: j['id'] as int,
        serialNumber: j['serialNumber']?.toString(),
        brand: j['brand']?.toString(),
        modelName: j['modelName']?.toString(),
        category: j['category']?.toString(),
        warrantyStatus: (j['warrantyStatus'] ?? 'ACTIVE').toString(),
      );
  String get label => [brand, modelName].where((e) => (e ?? '').isNotEmpty).join(' ').trim();
}

class ServiceHistoryContract {
  final int id;
  final String contractNumber;
  final String contractType;
  final String status;
  final DateTime? endDate;
  final double contractValue;
  const ServiceHistoryContract({required this.id, required this.contractNumber, this.contractType = 'AMC', this.status = 'ACTIVE', this.endDate, this.contractValue = 0});
  factory ServiceHistoryContract.fromJson(Map<String, dynamic> j) => ServiceHistoryContract(
        id: j['id'] as int,
        contractNumber: (j['contractNumber'] ?? '').toString(),
        contractType: (j['contractType'] ?? 'AMC').toString(),
        status: (j['status'] ?? 'ACTIVE').toString(),
        endDate: j['endDate'] != null ? DateTime.tryParse(j['endDate'].toString()) : null,
        contractValue: _toD(j['contractValue']),
      );
}

class CustomerServiceHistory {
  final String customerName;
  final String? customerCode;
  final String? phone;
  final ServiceHistoryStats stats;
  final List<ServiceHistoryTicket> recentTickets;
  final List<ServiceHistoryUnit> warrantyItems;
  final List<ServiceHistoryContract> contracts;
  const CustomerServiceHistory({
    required this.customerName,
    this.customerCode,
    this.phone,
    this.stats = const ServiceHistoryStats(),
    this.recentTickets = const [],
    this.warrantyItems = const [],
    this.contracts = const [],
  });
  factory CustomerServiceHistory.fromJson(Map<String, dynamic> j) {
    final c = j['customer'] as Map<String, dynamic>?;
    return CustomerServiceHistory(
      customerName: (c?['customerName'] ?? 'Customer').toString(),
      customerCode: c?['customerCode']?.toString(),
      phone: c?['phone']?.toString(),
      stats: ServiceHistoryStats.fromJson(j['stats'] as Map<String, dynamic>?),
      recentTickets: (j['recentTickets'] as List<dynamic>?)?.map((e) => ServiceHistoryTicket.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      warrantyItems: (j['warrantyItems'] as List<dynamic>?)?.map((e) => ServiceHistoryUnit.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      contracts: (j['contracts'] as List<dynamic>?)?.map((e) => ServiceHistoryContract.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
    );
  }
}
