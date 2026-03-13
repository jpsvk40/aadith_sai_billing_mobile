import 'package:dio/dio.dart';
import '../local/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final Function() onUnauthorized;

  AuthInterceptor({required this.dio, required this.onUnauthorized});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await SecureStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      onUnauthorized();
    }
    handler.next(err);
  }
}
