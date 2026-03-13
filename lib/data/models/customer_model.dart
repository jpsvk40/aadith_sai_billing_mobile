class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
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
    this.gstNumber,
    this.gstMode,
    this.discountPercent,
    this.isActive = true,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'],
      email: json['email'],
      address: json['address'],
      gstNumber: json['gstNumber'],
      gstMode: json['gstMode'],
      discountPercent: double.tryParse(json['discountPercent']?.toString() ?? '0'),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
