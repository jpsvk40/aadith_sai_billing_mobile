import '../network/api_client.dart';
import '../models/gst_compliance_model.dart';

/// Company-wide GST compliance registers + the GSTR-1 (Tally) review.
///
/// These READ endpoints are auth-only on the server (no module gate). The mobile
/// routes live under the `/finance/gst` prefix, which already gates the `gst`
/// module in route_guards. Per-invoice IRN / e-Way *generation* lives in
/// `InvoiceComplianceSection` — this repository is registers + summary only.
class GstComplianceRepository {
  final ApiClient _client;
  GstComplianceRepository(this._client);

  // Endpoint paths kept inline (api_constants.dart is intentionally not touched).
  static const _einvoicePath = '/api/gst-compliance/einvoice';
  static const _ewayPath = '/api/gst-compliance/eway-bill';
  static const _logsPath = '/api/gst-compliance/logs';
  static const _tallyReviewPath = '/api/gst/tally-review';
  static const _legalEntitiesPath = '/api/legal-entities';

  /// The register endpoints return a bare ARRAY; stay tolerant of a wrapped shape.
  List<Map<String, dynamic>> _asList(dynamic data) {
    final list = data is Map ? (data['data'] ?? data['items'] ?? data['rows'] ?? data) : data;
    if (list is List) return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return const [];
  }

  /// e-Invoice (IRN) register — every IRN doc for the company. [status] / [invoiceId]
  /// are optional server filters; the register screen fetches all and filters the
  /// clickable KPIs client-side.
  Future<List<EinvoiceDoc>> einvoiceRegister({String? status, String? invoiceId}) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'All') qp['status'] = status;
    if (invoiceId != null && invoiceId.isNotEmpty) qp['invoiceId'] = invoiceId;
    final data = await _client.get(_einvoicePath, queryParams: qp.isEmpty ? null : qp);
    return _asList(data).map(EinvoiceDoc.fromJson).toList();
  }

  /// e-Way bill register — [status] is a SERVER-side filter (unlike the IRN register).
  Future<List<EwayBillDoc>> ewayBillRegister({String? status}) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'All') qp['status'] = status;
    final data = await _client.get(_ewayPath, queryParams: qp.isEmpty ? null : qp);
    return _asList(data).map(EwayBillDoc.fromJson).toList();
  }

  /// Raw compliance activity / audit logs (parity add-on; not yet surfaced on a screen).
  Future<List<Map<String, dynamic>>> complianceLogs() async {
    final data = await _client.get(_logsPath);
    return _asList(data);
  }

  /// GSTR-1 (Tally export) review for a window — both dates required, `YYYY-MM-DD`.
  /// [financialYearId] / [legalEntityId] are optional SERVER-side filters (the same
  /// query params the web returns-review page threads to `/gst/tally-review`).
  Future<GstReturnsReview> gstTallyReview(
    String fromDate,
    String toDate, {
    String? financialYearId,
    String? legalEntityId,
  }) async {
    final qp = <String, dynamic>{'fromDate': fromDate, 'toDate': toDate};
    if (financialYearId != null && financialYearId.isNotEmpty) qp['financialYearId'] = financialYearId;
    if (legalEntityId != null && legalEntityId.isNotEmpty) qp['legalEntityId'] = legalEntityId;
    final data = await _client.get(_tallyReviewPath, queryParams: qp);
    return GstReturnsReview.fromJson(data is Map ? data.cast<String, dynamic>() : const {});
  }

  /// The company's legal entities (multi-GSTIN) for the "GST registration" filter.
  /// Uses the same bare `/api/legal-entities` list the web GST page reads — carries
  /// `gstNumber` so the dropdown can show "Name · GSTIN". Returns [] on any error so
  /// the filter simply hides for single-entity companies rather than breaking a screen.
  Future<List<LegalEntityLite>> legalEntities() async {
    final data = await _client.get(_legalEntitiesPath);
    return _asList(data).map(LegalEntityLite.fromJson).where((e) => e.isValid).toList();
  }
}
