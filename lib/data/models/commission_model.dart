class CommissionItem {
  final String? id;
  final String? invoiceNumber;
  final String? customerName;
  final double invoiceAmount;
  final double commissionRate;
  final double commissionAmount;

  const CommissionItem({
    this.id,
    this.invoiceNumber,
    this.customerName,
    required this.invoiceAmount,
    required this.commissionRate,
    required this.commissionAmount,
  });

  factory CommissionItem.fromJson(Map<String, dynamic> json) {
    return CommissionItem(
      id: json['id']?.toString(),
      invoiceNumber: json['invoice']?['invoiceNumber'] ?? json['invoiceNumber'],
      customerName: json['customer']?['name'] ?? json['customerName'],
      invoiceAmount: double.tryParse(json['invoiceAmount']?.toString() ?? '0') ?? 0,
      commissionRate: double.tryParse(json['commissionRate']?.toString() ?? '0') ?? 0,
      commissionAmount: double.tryParse(json['commissionAmount']?.toString() ?? '0') ?? 0,
    );
  }
}

class Commission {
  final String id;
  final String? repInvoiceNumber;
  final String? representativeId;
  final String? representativeName;
  final String period;
  final double totalSales;
  final double totalCommission;
  final String status;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final List<CommissionItem> items;

  const Commission({
    required this.id,
    this.repInvoiceNumber,
    this.representativeId,
    this.representativeName,
    required this.period,
    required this.totalSales,
    required this.totalCommission,
    required this.status,
    this.periodStart,
    this.periodEnd,
    this.items = const [],
  });

  factory Commission.fromJson(Map<String, dynamic> json) {
    return Commission(
      id: json['id']?.toString() ?? '',
      repInvoiceNumber: json['repInvoiceNumber'] ?? json['invoiceNumber'],
      representativeId: json['representativeId']?.toString(),
      representativeName: json['representative']?['name'] ?? json['representativeName'],
      period: json['period'] ?? '',
      totalSales: double.tryParse(json['totalSales']?.toString() ?? '0') ?? 0,
      totalCommission: double.tryParse(json['totalCommission']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'pending',
      periodStart: json['periodStart'] != null ? DateTime.tryParse(json['periodStart'].toString()) : null,
      periodEnd: json['periodEnd'] != null ? DateTime.tryParse(json['periodEnd'].toString()) : null,
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => CommissionItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class CommissionSummary {
  final double totalSales;
  final double totalCommission;
  final double pendingCommission;
  final double paidCommission;
  final int totalInvoices;

  const CommissionSummary({
    required this.totalSales,
    required this.totalCommission,
    required this.pendingCommission,
    required this.paidCommission,
    required this.totalInvoices,
  });

  factory CommissionSummary.fromJson(Map<String, dynamic> json) {
    return CommissionSummary(
      totalSales: double.tryParse(json['totalSales']?.toString() ?? '0') ?? 0,
      totalCommission: double.tryParse(json['totalCommission']?.toString() ?? '0') ?? 0,
      pendingCommission: double.tryParse(json['pendingCommission']?.toString() ?? '0') ?? 0,
      paidCommission: double.tryParse(json['paidCommission']?.toString() ?? '0') ?? 0,
      totalInvoices: int.tryParse(json['totalInvoices']?.toString() ?? '0') ?? 0,
    );
  }
}
