import '../network/api_client.dart';
import '../../core/constants/api_constants.dart';

/// Reads the dispatch queue's "Dispatched" source (`/api/dispatch`): dispatch
/// entries that are already Dispatched or Delivered, each carrying its order +
/// customer + transport + package details.
///
/// [dateFrom]/[dateTo] are threaded for parity with the other list screens, but
/// the current `/dispatch` endpoint ignores them, so the screen also applies a
/// client-side date filter for this scope. The "Packed" scope of the queue is
/// served by [OrderRepository] (`/orders?status=Packed`), which honours dates
/// server-side.
class DispatchRepository {
  final ApiClient _client;
  DispatchRepository(this._client);

  Future<List<Map<String, dynamic>>> getDispatchEntries({
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = await _client.get(
      ApiConstants.dispatch,
      queryParams: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      },
    );
    final list = data is Map ? (data['data'] ?? data['rows'] ?? const []) : data;
    if (list is List) {
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }
}
