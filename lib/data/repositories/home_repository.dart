import '../network/api_client.dart';
import '../models/mobile_home_model.dart';
import '../../core/constants/api_constants.dart';

class HomeRepository {
  final ApiClient _client;
  HomeRepository(this._client);

  Future<HomeOverview> getHome() async {
    final data = await _client.get(ApiConstants.mobileHome);
    return HomeOverview.fromJson(data as Map<String, dynamic>);
  }
}
