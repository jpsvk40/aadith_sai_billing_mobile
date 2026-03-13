class CollectionPayment {
  final String id;
  final double amount;
  final String paymentMode;
  final String? notes;
  final DateTime? paymentDate;

  const CollectionPayment({
    required this.id,
    required this.amount,
    required this.paymentMode,
    this.notes,
    this.paymentDate,
  });

  factory CollectionPayment.fromJson(Map<String, dynamic> json) {
    return CollectionPayment(
      id: json['id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      paymentMode: json['paymentMode'] ?? 'Cash',
      notes: json['remarks'] ?? json['customerFeedback'] ?? json['notes'],
      paymentDate: json['receivedDate'] != null
          ? DateTime.tryParse(json['receivedDate'].toString())
          : (json['paymentDate'] != null ? DateTime.tryParse(json['paymentDate'].toString()) : null),
    );
  }
}

class Collection {
  final String id;
  final String? customerId;
  final String? customerName;
  final String? representativeId;
  final String? representativeName;
  final double totalOutstanding;
  final double? collectedAmount;
  final String status;
  final DateTime? assignedDate;
  final DateTime? dueDate;
  final List<CollectionPayment> payments;

  const Collection({
    required this.id,
    this.customerId,
    this.customerName,
    this.representativeId,
    this.representativeName,
    required this.totalOutstanding,
    this.collectedAmount,
    required this.status,
    this.assignedDate,
    this.dueDate,
    this.payments = const [],
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id']?.toString() ?? '',
      customerId: json['invoice']?['customer']?['id']?.toString() ?? json['customerId']?.toString(),
      customerName: json['invoice']?['customer']?['customerName'] ?? json['customer']?['customerName'] ?? json['customerName'],
      representativeId: json['collectionRepId']?.toString() ?? json['representativeId']?.toString(),
      representativeName: json['collectionRep']?['name'] ?? json['representative']?['name'] ?? json['representativeName'],
      totalOutstanding: double.tryParse(json['balanceAmount']?.toString() ?? json['totalAmount']?.toString() ?? json['totalOutstanding']?.toString() ?? '0') ?? 0,
      collectedAmount: double.tryParse(json['collectedAmount']?.toString() ?? '0'),
      status: json['status'] ?? 'Pending',
      assignedDate: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['assignedDate'] != null ? DateTime.tryParse(json['assignedDate'].toString()) : null),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'].toString()) : null,
      payments: (json['payments'] as List<dynamic>?)
          ?.map((e) => CollectionPayment.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
