import '../network/api_client.dart';
import '../models/quotation_model.dart';
import '../../core/constants/api_constants.dart';

/// Quotations + convert-to-invoice. Module-gated `crm` on the server.
/// Amounts are server-authoritative — create sends only description/quantity/rate/taxPercent
/// per line; the server (re)computes subtotal/tax/total.
class QuotationRepository {
  final ApiClient _client;
  QuotationRepository(this._client);

  List<Map<String, dynamic>> _asList(dynamic data) {
    final list = data is Map ? (data['quotations'] ?? data['items'] ?? data['data'] ?? data) : data;
    if (list is List) return list.map((e) => e as Map<String, dynamic>).toList();
    return const [];
  }

  Future<List<Quotation>> getQuotations({String? status, int? customerId}) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'All') qp['status'] = status;
    if (customerId != null) qp['customerId'] = customerId;
    final data = await _client.get(ApiConstants.quotations, queryParams: qp.isEmpty ? null : qp);
    return _asList(data).map(Quotation.fromJson).toList();
  }

  Future<Quotation> getQuotation(int id) async {
    final data = await _client.get(ApiConstants.quotation(id.toString()));
    return Quotation.fromJson(data as Map<String, dynamic>);
  }

  Future<Quotation> createQuotation(Map<String, dynamic> body) async {
    final data = await _client.post(ApiConstants.quotations, data: body);
    return Quotation.fromJson(data as Map<String, dynamic>);
  }

  Future<Quotation> updateStatus(int id, String status) async {
    final data = await _client.patch(ApiConstants.quotationStatus(id.toString()), data: {'status': status});
    return Quotation.fromJson(data as Map<String, dynamic>);
  }

  /// Converts an ACCEPTED quote (with a real customer) into a GST invoice.
  /// Returns `{ invoiceId, invoiceNo, grandTotal, balanceAmount, paymentStatus }`.
  Future<Map<String, dynamic>> convertToInvoice(int id) async {
    final data = await _client.post(ApiConstants.quotationConvert(id.toString()), data: const {});
    return (data as Map).cast<String, dynamic>();
  }
}
