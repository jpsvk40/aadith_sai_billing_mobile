import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/vendor_purchase_model.dart';
import '../../../data/repositories/vendor_purchase_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

/// One vendor purchase bill with its line items (GET /vendor-purchases/:id).
final purchaseDetailProvider = FutureProvider.family<VendorPurchase, String>((ref, id) async {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return VendorPurchaseRepository(client).getPurchaseDetail(id);
});
