import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

final receivablesDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ApiClient.getInstance(
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
  );
  try {
    final data = await client.get(ApiConstants.customerOutstanding);
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
