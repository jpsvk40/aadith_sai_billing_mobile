class Vendor {
  final String id;
  final String? vendorCode;
  final String vendorName;
  final String? gstin;
  final String? phone;

  const Vendor({
    required this.id,
    this.vendorCode,
    required this.vendorName,
    this.gstin,
    this.phone,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id']?.toString() ?? '',
      vendorCode: json['vendorCode']?.toString(),
      vendorName: json['vendorName']?.toString() ?? '',
      gstin: json['gstin']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}
