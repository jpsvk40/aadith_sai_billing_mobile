double _toD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

/// A row in the merged vendor-payments list (single-bill `VendorPayment` OR bulk FIFO payment).
class VendorPaymentRow {
  final String id; // int for SINGLE; "bulk-<n>" for BULK
  final String kind; // 'SINGLE' | 'BULK'
  final String? paymentDate;
  final double amount;
  final String? paymentMode;
  final String? chequeStatus; // SINGLE cheque only
  final String? referenceNo;
  final String? remarks;
  final String? emailStatus; // SINGLE only
  final String vendorName;
  final String? purchaseNumber; // SINGLE
  final String? invoiceNumber; // SINGLE
  final double excessAmount; // BULK leftover → credit
  final List<String> allocationLabels; // BULK: purchase/invoice numbers

  const VendorPaymentRow({
    required this.id,
    required this.kind,
    required this.vendorName,
    this.paymentDate,
    this.amount = 0,
    this.paymentMode,
    this.chequeStatus,
    this.referenceNo,
    this.remarks,
    this.emailStatus,
    this.purchaseNumber,
    this.invoiceNumber,
    this.excessAmount = 0,
    this.allocationLabels = const [],
  });

  bool get isBulk => kind == 'BULK';

  factory VendorPaymentRow.fromJson(Map<String, dynamic> j) {
    final v = j['vendor'];
    final vp = j['vendorPurchase'];
    final allocs = (j['allocations'] as List<dynamic>?) ?? const [];
    return VendorPaymentRow(
      id: j['id'].toString(),
      kind: (j['kind'] ?? 'SINGLE').toString(),
      vendorName: v is Map ? (v['vendorName']?.toString() ?? '—') : '—',
      paymentDate: j['paymentDate']?.toString(),
      amount: _toD(j['amount']),
      paymentMode: j['paymentMode']?.toString(),
      chequeStatus: j['chequeStatus']?.toString(),
      referenceNo: j['referenceNo']?.toString(),
      remarks: j['remarks']?.toString(),
      emailStatus: j['emailStatus']?.toString(),
      purchaseNumber: vp is Map ? vp['purchaseNumber']?.toString() : null,
      invoiceNumber: vp is Map ? vp['invoiceNumber']?.toString() : null,
      excessAmount: _toD(j['excessAmount']),
      allocationLabels: allocs
          .whereType<Map>()
          .map((a) => (a['purchaseNumber'] ?? a['invoiceNumber'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}

/// One outstanding vendor bill on the ledger.
class VendorBill {
  final int id;
  final String? purchaseNumber;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? purchaseDate;
  final String? dueDate;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String? status;
  final bool isPaymentHold;
  final String? paymentHoldReason;

  const VendorBill({
    required this.id,
    this.purchaseNumber,
    this.invoiceNumber,
    this.invoiceDate,
    this.purchaseDate,
    this.dueDate,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.outstandingAmount = 0,
    this.status,
    this.isPaymentHold = false,
    this.paymentHoldReason,
  });

  factory VendorBill.fromJson(Map<String, dynamic> j) => VendorBill(
        id: j['id'] as int,
        purchaseNumber: j['purchaseNumber']?.toString(),
        invoiceNumber: j['invoiceNumber']?.toString(),
        invoiceDate: j['invoiceDate']?.toString(),
        purchaseDate: j['purchaseDate']?.toString(),
        dueDate: j['dueDate']?.toString(),
        totalAmount: _toD(j['totalAmount']),
        paidAmount: _toD(j['paidAmount']),
        outstandingAmount: _toD(j['outstandingAmount']),
        status: j['status']?.toString(),
        isPaymentHold: j['isPaymentHold'] == true,
        paymentHoldReason: j['paymentHoldReason']?.toString(),
      );
}

/// Vendor ledger — outstanding bills + KPIs + credit balance.
class VendorLedger {
  final int vendorId;
  final String vendorName;
  final double creditBalance;
  final double totalOutstanding;
  final double netPayable;
  final List<VendorBill> outstandingPurchases;
  final List<VendorBill> heldPurchases;

  const VendorLedger({
    required this.vendorId,
    required this.vendorName,
    this.creditBalance = 0,
    this.totalOutstanding = 0,
    this.netPayable = 0,
    this.outstandingPurchases = const [],
    this.heldPurchases = const [],
  });

  factory VendorLedger.fromJson(Map<String, dynamic> j) {
    final v = j['vendor'];
    return VendorLedger(
      vendorId: v is Map ? (v['id'] as int? ?? 0) : 0,
      vendorName: v is Map ? (v['vendorName']?.toString() ?? '—') : '—',
      creditBalance: _toD(j['creditBalance']),
      totalOutstanding: _toD(j['totalOutstanding']),
      netPayable: _toD(j['netPayable']),
      outstandingPurchases: (j['outstandingPurchases'] as List<dynamic>?)
              ?.map((e) => VendorBill.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      heldPurchases: (j['heldPurchases'] as List<dynamic>?)
              ?.map((e) => VendorBill.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  int get openBillCount => outstandingPurchases.length;
}

/// Canonical payment modes (identical to the web app-wide enum).
const kPaymentModes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque'];
