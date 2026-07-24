import '../network/api_client.dart';
import '../models/invoice_model.dart';
import '../../core/constants/api_constants.dart';

class InvoiceRepository {
  final ApiClient _client;
  InvoiceRepository(this._client);

  Future<List<Invoice>> getInvoices({
    String? paymentStatus,
    String? search,
    String? dateFrom,
    String? dateTo,
    String? financialYearId,
  }) async {
    final data = await _client.get(ApiConstants.invoices, queryParams: {
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (search != null && search.isNotEmpty) 'search': search,
      if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      if (financialYearId != null && financialYearId.isNotEmpty) 'financialYearId': financialYearId,
    });
    final list = data is Map ? (data['invoices'] ?? data['data'] ?? data) : data;
    if (list is List) {
      return list.map((e) => Invoice.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Invoice> getInvoiceDetail(String id) async {
    final data = await _client.get(ApiConstants.invoiceDetail(id));
    return Invoice.fromJson(data['invoice'] ?? data);
  }

  /// Send this invoice to the customer's WhatsApp via the shared platform number.
  Future<void> sendWhatsApp(String id, {String? to}) async {
    await _client.post('/api/invoices/$id/whatsapp',
        data: (to != null && to.isNotEmpty) ? {'to': to} : {},
        timeout: const Duration(seconds: 120));
  }
}
