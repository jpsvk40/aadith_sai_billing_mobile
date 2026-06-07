class Payment {
  final String id;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? customerId;
  final String? customerName;
  final double amount;
  final String paymentMode;
  final String approvalStatus; // Pending | Approved | Rejected
  final String? referenceNo;
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
    this.approvalStatus = 'Approved',
    this.referenceNo,
    this.notes,
    this.paymentDate,
    this.createdAt,
  });

  Payment copyWith({String? approvalStatus}) => Payment(
        id: id,
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        customerId: customerId,
        customerName: customerName,
        amount: amount,
        paymentMode: paymentMode,
        approvalStatus: approvalStatus ?? this.approvalStatus,
        referenceNo: referenceNo,
        notes: notes,
        paymentDate: paymentDate,
        createdAt: createdAt,
      );

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id']?.toString() ?? '',
      invoiceId: json['invoiceId']?.toString(),
      invoiceNumber: json['invoice']?['invoiceNo'] ?? json['invoiceNumber'],
      customerId: json['customerId']?.toString(),
      customerName: json['customer']?['customerName'] ?? json['customerName'],
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      paymentMode: json['paymentMode'] ?? 'Cash',
      approvalStatus: json['approvalStatus']?.toString() ?? 'Approved',
      referenceNo: json['referenceNo']?.toString(),
      notes: json['remarks'] ?? json['notes'],
      paymentDate: json['paymentDate'] != null ? DateTime.tryParse(json['paymentDate'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}
