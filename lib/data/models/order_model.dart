class OrderItem {
  final String? id;
  final String? productId;
  final String? productName;
  final String? variantLabel;
  final double quantity;
  final double? confirmedQuantity;
  final String? customerRemark;
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
    this.variantLabel,
    required this.quantity,
    this.confirmedQuantity,
    this.customerRemark,
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
      productName:
          json['product']?['productName'] ??
          json['productNameSnapshot'] ??
          json['productName'],
      variantLabel: json['variant']?['label']?.toString() ?? json['variantLabel']?.toString(),
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      confirmedQuantity: json['confirmedQuantity'] != null
          ? double.tryParse(json['confirmedQuantity'].toString())
          : null,
      customerRemark: json['customerRemark']?.toString(),
      rate:
          double.tryParse(
            json['rate']?.toString() ?? json['price']?.toString() ?? '0',
          ) ??
          0,
      unit: json['unit']?.toString(),
      discountType: json['discountType']?.toString(),
      discountValue: double.tryParse(
        json['discountValue']?.toString() ??
            json['discount']?.toString() ??
            '0',
      ),
      taxPercent: double.tryParse(
        json['taxPercent']?.toString() ?? json['taxRate']?.toString() ?? '0',
      ),
      total: double.tryParse(
        json['lineTotal']?.toString() ?? json['total']?.toString() ?? '0',
      ),
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? representativeId;
  final String? representativeName;
  final String? createdByName;
  final double? totalAmount;
  final double subtotal;
  final double taxTotal;
  final double discountTotal;
  final String? notes;
  final String? deliveryAddress;
  final DateTime? createdAt;
  final DateTime? deliveryDate;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.representativeId,
    this.representativeName,
    this.createdByName,
    this.totalAmount,
    this.subtotal = 0,
    this.taxTotal = 0,
    this.discountTotal = 0,
    this.notes,
    this.deliveryAddress,
    this.createdAt,
    this.deliveryDate,
    this.items = const [],
  });

  bool get isEditable => status == 'New';

  bool get canReviewFinalQuantity =>
      ['New', 'Production Completed', 'Packed'].contains(status);

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      orderNumber:
          json['orderNo'] ??
          json['orderNumber'] ??
          json['id']?.toString() ??
          '',
      status: json['status'] ?? 'New',
      customerId: json['customerId']?.toString(),
      customerName: json['customer']?['customerName'] ?? json['customerName'],
      customerPhone: json['customer']?['phone']?.toString() ?? json['customerPhone']?.toString(),
      representativeId: json['representativeId']?.toString(),
      representativeName:
          json['representative']?['name'] ?? json['representativeName'],
      createdByName: json['creator']?['name']?.toString(),
      totalAmount: double.tryParse(
        json['grandTotal']?.toString() ??
            json['totalAmount']?.toString() ??
            '0',
      ),
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      taxTotal: double.tryParse(json['taxTotal']?.toString() ?? '0') ?? 0,
      discountTotal: double.tryParse(json['discountTotal']?.toString() ?? '0') ?? 0,
      notes: json['notes'],
      deliveryAddress: json['deliveryAddress']?.toString(),
      createdAt: json['orderDate'] != null
          ? DateTime.tryParse(json['orderDate'].toString())
          : (json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString())
                : null),
      deliveryDate: json['expectedDeliveryDate'] != null
          ? DateTime.tryParse(json['expectedDeliveryDate'].toString())
          : (json['deliveryDate'] != null
                ? DateTime.tryParse(json['deliveryDate'].toString())
                : null),
      items:
          ((json['orderItems'] ?? json['items']) as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
