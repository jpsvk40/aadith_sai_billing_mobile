import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

final invoiceDetailProvider = FutureProvider.family<Invoice, String>((ref, id) async {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return InvoiceRepository(client).getInvoiceDetail(id);
});
