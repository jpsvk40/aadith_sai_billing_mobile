import '../network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/service_ticket_model.dart';
import '../models/service_item_model.dart';
import '../models/service_contract_model.dart';
import '../models/calendar_event_model.dart';

/// One repository for the whole Service & Warranty module (tickets, items, AMC, reports).
/// Thin wrapper over ApiClient; screens/providers call these.
class ServiceRepository {
  final ApiClient _client;
  ServiceRepository(this._client);

  List<Map<String, dynamic>> _asList(dynamic data) {
    final list = data is Map ? (data['tickets'] ?? data['items'] ?? data['data'] ?? data) : data;
    if (list is List) return list.map((e) => e as Map<String, dynamic>).toList();
    return const [];
  }

  // ─── Tickets ───
  Future<List<ServiceTicket>> getTickets({String? assignedTo, String? status, String? search, int? customerId}) async {
    final qp = <String, dynamic>{};
    if (assignedTo != null) qp['assignedTo'] = assignedTo;
    if (status != null && status.isNotEmpty && status != 'All') qp['status'] = status;
    if (search != null && search.isNotEmpty) qp['search'] = search;
    if (customerId != null) qp['customerId'] = customerId;
    final data = await _client.get(ApiConstants.serviceTickets, queryParams: qp.isEmpty ? null : qp);
    return _asList(data).map(ServiceTicket.fromJson).toList();
  }

