import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/vendor_model.dart';
import '../../../data/repositories/vendor_repository.dart';
import '../../../data/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class VendorListState {
  final List<Vendor> vendors;
  final bool isLoading;
  final String? error;
  final String search;

  const VendorListState({this.vendors = const [], this.isLoading = false, this.error, this.search = ''});

  VendorListState copyWith({List<Vendor>? vendors, bool? isLoading, String? error, String? search}) {
    return VendorListState(
      vendors: vendors ?? this.vendors,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      search: search ?? this.search,
    );
  }
}

class VendorListNotifier extends StateNotifier<VendorListState> {
  final VendorRepository _repo;
  VendorListNotifier(this._repo) : super(const VendorListState());

  /// Loads the full vendor list. Like the web VendorList page, search + status
  /// filters run client-side over this full set, so we do not pass `search` here.
  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final vendors = await _repo.getVendors();
      state = state.copyWith(vendors: vendors, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearch(String s) => state = state.copyWith(search: s);
}

final vendorListProvider = StateNotifierProvider<VendorListNotifier, VendorListState>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return VendorListNotifier(VendorRepository(client));
});
