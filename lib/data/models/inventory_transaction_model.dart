/// Posted inventory transaction (a "stock entry") and its item lines.
///
/// Mirrors the web `GET /api/inventory-transactions` list shape used by
/// `StockEntriesPage.jsx`. The backend returns each transaction with its
/// `location` and `lines` (each line embeds its `item`), plus a few derived
/// reference fields (`referenceLabel`, `linkedNumber`, `linkedInvoiceNo`,
/// `partyName`) for entries created from a purchase receipt etc.
///
/// All parsing is tolerant — missing/renamed keys degrade to sane defaults so a
/// partial payload never throws.
library;

double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

int? _toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

String? _nonEmpty(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// Friendly label for a transaction type code.
String txnTypeLabel(String? type) {
  switch (type) {
    case 'OPENING':
      return 'Initial Stock';
    case 'INWARD':
      return 'Inward';
    case 'OUTWARD':
      return 'Outward';
    case 'ADJUST_IN':
      return 'Adjust In';
    case 'ADJUST_OUT':
      return 'Adjust Out';
    case 'TRANSFER_IN':
      return 'Transfer In';
    case 'TRANSFER_OUT':
      return 'Transfer Out';
    default:
      return (type ?? '').replaceAll('_', ' ');
  }
}

/// A single item line on a stock entry. Quantity is signed on the server
/// (negative = stock out); the UI shows the sign to convey direction.
class InventoryTxnLine {
  final int? itemId;
  final double quantity;
  final String? remarks;
  final String itemName;
  final String itemCode;
  final String unit;

  const InventoryTxnLine({
    this.itemId,
    this.quantity = 0,
    this.remarks,
    this.itemName = '',
    this.itemCode = '',
    this.unit = '',
  });

  factory InventoryTxnLine.fromJson(Map<String, dynamic> j) {
    final item = (j['item'] as Map?)?.cast<String, dynamic>() ?? const {};
    return InventoryTxnLine(
      itemId: _toInt(j['itemId'] ?? item['id']),
      quantity: _toDouble(j['quantity']),
      remarks: _nonEmpty(j['remarks']),
      itemName: (item['itemName'] ?? j['itemName'] ?? '').toString(),
      itemCode: (item['itemCode'] ?? j['itemCode'] ?? '').toString(),
      unit: (item['unit'] ?? j['unit'] ?? '').toString(),
    );
  }

  /// Magnitude (always positive) — matches the web which shows abs(quantity).
  double get magnitude => quantity.abs();
}

class InventoryTransaction {
  final int? id;
  final String txnNumber;
  final String txnType;
  final DateTime? txnDate;
  final String? notes;
  final String locationName;
  final String locationCode;
  final String? referenceType;
  final String? referenceLabel;
  final String? linkedNumber;
  final String? linkedInvoiceNo;
  final String? partyName;
  final List<InventoryTxnLine> lines;

  const InventoryTransaction({
    this.id,
    this.txnNumber = '',
    this.txnType = '',
    this.txnDate,
    this.notes,
    this.locationName = '',
    this.locationCode = '',
    this.referenceType,
    this.referenceLabel,
    this.linkedNumber,
    this.linkedInvoiceNo,
    this.partyName,
    this.lines = const [],
  });

  factory InventoryTransaction.fromJson(Map<String, dynamic> j) {
    final loc = (j['location'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawLines = (j['lines'] as List?) ?? const [];
    return InventoryTransaction(
      id: _toInt(j['id']),
      txnNumber: (j['txnNumber'] ?? '').toString(),
      txnType: (j['txnType'] ?? '').toString(),
      txnDate: _toDate(j['txnDate']),
      notes: _nonEmpty(j['notes']),
      locationName: (loc['locationName'] ?? '').toString(),
      locationCode: (loc['locationCode'] ?? '').toString(),
      referenceType: _nonEmpty(j['referenceType']),
      referenceLabel: _nonEmpty(j['referenceLabel']),
      linkedNumber: _nonEmpty(j['linkedNumber']),
      linkedInvoiceNo: _nonEmpty(j['linkedInvoiceNo']),
      partyName: _nonEmpty(j['partyName']),
      lines: rawLines.whereType<Map>().map((e) => InventoryTxnLine.fromJson(e.cast<String, dynamic>())).toList(),
    );
  }

  String get typeLabel => txnTypeLabel(txnType);

  int get lineCount => lines.length;

  /// e.g. "Rebar 12mm, Cement" — first few item names, joined.
  String get itemSummary {
    if (lines.isEmpty) return '';
    final names = lines.map((l) => l.itemName).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return '';
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} +${names.length - 3} more';
  }

  /// Source label shown in the list — the linked document if this entry was
  /// system-generated (purchase receipt, transfer…), else the reference label.
  String? get sourceLabel {
    if (linkedNumber != null) return '${referenceLabel ?? 'Reference'}: $linkedNumber';
    return referenceLabel;
  }
}
