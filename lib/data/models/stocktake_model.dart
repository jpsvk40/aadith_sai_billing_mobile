import 'package:flutter/material.dart';

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
double? _toDN(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
int _toI(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

/// Reads the first present (non-null) value across a set of candidate keys.
/// The backend field for the frozen book quantity isn't fixed in the contract,
/// so lines defensively look under several likely names.
dynamic _pick(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    if (j[k] != null) return j[k];
  }
  return null;
}

class StocktakeSummary {
  final int totalLines;
  final int counted;
  final int variances;
  final double netUnits;
  const StocktakeSummary({this.totalLines = 0, this.counted = 0, this.variances = 0, this.netUnits = 0});

  factory StocktakeSummary.fromJson(Map<String, dynamic> j) => StocktakeSummary(
        totalLines: _toI(j['totalLines']),
        counted: _toI(j['counted']),
        variances: _toI(j['variances']),
        netUnits: _toD(j['netUnits']),
      );
}

/// One stock-take line: the frozen book (system) qty + the coach's physical count.
class StocktakeLine {
  final int id;
  final int itemId;
  final String itemCode;
  final String itemName;
  final String unit;
  final double systemQty; // frozen book quantity at freeze time
  final double? countedQty;
  final double? variance;
  final String? varianceReason;

  const StocktakeLine({
    required this.id,
    required this.itemId,
    this.itemCode = '',
    this.itemName = '',
    this.unit = '',
    this.systemQty = 0,
    this.countedQty,
    this.variance,
    this.varianceReason,
  });

  factory StocktakeLine.fromJson(Map<String, dynamic> j) {
    final item = j['item'];
    final itemMap = item is Map ? item.cast<String, dynamic>() : const <String, dynamic>{};
    return StocktakeLine(
      id: _toI(j['id']),
      itemId: _toI(_pick(j, ['itemId', 'inventoryItemId']) ?? itemMap['id']),
      itemCode: (itemMap['itemCode'] ?? j['itemCode'] ?? '').toString(),
      itemName: (itemMap['itemName'] ?? itemMap['displayName'] ?? j['itemName'] ?? '').toString(),
      unit: (itemMap['unit'] ?? j['unit'] ?? '').toString(),
      systemQty: _toD(_pick(j, ['systemQty', 'bookQty', 'snapshotQty', 'expectedQty', 'qtyExpected', 'openingQty', 'systemQuantity'])),
      countedQty: _toDN(_pick(j, ['countedQty', 'counted', 'countedQuantity'])),
      variance: _toDN(_pick(j, ['variance', 'varianceQty', 'varianceQuantity'])),
      varianceReason: _pick(j, ['varianceReason', 'reason'])?.toString(),
    );
  }

  String get label => itemCode.isEmpty ? itemName : '$itemName ($itemCode)';
}

class Stocktake {
  final int id;
  final String status;
  final int? locationId;
  final String? locationName;
  final String? notes;
  final String? createdAt;
  final StocktakeSummary? summary;
  final List<StocktakeLine> lines;

  const Stocktake({
    required this.id,
    required this.status,
    this.locationId,
    this.locationName,
    this.notes,
    this.createdAt,
    this.summary,
    this.lines = const [],
  });

  factory Stocktake.fromJson(Map<String, dynamic> j) {
    final loc = j['location'];
    final locMap = loc is Map ? loc.cast<String, dynamic>() : const <String, dynamic>{};
    return Stocktake(
      id: _toI(j['id']),
      status: (j['status'] ?? 'DRAFT').toString(),
      locationId: (j['locationId'] ?? locMap['id']) == null ? null : _toI(j['locationId'] ?? locMap['id']),
      locationName: (locMap['locationName'] ?? locMap['name'] ?? j['locationName'])?.toString(),
      notes: j['notes']?.toString(),
      createdAt: (j['createdAt'] ?? j['created_at'])?.toString(),
      summary: j['summary'] is Map ? StocktakeSummary.fromJson((j['summary'] as Map).cast<String, dynamic>()) : null,
      lines: (j['lines'] as List<dynamic>?)?.map((e) => StocktakeLine.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
    );
  }

  bool get isDraft => status == 'DRAFT';
  bool get isFrozen => status == 'FROZEN';
  bool get isCounting => status == 'COUNTING';
  bool get isCountable => status == 'FROZEN' || status == 'COUNTING';
  bool get isTerminal => status == 'APPROVED' || status == 'CANCELLED';
}

class StocktakeLocation {
  final int id;
  final String name;
  const StocktakeLocation(this.id, this.name);
}

/// Lifecycle statuses + colours.
class StocktakeStatus {
  static const all = ['DRAFT', 'FROZEN', 'COUNTING', 'APPROVED', 'CANCELLED'];

  static Color color(String s) {
    switch (s) {
      case 'DRAFT':
        return const Color(0xFF64748B);
      case 'FROZEN':
        return const Color(0xFF0EA5E9);
      case 'COUNTING':
        return const Color(0xFFF59E0B);
      case 'APPROVED':
        return const Color(0xFF059669);
      case 'CANCELLED':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }
}
