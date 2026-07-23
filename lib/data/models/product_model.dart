double _pToD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int? _pToI(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

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

/// Full product-master row for the create/edit form + admin list. Mirrors the web
/// ProductForm.jsx fields. Kept separate from the minimal [Product] used by pickers.
class ProductDetail {
  final int id;
  final String? sku;
  final String productName;
  final String? productNameEn;
  final String? productNameTa;
  final String? category;
  final String? unit;
  final double sellingPrice;
  final double taxPercent;
  final String? hsnCode;
  final String? uqcCode;
  final int? minStockAlert;
  final double? priceWithGst;
  final double? mrpPerPiece;
  final int? minPurchaseQty;
  final int warrantyMonths;
  final String? warrantyType;
  final double? packSize;
  final String? baseUnit;
  final bool isActive;

  const ProductDetail({
    required this.id,
    required this.productName,
    this.sku,
    this.productNameEn,
    this.productNameTa,
    this.category,
    this.unit,
    this.sellingPrice = 0,
    this.taxPercent = 0,
    this.hsnCode,
    this.uqcCode,
    this.minStockAlert,
    this.priceWithGst,
    this.mrpPerPiece,
    this.minPurchaseQty,
    this.warrantyMonths = 0,
    this.warrantyType,
    this.packSize,
    this.baseUnit,
    this.isActive = true,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
        id: _pToI(j['id']) ?? 0,
        sku: j['sku']?.toString(),
        productName: (j['productName'] ?? j['name'] ?? '').toString(),
        productNameEn: j['productNameEn']?.toString(),
        productNameTa: j['productNameTa']?.toString(),
        category: j['category']?.toString(),
        unit: j['unit']?.toString(),
        sellingPrice: _pToD(j['sellingPrice']),
        taxPercent: _pToD(j['taxPercent']),
        hsnCode: j['hsnCode']?.toString(),
        uqcCode: j['uqcCode']?.toString(),
        minStockAlert: _pToI(j['minStockAlert']),
        priceWithGst: j['priceWithGst'] == null ? null : _pToD(j['priceWithGst']),
        mrpPerPiece: j['mrpPerPiece'] == null ? null : _pToD(j['mrpPerPiece']),
        minPurchaseQty: _pToI(j['minPurchaseQty']),
        warrantyMonths: _pToI(j['warrantyMonths']) ?? 0,
        warrantyType: j['warrantyType']?.toString(),
        packSize: j['packSize'] == null ? null : _pToD(j['packSize']),
        baseUnit: j['baseUnit']?.toString(),
        isActive: j['isActive'] != false,
      );
}
