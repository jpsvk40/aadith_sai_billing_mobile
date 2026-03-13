import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/auth_user_model.dart';
import '../../../data/network/api_client.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileNotifier extends StateNotifier<AsyncValue<AuthUser>> {
  final AuthRepository _repo;
  ProfileNotifier(this._repo) : super(const AsyncValue.loading());

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.getMe();
      state = AsyncValue.data(user);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<AuthUser>>((ref) {
  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  return ProfileNotifier(AuthRepository(client));
});
