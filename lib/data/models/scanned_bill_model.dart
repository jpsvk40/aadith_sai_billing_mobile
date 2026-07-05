/// One width/variant sub-row of a scanned line (Bero BOPP width tracking).
/// Carried through verbatim to the create payload so the backend keeps its
/// per-width inventory allocations.
class ScannedVariantAllocation {
  final int? variantId;
  final String? label; // e.g. "250 MM"
  final double? widthMm;
  final double quantity;
  final String? unit;
  final dynamic rawValues; // original printed text, e.g. "250 MM = 12.4+12.8+13.8"
  final double? secondaryQty;
  final String? secondaryUnit;

  const ScannedVariantAllocation({
    this.variantId,
    this.label,
    this.widthMm,
    this.quantity = 0,
    this.unit,
    this.rawValues,
    this.secondaryQty,
    this.secondaryUnit,
  });

  factory ScannedVariantAllocation.fromJson(Map<String, dynamic> j) {
    double? nOrNull(dynamic v) => v == null ? null : double.tryParse(v.toString());
    return ScannedVariantAllocation(
      variantId: int.tryParse(j['variantId']?.toString() ?? ''),
      label: j['label']?.toString(),
      widthMm: nOrNull(j['widthMm']),
      quantity: double.tryParse(j['quantity']?.toString() ?? '') ?? 0,
      unit: j['unit']?.toString(),
      rawValues: j['rawValues'],
      secondaryQty: nOrNull(j['secondaryQty']),
      secondaryUnit: j['secondaryUnit']?.toString(),
    );
  }

  Map<String, dynamic> toPayload() => {
        if (variantId != null) 'variantId': variantId,
        if (label != null) 'label': label,
        if (widthMm != null) 'widthMm': widthMm,
        'quantity': quantity,
        if (unit != null) 'unit': unit,
        if (rawValues != null) 'rawValues': rawValues,
        if (secondaryQty != null) 'secondaryQty': secondaryQty,
        if (secondaryUnit != null) 'secondaryUnit': secondaryUnit,
      };
}

/// One line item extracted from a scanned vendor bill.
class ScannedItem {
  final String itemDescription;
  final String? hsnCode;
  final String? unit;
  final double quantity;
  final double unitPrice;
  final double? discountAmount;
  final double cgstPercent;
  final double sgstPercent;
  final double igstPercent;
  final List<ScannedVariantAllocation> variantAllocations;

  const ScannedItem({
    this.itemDescription = '',
    this.hsnCode,
    this.unit,
    this.quantity = 0,
    this.unitPrice = 0,
    this.discountAmount,
    this.cgstPercent = 0,
    this.sgstPercent = 0,
    this.igstPercent = 0,
    this.variantAllocations = const [],
  });

  factory ScannedItem.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    double? nOrNull(dynamic v) => v == null ? null : double.tryParse(v.toString());
    final allocs = (j['variantAllocations'] is List)
        ? (j['variantAllocations'] as List)
            .whereType<Map>()
            .map((e) => ScannedVariantAllocation.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <ScannedVariantAllocation>[];
    return ScannedItem(
      itemDescription: (j['itemDescription'] ?? j['productName'] ?? j['description'] ?? '').toString(),
      hsnCode: j['hsnCode']?.toString(),
      unit: j['unit']?.toString(),
      quantity: n(j['quantity']),
      unitPrice: n(j['unitPrice'] ?? j['rate']),
      discountAmount: nOrNull(j['discountAmount']),
      cgstPercent: n(j['cgstPercent']),
      sgstPercent: n(j['sgstPercent']),
      igstPercent: n(j['igstPercent']),
      variantAllocations: allocs,
    );
  }
}

/// Result of POST /api/ai/scan-vendor-bill (single-invoice extraction JSON).
class ScannedBill {
  final String? vendorName;
  final String? vendorGstin;
  final String? vendorPhone;
  final String? vendorEmail;
  final String? vendorContactPerson;
  final String? vendorAddress;
  final String? vendorCity;
  final String? vendorState;
  final String? vendorPincode;
  final String? customerGstin; // buyer GSTIN (validated server-side)
  final String? invoiceNumber;
  final String? invoiceDate; // AI returns YYYY-MM-DD (kept as string)
  final String? dueDate;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalAmount;
  final double? freightCharges;
  final double? roundOffAmount;
  final String? notes;
  final bool needsManualReview;
  final List<String> validationWarnings;
  final List<ScannedItem> items;

  const ScannedBill({
    this.vendorName,
    this.vendorGstin,
    this.vendorPhone,
    this.vendorEmail,
    this.vendorContactPerson,
    this.vendorAddress,
    this.vendorCity,
    this.vendorState,
    this.vendorPincode,
    this.customerGstin,
    this.invoiceNumber,
    this.invoiceDate,
    this.dueDate,
    this.taxableAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.totalAmount = 0,
    this.freightCharges,
    this.roundOffAmount,
    this.notes,
    this.needsManualReview = false,
    this.validationWarnings = const [],
    this.items = const [],
  });

  double get gstAmount => cgstAmount + sgstAmount + igstAmount;
  bool get hasItems => items.isNotEmpty;

  factory ScannedBill.fromJson(Map<String, dynamic> json) {
    double n(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    double? nOrNull(dynamic v) => v == null ? null : double.tryParse(v.toString());
    final total = json['totalAmount'] ??
        json['invoiceTotalInclGst'] ??
        json['grandTotal'] ??
        json['total'];
    final items = (json['items'] is List)
        ? (json['items'] as List)
            .whereType<Map>()
            .map((e) => ScannedItem.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <ScannedItem>[];
    final warnings = (json['validationWarnings'] is List)
        ? (json['validationWarnings'] as List).map((e) => e.toString()).toList()
        : <String>[];
    return ScannedBill(
      vendorName: json['vendorName']?.toString(),
      vendorGstin: json['vendorGstin']?.toString(),
      vendorPhone: json['vendorPhone']?.toString(),
      vendorEmail: json['vendorEmail']?.toString(),
      vendorContactPerson: json['vendorContactPerson']?.toString(),
      vendorAddress: json['vendorAddress']?.toString(),
      vendorCity: json['vendorCity']?.toString(),
      vendorState: json['vendorState']?.toString(),
      vendorPincode: json['vendorPincode']?.toString(),
      customerGstin: json['customerGstin']?.toString(),
      invoiceNumber: json['invoiceNumber']?.toString(),
      invoiceDate: json['invoiceDate']?.toString(),
      dueDate: json['dueDate']?.toString(),
      taxableAmount: n(json['taxableAmount']),
      cgstAmount: n(json['cgstAmount']),
      sgstAmount: n(json['sgstAmount']),
      igstAmount: n(json['igstAmount']),
      totalAmount: n(total),
      freightCharges: nOrNull(json['freightCharges']),
      roundOffAmount: nOrNull(json['roundOffAmount']),
      notes: json['notes']?.toString(),
      needsManualReview: json['needsManualReview'] == true,
      validationWarnings: warnings,
      items: items,
    );
  }
}
