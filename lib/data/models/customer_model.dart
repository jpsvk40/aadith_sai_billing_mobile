class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? shippingAddress;
  final String? city;
  final String? district;
  final String? gstNumber;
  final String? gstMode;
  final double? discountPercent;
  final bool isActive;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.shippingAddress,
    this.city,
    this.district,
    this.gstNumber,
    this.gstMode,
    this.discountPercent,
    this.isActive = true,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['customerName']?.toString() ?? json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? json['whatsappContact']?.toString(),
      email: json['email']?.toString(),
      address: json['billingAddress']?.toString() ?? json['address']?.toString(),
      shippingAddress: json['shippingAddress']?.toString(),
      city: json['city']?.toString(),
      district: json['district']?.toString(),
      gstNumber: json['gstin']?.toString() ?? json['gstNumber']?.toString(),
      gstMode: json['gstMode']?.toString(),
      discountPercent: double.tryParse(json['discountPercentage']?.toString() ?? json['discountPercent']?.toString() ?? '0'),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
