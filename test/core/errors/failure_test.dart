import 'package:dio/dio.dart';
import 'package:flutter_bloc_template/core/errors/failure.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _response(int statusCode, [Object? data]) {
  final options = RequestOptions(path: '/items');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
    ),
  );
}

void main() {
  group('Failure.fromDioException', () {
    test('maps transport failures to ConnectionFailure', () {
      final failure = Failure.fromDioException(
        DioException(
          requestOptions: RequestOptions(path: '/items'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(failure, const ConnectionFailure());
      expect(failure.message, Failure.connectionMessage);
    });

    test('maps status codes to typed failures with backend messages', () {
      const body = {'message': 'Backend says no.'};

      expect(
        Failure.fromDioException(_response(401, body)),
        const UnauthorizedFailure('Backend says no.'),
      );
      expect(
        Failure.fromDioException(_response(403, body)),
        const ForbiddenFailure('Backend says no.'),
      );
      expect(
        Failure.fromDioException(_response(404, body)),
        const NotFoundFailure('Backend says no.'),
      );
      expect(
        Failure.fromDioException(_response(409, body)),
        const ConflictFailure('Backend says no.'),
      );
      expect(
        Failure.fromDioException(_response(500, body)),
        const ServerFailure('Backend says no.', statusCode: 500),
      );
    });

    test('maps field errors to ValidationFailure using the first field', () {
      final failure = Failure.fromDioException(
        _response(422, const {
          'message': 'The given data was invalid.',
          'errors': {
            'email': ['The email field is required.'],
          },
        }),
      );

      expect(
        failure,
        const ValidationFailure(
          'The email field is required.',
          fieldErrors: {'email': 'The email field is required.'},
          statusCode: 422,
        ),
      );
    });

    test('treats 400 without field errors as a validation failure', () {
      expect(
        Failure.fromDioException(_response(400, const {'detail': 'Bad date'})),
        const ValidationFailure('Bad date', statusCode: 400),
      );
    });

    test('uses the fallback when the body has no usable message', () {
      expect(
        Failure.fromDioException(
          _response(502, '<html>Bad Gateway</html>'),
          fallbackMessage: 'Could not load items.',
        ),
        const ServerFailure('Could not load items.', statusCode: 502),
      );
    });
  });
}
