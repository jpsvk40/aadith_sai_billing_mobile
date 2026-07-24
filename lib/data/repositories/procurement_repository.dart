import '../network/api_client.dart';
import '../models/procurement_models.dart';

/// Procurement front-funnel repository. Backend routes live under
/// `/api/procurement` and are gated by the `vendor_purchases` module
/// (see backend/src/routes/procurement.js — `requireModule('vendor_purchases')`).
///
/// Endpoint paths are kept as feature-local constants here (NOT in
/// core/constants/api_constants.dart) since this is a self-contained feature.
class ProcurementRepository {
  final ApiClient _client;
  ProcurementRepository(this._client);

  static const String _base = '/api/procurement';
  static const String _requisitions = '$_base/requisitions';
  static const String _rfqs = '$_base/rfqs';
  static const String _purchaseOrders = '$_base/purchase-orders';
  static const String _paymentRequests = '$_base/payment-requests';
  // Vendor + project masters are reused (best-effort) to label RFQ rows and seed the form.
  static const String _vendors = '/api/vendors';
  static const String _projects = '/api/projects';

  /// Lists come back as bare JSON arrays; some masters wrap under a key.
  List<Map<String, dynamic>> _rows(dynamic data, [String? key]) {
    dynamic raw = data;
    if (data is Map) {
      raw = (key != null ? data[key] : null) ?? data['data'] ?? data;
    }
    if (raw is List) {
      return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }

  Map<String, dynamic> _obj(dynamic data) =>
      data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};

  // ─── Requisitions ───
  Future<List<Requisition>> getRequisitions({String? status}) async {
    final data = await _client.get(_requisitions,
        queryParams: (status != null && status.isNotEmpty) ? {'status': status} : null);
    return _rows(data).map(Requisition.fromJson).toList();
  }

  Future<Requisition> getRequisitionDetail(int id) async {
    final data = await _client.get('$_requisitions/$id');
    return Requisition.fromJson(_obj(data));
  }

  Future<Requisition> createRequisition({
    String? projectId,
    String? department,
    String priority = 'NORMAL',
    String? requiredByDate,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _client.post(_requisitions, data: {
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      if (department != null && department.isNotEmpty) 'department': department,
      'priority': priority,
      if (requiredByDate != null && requiredByDate.isNotEmpty) 'requiredByDate': requiredByDate,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'items': items,
    });
    return Requisition.fromJson(_obj(data));
  }

  Future<void> submitRequisition(int id) => _client.post('$_requisitions/$id/submit', data: const {});
  Future<void> approveRequisition(int id) => _client.post('$_requisitions/$id/approve', data: const {});
  Future<void> rejectRequisition(int id, String reason) =>
      _client.post('$_requisitions/$id/reject', data: {'reason': reason});

  // ─── RFQs ───
  Future<List<Rfq>> getRfqs({String? status}) async {
    final data = await _client.get(_rfqs,
        queryParams: (status != null && status.isNotEmpty) ? {'status': status} : null);
    return _rows(data).map(Rfq.fromJson).toList();
  }

  Future<Rfq> getRfqDetail(int id) async {
    final data = await _client.get('$_rfqs/$id');
    return Rfq.fromJson(_obj(data));
  }

  // ─── Purchase Orders ───
  Future<List<PurchaseOrder>> getPurchaseOrders({String? status}) async {
    final data = await _client.get(_purchaseOrders,
        queryParams: (status != null && status.isNotEmpty) ? {'status': status} : null);
    return _rows(data).map(PurchaseOrder.fromJson).toList();
  }

  Future<PurchaseOrder> getPurchaseOrderDetail(int id) async {
    final data = await _client.get('$_purchaseOrders/$id');
    return PurchaseOrder.fromJson(_obj(data));
  }

  // ─── Payment Requests ───
  Future<List<PaymentRequest>> getPaymentRequests({String? status}) async {
    final data = await _client.get(_paymentRequests,
        queryParams: (status != null && status.isNotEmpty) ? {'status': status} : null);
    return _rows(data).map(PaymentRequest.fromJson).toList();
  }

  Future<void> approvePaymentRequest(int id) =>
      _client.post('$_paymentRequests/$id/approve', data: const {});
  Future<void> holdPaymentRequest(int id, {String? reason}) =>
      _client.post('$_paymentRequests/$id/hold', data: {'reason': reason ?? 'On hold'});
  Future<void> rejectPaymentRequest(int id) =>
      _client.post('$_paymentRequests/$id/reject', data: const {});

  // ─── Masters (best-effort — used only to label / seed) ───

  /// Vendor id → name map for labelling RFQ vendors/quotations.
  Future<Map<int, String>> getVendorNames() async {
    final data = await _client.get(_vendors);
    final map = <int, String>{};
    for (final v in _rows(data, 'vendors')) {
      final id = v['id'];
      final name = v['vendorName'] ?? v['name'];
      if (id != null && name != null) {
        final iid = id is int ? id : int.tryParse(id.toString());
        if (iid != null) map[iid] = name.toString();
      }
    }
    return map;
  }

  Future<List<ProcProject>> getProjects() async {
    final data = await _client.get(_projects);
    return _rows(data, 'projects').map(ProcProject.fromJson).toList();
  }
}
