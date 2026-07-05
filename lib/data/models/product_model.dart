class Product {
  final String id;
  final String name;
  final double sellingPrice;
  final double taxPercent;
  final String? unit;
  final String? hsnCode;

  const Product({
    required this.id,
    required this.name,
    this.sellingPrice = 0,
    this.taxPercent = 0,
    this.unit,
    this.hsnCode,
  });

  /// Name always paired with the unit (many products share a name, differing only by unit).
  String get displayName => (unit != null && unit!.isNotEmpty) ? '$name ($unit)' : name;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id']?.toString() ?? '',
        name: j['productName']?.toString() ?? j['name']?.toString() ?? '',
        sellingPrice: double.tryParse(j['sellingPrice']?.toString() ?? '0') ?? 0,
        taxPercent: double.tryParse(j['taxPercent']?.toString() ?? '0') ?? 0,
        unit: j['unit']?.toString(),
        hsnCode: j['hsnCode']?.toString(),
      );
}