  Future<ServiceTicket> getTicket(int id) async {
    final data = await _client.get(ApiConstants.serviceTicket('$id'));
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceTicket> createTicket(Map<String, dynamic> body) async {
    final data = await _client.post(ApiConstants.serviceTickets, data: body);
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceTicket> changeStatus(int id, String status, {String? note, String? deliveredTo, String? deliveryContact, String? deliveryNote}) async {
    final data = await _client.patch(ApiConstants.serviceTicketStatus('$id'), data: {
      'status': status,
      if (note != null) 'note': note,
      if (deliveredTo != null) 'deliveredTo': deliveredTo,
      if (deliveryContact != null) 'deliveryContact': deliveryContact,
      if (deliveryNote != null) 'deliveryNote': deliveryNote,
    });
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceTicket> updateTicket(int id, Map<String, dynamic> body) async {
    final data = await _client.patch(ApiConstants.serviceTicket('$id'), data: body);
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceTicket> assignTechnician(int id, int? technicianEmployeeId) async {
    final data = await _client.patch(ApiConstants.serviceTicketAssign('$id'), data: {'assignedTechnicianId': technicianEmployeeId});
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceTicket> addPart(int id, {required int inventoryItemId, required double quantity, double? unitPrice, bool chargeable = true}) async {
    final data = await _client.post(ApiConstants.serviceTicketParts('$id'), data: {
      'inventoryItemId': inventoryItemId,
      'quantity': quantity,
      if (unitPrice != null) 'unitPrice': unitPrice,
      'chargeable': chargeable,
    });
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceTicket> removePart(int id, int partId) async {
    final data = await _client.delete(ApiConstants.serviceTicketPart('$id', '$partId'));
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceTicket> recordPayment(int id, {required double amount, String? paymentMode}) async {
    final data = await _client.post(ApiConstants.serviceTicketPayment('$id'), data: {
      'amount': amount,
      if (paymentMode != null) 'paymentMode': paymentMode,
    });
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceTicket> raiseEstimate(int id, {required double amount, String? notes}) async {
    final data = await _client.post(ApiConstants.serviceTicketEstimate('$id'), data: {'estimateAmount': amount, if (notes != null) 'estimateNotes': notes});
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<ServiceTicket> approveEstimate(int id, {String? respondedBy}) async {
    final data = await _client.post(ApiConstants.serviceTicketEstimateApprove('$id'), data: {if (respondedBy != null) 'respondedBy': respondedBy});
    return ServiceTicket.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createInvoice(int id) async {
    final data = await _client.post(ApiConstants.serviceTicketInvoice('$id'), data: {});
    return data as Map<String, dynamic>;
  }

  // ─── Attachments (photos + signed handover) ───
  Future<List<ServiceAttachment>> getAttachments(int id) async {
    final data = await _client.get(ApiConstants.serviceTicketAttachments('$id'));
    if (data is List) return data.map((e) => ServiceAttachment.fromJson(e as Map<String, dynamic>)).toList();
    return const [];
  }

  Future<ServiceAttachment> uploadAttachment(int id, String filePath, {required String kind, String? note}) async {
    final data = await _client.uploadFile(
      ApiConstants.serviceTicketAttachments('$id'),
      filePath,
      fields: {'kind': kind, if (note != null) 'note': note},
    );
    return ServiceAttachment.fromJson(data as Map<String, dynamic>);
  }

  // ─── Items / warranty ───
  Future<List<ServiceItem>> getItems({String? search, int? customerId}) async {
    final qp = <String, dynamic>{};
    if (search != null && search.isNotEmpty) qp['search'] = search;
    if (customerId != null) qp['customerId'] = customerId;
    final data = await _client.get(ApiConstants.serviceItems, queryParams: qp.isEmpty ? null : qp);
    return _asList(data).map(ServiceItem.fromJson).toList();
  }

  /// Counter warranty check by serial/IMEI. Returns null on 404 (no match).
  Future<ServiceItem?> lookupBySerial(String serial) async {
    try {
      final data = await _client.get(ApiConstants.serviceItemLookup, queryParams: {'serial': serial});
      return ServiceItem.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<PartCatalogItem>> partsCatalog({String? search}) async {
    final data = await _client.get(ApiConstants.servicePartsCatalog, queryParams: search != null && search.isNotEmpty ? {'search': search} : null);
    if (data is List) return data.map((e) => PartCatalogItem.fromJson(e as Map<String, dynamic>)).toList();
    return const [];
  }

  /// AI triage of a reported problem (read-only suggestion). Throws on 503 (not configured).
  Future<ServiceTriage> aiTriage({required String reportedProblem, String? category, String? brand, String? modelName, bool? underWarranty}) async {
    final data = await _client.post(ApiConstants.serviceAiTriage, data: {
      'reportedProblem': reportedProblem,
      if (category != null) 'category': category,
      if (brand != null) 'brand': brand,
      if (modelName != null) 'modelName': modelName,
      if (underWarranty != null) 'underWarranty': underWarranty,
    }, timeout: const Duration(seconds: 60));
    return ServiceTriage.fromJson(data as Map<String, dynamic>);
  }

  /// Assignable technicians (active employees), for the assign picker.
  Future<List<TechnicianRef>> getTechnicians() async {
    final data = await _client.get(ApiConstants.serviceTechnicians);
    if (data is List) return data.map((e) => TechnicianRef.fromJson(e as Map<String, dynamic>)).toList();
    return const [];
  }

  // ─── AMC contracts / visits ───
  Future<List<ServiceContract>> getContracts({String? status}) async {
    final data = await _client.get(ApiConstants.serviceContracts, queryParams: status != null ? {'status': status} : null);
    return _asList(data).map(ServiceContract.fromJson).toList();
  }

  Future<List<ContractVisit>> getDueVisits({int days = 30}) async {
    final data = await _client.get(ApiConstants.serviceDueVisits, queryParams: {'days': days});
    if (data is List) return data.map((e) => ContractVisit.fromJson(e as Map<String, dynamic>)).toList();
    return const [];
  }

  Future<void> markVisit(int contractId, int visitId, {required String status, String? notes, String? completedDate}) async {
    await _client.patch(ApiConstants.serviceContractVisit('$contractId', '$visitId'), data: {
      'status': status,
      if (notes != null) 'notes': notes,
      if (completedDate != null) 'completedDate': completedDate,
    });
  }

  // ─── Calendar (AMC visits / renewals / invoice due) ───
  Future<List<CalendarEvent>> getCalendar({required DateTime from, required DateTime to, String? module}) async {
    final data = await _client.get(ApiConstants.calendar, queryParams: {
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      if (module != null) 'module': module,
    });
    final list = data is Map ? (data['events'] ?? const []) : const [];
    if (list is List) return list.map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>)).toList();
    return const [];
  }

  /// Move a derived calendar event (e.g. an AMC PM visit) to a new date.
  Future<void> rescheduleEvent({required String refType, required dynamic refId, required DateTime startAt}) async {
    await _client.patch(ApiConstants.calendarReschedule, data: {
      'refType': refType,
      'refId': refId,
      'startAt': startAt.toIso8601String(),
    });
  }

  // ─── Reports ───
  Future<Map<String, dynamic>> dashboard({int? technicianId}) async {
    final data = await _client.get(ApiConstants.serviceDashboard, queryParams: technicianId != null ? {'technicianId': technicianId} : null);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> serviceRevenue() async {
    final data = await _client.get(ApiConstants.serviceRevenue);
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> technicianProductivity() async {
    final data = await _client.get(ApiConstants.serviceTechProductivity);
    if (data is List) return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return const [];
  }

  Future<List<Map<String, dynamic>>> partsUsage() async {
    final data = await _client.get(ApiConstants.servicePartsUsage);
    if (data is List) return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return const [];
  }
}
