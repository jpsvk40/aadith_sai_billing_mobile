class InvoiceItem {
  final String? id;
  final String? productName;
  final double quantity;
  final double price;
  final double? discount;
  final double? cgst;
  final double? sgst;
  final double? igst;
  final double? total;

  const InvoiceItem({
    this.id,
    this.productName,
    required this.quantity,
    required this.price,
    this.discount,
    this.cgst,
    this.sgst,
    this.igst,
    this.total,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id']?.toString(),
      productName: json['product']?['productName'] ?? json['productNameSnapshot'] ?? json['productName'] ?? json['description'],
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
      price: double.tryParse(json['rate']?.toString() ?? json['price']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discountValue']?.toString() ?? json['discount']?.toString() ?? '0'),
      cgst: double.tryParse(json['cgstTotal']?.toString() ?? json['cgst']?.toString() ?? '0'),
      sgst: double.tryParse(json['sgstTotal']?.toString() ?? json['sgst']?.toString() ?? '0'),
      igst: double.tryParse(json['igstTotal']?.toString() ?? json['igst']?.toString() ?? '0'),
      total: double.tryParse(json['lineTotal']?.toString() ?? json['total']?.toString() ?? '0'),
    );
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String status;
  final String? customerId;
  final String? customerName;
  final double subtotal;
  final double? cgst;
  final double? sgst;
  final double? igst;
  final double totalAmount;
  final double? paidAmount;
  final double? outstandingAmount;
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final List<InvoiceItem> items;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    this.customerId,
    this.customerName,
    required this.subtotal,
    this.cgst,
    this.sgst,
    this.igst,
    required this.totalAmount,
    this.paidAmount,
    this.outstandingAmount,
    this.invoiceDate,
    this.dueDate,
    this.items = const [],
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoiceNo'] ?? json['invoiceNumber'] ?? json['id']?.toString() ?? '',
      status: json['paymentStatus'] ?? json['status'] ?? 'Unpaid',
      customerId: json['customerId']?.toString(),
      customerName: json['customer']?['customerName'] ?? json['billingName'] ?? json['customerName'],
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      cgst: double.tryParse(json['cgstTotal']?.toString() ?? json['cgst']?.toString() ?? '0'),
      sgst: double.tryParse(json['sgstTotal']?.toString() ?? json['sgst']?.toString() ?? '0'),
      igst: double.tryParse(json['igstTotal']?.toString() ?? json['igst']?.toString() ?? '0'),
      totalAmount: double.tryParse(json['grandTotal']?.toString() ?? json['totalAmount']?.toString() ?? '0') ?? 0,
      paidAmount: double.tryParse(json['paidAmount']?.toString() ?? '0'),
      outstandingAmount: double.tryParse(json['balanceAmount']?.toString() ?? json['outstandingAmount']?.toString() ?? '0'),
      invoiceDate: json['invoiceDate'] != null ? DateTime.tryParse(json['invoiceDate'].toString()) : null,
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'].toString()) : null,
      items: ((json['invoiceItems'] ?? json['items']) as List<dynamic>?)
          ?.map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now()) && status.toLowerCase() != 'paid';
  }
}
