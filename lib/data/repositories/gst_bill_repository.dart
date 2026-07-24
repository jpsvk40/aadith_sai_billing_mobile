import '../network/api_client.dart';
import '../models/gst_bill_model.dart';

/// GST Bills — parity with web `GstBillsPage.jsx` + backend `routes/gst-bills.js`.
///
/// All endpoints are auth + company-scoped on the server. The mobile route
/// (`/gst-bills`) is gated to the `gst` module in route_guards. Endpoint paths are
/// kept inline here — `api_constants.dart` is intentionally not touched.
class GstBillRepository {
  final ApiClient _client;
  GstBillRepository(this._client);

  static const _base = '/api/gst-bills';

  int? _intOf(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));

  /// List GST-visible invoices. Requests the FULL matched set (`all=1`) so the
  /// mobile summary cards + by-entity grouping operate over every row (the screen
  /// searches/sorts client-side). [status] accepts Unpaid | Partial | Paid |
  /// Voided (Voided = cancelled bills). Date filtering is server-side: a [period]
  /// key wins over [dateFrom]/[dateTo].
  Future<GstBillListResult> list({
    String? status,
    String? search,
    String? period,
    String? dateFrom,
    String? dateTo,
    String? financialYearId,
  }) async {
    final data = await _client.get(_base, queryParams: {
      'all': '1',
      if (status != null && status.isNotEmpty) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
      if (period != null && period.isNotEmpty) 'period': period,
      if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      if (financialYearId != null && financialYearId.isNotEmpty) 'financialYearId': financialYearId,
    });
    final raw = data is Map ? (data['invoices'] ?? data['data'] ?? const []) : data;
    final bills = (raw is List ? raw : const [])
        .whereType<Map>()
        .map((e) => GstBill.fromJson(e.cast<String, dynamic>()))
        .toList();
    final total = (data is Map ? _intOf(data['total']) : null) ?? bills.length;
    return GstBillListResult(bills: bills, total: total);
  }

  /// GET /summary — company totals for the same date/FY window (status buckets are
  /// computed server-side, so status is NOT forwarded here).
  Future<GstBillSummary> summary({
    String? period,
    String? dateFrom,
    String? dateTo,
    String? financialYearId,
  }) async {
    final data = await _client.get('$_base/summary', queryParams: {
      if (period != null && period.isNotEmpty) 'period': period,
      if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      if (financialYearId != null && financialYearId.isNotEmpty) 'financialYearId': financialYearId,
    });
    return GstBillSummary.fromJson(data is Map ? data.cast<String, dynamic>() : const {});
  }

  /// Void a GST bill — excludes it from GST returns.
  Future<void> voidBill(int id) => _client.patch('$_base/$id/void', data: const {});

  /// Restore a voided GST bill (re-issues a GST number if one is now due).
  Future<void> unvoidBill(int id) => _client.patch('$_base/$id/unvoid', data: const {});

  /// Assign the next available GST number (server-side admin-only — a 403 is
  /// surfaced to the caller otherwise). Returns the assigned number.
  Future<String?> assignGstNumber(int id) async {
    final data = await _client.post('$_base/$id/assign-gst-number', data: const {});
    return data is Map ? data['gstInvoiceNo']?.toString() : null;
  }

  /// Portal-assisted e-Invoice (IRN) JSON export.
  Future<GstExportResult> exportEinvoice(int id, {bool sandbox = true}) =>
      _export('einvoice', id, sandbox: sandbox);

  /// Portal-assisted e-Way Bill JSON export (server rejects bills < ₹50,000).
  Future<GstExportResult> exportEwayBill(int id, {bool sandbox = true}) =>
      _export('eway-bill', id, sandbox: sandbox);

  Future<GstExportResult> _export(String kind, int id, {required bool sandbox}) async {
    final data = await _client.get(
      '$_base/export/$kind/$id',
      queryParams: {'sandbox': sandbox ? '1' : '0'},
    );
    final map = data is Map ? data.cast<String, dynamic>() : const <String, dynamic>{};
    final warnings = (map['warnings'] is List)
        ? (map['warnings'] as List).map((w) => w.toString()).toList()
        : <String>[];
    return GstExportResult(
      docNo: (map['invoiceNo'] ?? id).toString(),
      payload: map['payload'],
      warnings: warnings,
    );
  }
}
