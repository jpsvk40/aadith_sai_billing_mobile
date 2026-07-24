import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// Server-side query params the canonical `/customer-outstanding` endpoint accepts.
/// The receivables screen builds one of these from its filter sheet and threads it
/// through the GET (the endpoint previously received zero params):
///   * [asOfDate]  — balances computed AS OF this date (yyyy-MM-dd); omit = today.
///   * [fromDate]  — only invoices dated on/after this (yyyy-MM-dd).
///   * [minOverdueDays] — drop invoices less than N days overdue (0 = all ages).
class ReceivablesQuery {
  final String? asOfDate;
  final String? fromDate;
  final int minOverdueDays;
  const ReceivablesQuery({this.asOfDate, this.fromDate, this.minOverdueDays = 0});

  /// null when nothing is set, so the caller sends no query string at all.
  Map<String, dynamic>? toQueryParams() {
    final qp = <String, dynamic>{};
    if (asOfDate != null && asOfDate!.isNotEmpty) qp['asOfDate'] = asOfDate;
    if (fromDate != null && fromDate!.isNotEmpty) qp['fromDate'] = fromDate;
    if (minOverdueDays > 0) qp['minOverdueDays'] = minOverdueDays;
    return qp.isEmpty ? null : qp;
  }

  @override
  bool operator ==(Object other) =>
      other is ReceivablesQuery &&
      other.asOfDate == asOfDate &&
      other.fromDate == fromDate &&
      other.minOverdueDays == minOverdueDays;

  @override
  int get hashCode => Object.hash(asOfDate, fromDate, minOverdueDays);
}

final receivablesDataProvider =
    FutureProvider.family<Map<String, dynamic>, ReceivablesQuery>((ref, query) async {
  final client = ApiClient.getInstance(
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
  );
  try {
    final data = await client.get(
      ApiConstants.customerOutstanding,
      queryParams: query.toQueryParams(),
    );
    return data is Map ? data.cast<String, dynamic>() : {};
  } catch (e) {
    throw Exception('Failed to load receivables: $e');
  }
});

final recordPaymentProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, paymentData) async {
  final client = ApiClient.getInstance(
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
  );
  await client.post('${ApiConstants.collections}/payment', data: paymentData);
});

final sendWhatsAppProvider = FutureProvider.family<void, Map<String, dynamic>>((ref, waData) async {
  final client = ApiClient.getInstance(
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
  );
  await client.post('${ApiConstants.collections}/whatsapp-print', data: waData);
});
