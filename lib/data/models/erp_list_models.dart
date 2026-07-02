// Read-only list rows for the ERP module tabs (Projects / Machinery / Tenders).
// These mirror the web list endpoints; mobile shows them view-only.

double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class Project {
  final int id;
  final String projectCode;
  final String projectName;
  final String status;
  final double contractValue;
  final String? city;
  final String? customerName;
  final String? workOrderNo;

  const Project({
    required this.id,
    required this.projectCode,
    required this.projectName,
    this.status = '',
    this.contractValue = 0,
    this.city,
    this.customerName,
    this.workOrderNo,
  });

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: _i(j['id']),
        projectCode: (j['projectCode'] ?? '').toString(),
        projectName: (j['projectName'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        contractValue: _d(j['contractValue']),
        city: j['city']?.toString(),
        customerName: (j['customer'] is Map) ? (j['customer']['customerName'] ?? j['customer']['name'])?.toString() : null,
        workOrderNo: j['workOrderNo']?.toString(),
      );
}

class Machine {
  final int id;
  final String machineCode;
  final String name;
  final String category;
  final String? make;
  final String? model;
  final String status;
  final String? currentLocation;
  final String? projectName;
  final int docsExpiring;
  final String? ownership;

  const Machine({
    required this.id,
    required this.machineCode,
    required this.name,
    this.category = '',
    this.make,
    this.model,
    this.status = '',
    this.currentLocation,
    this.projectName,
    this.docsExpiring = 0,
    this.ownership,
  });

  factory Machine.fromJson(Map<String, dynamic> j) => Machine(
        id: _i(j['id']),
        machineCode: (j['machineCode'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        make: j['make']?.toString(),
        model: j['model']?.toString(),
        status: (j['status'] ?? '').toString(),
        currentLocation: j['currentLocation']?.toString(),
        projectName: j['projectName']?.toString(),
        docsExpiring: _i(j['docsExpiring']),
        ownership: j['ownership']?.toString(),
      );
}

class Tender {
  final int id;
  final String tenderCode;
  final String title;
  final String? authority;
  final String? tenderType;
  final double estimatedValue;
  final double emdAmount;
  final DateTime? submissionDeadline;
  final String status;
  final String? resultStatus;
  final String? projectName;

  const Tender({
    required this.id,
    required this.tenderCode,
    required this.title,
    this.authority,
    this.tenderType,
    this.estimatedValue = 0,
    this.emdAmount = 0,
    this.submissionDeadline,
    this.status = '',
    this.resultStatus,
    this.projectName,
  });

  factory Tender.fromJson(Map<String, dynamic> j) => Tender(
        id: _i(j['id']),
        tenderCode: (j['tenderCode'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        authority: j['authority']?.toString(),
        tenderType: j['tenderType']?.toString(),
        estimatedValue: _d(j['estimatedValue']),
        emdAmount: _d(j['emdAmount']),
        submissionDeadline: _dt(j['submissionDeadline']),
        status: (j['status'] ?? '').toString(),
        resultStatus: j['resultStatus']?.toString(),
        projectName: j['projectName']?.toString(),
      );
}
