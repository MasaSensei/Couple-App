import 'package:dio/dio.dart';

import 'api_exception.dart';

class ApiErrorHandler {
  static ApiException handle(DioException exception) {
    final response = exception.response;
    final statusCode = response?.statusCode;
    final body = response?.data;

    if (body is Map) {
      final message = body['message'];
      final payload = body['data'];

      // Laravel API response: { data: { errors: {...} } }
      final errors = payload is Map ? payload['errors'] : body['errors'];

      if (errors is Map) {
        final details = <String>[];

        errors.forEach((field, messages) {
          if (messages is List) {
            for (final item in messages) {
              details.add('$field: $item');
            }
          } else if (messages != null) {
            details.add('$field: $messages');
          }
        });

        if (details.isNotEmpty) {
          return ApiException(
            message: details.join('\n'),
            statusCode: statusCode,
          );
        }
      }

      if (message is String && message.isNotEmpty) {
        return ApiException(
          message: message,
          statusCode: statusCode,
          data: payload,
        );
      }
    }

    return ApiException(
      message: _fallbackMessage(exception),
      statusCode: statusCode,
    );
  }

  static String _fallbackMessage(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
        return 'The request timed out. Please try again.';

      case DioExceptionType.sendTimeout:
        return 'The request timed out. Please try again.';

      case DioExceptionType.receiveTimeout:
        return 'The request timed out. Please try again.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to the server.';

      case DioExceptionType.badResponse:
        return 'The server returned an unexpected response.';

      case DioExceptionType.cancel:
        return 'The request was cancelled.';

      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
