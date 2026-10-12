import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../network/api_error_parser.dart';

/// A categorized, user-safe error that repositories may throw.
///
/// Presentation reacts to the failure type (for example signing out on
/// [UnauthorizedFailure] or highlighting fields on [ValidationFailure])
/// instead of parsing message strings.
sealed class Failure extends Equatable implements Exception {
  const Failure(this.message, {this.statusCode});

  factory Failure.fromDioException(
    DioException error, {
    String fallbackMessage = defaultMessage,
  }) {
    if (ApiErrorParser.isConnectionError(error)) {
      return const ConnectionFailure();
    }

    final data = error.response?.data;
    final statusCode = error.response?.statusCode;
    final fieldErrors = ApiErrorParser.fieldErrors(data);
    final message =
        fieldErrors.values.firstOrNull ??
        ApiErrorParser.message(data) ??
        fallbackMessage;

    return switch (statusCode) {
      401 => UnauthorizedFailure(message),
      403 => ForbiddenFailure(message),
      _ when fieldErrors.isNotEmpty || statusCode == 400 || statusCode == 422 =>
        ValidationFailure(
          message,
          fieldErrors: fieldErrors,
          statusCode: statusCode,
        ),
      404 => NotFoundFailure(message),
      409 => ConflictFailure(message),
      _ => ServerFailure(message, statusCode: statusCode),
    };
  }

  static const defaultMessage = 'Something went wrong. Please try again.';
  static const connectionMessage =
      'No internet connection. Check your network and try again.';

  final String message;

  /// HTTP status of the failed response, when the failure came from one.
  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

/// A response or stored value could not be read into valid domain data.
final class DataFailure extends Failure {
  const DataFailure(super.message);
}

final class ConnectionFailure extends Failure {
  const ConnectionFailure([super.message = Failure.connectionMessage]);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message) : super(statusCode: 401);
}

final class ForbiddenFailure extends Failure {
  const ForbiddenFailure(super.message) : super(statusCode: 403);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message) : super(statusCode: 404);
}

final class ConflictFailure extends Failure {
  const ConflictFailure(super.message) : super(statusCode: 409);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const <String, String>{},
    super.statusCode,
  });

  /// Field name to its first validation message.
  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// The server answered with an error that has no more specific category.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}
