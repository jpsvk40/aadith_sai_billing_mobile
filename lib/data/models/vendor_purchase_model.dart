class VendorPurchase {
  final String id;
  final String purchaseNumber;
  final String? vendorName;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final DateTime? purchaseDate;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String status;

  const VendorPurchase({
    required this.id,
    required this.purchaseNumber,
    this.vendorName,
    this.invoiceNumber,
    this.invoiceDate,
    this.purchaseDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.status,
  });

  factory VendorPurchase.fromJson(Map<String, dynamic> json) {
    return VendorPurchase(
      id: json['id']?.toString() ?? '',
      purchaseNumber: json['purchaseNumber']?.toString() ?? '',
      vendorName: json['vendor']?['vendorName'] ?? json['vendorName'],
      invoiceNumber: json['invoiceNumber']?.toString(),
      invoiceDate: json['invoiceDate'] != null
          ? DateTime.tryParse(json['invoiceDate'].toString())
          : null,
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.tryParse(json['purchaseDate'].toString())
          : null,
      totalAmount: double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0,
      paidAmount: double.tryParse(json['paidAmount']?.toString() ?? '0') ?? 0,
      outstandingAmount:
          double.tryParse(json['outstandingAmount']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'PENDING',
    );
  }
}
