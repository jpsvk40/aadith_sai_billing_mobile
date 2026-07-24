import '../network/api_client.dart';
import '../models/machine_detail_models.dart';
import '../../core/constants/api_constants.dart';

/// Machinery field persona — machine detail, daily logbook entries, breakdown
/// reporting with AI diagnosis, transfers (receive) and manager job approval.
/// The backend enforces the operator boundary (assigned machines, no costs).
class MachineryRepository {
  final ApiClient _client;
  MachineryRepository(this._client);

  Future<MachineDetail> getMachine(int id) async {
    final data = await _client.get(ApiConstants.machineDetail('$id'));
    return MachineDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<MachineryMineSummary> getSummary() async {
    final data = await _client.get(ApiConstants.machinerySummary);
    return MachineryMineSummary.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<MachineLog> createLog(
    int machineId, {
    DateTime? logDate,
    String? shift,
    required double openingMeter,
    required double closingMeter,
    double? idleHours,
    double? fuelQty,
    double? fuelRate,
    String? remarks,
  }) async {
    final data = await _client.post(ApiConstants.machineLogs('$machineId'), data: {
      if (logDate != null) 'logDate': logDate.toIso8601String(),
      if (shift != null) 'shift': shift,
      'openingMeter': openingMeter,
      'closingMeter': closingMeter,
      if (idleHours != null) 'idleHours': idleHours,
      if (fuelQty != null) 'fuelQty': fuelQty,
      if (fuelRate != null) 'fuelRate': fuelRate,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
    return MachineLog.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<MachineJob> reportBreakdown(int machineId, {required String description}) async {
    final data = await _client.post(ApiConstants.machineJobs('$machineId'), data: {
      'description': description,
      'type': 'BREAKDOWN',
    });
    return MachineJob.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<MachineDiagnosis> aiDiagnose({int? machineId, required String symptom}) async {
    final data = await _client.post(ApiConstants.machineryAiDiagnose, data: {
      if (machineId != null) 'machineId': machineId,
      'symptom': symptom,
    }, timeout: const Duration(seconds: 45));
    return MachineDiagnosis.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Fleet-wide logbook (GET /machinery/logs). Optional server filters mirror the web
  /// register: [machineId] (single machine), [from]/[to] as `YYYY-MM-DD` date bounds.
  /// The operator role is auto-scoped by the backend to its assigned machines.
  Future<List<MachineLog>> getLogs({int? machineId, String? from, String? to}) async {
    final data = await _client.get('${ApiConstants.machinery}/logs', queryParams: {
      if (machineId != null) 'machineId': machineId,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    });
    final list = data is List ? data : const [];
    return list.map((e) => MachineLog.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<List<MachineTransferLite>> getTransfers() async {
    final data = await _client.get(ApiConstants.machineryTransfers);
    final list = data is List ? data : const [];
    return list.map((e) => MachineTransferLite.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// Raise a machine transfer (POST /machinery/transfers). Codes (TRF-…) are server
  /// generated; empty optional fields are dropped so the API applies its own defaults.
  Future<MachineTransferLite> createTransfer({
    required int machineId,
    DateTime? transferDate,
    String? fromLocation,
    int? toProjectId,
    String? toLocation,
    double? transportCost,
    String? gatePassNo,
    String? vehicleUsed,
    String? notes,
  }) async {
    final data = await _client.post(ApiConstants.machineryTransfers, data: {
      'machineId': machineId,
      if (transferDate != null) 'transferDate': transferDate.toIso8601String(),
      if (fromLocation != null && fromLocation.isNotEmpty) 'fromLocation': fromLocation,
      if (toProjectId != null) 'toProjectId': toProjectId,
      if (toLocation != null && toLocation.isNotEmpty) 'toLocation': toLocation,
      if (transportCost != null) 'transportCost': transportCost,
      if (gatePassNo != null && gatePassNo.isNotEmpty) 'gatePassNo': gatePassNo,
      if (vehicleUsed != null && vehicleUsed.isNotEmpty) 'vehicleUsed': vehicleUsed,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return MachineTransferLite.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> receiveTransfer(int id) async {
    await _client.patch(ApiConstants.machineryTransferReceive('$id'));
  }

  Future<MachineJob> approveJob(int jobId) async {
    final data = await _client.post(ApiConstants.machineJobApprove('$jobId'));
    return MachineJob.fromJson((data as Map).cast<String, dynamic>());
  }
}
