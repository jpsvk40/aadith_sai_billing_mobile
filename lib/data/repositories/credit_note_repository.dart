import '../network/api_client.dart';
import '../models/credit_note_model.dart';
import '../models/invoice_model.dart';
import '../../core/constants/api_constants.dart';

/// Credit notes — customer-side (rich, `invoices` module) and vendor-side (lump-sum,
/// always against one purchase). Amounts are server-authoritative; on create we send
/// the computed lump-sum totals and the server re-validates. Endpoint path strings are
/// inline here (they are not all in ApiConstants); pickers reuse the shared customer /
/// invoice / vendor list endpoints.
class CreditNoteRepository {
  final ApiClient _client;
  CreditNoteRepository(this._client);

  static const String _customerBase = '/api/customer-credit-notes';
  static const String _vendorBase = '/api/vendor-credit-notes';

  List<Map<String, dynamic>> _asList(dynamic data) {
    final list = data is Map ? (data['creditNotes'] ?? data['data'] ?? data['items'] ?? data) : data;
    if (list is List) return list.map((e) => e as Map<String, dynamic>).toList();
    return const [];
  }

  // ── Customer credit notes ──────────────────────────────────────────────────

  Future<List<CustomerCreditNote>> listCustomerCreditNotes({
    String? status,
    int? customerId,
    int? invoiceId,
    String? search,
  }) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'All') qp['status'] = status;
    if (customerId != null) qp['customerId'] = customerId;
    if (invoiceId != null) qp['invoiceId'] = invoiceId;
    if (search != null && search.isNotEmpty) qp['search'] = search;
    final data = await _client.get(_customerBase, queryParams: qp.isEmpty ? null : qp);
    return _asList(data).map(CustomerCreditNote.fromJson).toList();
  }

  /// Prefill amounts + items from a source invoice.
  Future<CreditNoteSuggestion> suggestFromInvoice(int invoiceId) async {
    final data = await _client.get('$_customerBase/suggest', queryParams: {'invoiceId': invoiceId});
    final map = data is Map
        ? (data['suggestion'] is Map ? data['suggestion'] : data)
        : <String, dynamic>{};
    return CreditNoteSuggestion.fromJson((map as Map).cast<String, dynamic>());
  }

  /// Create a customer credit note. On a soft-block the server returns HTTP 409 with
  /// `{ needsOverride, warnings }` — that AppException propagates to the caller (with
  /// `.data`), which can re-call with `override: true`.
  Future<CustomerCreditNote> createCustomerCreditNote(Map<String, dynamic> body, {bool override = false}) async {
    final data = await _client.post(_customerBase, data: {
      ...body,
      if (override) 'override': true,
    });
    final map = data is Map ? (data['creditNote'] is Map ? data['creditNote'] : data) : <String, dynamic>{};
    return CustomerCreditNote.fromJson((map as Map).cast<String, dynamic>());
  }

  /// Open invoices for a customer (balance > 0) — the "Against invoice" picker source.
  Future<List<Invoice>> getCustomerOpenInvoices(int customerId) async {
    final data = await _client.get(ApiConstants.invoices, queryParams: {'customerId': customerId});
    final list = data is Map ? (data['invoices'] ?? data['data'] ?? data) : data;
    final rows = list is List ? list.map((e) => e as Map<String, dynamic>).toList() : const <Map<String, dynamic>>[];
    return rows
        .map(Invoice.fromJson)
        .where((i) => (i.outstandingAmount ?? 0) > 0)
        .toList();
  }

  // ── Vendor credit notes ────────────────────────────────────────────────────

  Future<List<VendorCreditNote>> listVendorCreditNotes({int? vendorId, String? search}) async {
    final qp = <String, dynamic>{};
    if (vendorId != null) qp['vendorId'] = vendorId;
    if (search != null && search.isNotEmpty) qp['search'] = search;
    final data = await _client.get(_vendorBase, queryParams: qp.isEmpty ? null : qp);
    return _asList(data).map(VendorCreditNote.fromJson).toList();
  }

  /// Create a vendor credit note against one purchase. The server enforces total ≤ the
  /// purchase's outstanding (HTTP 400); the screen also pre-checks client-side.
  Future<VendorCreditNote> createVendorCreditNote(Map<String, dynamic> body) async {
    final data = await _client.post(_vendorBase, data: body);
    final map = data is Map ? (data['creditNote'] is Map ? data['creditNote'] : data) : <String, dynamic>{};
    return VendorCreditNote.fromJson((map as Map).cast<String, dynamic>());
  }

  /// Fetch a single vendor purchase (for the optional `vendorPurchaseId` deep-link path)
  /// so the ceiling + label are known without going through the vendor→bill pickers.
  /// Returns a light map: { id, label, outstanding }.
  Future<Map<String, dynamic>?> getVendorPurchaseTarget(int purchaseId) async {
    final data = await _client.get(ApiConstants.vendorPurchaseDetail(purchaseId.toString()));
    final p = data is Map ? (data['purchase'] is Map ? data['purchase'] : data) : null;
    if (p is! Map) return null;
    double n(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
    final outstanding = p['outstandingAmount'] != null
        ? n(p['outstandingAmount'])
        : (n(p['totalAmount']) - n(p['paidAmount']));
    final label = (p['purchaseNumber'] ?? p['invoiceNumber'] ?? 'Bill').toString();
    return {'id': purchaseId, 'label': label, 'outstanding': outstanding};
  }
}
