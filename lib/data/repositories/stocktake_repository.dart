import '../network/api_client.dart';
import '../models/stocktake_model.dart';
import '../../core/errors/app_exceptions.dart';

/// Physical stock-take (garments edition, module `stocktake`). Lifecycle
/// DRAFT → FROZEN → COUNTING → APPROVED (or CANCELLED). Endpoint strings inline.
class StocktakeRepository {
  final ApiClient _client;
  StocktakeRepository(this._client);

  List<Map<String, dynamic>> _asList(dynamic data) {
    final list = data is Map ? (data['stocktakes'] ?? data['items'] ?? data['data'] ?? data) : data;
    if (list is List) return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return const [];
  }

  Future<List<Stocktake>> getStocktakes({String? status, int? locationId}) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'All') qp['status'] = status;
    if (locationId != null) qp['locationId'] = locationId;
    final data = await _client.get('/api/stocktakes', queryParams: qp.isEmpty ? null : qp);
    return _asList(data).map(Stocktake.fromJson).toList();
  }

  Future<Stocktake> getStocktake(int id) async {
    final data = await _client.get('/api/stocktakes/$id');
    return Stocktake.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Stocktake> createStocktake({required int locationId, String? notes}) async {
    final data = await _client.post('/api/stocktakes', data: {
      'locationId': locationId,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return Stocktake.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Stocktake> freeze(int id) async {
    final data = await _client.post('/api/stocktakes/$id/freeze', data: const {});
    return Stocktake.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Posts the counted lines. Each entry: {itemId, countedQty (num|null), varianceReason?}.
  Future<Stocktake> saveCounts(int id, List<Map<String, dynamic>> lines) async {
    final data = await _client.post('/api/stocktakes/$id/count', data: {'lines': lines});
    return Stocktake.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Stocktake> approve(int id) async {
    final data = await _client.post('/api/stocktakes/$id/approve', data: const {});
    return Stocktake.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<Stocktake> cancel(int id) async {
    final data = await _client.post('/api/stocktakes/$id/cancel', data: const {});
    return Stocktake.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<List<StocktakeLocation>> getLocations() async {
    final data = await _client.get('/api/inventory-locations');
    final list = data is List ? data : const [];
    return list
        .whereType<Map>()
        .map((e) => StocktakeLocation(
              (e['id'] as num).toInt(),
              (e['locationName'] ?? e['locationCode'] ?? 'Location').toString(),
            ))
        .toList();
  }

  /// Resolves a scanned barcode via the POS scan endpoint (gated `retail_pos`).
  /// Returns the resolved payload ({name, sku, ...}) or null when the barcode is
  /// unknown (404) or POS isn't enabled for this company (403) — callers then fall
  /// back to a manual search over the frozen lines.
  Future<Map<String, dynamic>?> resolveBarcode(String barcode) async {
    try {
      final data = await _client.get('/api/pos/scan/$barcode');
      return data is Map ? data.cast<String, dynamic>() : null;
    } on ForbiddenException {
      return null;
    } on NotFoundException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
