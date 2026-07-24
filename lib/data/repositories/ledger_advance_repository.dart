import '../network/api_client.dart';
import '../models/ledger_advance_model.dart';

/// Vendor/customer LEDGER advances — web `backend/src/routes/advances.js`
/// (mounted at `/api/advances`). NOT the petty-cash `/api/advance-floats`.
const _advances = '/api/advances';

class LedgerAdvanceRepository {
  final ApiClient _client;
  LedgerAdvanceRepository(this._client);

  /// GET /api/advances?party=VENDOR|CUSTOMER[&status=OPEN]
  Future<List<LedgerAdvance>> list({required String party, String? status}) async {
    final data = await _client.get(_advances, queryParams: {
      'party': party,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    final rows = data is List ? data : const [];
    return rows
        .whereType<Map>()
        .map((e) => LedgerAdvance.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/advances — record + post an advance (requires accountant/manager/admin).
  Future<void> create({
    required String party,
    required String partyName,
    required double amount,
    String paymentMode = 'Bank Transfer',
    String? notes,
  }) async {
    await _client.post(_advances, data: {
      'party': party,
      'partyName': partyName,
      'amount': amount,
      'paymentMode': paymentMode,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  /// POST /api/advances/:id/adjust — adjust (part of) the advance against a bill.
  /// The API records a free-text [reference] + [amount] and posts the GL journal.
  Future<void> adjust({required int id, required double amount, String? reference}) async {
    await _client.post('$_advances/$id/adjust', data: {
      'amount': amount,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
    });
  }

  /// DELETE /api/advances/:id — only when it has no adjustments.
  Future<void> delete(int id) async {
    await _client.delete('$_advances/$id');
  }
}
