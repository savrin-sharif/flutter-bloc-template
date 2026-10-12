import 'package:dio/dio.dart';
import 'package:flutter_bloc_template/core/network/api_error_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiErrorParser.fieldErrors', () {
    test('reads a list of field/message objects', () {
      expect(
        ApiErrorParser.fieldErrors(const {
          'errors': [
            {'field': 'email', 'message': 'Email is taken.'},
            {'field': 'email', 'message': 'Ignored duplicate.'},
            {'field': 'name', 'message': 'Name is required.'},
          ],
        }),
        {'email': 'Email is taken.', 'name': 'Name is required.'},
      );
    });

    test('reads an errors map with list or string values', () {
      expect(
        ApiErrorParser.fieldErrors(const {
          'message': 'The given data was invalid.',
          'errors': {
            'email': ['The email field is required.'],
            'age': 'Must be positive.',
          },
        }),
        {'email': 'The email field is required.', 'age': 'Must be positive.'},
      );
    });

    test('reads top-level field arrays but not message keys', () {
      expect(
        ApiErrorParser.fieldErrors(const {
          'detail': 'Invalid input.',
          'non_field_errors': ['Passwords do not match.'],
          'phone': ['Enter a valid phone number.'],
        }),
        {'phone': 'Enter a valid phone number.'},
      );
    });

    test('returns an empty map for bodies without field errors', () {
      expect(ApiErrorParser.fieldErrors(null), isEmpty);
      expect(ApiErrorParser.fieldErrors('Server error'), isEmpty);
      expect(ApiErrorParser.fieldErrors(const {'message': 'Nope'}), isEmpty);
    });
  });

  group('ApiErrorParser.message', () {
    test('prefers the first item in an errors list', () {
      expect(
        ApiErrorParser.message(const {
          'message': 'Generic',
          'errors': [
            {'message': 'Specific'},
          ],
        }),
        'Specific',
      );
    });

    test('reads message, detail, and error keys in order', () {
      expect(
        ApiErrorParser.message(const {'detail': 'Not found.'}),
        'Not found.',
      );
      expect(
        ApiErrorParser.message(const {'error': 'Bad token', 'detail': ''}),
        'Bad token',
      );
    });

    test('reads nested error objects', () {
      expect(
        ApiErrorParser.message(const {
          'error': {'code': 42, 'message': 'Quota exceeded.'},
        }),
        'Quota exceeded.',
      );
    });

    test('falls back to the first top-level field array', () {
      expect(
        ApiErrorParser.message(const {
          'phone_or_email': ['No account was found.'],
        }),
        'No account was found.',
      );
    });

    test('accepts plain text but ignores HTML error pages', () {
      expect(ApiErrorParser.message('  Rate limited  '), 'Rate limited');
      expect(ApiErrorParser.message('<html>502 Bad Gateway</html>'), isNull);
      expect(ApiErrorParser.message(''), isNull);
    });
  });

  group('ApiErrorParser.isConnectionError', () {
    DioException exception(
      DioExceptionType type, {
      Object? cause,
      bool withResponse = false,
    }) {
      final options = RequestOptions(path: '/items');
      return DioException(
        requestOptions: options,
        type: type,
        error: cause,
        response: withResponse
            ? Response<Object?>(requestOptions: options, statusCode: 503)
            : null,
      );
    }

    test('treats timeouts and connection errors as connection failures', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
      ]) {
        expect(ApiErrorParser.isConnectionError(exception(type)), isTrue);
      }
    });

    test('recognizes socket failures wrapped in unknown errors', () {
      expect(
        ApiErrorParser.isConnectionError(
          exception(
            DioExceptionType.unknown,
            cause: 'SocketException: Failed host lookup: api.example.com',
          ),
        ),
        isTrue,
      );
    });

    test('never treats a server response as a connection failure', () {
      expect(
        ApiErrorParser.isConnectionError(
          exception(DioExceptionType.connectionError, withResponse: true),
        ),
        isFalse,
      );
      expect(
        ApiErrorParser.isConnectionError(
          exception(DioExceptionType.badResponse),
        ),
        isFalse,
      );
      expect(
        ApiErrorParser.isConnectionError(exception(DioExceptionType.cancel)),
        isFalse,
      );
    });
  });
}
