import 'dart:typed_data';

import 'package:dio/dio.dart';
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
        payload: const {'name': 'Ada'},
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
      expect(log, isNot(contains('query-secret')));
    });

    test('writes each message and HTTP exchange as a single block', () {
      logger
        ..info('first line\nsecond line')
        ..logRequest(
          'GET',
          Uri.parse('https://api.example.com/items'),
          key: 'request-1',
        )
        ..logResponse(200, const {'ok': true}, key: 'request-1');

      expect(output, hasLength(2));
      expect(output.first, contains('first line'));
      expect(output.first, contains('second line'));
      expect(output.first.split('\n').length, greaterThan(2));
      expect(output.last, contains('REQUEST'));
      expect(output.last, contains('RESPONSE  200 OK'));
    });

    test('fully redacts non-authorization secrets', () {
      logger
        ..logRequest(
          'GET',
          Uri.parse('https://api.example.com/items?api_key=a&api_key=b&q=ok'),
          headers: const {'Cookie': 'session=abcdef1234567890'},
          key: 'request-1',
        )
        ..logResponse(200, const {'ok': true}, key: 'request-1');

      final log = output.join('\n');
      expect(log, isNot(contains('abcdef')));
      expect(log, isNot(contains('api_key=a')));
      expect(log, contains('q=ok'));
    });

    test('redacts sensitive keys inside JSON sent as strings', () {
      logger
        ..logRequest(
          'POST',
          Uri.parse('https://api.example.com/login'),
          payload: '{"email":"ada@example.com","password":"hunter22"}',
          key: 'request-1',
        )
        ..logResponse(
          200,
          '{"access_token":"jwt-secret","user":"Ada"}',
          key: 'request-1',
        );

      final log = output.join('\n');
      expect(log, contains('ada@example.com'));
      expect(log, contains('Ada'));
      expect(log, isNot(contains('hunter22')));
      expect(log, isNot(contains('jwt-secret')));
    });

    test('summarizes multipart and binary bodies safely', () {
      final form = FormData.fromMap({
        'name': 'Avatar',
        'password': 'hunter22',
        'file': MultipartFile.fromBytes([1, 2, 3], filename: 'avatar.png'),
      });
      logger
        ..logRequest(
          'POST',
          Uri.parse('https://api.example.com/upload'),
          payload: form,
          key: 'request-1',
        )
        ..logResponse(200, Uint8List(2048), key: 'request-1');

      final log = output.join('\n');
      expect(log, contains('avatar.png'));
      expect(log, contains('"length": 3'));
      expect(log, isNot(contains('hunter22')));
      expect(log, contains('<binary: 2048 bytes>'));
    });

    test('logs the request as it was when sent', () {
      final headers = <String, dynamic>{'X-Trace': 'before'};
      logger.logRequest(
        'GET',
        Uri.parse('https://api.example.com/items'),
        headers: headers,
        key: 'request-1',
      );
      headers['X-Trace'] = 'after';
      logger.logResponse(200, null, key: 'request-1');

      final log = output.join('\n');
      expect(log, contains('before'));
      expect(log, isNot(contains('after')));
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
