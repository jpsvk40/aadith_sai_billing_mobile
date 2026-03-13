class Payment {
  final String id;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? customerId;
  final String? customerName;
  final double amount;
  final String paymentMode;
  final String? notes;
  final DateTime? paymentDate;
  final DateTime? createdAt;

  const Payment({
    required this.id,
    this.invoiceId,
    this.invoiceNumber,
    this.customerId,
    this.customerName,
    required this.amount,
    required this.paymentMode,
    this.notes,
    this.paymentDate,
    this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id']?.toString() ?? '',
      invoiceId: json['invoiceId']?.toString(),
      invoiceNumber: json['invoice']?['invoiceNo'] ?? json['invoiceNumber'],
      customerId: json['customerId']?.toString(),
      customerName: json['customer']?['customerName'] ?? json['customerName'],
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      paymentMode: json['paymentMode'] ?? 'Cash',
      notes: json['remarks'] ?? json['notes'],
      paymentDate: json['paymentDate'] != null ? DateTime.tryParse(json['paymentDate'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}
