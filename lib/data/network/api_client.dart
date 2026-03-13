import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exceptions.dart';
import 'auth_interceptor.dart';

class ApiClient {
  late final Dio _dio;
  static ApiClient? _instance;

  ApiClient._internal(Function() onUnauthorized) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(
      AuthInterceptor(dio: _dio, onUnauthorized: onUnauthorized),
    );
  }

  static ApiClient getInstance({required Function() onUnauthorized}) {
    _instance ??= ApiClient._internal(onUnauthorized);
    return _instance!;
  }

  static void reset() => _instance = null;

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> patch(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      return const NetworkException();
    }
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;
    final responseMap = responseData is Map<String, dynamic> ? responseData : null;
    final message = responseMap?['error'] as String? ??
        responseMap?['message'] as String? ??
        e.message ??
        'Something went wrong';

    switch (statusCode) {
      case 401: return UnauthorizedException(message);
      case 403: return ForbiddenException(message);
      case 404: return NotFoundException(message);
      case 400:
      case 422:
        return ValidationException(message);
      case 500: return const ServerException();
      default: return AppException(message, statusCode: statusCode);
    }
  }
}
