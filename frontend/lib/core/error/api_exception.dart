class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.data});

  final String message;
  final int? statusCode;

  /// The response's `data` payload, e.g. the current settings on a 409.
  final Object? data;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message)';
  }
}
