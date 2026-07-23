import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/vendor_payment_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/vendor_payment_repository.dart';
import '../../auth/providers/auth_provider.dart';

final vendorPaymentRepositoryProvider = Provider<VendorPaymentRepository>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return VendorPaymentRepository(client);
});

/// Merged single + bulk vendor payments (most recent first).
final vendorPaymentsProvider = FutureProvider<List<VendorPaymentRow>>((ref) async {
  return ref.watch(vendorPaymentRepositoryProvider).getPayments();
});

/// Per-vendor ledger (outstanding bills + credit + KPIs) for the Pay screen.
final vendorLedgerProvider = FutureProvider.family<VendorLedger, String>((ref, vendorId) async {
  return ref.watch(vendorPaymentRepositoryProvider).getLedger(vendorId);
});
