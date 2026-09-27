import 'package:dio/dio.dart';

import 'api_exception.dart';

class ApiErrorHandler {
  static ApiException handle(DioException exception) {
    final response = exception.response;
    final statusCode = response?.statusCode;

    if (response?.data is Map<String, dynamic>) {
      final data = response!.data as Map<String, dynamic>;

      final message = data['message'];

      if (message is String && message.isNotEmpty) {
        return ApiException(message: message, statusCode: statusCode);
      }
    }

    return ApiException(
      message: _fallbackMessage(exception),
      statusCode: statusCode,
    );
  }

  static String _fallbackMessage(DioException exception) {
    print('DIO ERROR TYPE: ${exception.type}');
    print('DIO ERROR MESSAGE: ${exception.message}');
    print('DIO REQUEST PATH: ${exception.requestOptions.path}');
    print('DIO REQUEST URI: ${exception.requestOptions.uri}');
    print('DIO RESPONSE: ${exception.response}');

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
