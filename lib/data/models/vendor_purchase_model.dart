double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

/// One line on a vendor purchase bill. Populated by the detail endpoint
/// (GET /vendor-purchases/:id); the list endpoint returns header rows only.
class VendorPurchaseItem {
  final String description;
  final String? sku;
  final String? hsnCode;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double taxPercent;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double discountAmount;
  final double lineTotal;
  final double receivedQty;

  const VendorPurchaseItem({
    required this.description,
    this.sku,
    this.hsnCode,
    this.unit = 'pcs',
    this.quantity = 0,
    this.unitPrice = 0,
    this.taxPercent = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.discountAmount = 0,
    this.lineTotal = 0,
    this.receivedQty = 0,
  });

  double get gstAmount => cgstAmount + sgstAmount + igstAmount;

  factory VendorPurchaseItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return VendorPurchaseItem(
      description: (product?['productName'] ?? json['itemDescription'] ?? json['description'] ?? 'Item').toString(),
      sku: product?['sku']?.toString(),
      hsnCode: json['hsnCode']?.toString(),
      unit: json['unit']?.toString() ?? 'pcs',
      quantity: _d(json['quantity']),
      unitPrice: _d(json['unitPrice']),
      taxPercent: _d(json['taxPercent']),
      cgstAmount: _d(json['cgstAmount']),
      sgstAmount: _d(json['sgstAmount']),
      igstAmount: _d(json['igstAmount']),
      discountAmount: _d(json['discountAmount']),
      lineTotal: _d(json['lineTotal']),
      receivedQty: _d(json['receivedQty']),
    );
  }
}

class VendorPurchase {
  final String id;
  final String purchaseNumber;
  final String? vendorName;
  final String? vendorGstin;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final DateTime? purchaseDate;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String status;

  // ── Detail-only fields (empty/zero on list rows) ──
  final List<VendorPurchaseItem> items;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double discountTotal;
  final double freightCharges;
  final double miscCharges;
  final double roundOff;
  final String? notes;

  const VendorPurchase({
    required this.id,
    required this.purchaseNumber,
    this.vendorName,
    this.vendorGstin,
    this.invoiceNumber,
    this.invoiceDate,
    this.purchaseDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.status,
    this.items = const [],
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.discountTotal = 0,
    this.freightCharges = 0,
    this.miscCharges = 0,
    this.roundOff = 0,
    this.notes,
  });

  double get gstAmount => cgstAmount + sgstAmount + igstAmount;

  /// Taxable value = grand − gst − freight − misc − roundOff + discount.
  /// Derived so it always reconciles with the header the backend sent.
  double get taxableAmount => items.isNotEmpty
      ? items.fold<double>(0, (s, it) => s + (it.quantity * it.unitPrice - it.discountAmount))
      : (totalAmount - gstAmount - freightCharges - miscCharges - roundOff);

  factory VendorPurchase.fromJson(Map<String, dynamic> json) {
    return VendorPurchase(
      id: json['id']?.toString() ?? '',
      purchaseNumber: json['purchaseNumber']?.toString() ?? '',
      vendorName: (json['vendor'] as Map<String, dynamic>?)?['vendorName'] ?? json['vendorName'],
      vendorGstin: (json['vendor'] as Map<String, dynamic>?)?['gstin']?.toString(),
      invoiceNumber: json['invoiceNumber']?.toString(),
      invoiceDate: json['invoiceDate'] != null ? DateTime.tryParse(json['invoiceDate'].toString()) : null,
      purchaseDate: json['purchaseDate'] != null ? DateTime.tryParse(json['purchaseDate'].toString()) : null,
      totalAmount: _d(json['totalAmount']),
      paidAmount: _d(json['paidAmount']),
      outstandingAmount: _d(json['outstandingAmount']),
      status: json['status']?.toString() ?? 'PENDING',
      items: ((json['items'] ?? json['purchaseItems']) as List<dynamic>?)
              ?.map((e) => VendorPurchaseItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      cgstAmount: _d(json['cgstAmount']),
      sgstAmount: _d(json['sgstAmount']),
      igstAmount: _d(json['igstAmount']),
      discountTotal: _d(json['discountTotal']),
      freightCharges: _d(json['freightCharges']),
      miscCharges: _d(json['miscCharges']),
      roundOff: _d(json['roundOff']),
      notes: json['notes']?.toString(),
    );
  }
}
