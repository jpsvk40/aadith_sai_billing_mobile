import 'payment_model.dart';

/// A unified item in the owner action queue — either a pending payment awaiting
/// approval (`requirePaymentApproval` flow) or a request from the `/api/approvals`
/// engine (PO/voucher multi-level workflow). The mobile Approvals inbox merges both.
class ApprovalItem {
  final String kind; // 'payment' | 'request'
  final String id;
  final String title;
  final String? subtitle;
  final String docLabel;
  final double amount;
  final String? by;

  const ApprovalItem({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
    required this.docLabel,
    this.amount = 0,
    this.by,
  });

  bool get isPayment => kind == 'payment';

  factory ApprovalItem.fromPayment(Payment p) => ApprovalItem(
        kind: 'payment',
        id: p.id,
        title: p.customerName ?? 'Payment',
        subtitle: p.invoiceNumber,
        docLabel: 'PAYMENT',
        amount: p.amount,
        by: p.paymentMode,
      );

  factory ApprovalItem.fromRequest(ApprovalRequest r) => ApprovalItem(
        kind: 'request',
        id: r.id.toString(),
        title: r.title,
        subtitle: r.totalLevels > 0 ? '${r.docType} · Level ${r.currentLevel}/${r.totalLevels}' : r.docType,
        docLabel: r.docType,
        amount: r.amount,
        by: r.requestedByName,
      );
}

/// An approval request from the cross-cutting approvals engine (`/api/approvals`).
/// docType is the document kind awaiting sign-off (PO, VOUCHER, ORDER, PAYMENT, …).
class ApprovalRequest {
  final int id;
  final String docType;
  final int? docId;
  final String title;
  final double amount;
  final String? summary;
  final String status; // PENDING | HOLD | APPROVED | REJECTED
  final int currentLevel;
  final int totalLevels;
  final String? currentLevelRole;
  final String? requestedByName;
  final DateTime? createdAt;

  const ApprovalRequest({
    required this.id,
    required this.docType,
    this.docId,
    required this.title,
    required this.amount,
    this.summary,
    required this.status,
    this.currentLevel = 0,
    this.totalLevels = 0,
    this.currentLevelRole,
    this.requestedByName,
    this.createdAt,
  });

  bool get isOpen => status == 'PENDING' || status == 'HOLD';

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
  static int _i(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

  factory ApprovalRequest.fromJson(Map<String, dynamic> j) => ApprovalRequest(
        id: _i(j['id']),
        docType: (j['docType'] ?? '').toString(),
        docId: j['docId'] == null ? null : _i(j['docId']),
        title: (j['title'] ?? '${j['docType'] ?? 'Request'} #${j['docId'] ?? ''}').toString().trim(),
        amount: _d(j['amount']),
        summary: j['summary']?.toString(),
        status: (j['status'] ?? 'PENDING').toString(),
        currentLevel: _i(j['currentLevel']),
        totalLevels: _i(j['totalLevels']),
        currentLevelRole: j['currentLevelRole']?.toString(),
        requestedByName: j['requestedByName']?.toString(),
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'].toString()) : null,
      );
}

/// Counters from `/api/approvals/summary`.
class ApprovalSummary {
  final int pending;
  final int hold;
  final int inboxForMe;
  final int mine;

  const ApprovalSummary({this.pending = 0, this.hold = 0, this.inboxForMe = 0, this.mine = 0});

  factory ApprovalSummary.fromJson(Map<String, dynamic> j) => ApprovalSummary(
        pending: int.tryParse(j['pending']?.toString() ?? '0') ?? 0,
        hold: int.tryParse(j['hold']?.toString() ?? '0') ?? 0,
        inboxForMe: int.tryParse(j['inboxForMe']?.toString() ?? '0') ?? 0,
        mine: int.tryParse(j['mine']?.toString() ?? '0') ?? 0,
      );
}
