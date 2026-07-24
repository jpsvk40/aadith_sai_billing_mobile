import '../network/api_client.dart';
import '../../core/constants/api_constants.dart';

/// A location/godown option surfaced in the stock-summary response, used to
/// populate the mobile Inventory report's Location filter.
class InventoryLocationOption {
  final int id;
  final String name;
  const InventoryLocationOption(this.id, this.name);
}

/// Parsed shape of `/api/inventory-reports/stock-summary`. We only surface the
/// pieces the mobile stock report needs: per-item totals, per-location rows, and
/// the location master embedded in the payload (so the Location filter needs no
/// extra request).
class InventoryStockSummary {
  final List<Map<String, dynamic>> itemTotals;
  final List<Map<String, dynamic>> rows;
  final List<InventoryLocationOption> locations;

  const InventoryStockSummary({
    required this.itemTotals,
    required this.rows,
    required this.locations,
  });

  factory InventoryStockSummary.fromJson(Map<String, dynamic> m) {
    List<Map<String, dynamic>> asRows(dynamic v) =>
        ((v as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

    final locs = ((m['locations'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where((e) => e['id'] != null)
        .map((e) => InventoryLocationOption(
              (e['id'] as num).toInt(),
              (e['locationName'] ?? e['locationCode'] ?? 'Location').toString(),
            ))
        .toList();

    return InventoryStockSummary(
      itemTotals: asRows(m['itemTotals']),
      rows: asRows(m['rows']),
      locations: locs,
    );
  }
}

/// Reads the inventory stock reports that back the mobile "Inventory" report
/// screen. Mirrors the web `InventoryStockReportPage` data sources
/// (`/api/inventory-reports/stock-summary` and `/ledger`). `itemId`/`locationId`
/// are threaded to the server exactly like the web filters do.
class InventoryReportRepository {
  final ApiClient _client;
  InventoryReportRepository(this._client);

  /// Fetches the stock summary. Pass [locationId] to scope every quantity to a
  /// single godown/location server-side; [itemId] narrows to one item.
  Future<InventoryStockSummary> getStockSummary({int? itemId, int? locationId}) async {
    final qp = <String, dynamic>{};
    if (itemId != null) qp['itemId'] = itemId;
    if (locationId != null) qp['locationId'] = locationId;
    final data = await _client.get(ApiConstants.inventoryStockSummary, queryParams: qp.isEmpty ? null : qp);
    final m = (data is Map ? data : const {}).cast<String, dynamic>();
    return InventoryStockSummary.fromJson(m);
  }

  /// Builds an itemId -> effective unit cost map from `/api/inventory-items`
  /// (the endpoint returns an already-resolved `defaultUnitCost`, falling back
  /// to the most recent purchase cost). Used to compute a "Stock value" sort,
  /// since the stock-summary payload itself carries no monetary value. Cost is
  /// item-level and location independent, so callers can fetch this once.
  Future<Map<int, double>> getUnitCostByItemId() async {
    final data = await _client.get(ApiConstants.inventoryItems);
    final list = data is List ? data : const [];
    final out = <int, double>{};
    for (final e in list.whereType<Map>()) {
      final id = e['id'];
      final cost = e['defaultUnitCost'];
      if (id is num && cost != null) {
        final c = double.tryParse(cost.toString());
        if (c != null && c > 0) out[id.toInt()] = c;
      }
    }
    return out;
  }

  /// Fetches inventory movement history (the web "Ledger View"). [from]/[to] are
  /// `yyyy-MM-dd` strings forwarded as `dateFrom`/`dateTo`. Returns the enriched
  /// rows as-is (txnDate, txnNumber, txnType, locationName, item labels,
  /// quantity, before/after balance, party + reference).
  Future<List<Map<String, dynamic>>> getLedger({int? itemId, int? locationId, String? from, String? to}) async {
    final qp = <String, dynamic>{};
    if (itemId != null) qp['itemId'] = itemId;
    if (locationId != null) qp['locationId'] = locationId;
    if (from != null && from.isNotEmpty) qp['dateFrom'] = from;
    if (to != null && to.isNotEmpty) qp['dateTo'] = to;
    final data = await _client.get(ApiConstants.inventoryLedger, queryParams: qp.isEmpty ? null : qp);
    final list = data is List ? data : const [];
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}
