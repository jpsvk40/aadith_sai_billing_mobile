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

/// The company's legal entities (multi-GSTIN) for the "GST registration" filter.
/// Cached for the session; the screens fall back to no filter if this errors.
final legalEntitiesProvider = FutureProvider<List<LegalEntityLite>>((ref) async {
  return ref.watch(gstComplianceRepositoryProvider).legalEntities();
});

/// The from/to window (both `YYYY-MM-DD`) plus optional server-side GST filters
/// (financial year + legal entity) for the GST returns review. Records compare
/// structurally, so the family caches per unique filter combination.
typedef GstReviewRange = ({String from, String to, String? financialYearId, String? legalEntityId});

/// GSTR-1 (Tally) review keyed by a date window + optional FY / legal-entity filters.
final gstReturnsReviewProvider = FutureProvider.family<GstReturnsReview, GstReviewRange>((ref, range) async {
  return ref.watch(gstComplianceRepositoryProvider).gstTallyReview(
        range.from,
        range.to,
        financialYearId: range.financialYearId,
        legalEntityId: range.legalEntityId,
      );
});
