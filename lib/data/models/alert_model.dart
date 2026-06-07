class Alert {
  final String id;
  final String alertType;
  final String relatedModule;
  final String? relatedId;
  final String title;
  final String message;
  final String severity; // critical | high | medium | low | info
  final String status; // active | acknowledged | resolved
  final bool isRead;
  final double? amount;
  final String? customerName;
  final DateTime? createdAt;

  const Alert({
    required this.id,
    this.alertType = 'info',
    this.relatedModule = '',
    this.relatedId,
    this.title = '',
    this.message = '',
    this.severity = 'info',
    this.status = 'active',
    this.isRead = false,
    this.amount,
    this.customerName,
    this.createdAt,
  });

  /// A pending payment that the admin can approve/reject straight from the alert.
  bool get isPaymentApproval =>
      alertType == 'payment_received' && severity == 'high' && status == 'active';

  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
        id: j['id']?.toString() ?? '',
        alertType: j['alertType']?.toString() ?? 'info',
        relatedModule: j['relatedModule']?.toString() ?? '',
        relatedId: j['relatedId']?.toString(),
        title: j['title']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
        severity: j['severity']?.toString() ?? 'info',
        status: j['status']?.toString() ?? 'active',
        isRead: j['isRead'] as bool? ?? false,
        amount: j['amount'] != null ? double.tryParse(j['amount'].toString()) : null,
        customerName: j['customerName']?.toString(),
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      );
}
