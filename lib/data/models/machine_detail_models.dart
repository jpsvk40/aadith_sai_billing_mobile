// Machinery field-persona models: machine detail (docs / schedules / jobs / logs / transfers)
// and the AI field diagnosis. Cost fields are nullable — the backend strips them for the
// operator role, managers get them.

double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
double? _dn(dynamic v) => v == null ? null : double.tryParse(v.toString());
int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class MachineDetail {
  final int id;
  final String machineCode;
  final String name;
  final String category;
  final String? make;
  final String? model;
  final String status;
  final String meterType; // HOURS | KM | NONE
  final double currentMeter;
  final String? currentLocation;
  final String? projectName;
  final String? operatorName;
  final String? capacity;
  final String? registrationNo;
  final String? photoResolvedUrl;
  final List<MachineDoc> documents;
  final List<MachineSchedule> schedules;
  final List<MachineJob> jobs;
  final List<MachineLog> logs;

  const MachineDetail({
    required this.id,
    required this.machineCode,
    required this.name,
    this.category = '',
    this.make,
    this.model,
    this.status = '',
    this.meterType = 'HOURS',
    this.currentMeter = 0,
    this.currentLocation,
    this.projectName,
    this.operatorName,
    this.capacity,
    this.registrationNo,
    this.photoResolvedUrl,
    this.documents = const [],
    this.schedules = const [],
    this.jobs = const [],
    this.logs = const [],
  });

  String get meterUnit => meterType == 'KM' ? 'km' : 'hrs';

  factory MachineDetail.fromJson(Map<String, dynamic> j) => MachineDetail(
        id: _i(j['id']),
        machineCode: (j['machineCode'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        make: j['make']?.toString(),
        model: j['model']?.toString(),
        status: (j['status'] ?? '').toString(),
        meterType: (j['meterType'] ?? 'HOURS').toString(),
        currentMeter: _d(j['currentMeter']),
        currentLocation: j['currentLocation']?.toString(),
        projectName: j['projectName']?.toString(),
        operatorName: j['operatorName']?.toString(),
        capacity: j['capacity']?.toString(),
        registrationNo: j['registrationNo']?.toString(),
        photoResolvedUrl: j['photoResolvedUrl']?.toString(),
        documents: (j['documents'] as List? ?? const []).map((e) => MachineDoc.fromJson((e as Map).cast<String, dynamic>())).toList(),
        schedules: (j['schedules'] as List? ?? const []).map((e) => MachineSchedule.fromJson((e as Map).cast<String, dynamic>())).toList(),
        jobs: (j['jobs'] as List? ?? const []).map((e) => MachineJob.fromJson((e as Map).cast<String, dynamic>())).toList(),
        logs: (j['logs'] as List? ?? const []).map((e) => MachineLog.fromJson((e as Map).cast<String, dynamic>())).toList(),
      );
}

class MachineDoc {
  final int id;
  final String docType;
  final String? docNumber;
  final DateTime? expiryDate;
  const MachineDoc({required this.id, required this.docType, this.docNumber, this.expiryDate});

  int? get daysToExpiry => expiryDate?.difference(DateTime.now()).inDays;

  factory MachineDoc.fromJson(Map<String, dynamic> j) => MachineDoc(
        id: _i(j['id']),
        docType: (j['docType'] ?? 'OTHER').toString(),
        docNumber: j['docNumber']?.toString(),
        expiryDate: _dt(j['expiryDate']),
      );
}

class MachineSchedule {
  final int id;
  final String title;
  final String basis; // DATE | METER
  final DateTime? nextDueDate;
  final double? nextDueMeter;
  final String? checklist;
  const MachineSchedule({required this.id, required this.title, this.basis = 'DATE', this.nextDueDate, this.nextDueMeter, this.checklist});

  bool isDue(double currentMeter) {
    if (basis == 'METER') return nextDueMeter != null && currentMeter >= nextDueMeter!;
    return nextDueDate != null && !nextDueDate!.isAfter(DateTime.now());
  }

  factory MachineSchedule.fromJson(Map<String, dynamic> j) => MachineSchedule(
        id: _i(j['id']),
        title: (j['title'] ?? '').toString(),
        basis: (j['basis'] ?? 'DATE').toString(),
        nextDueDate: _dt(j['nextDueDate']),
        nextDueMeter: _dn(j['nextDueMeter']),
        checklist: j['checklist']?.toString(),
      );
}

class MachineJob {
  final int id;
  final String jobCode;
  final String type; // PREVENTIVE | BREAKDOWN | INSPECTION
  final String status; // PENDING | IN_PROGRESS | COMPLETED | APPROVED
  final String description;
  final DateTime? reportedDate;
  final double? totalCost; // null for the operator role (backend strips it)
  const MachineJob({required this.id, required this.jobCode, this.type = 'BREAKDOWN', this.status = 'PENDING', this.description = '', this.reportedDate, this.totalCost});

  factory MachineJob.fromJson(Map<String, dynamic> j) => MachineJob(
        id: _i(j['id']),
        jobCode: (j['jobCode'] ?? '').toString(),
        type: (j['type'] ?? 'BREAKDOWN').toString(),
        status: (j['status'] ?? 'PENDING').toString(),
        description: (j['description'] ?? '').toString(),
        reportedDate: _dt(j['reportedDate']),
        totalCost: _dn(j['totalCost']),
      );
}

class MachineLog {
  final int id;
  final DateTime? logDate;
  final String? shift;
  final String? operatorName;
  final double openingMeter;
  final double closingMeter;
  final double? workingHours;
  final double? idleHours;
  final double? distanceKm;
  final double? fuelQty;
  final double? fuelCost;
  final String? remarks;
  // Fleet-wide logbook (GET /machinery/logs) embellishes each row with its machine
  // + deployment. Null on the per-machine detail feed (that scope already knows the machine).
  final String? machineName;
  final String? machineCode;
  final String? projectName;
  final String? location;
  const MachineLog({
    required this.id,
    this.logDate,
    this.shift,
    this.operatorName,
    this.openingMeter = 0,
    this.closingMeter = 0,
    this.workingHours,
    this.idleHours,
    this.distanceKm,
    this.fuelQty,
    this.fuelCost,
    this.remarks,
    this.machineName,
    this.machineCode,
    this.projectName,
    this.location,
  });

  factory MachineLog.fromJson(Map<String, dynamic> j) => MachineLog(
        id: _i(j['id']),
        logDate: _dt(j['logDate']),
        shift: j['shift']?.toString(),
        operatorName: j['operatorName']?.toString(),
        openingMeter: _d(j['openingMeter']),
        closingMeter: _d(j['closingMeter']),
        workingHours: _dn(j['workingHours']),
        idleHours: _dn(j['idleHours']),
        distanceKm: _dn(j['distanceKm']),
        fuelQty: _dn(j['fuelQty']),
        fuelCost: _dn(j['fuelCost']),
        remarks: j['remarks']?.toString(),
        machineName: (j['machine'] is Map) ? j['machine']['name']?.toString() : null,
        machineCode: (j['machine'] is Map) ? j['machine']['machineCode']?.toString() : null,
        projectName: j['projectName']?.toString(),
        location: j['location']?.toString(),
      );
}

class MachineTransferLite {
  final int id;
  final String transferCode;
  final String status; // PENDING | IN_TRANSIT | RECEIVED
  final DateTime? transferDate;
  final String? machineName;
  final String? machineCode;
  final String? fromName;
  final String? toName;
  final double? transportCost;
  final String? gatePassNo;
  final String? vehicleUsed;
  const MachineTransferLite({
    required this.id,
    required this.transferCode,
    this.status = 'PENDING',
    this.transferDate,
    this.machineName,
    this.machineCode,
    this.fromName,
    this.toName,
    this.transportCost,
    this.gatePassNo,
    this.vehicleUsed,
  });

  factory MachineTransferLite.fromJson(Map<String, dynamic> j) => MachineTransferLite(
        id: _i(j['id']),
        transferCode: (j['transferCode'] ?? '').toString(),
        status: (j['status'] ?? 'PENDING').toString(),
        transferDate: _dt(j['transferDate']),
        machineName: (j['machine'] is Map) ? j['machine']['name']?.toString() : null,
        machineCode: (j['machine'] is Map) ? j['machine']['machineCode']?.toString() : null,
        fromName: j['fromName']?.toString(),
        toName: j['toName']?.toString(),
        transportCost: _dn(j['transportCost']),
        gatePassNo: j['gatePassNo']?.toString(),
        vehicleUsed: j['vehicleUsed']?.toString(),
      );
}

/// AI field diagnosis (POST /machinery/ai-diagnose) — mirrors the service triage shape.
class MachineDiagnosis {
  final String severity; // STOP_OPERATION | RUN_WITH_CAUTION | MONITOR
  final String faultCategory;
  final List<String> probableCauses;
  final List<String> suggestedParts;
  final List<String> safetyChecklist;
  final int estimatedDowntimeHours;
  final String cleanedSymptom;

  const MachineDiagnosis({
    this.severity = 'RUN_WITH_CAUTION',
    this.faultCategory = '',
    this.probableCauses = const [],
    this.suggestedParts = const [],
    this.safetyChecklist = const [],
    this.estimatedDowntimeHours = 0,
    this.cleanedSymptom = '',
  });

  factory MachineDiagnosis.fromJson(Map<String, dynamic> j) => MachineDiagnosis(
        severity: (j['severity'] ?? 'RUN_WITH_CAUTION').toString(),
        faultCategory: (j['faultCategory'] ?? '').toString(),
        probableCauses: (j['probableCauses'] as List? ?? const []).map((e) => e.toString()).toList(),
        suggestedParts: (j['suggestedParts'] as List? ?? const []).map((e) => e.toString()).toList(),
        safetyChecklist: (j['safetyChecklist'] as List? ?? const []).map((e) => e.toString()).toList(),
        estimatedDowntimeHours: _i(j['estimatedDowntimeHours']),
        cleanedSymptom: (j['cleanedSymptom'] ?? '').toString(),
      );
}

/// Operator "my machines" dashboard summary (GET /machinery/dashboard-summary, mine:true shape).
class MachineryMineSummary {
  final int total;
  final int underMaintenance;
  final int docsExpiring;
  final int jobsOpen;
  const MachineryMineSummary({this.total = 0, this.underMaintenance = 0, this.docsExpiring = 0, this.jobsOpen = 0});

  factory MachineryMineSummary.fromJson(Map<String, dynamic> j) => MachineryMineSummary(
        total: _i(j['total']),
        underMaintenance: _i((j['statusCounts'] is Map) ? j['statusCounts']['UNDER_MAINTENANCE'] : 0),
        docsExpiring: _i(j['docsExpiring']),
        jobsOpen: _i(j['jobsOpen']),
      );
}
