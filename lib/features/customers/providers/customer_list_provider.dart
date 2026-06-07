import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class CustomerListState {
  final List<Customer> customers;
  final bool isLoading;
  final String? error;
  final String search;

  const CustomerListState({this.customers = const [], this.isLoading = false, this.error, this.search = ''});

  CustomerListState copyWith({List<Customer>? customers, bool? isLoading, String? error, String? search}) {
    return CustomerListState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      search: search ?? this.search,
    );
  }
}

class CustomerListNotifier extends StateNotifier<CustomerListState> {
  final CustomerRepository _repo;
  CustomerListNotifier(this._repo) : super(const CustomerListState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final customers = await _repo.getCustomers();
      state = state.copyWith(customers: customers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearch(String s) => state = state.copyWith(search: s);
}

final customerListProvider = StateNotifierProvider<CustomerListNotifier, CustomerListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return CustomerListNotifier(CustomerRepository(client));
});
