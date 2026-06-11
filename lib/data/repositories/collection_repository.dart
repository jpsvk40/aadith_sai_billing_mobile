import '../network/api_client.dart';
import '../models/collection_model.dart';
import '../../core/constants/api_constants.dart';

class CollectionRepository {
  final ApiClient _client;
  CollectionRepository(this._client);

  Future<List<Collection>> getCollections({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _client.get(
      ApiConstants.collections,
      queryParams: {'page': page, 'limit': limit},
    );
    final list = data is Map ? (data['collections'] ?? data['data'] ?? data) : data;
    if (list is List) {
      return list
          .map((e) => Collection.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Collection> getCollectionDetail(String id) async {
    final data = await _client.get(ApiConstants.collectionDetail(id));
    return Collection.fromJson(data['collection'] ?? data);
  }

  /// Send the invoice PDF to the customer's WhatsApp.
  Future<void> sendInvoiceWhatsApp(String invoiceId, {String? to}) async {
    await _client.post('/invoices/$invoiceId/whatsapp', data: (to != null && to.isNotEmpty) ? {'to': to} : {});
  }

  /// Send a payment-receipt PDF for a collection payment to the customer's WhatsApp.
  Future<void> sendReceiptWhatsApp(String paymentId, {String? to}) async {
    await _client.post('/collections/payment/$paymentId/whatsapp-receipt', data: (to != null && to.isNotEmpty) ? {'to': to} : {});
  }

  Future<void> recordCollectionPayment(
    String id,
    Map<String, dynamic> paymentData,
  ) async {
    await _client.post(ApiConstants.collectionPayment(id), data: paymentData);
  }

  Future<void> recordCollectionCorrection(
    String id,
    Map<String, dynamic> correctionData,
  ) async {
    await _client.post(
      ApiConstants.collectionCorrection(id),
      data: correctionData,
    );
  }
}
