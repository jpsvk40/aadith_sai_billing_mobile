class Alert {
  final String id;
  final String type;
  final String message;
  final bool isRead;
  final String? customerId;
  final String? customerName;
  final String? invoiceId;
  final String? invoiceNumber;
  final double? amount;
  final DateTime? createdAt;

  const Alert({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    this.customerId,
    this.customerName,
    this.invoiceId,
    this.invoiceNumber,
    this.amount,
    this.createdAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'info',
      message: json['message'] ?? '',
      isRead: json['isRead'] as bool? ?? false,
      customerId: json['customerId']?.toString(),
      customerName: json['customer']?['name'] ?? json['customerName'],
      invoiceId: json['invoiceId']?.toString(),
      invoiceNumber: json['invoice']?['invoiceNumber'] ?? json['invoiceNumber'],
      amount: double.tryParse(json['amount']?.toString() ?? '0'),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}
