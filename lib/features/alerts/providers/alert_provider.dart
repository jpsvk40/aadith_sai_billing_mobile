import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/repositories/alert_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class AlertState {
  final List<Alert> alerts;
  final bool isLoading;
  final String? error;

  const AlertState({this.alerts = const [], this.isLoading = false, this.error});

  AlertState copyWith({List<Alert>? alerts, bool? isLoading, String? error}) {
    return AlertState(alerts: alerts ?? this.alerts, isLoading: isLoading ?? this.isLoading, error: error);
  }
}

class AlertNotifier extends StateNotifier<AlertState> {
  final AlertRepository _repo;
  AlertNotifier(this._repo) : super(const AlertState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final alerts = await _repo.getAlerts();
      state = AlertState(alerts: alerts);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repo.markAsRead(id);
      state = state.copyWith(
        alerts: state.alerts.map((a) => a.id == id
            ? Alert(id: a.id, type: a.type, message: a.message, isRead: true,
                customerId: a.customerId, customerName: a.customerName,
                invoiceId: a.invoiceId, invoiceNumber: a.invoiceNumber,
                amount: a.amount, createdAt: a.createdAt)
            : a).toList(),
      );
    } catch (_) {}
  }
}

final alertProvider = StateNotifierProvider<AlertNotifier, AlertState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return AlertNotifier(AlertRepository(client));
});
