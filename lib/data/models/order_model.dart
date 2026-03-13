class OrderItem {
  final String? id;
  final String? productId;
  final String? productName;
  final double quantity;
  final double rate;
  final String? unit;
  final String? discountType;
  final double? discountValue;
  final double? taxPercent;
  final double? total;

  const OrderItem({
    this.id,
    this.productId,
    this.productName,
    required this.quantity,
    required this.rate,
    this.unit,
    this.discountType,
    this.discountValue,
    this.taxPercent,
    this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString(),
      productId: json['productId']?.toString(),
      productName: json['product']?['productName'] ?? json['productNameSnapshot'] ?? json['productName'],
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      rate: double.tryParse(json['rate']?.toString() ?? json['price']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString(),
      discountType: json['discountType']?.toString(),
      discountValue: double.tryParse(json['discountValue']?.toString() ?? json['discount']?.toString() ?? '0'),
      taxPercent: double.tryParse(json['taxPercent']?.toString() ?? json['taxRate']?.toString() ?? '0'),
      total: double.tryParse(json['lineTotal']?.toString() ?? json['total']?.toString() ?? '0'),
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final String? customerId;
  final String? customerName;
  final String? representativeId;
  final String? representativeName;
  final double? totalAmount;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? deliveryDate;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.customerId,
    this.customerName,
    this.representativeId,
    this.representativeName,
    this.totalAmount,
    this.notes,
    this.createdAt,
    this.deliveryDate,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNo'] ?? json['orderNumber'] ?? json['id']?.toString() ?? '',
      status: json['status'] ?? 'New',
      customerId: json['customerId']?.toString(),
      customerName: json['customer']?['customerName'] ?? json['customerName'],
      representativeId: json['representativeId']?.toString(),
      representativeName: json['representative']?['name'] ?? json['representativeName'],
      totalAmount: double.tryParse(json['grandTotal']?.toString() ?? json['totalAmount']?.toString() ?? '0'),
      notes: json['notes'],
      createdAt: json['orderDate'] != null
          ? DateTime.tryParse(json['orderDate'].toString())
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null),
      deliveryDate: json['expectedDeliveryDate'] != null
          ? DateTime.tryParse(json['expectedDeliveryDate'].toString())
          : (json['deliveryDate'] != null ? DateTime.tryParse(json['deliveryDate'].toString()) : null),
      items: ((json['orderItems'] ?? json['items']) as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
