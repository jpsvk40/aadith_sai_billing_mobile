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

  Future<List<MachineTransferLite>> getTransfers() async {
    final data = await _client.get(ApiConstants.machineryTransfers);
    final list = data is List ? data : const [];
    return list.map((e) => MachineTransferLite.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> receiveTransfer(int id) async {
    await _client.patch(ApiConstants.machineryTransferReceive('$id'));
  }

  Future<MachineJob> approveJob(int jobId) async {
    final data = await _client.post(ApiConstants.machineJobApprove('$jobId'));
    return MachineJob.fromJson((data as Map).cast<String, dynamic>());
  }
}
