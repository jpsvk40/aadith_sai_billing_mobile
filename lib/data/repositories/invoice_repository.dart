import '../network/api_client.dart';
import '../models/invoice_model.dart';
import '../../core/constants/api_constants.dart';

class InvoiceRepository {
  final ApiClient _client;
  InvoiceRepository(this._client);

  Future<List<Invoice>> getInvoices({
    String? paymentStatus,
    String? search,
  }) async {
    final data = await _client.get(ApiConstants.invoices, queryParams: {
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final list = data['invoices'] ?? data['data'] ?? data;
    if (list is List) {
      return list.map((e) => Invoice.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Invoice> getInvoiceDetail(String id) async {
    final data = await _client.get(ApiConstants.invoiceDetail(id));
    return Invoice.fromJson(data['invoice'] ?? data);
  }
}
