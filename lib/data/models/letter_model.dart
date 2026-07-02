/// A correspondence letter (inward/outward) — `/api/correspondence/letters`.
class Letter {
  final int id;
  final String letterCode;
  final String direction; // INWARD | OUTWARD
  final String? refNumber;
  final String subject;
  final String? body;
  final String partyType;
  final String? partyName;
  final String? category;
  final String priority; // LOW | NORMAL | HIGH | URGENT
  final DateTime? letterDate;
  final DateTime? receivedOrSentDate;
  final DateTime? dueDate;
  final String status; // DRAFT | PENDING_APPROVAL | APPROVED | SENT | RECEIVED | CLOSED
  final String? remarks;
  final String? fileUrl;
  final int? assignedTo;
  final List<Letter> replies;

  const Letter({
    required this.id,
    required this.letterCode,
    required this.direction,
    this.refNumber,
    required this.subject,
    this.body,
    this.partyType = 'OTHER',
    this.partyName,
    this.category,
    this.priority = 'NORMAL',
    this.letterDate,
    this.receivedOrSentDate,
    this.dueDate,
    this.status = 'DRAFT',
    this.remarks,
    this.fileUrl,
    this.assignedTo,
    this.replies = const [],
  });

  static DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

  factory Letter.fromJson(Map<String, dynamic> j) => Letter(
        id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
        letterCode: (j['letterCode'] ?? '').toString(),
        direction: (j['direction'] ?? 'INWARD').toString(),
        refNumber: j['refNumber']?.toString(),
        subject: (j['subject'] ?? '').toString(),
        body: j['body']?.toString(),
        partyType: (j['partyType'] ?? 'OTHER').toString(),
        partyName: j['partyName']?.toString(),
        category: j['category']?.toString(),
        priority: (j['priority'] ?? 'NORMAL').toString(),
        letterDate: _dt(j['letterDate']),
        receivedOrSentDate: _dt(j['receivedOrSentDate']),
        dueDate: _dt(j['dueDate']),
        status: (j['status'] ?? 'DRAFT').toString(),
        remarks: j['remarks']?.toString(),
        fileUrl: j['fileUrl']?.toString(),
        assignedTo: j['assignedTo'] == null ? null : int.tryParse(j['assignedTo'].toString()),
        replies: (j['replies'] as List?)?.map((e) => Letter.fromJson((e as Map).cast<String, dynamic>())).toList() ?? const [],
      );

  bool get isOutward => direction == 'OUTWARD';
  bool get isClosed => status == 'CLOSED';
  bool get isPendingApproval => status == 'PENDING_APPROVAL';
  bool get canSend => isOutward && (status == 'APPROVED' || status == 'DRAFT');

  /// Awaiting reply and past its due date (mirrors the backend "pending replies" count).
  bool get isOverdue =>
      dueDate != null && status != 'CLOSED' && status != 'SENT' && dueDate!.isBefore(DateTime.now());

  int? get daysOverdue {
    if (dueDate == null || status == 'CLOSED' || status == 'SENT') return null;
    return DateTime.now().difference(dueDate!).inDays;
  }
}
