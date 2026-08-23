import 'package:flutter_bloc_template/core/logging/logger_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoggerService', () {
    late List<String> output;
    late LoggerService logger;

    setUp(() {
      output = [];
      logger = LoggerService.forTesting(output: output.add);
    });

    test('writes diagnostic messages with their level and details', () {
      logger.info('Application started');
      logger.error('Request failed', StateError('offline'));

      final log = output.join('\n');
      expect(log, contains('[INFO]'));
      expect(log, contains('Application started'));
      expect(log, contains('[ERROR]'));
      expect(log, contains('Bad state: offline'));
    });

    test('pairs requests with responses and masks sensitive headers', () {
      const token = '1234567890abcdefghijkl';
      logger.logRequest(
        'POST',
        Uri.parse('https://api.example.com/users?token=query-secret'),
        headers: const {
          'authorization': 'Bearer $token',
          'X-API-Key': 'super-secret-api-key',
        },
        payload: const {'name': 'Ada', 'password': 'do-not-log-me'},
        key: 'request-1',
      );
      logger.logResponse(201, const {
        'id': 42,
        'active': true,
      }, key: 'request-1');

      final log = output.join('\n');
      expect(log, contains('REQUEST'));
      expect(log, contains('[POST]'));
      expect(log, contains('RESPONSE  201 Created'));
      expect(log, contains('123456…ghijkl'));
      expect(log, isNot(contains(token)));
      expect(log, isNot(contains('super-secret-api-key')));
      expect(log, isNot(contains('do-not-log-me')));
      expect(log, isNot(contains('query-secret')));
    });

    test('does not write or buffer output when disabled', () {
      final disabledLogger = LoggerService.forTesting(
        enabled: false,
        output: output.add,
      );

      disabledLogger
        ..info('hidden')
        ..logRequest(
          'GET',
          Uri.parse('https://api.example.com'),
          key: 'request-1',
        )
        ..logResponse(200, const {'ok': true}, key: 'request-1');

      expect(output, isEmpty);
    });
  });
}
