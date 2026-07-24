class Vendor {
  final String id;
  final String? vendorCode;
  final String vendorName;
  final String? gstin;
  final String? phone;
  final String? city;
  // Extra fields used by the Vendors master list (all optional / backward-compatible
  // with the picker usages, which only read id/name/code/gstin/phone/city).
  final String? email;
  final String? contactPerson;
  final String? state;
  final int? paymentTermsDays;
  final double openingBalance;
  final bool isActive;
  final String? assignedRepName;

  const Vendor({
    required this.id,
    this.vendorCode,
    required this.vendorName,
    this.gstin,
    this.phone,
    this.city,
    this.email,
    this.contactPerson,
    this.state,
    this.paymentTermsDays,
    this.openingBalance = 0,
    this.isActive = true,
    this.assignedRepName,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    final rep = json['assignedRep'];
    return Vendor(
      id: json['id']?.toString() ?? '',
      vendorCode: json['vendorCode']?.toString(),
      vendorName: json['vendorName']?.toString() ?? '',
      gstin: json['gstin']?.toString(),
      phone: json['phone']?.toString(),
      city: json['city']?.toString(),
      email: json['email']?.toString(),
      contactPerson: json['contactPerson']?.toString(),
      state: json['state']?.toString(),
      paymentTermsDays: int.tryParse(json['paymentTermsDays']?.toString() ?? ''),
      openingBalance: double.tryParse(json['openingBalance']?.toString() ?? '') ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      assignedRepName: rep is Map ? rep['name']?.toString() : null,
    );
  }
}
