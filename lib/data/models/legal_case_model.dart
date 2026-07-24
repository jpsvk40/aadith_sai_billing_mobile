// A legal / arbitration case and its proceedings — `/api/correspondence/cases`.
// Mirrors the web `LegalCases` tab (CorrespondencePage.jsx) + `LegalCaseDetail.jsx`.
// All `fromJson` parsing is tolerant: numbers may arrive as strings (Prisma
// Decimal), dates as ISO strings, and any field may be absent.

/// Fixed enum lists (kept in sync with web `utils/erp.js`).
const List<String> kCaseTypes = ['ARBITRATION', 'CIVIL', 'CONSUMER', 'WRIT', 'APPEAL', 'OTHER'];
const List<String> kCaseStatuses = ['NOTICE', 'FILED', 'IN_PROGRESS', 'AWARD', 'APPEAL', 'SETTLED', 'CLOSED'];
const List<String> kCaseRoles = ['CLAIMANT', 'RESPONDENT'];
const List<String> kProceedingStages = ['HEARING', 'EVIDENCE', 'ARGUMENTS', 'ORDER', 'AWARD'];

/// One recorded proceeding on a case (hearing / evidence / order …).
class LegalProceeding {
  final int id;
  final DateTime? proceedingDate;
  final String stage; // HEARING | EVIDENCE | ARGUMENTS | ORDER | AWARD
  final String? summary;
  final DateTime? nextDate;
  final String? documentUrl;

  const LegalProceeding({
    required this.id,
    this.proceedingDate,
    this.stage = 'HEARING',
    this.summary,
    this.nextDate,
    this.documentUrl,
  });

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  factory LegalProceeding.fromJson(Map<String, dynamic> j) => LegalProceeding(
        id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
        proceedingDate: _dt(j['proceedingDate']),
        stage: (j['stage'] ?? 'HEARING').toString(),
        summary: j['summary']?.toString(),
        nextDate: _dt(j['nextDate']),
        documentUrl: j['documentUrl']?.toString(),
      );
}

class LegalCase {
  final int id;
  final String caseCode;
  final String caseType; // ARBITRATION | CIVIL | CONSUMER | WRIT | APPEAL | OTHER
  final String title;
  final String? opposingParty;
  final String ourRole; // CLAIMANT | RESPONDENT
  final String? forum;
  final String? caseNumber;
  final DateTime? filingDate;
  final double? claimAmount;
  final double? counterClaimAmount;
  final String? advocateName;
  final String? advocateContact;
  final String status; // NOTICE | FILED | IN_PROGRESS | AWARD | APPEAL | SETTLED | CLOSED
  final DateTime? nextHearingDate;
  final String? outcome;
  final double? awardAmount;
  final String? notes;
  final String? fileUrl;
  final List<LegalProceeding> proceedings;

  const LegalCase({
    required this.id,
    required this.caseCode,
    this.caseType = 'ARBITRATION',
    required this.title,
    this.opposingParty,
    this.ourRole = 'CLAIMANT',
    this.forum,
    this.caseNumber,
    this.filingDate,
    this.claimAmount,
    this.counterClaimAmount,
    this.advocateName,
    this.advocateContact,
    this.status = 'NOTICE',
    this.nextHearingDate,
    this.outcome,
    this.awardAmount,
    this.notes,
    this.fileUrl,
    this.proceedings = const [],
  });

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
  static double? _num(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  factory LegalCase.fromJson(Map<String, dynamic> j) => LegalCase(
        id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
        caseCode: (j['caseCode'] ?? '').toString(),
        caseType: (j['caseType'] ?? 'ARBITRATION').toString(),
        title: (j['title'] ?? '').toString(),
        opposingParty: j['opposingParty']?.toString(),
        ourRole: (j['ourRole'] ?? 'CLAIMANT').toString(),
        forum: j['forum']?.toString(),
        caseNumber: j['caseNumber']?.toString(),
        filingDate: _dt(j['filingDate']),
        claimAmount: _num(j['claimAmount']),
        counterClaimAmount: _num(j['counterClaimAmount']),
        advocateName: j['advocateName']?.toString(),
        advocateContact: j['advocateContact']?.toString(),
        status: (j['status'] ?? 'NOTICE').toString(),
        nextHearingDate: _dt(j['nextHearingDate']),
        outcome: j['outcome']?.toString(),
        awardAmount: _num(j['awardAmount']),
        notes: j['notes']?.toString(),
        fileUrl: j['fileUrl']?.toString(),
        proceedings: (j['proceedings'] as List?)
                ?.map((e) => LegalProceeding.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );

  bool get isClosed => status == 'CLOSED' || status == 'SETTLED';

  /// Whole days from today to the next hearing (negative = past, null = none).
  int? get daysToHearing {
    final h = nextHearingDate;
    if (h == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hd = DateTime(h.year, h.month, h.day);
    return hd.difference(today).inDays;
  }

  /// A hearing scheduled within the next 30 days (matches the web "Upcoming Hearings" KPI window).
  bool get hearingUpcoming {
    final d = daysToHearing;
    return d != null && d >= 0 && d <= 30;
  }
}
