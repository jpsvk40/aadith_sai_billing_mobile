// ignore_for_file: use_super_parameters

class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Session expired. Please login again.'])
      : super(message, statusCode: 401);
}

class ForbiddenException extends AppException {
  const ForbiddenException([String message = 'You do not have permission to perform this action.'])
      : super(message, statusCode: 403);
}

class NotFoundException extends AppException {
  const NotFoundException([String message = 'The requested resource was not found.'])
      : super(message, statusCode: 404);
}

class NetworkException extends AppException {
  const NetworkException([String message = 'No internet connection. Please check your network.'])
      : super(message);
}

class ServerException extends AppException {
  const ServerException([String message = 'Server error. Please try again later.'])
      : super(message, statusCode: 500);
}

class ValidationException extends AppException {
  const ValidationException(String message) : super(message, statusCode: 422);
}
