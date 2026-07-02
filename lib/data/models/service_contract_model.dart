// AMC / service contract + its PM visits. Mirrors GET /api/service-contracts (decorate()),
// /:id, and /due-visits.
import 'service_ticket_model.dart' show ServiceParty;

double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class ServiceContract {
  final int id;
  final String contractNumber;
  final String contractType; // AMC | WARRANTY_EXT | SLA
  final String status; // ACTIVE | EXPIRED | CANCELLED | RENEWED
  final DateTime? startDate;
  final DateTime? endDate;
  final String billingFrequency;
  final double contractValue;
  final int visitsIncluded;
  final int visitsUsed;
  final int visitsRemaining;
  final int? daysToExpiry;
  final bool isExpired;
  final bool isExpiringSoon;
  final ServiceParty? customer;
  final List<ContractVisit> visits;

  const ServiceContract({
    required this.id,
    required this.contractNumber,
    this.contractType = 'AMC',
    this.status = 'ACTIVE',
    this.startDate,
    this.endDate,
    this.billingFrequency = 'ANNUAL',
    this.contractValue = 0,
    this.visitsIncluded = 0,
    this.visitsUsed = 0,
    this.visitsRemaining = 0,
    this.daysToExpiry,
    this.isExpired = false,
    this.isExpiringSoon = false,
    this.customer,
    this.visits = const [],
  });

  factory ServiceContract.fromJson(Map<String, dynamic> j) => ServiceContract(
        id: j['id'] as int,
        contractNumber: (j['contractNumber'] ?? '').toString(),
        contractType: (j['contractType'] ?? 'AMC').toString(),
        status: (j['status'] ?? 'ACTIVE').toString(),
        startDate: j['startDate'] != null ? DateTime.tryParse(j['startDate'].toString()) : null,
        endDate: j['endDate'] != null ? DateTime.tryParse(j['endDate'].toString()) : null,
        billingFrequency: (j['billingFrequency'] ?? 'ANNUAL').toString(),
        contractValue: _toD(j['contractValue']),
        visitsIncluded: (j['visitsIncluded'] as int?) ?? 0,
        visitsUsed: (j['visitsUsed'] as int?) ?? 0,
        visitsRemaining: (j['visitsRemaining'] as int?) ?? 0,
        daysToExpiry: j['daysToExpiry'] as int?,
        isExpired: j['isExpired'] == true,
        isExpiringSoon: j['isExpiringSoon'] == true,
        customer: j['customer'] != null ? ServiceParty.fromJson(j['customer'] as Map<String, dynamic>) : null,
        visits: (j['visits'] as List<dynamic>?)?.map((e) => ContractVisit.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      );
}

class ContractVisit {
  final int id;
  final int? contractId;
  final int sequence;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final String status; // SCHEDULED | DONE | MISSED | CANCELLED
  final int? ticketId;
  final String? notes;
  final bool overdue;
  // Present on the /due-visits feed (denormalised contract + customer).
  final String? contractNumber;
  final ServiceParty? customer;

  const ContractVisit({
    required this.id,
    this.contractId,
    this.sequence = 0,
    this.scheduledDate,
    this.completedDate,
    this.status = 'SCHEDULED',
    this.ticketId,
    this.notes,
    this.overdue = false,
    this.contractNumber,
    this.customer,
  });

  factory ContractVisit.fromJson(Map<String, dynamic> j) {
    final c = j['contract'] as Map<String, dynamic>?;
    return ContractVisit(
      id: j['id'] as int,
      contractId: (j['contractId'] as int?) ?? c?['id'] as int?,
      sequence: (j['sequence'] as int?) ?? 0,
      scheduledDate: j['scheduledDate'] != null ? DateTime.tryParse(j['scheduledDate'].toString()) : null,
      completedDate: j['completedDate'] != null ? DateTime.tryParse(j['completedDate'].toString()) : null,
      status: (j['status'] ?? 'SCHEDULED').toString(),
      ticketId: j['ticketId'] as int?,
      notes: j['notes']?.toString(),
      overdue: j['overdue'] == true,
      contractNumber: c?['contractNumber']?.toString(),
      customer: c?['customer'] != null ? ServiceParty.fromJson(c!['customer'] as Map<String, dynamic>) : null,
    );
  }

  bool get isDone => status == 'DONE';
}
