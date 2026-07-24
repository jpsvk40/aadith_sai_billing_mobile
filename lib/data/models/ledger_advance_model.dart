/// A vendor/customer LEDGER advance (web `/advances`, table `LedgerAdvance`).
///
/// DISTINCT from the petty-cash "Advance Floats" (`/api/advance-floats`). Each
/// row is an advance PAID to a vendor or RECEIVED from a customer that posts to
/// the GL and can be adjusted (part or whole) against a bill/invoice.
class LedgerAdvance {
  final int id;
  final String party; // 'VENDOR' | 'CUSTOMER'
  final int? partyId;
  final String? partyName;
  final String? advanceDate; // ISO string from the API
  final double amount;
  final String? paymentMode;
  final double adjustedAmount;
  final String status; // 'OPEN' | 'ADJUSTED'
  final String? notes;
  final double balance;

  const LedgerAdvance({
    required this.id,
    required this.party,
    this.partyId,
    this.partyName,
    this.advanceDate,
    required this.amount,
    this.paymentMode,
    required this.adjustedAmount,
    required this.status,
    this.notes,
    required this.balance,
  });

  factory LedgerAdvance.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    final amount = d(j['amount']);
    final adjusted = d(j['adjustedAmount']);
    return LedgerAdvance(
      id: (j['id'] as num?)?.toInt() ?? 0,
      party: (j['party'] ?? 'VENDOR').toString(),
      partyId: (j['partyId'] as num?)?.toInt(),
      partyName: j['partyName']?.toString(),
      advanceDate: j['advanceDate']?.toString(),
      amount: amount,
      paymentMode: j['paymentMode']?.toString(),
      adjustedAmount: adjusted,
      status: (j['status'] ?? 'OPEN').toString(),
      notes: j['notes']?.toString(),
      // API already returns balance = amount - adjustedAmount; fall back locally.
      balance: j.containsKey('balance') ? d(j['balance']) : (amount - adjusted),
    );
  }

  bool get isOpen => status == 'OPEN';

  String get displayName =>
      (partyName != null && partyName!.isNotEmpty) ? partyName! : '#${partyId ?? ''}';
}
