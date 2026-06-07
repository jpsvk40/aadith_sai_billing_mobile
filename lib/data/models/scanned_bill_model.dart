/// Result of POST /api/ai/scan-vendor-bill (the extraction JSON, returned directly).
class ScannedBill {
  final String? vendorName;
  final String? vendorGstin;
  final String? invoiceNumber;
  final String? invoiceDate; // AI returns YYYY-MM-DD (kept as string)
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalAmount;

  const ScannedBill({
    this.vendorName,
    this.vendorGstin,
    this.invoiceNumber,
    this.invoiceDate,
    this.taxableAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.totalAmount = 0,
  });

  double get gstAmount => cgstAmount + sgstAmount + igstAmount;

  factory ScannedBill.fromJson(Map<String, dynamic> json) {
    double n(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    final total = json['totalAmount'] ??
        json['invoiceTotalInclGst'] ??
        json['grandTotal'] ??
        json['total'];
    return ScannedBill(
      vendorName: json['vendorName']?.toString(),
      vendorGstin: json['vendorGstin']?.toString(),
      invoiceNumber: json['invoiceNumber']?.toString(),
      invoiceDate: json['invoiceDate']?.toString(),
      taxableAmount: n(json['taxableAmount']),
      cgstAmount: n(json['cgstAmount']),
      sgstAmount: n(json['sgstAmount']),
      igstAmount: n(json['igstAmount']),
      totalAmount: n(total),
    );
  }
}
