import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/gst_compliance_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/gst_compliance_repository.dart';
import '../../auth/providers/auth_provider.dart';

final gstComplianceRepositoryProvider = Provider<GstComplianceRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return GstComplianceRepository(client);
});

/// e-Invoice (IRN) register — full list; the screen filters KPIs client-side.
final einvoiceRegisterProvider = FutureProvider<List<EinvoiceDoc>>((ref) async {
  return ref.watch(gstComplianceRepositoryProvider).einvoiceRegister();
});

/// e-Way bill register keyed by the (server-side) status filter — 'All' = unfiltered.
final ewayRegisterProvider = FutureProvider.family<List<EwayBillDoc>, String>((ref, status) async {
  return ref.watch(gstComplianceRepositoryProvider).ewayBillRegister(status: status == 'All' ? null : status);
});

/// The from/to window (both `YYYY-MM-DD`) for the GST returns review.
typedef GstReviewRange = ({String from, String to});

/// GSTR-1 (Tally) review keyed by a date window.
final gstReturnsReviewProvider = FutureProvider.family<GstReturnsReview, GstReviewRange>((ref, range) async {
  return ref.watch(gstComplianceRepositoryProvider).gstTallyReview(range.from, range.to);
});
