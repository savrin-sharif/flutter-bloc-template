import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

typedef LogOutput = void Function(String message);

/// Lightweight application logger with formatted diagnostic and HTTP output.
///
/// Logging is disabled in release builds by default. HTTP requests are buffered
/// until their response arrives so each exchange is printed as a single block.
class LoggerService {
  factory LoggerService() => _instance;

  LoggerService._internal({bool? enabled, LogOutput? output})
    : enabled = enabled ?? kDebugMode,
      _output = output ?? _printLine;

  /// Creates an isolated logger for tests without changing the app singleton.
  @visibleForTesting
  factory LoggerService.forTesting({bool enabled = true, LogOutput? output}) =>
      LoggerService._internal(enabled: enabled, output: output);

  static final LoggerService _instance = LoggerService._internal();

  final bool enabled;
  final LogOutput _output;
  final Map<Object, _RequestBuffer> _pending = <Object, _RequestBuffer>{};

  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _dim = '\x1B[2m';
  static const _green = '\x1B[32m';
  static const _cyan = '\x1B[36m';
  static const _white = '\x1B[37m';
  static const _brightRed = '\x1B[91m';
  static const _brightGreen = '\x1B[92m';
  static const _brightYellow = '\x1B[93m';
  static const _brightBlue = '\x1B[94m';

  static const _jsonKey = '\x1B[31m';
  static const _jsonString = '\x1B[94m';
  static const _jsonNumber = '\x1B[92m';
  static const _jsonBoolean = '\x1B[93m';
  static const _jsonNull = '\x1B[1m\x1B[37m';
  static const _jsonPunctuation = '\x1B[37m';

  static const _boxWidth = 72;
  static const _boxTopLeft = '┌';
  static const _boxMiddleLeft = '├';
  static const _boxBottomLeft = '└';
  static const _boxVertical = '│';
  static const _boxHorizontal = '─';
  static const _boxDashed = '┄';
  static const _redacted = '<redacted>';
  static const _maximumBodyLength = 4000;

  void debug(String message) => _log(_dim, '🐛', 'DEBUG', message);

  void verbose(String message) => _log(_dim, '💬', 'TRACE', message);

  void info(String message) => _log(_cyan, '💡', 'INFO', message);

  void warn(String message) => _log(_brightYellow, '⚠️ ', 'WARN', message);

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    final parts = [message];
    if (error != null) {
      parts.add('Error: $error');
    }
    if (stackTrace != null) {
      parts.add('Stack:\n$stackTrace');
    }
    _log(_brightRed, '❌', 'ERROR', parts.join('\n'));
  }

  /// Buffers an HTTP request until [logResponse] is called with the same key.
  ///
  /// Headers and payload are formatted immediately, so later mutation of the
  /// request objects cannot change what is logged.
  void logRequest(
    String method,
    Uri uri, {
    Map<String, dynamic>? headers,
    Object? payload,
    required Object key,
    DateTime? startedAt,
  }) {
    if (!enabled) return;

    _pending[key] = _RequestBuffer(
      method: method,
      uri: _sanitizeUri(uri),
      headers: _maskHeaders(headers ?? const <String, dynamic>{}),
      formattedPayload: _formatPayload(payload),
      timestamp: startedAt ?? DateTime.now(),
    );
  }

  /// Prints a buffered request and its response as one formatted block.
  void logResponse(int? statusCode, Object? data, {required Object key}) {
    if (!enabled) return;

    final completedAt = DateTime.now();
    final buffer = _pending.remove(key);
    final code = statusCode ?? 0;
    final responseColor = switch (code) {
      >= 200 && < 300 => _brightGreen,
      >= 300 && < 400 => _brightYellow,
      _ => _brightRed,
    };
    final statusText = _httpStatusText(code);
    final dashedBar = '$_dim${_boxDashed * _boxWidth}$_reset';
    final vertical = '$_bold$_white$_boxVertical$_reset';
    final lines = <String>[
      '$_bold$_white$_boxTopLeft${_boxHorizontal * _boxWidth}$_reset',
      '$vertical  $_dim${_timestamp(buffer?.timestamp ?? completedAt)}$_reset',
    ];

    if (buffer != null) {
      final elapsed = completedAt.difference(buffer.timestamp);
      lines
        ..add('$_boxMiddleLeft$dashedBar')
        ..add('$vertical  $_bold$_brightBlue━━  REQUEST$_reset')
        ..add(vertical)
        ..add(
          '$vertical  ${_methodColor(buffer.method)}$_bold'
          '[${buffer.method}]$_reset  $_cyan${buffer.uri}$_reset',
        )
        ..add(vertical)
        ..add('$vertical  $_bold$_white📑  HEADERS$_reset');

      final headers = buffer.headers;
      if (headers.isEmpty) {
        lines.add('$vertical     $_dim<empty>$_reset');
      } else {
        headers.forEach((name, value) {
          lines.add('$vertical     $_dim$name$_reset $_white$value$_reset');
        });
      }

      lines
        ..add(vertical)
        ..add('$vertical  $_bold$_white📦  BODY$_reset');
      for (final line in buffer.formattedPayload.split('\n')) {
        lines.add('$vertical     $_green$line$_reset');
      }
      lines.add('$vertical  $_dim⏱  ${elapsed.inMilliseconds} ms$_reset');
    }

    lines
      ..add('$_boxMiddleLeft$dashedBar')
      ..add(
        '$vertical  $responseColor$_bold━━  RESPONSE  '
        '$code $statusText$_reset',
      )
      ..add(vertical);

    final body = _formatJson(data);
    final clipped = body.length > _maximumBodyLength;
    final display = clipped ? body.substring(0, _maximumBodyLength) : body;
    lines.add('$vertical  $_bold$_white📄  BODY$_reset');
    for (final line in display.split('\n')) {
      lines.add('$vertical     ${_colorJsonLine(line)}');
    }
    if (clipped) {
      lines.add(
        '$vertical     $_dim… truncated (${body.length} chars total)$_reset',
      );
    }

    lines.add(
      '$_bold$_white$_boxBottomLeft${_boxHorizontal * _boxWidth}$_reset',
    );
    for (final line in lines) {
      _output(line);
    }
  }

  void _log(String color, String emoji, String level, String message) {
    if (!enabled) return;

    final vertical = '$_bold$_white$_boxVertical$_reset';
    final lines = <String>[
      '$_bold$_white$_boxTopLeft${_boxHorizontal * _boxWidth}$_reset',
      '$vertical  $_dim${_timestamp(DateTime.now())}  [$level]$_reset',
      '$_boxMiddleLeft$_dim${_boxDashed * _boxWidth}$_reset',
      ...message
          .split('\n')
          .map((line) => '$vertical  $color$emoji  $line$_reset'),
      '$_bold$_white$_boxBottomLeft${_boxHorizontal * _boxWidth}$_reset',
    ];
    for (final line in lines) {
      _output(line);
    }
  }

  String _timestamp(DateTime dateTime) =>
      '${dateTime.year}-${_pad(dateTime.month)}-${_pad(dateTime.day)} '
      '${_pad(dateTime.hour)}:${_pad(dateTime.minute)}:'
      '${_pad(dateTime.second)}';

  String _pad(int value) => value.toString().padLeft(2, '0');

  String _methodColor(String method) => switch (method.toUpperCase()) {
    'GET' => _brightBlue,
    'POST' => _brightGreen,
    'PUT' || 'PATCH' => _brightYellow,
    'DELETE' => _brightRed,
    _ => _white,
  };

  String _httpStatusText(int code) => switch (code) {
    0 => 'Network Error',
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',
    204 => 'No Content',
    301 => 'Moved Permanently',
    302 => 'Found',
    304 => 'Not Modified',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    408 => 'Request Timeout',
    409 => 'Conflict',
    415 => 'Unsupported Media Type',
    422 => 'Unprocessable Entity',
    429 => 'Too Many Requests',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    _ => '',
  };

  Map<String, Object?> _maskHeaders(Map<String, dynamic> headers) {
    return headers.map(
      (name, value) => MapEntry(
        name,
        _isSensitiveKey(name)
            ? _maskedHeaderValue(name, value.toString())
            : value,
      ),
    );
  }

  /// Authorization keeps its scheme and a short fingerprint so different
  /// tokens can be told apart; other secrets are fully redacted.
  String _maskedHeaderValue(String name, String value) {
    if (_normalizedKey(name) != 'authorization') return _redacted;

    final separator = value.indexOf(' ');
    final prefix = separator > 0 ? '${value.substring(0, separator)} ' : '';
    final secret = separator > 0 ? value.substring(separator + 1) : value;
    if (secret.length <= 12) return '$prefix••••••';

    return '$prefix${secret.substring(0, 6)}…'
        '${secret.substring(secret.length - 6)}';
  }

  String _formatPayload(Object? payload) {
    if (payload == null) return '<empty>';

    if (payload is FormData) {
      final fields = payload.fields
          .map(
            (entry) => <String, Object?>{
              'key': entry.key,
              'value': _isSensitiveKey(entry.key)
                  ? _redacted
                  : _sanitizeData(entry.value),
            },
          )
          .toList();
      final files = payload.files
          .map(
            (entry) => <String, Object?>{
              'key': entry.key,
              'filename': entry.value.filename,
              'contentType': entry.value.contentType?.toString(),
              'length': entry.value.length,
            },
          )
          .toList();
      return _prettyEncode(<String, Object?>{'fields': fields, 'files': files});
    }
    return _formatJson(payload);
  }

  String _formatJson(Object? data) {
    if (data == null) return '<empty>';
    if (data is Uint8List) return '<binary: ${data.length} bytes>';
    if (data is String) {
      final sanitized = _sanitizeData(data);
      return sanitized is String ? sanitized : _prettyEncode(sanitized);
    }
    if (data is Map || data is Iterable) {
      return _prettyEncode(_sanitizeData(data));
    }
    return _safeToString(data);
  }

  String _prettyEncode(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } on Object {
      return _safeToString(value);
    }
  }

  String _safeToString(Object? value) {
    try {
      return value.toString();
    } on Object {
      return '<unprintable ${value.runtimeType}>';
    }
  }

  Uri _sanitizeUri(Uri uri) {
    if (uri.queryParametersAll.isEmpty) return uri;

    final parameters = <String, Object?>{};
    uri.queryParametersAll.forEach((name, values) {
      parameters[name] = _isSensitiveKey(name)
          ? List<String>.filled(values.length, _redacted)
          : values;
    });
    return uri.replace(queryParameters: parameters);
  }

  Object? _sanitizeData(Object? value) {
    if (value is Uint8List) return '<binary: ${value.length} bytes>';
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): _isSensitiveKey(entry.key.toString())
              ? _redacted
              : _sanitizeData(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_sanitizeData).toList();
    }
    if (value is String) {
      // JSON sent as a string must not bypass key-based redaction.
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map || decoded is List) return _sanitizeData(decoded);
      } on FormatException {
        // Ordinary string values need no structural sanitization.
      }
    }
    return value;
  }

  String _normalizedKey(String key) =>
      key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  bool _isSensitiveKey(String key) {
    final normalized = _normalizedKey(key);
    if (const {'authorization', 'cookie', 'setcookie'}.contains(normalized)) {
      return true;
    }
    return normalized.endsWith('apikey') ||
        normalized.endsWith('password') ||
        normalized.endsWith('passwd') ||
        normalized.endsWith('secret') ||
        normalized.endsWith('token');
  }

  String _colorJsonLine(String line) {
    final keyValueMatch = RegExp(
      r'^(\s*)("(?:[^"\\]|\\.)*")(\s*:\s*)(.+?)(,?)$',
    ).firstMatch(line);
    if (keyValueMatch != null) {
      return '${keyValueMatch[1]!}$_jsonKey${keyValueMatch[2]!}$_reset'
          '$_jsonPunctuation${keyValueMatch[3]!}$_reset'
          '${_colorJsonValue(keyValueMatch[4]!)}'
          '$_jsonPunctuation${keyValueMatch[5]!}$_reset';
    }

    final trimmed = line.trimLeft();
    final indent = line.substring(0, line.length - trimmed.length);
    if (RegExp(r'^[{}\[\]],?$').hasMatch(trimmed)) {
      return '$indent$_jsonPunctuation$trimmed$_reset';
    }
    if (trimmed.startsWith('"')) {
      final comma = trimmed.endsWith(',') ? ',' : '';
      final raw = comma.isEmpty
          ? trimmed
          : trimmed.substring(0, trimmed.length - 1);
      return '$indent$_jsonString$raw$_reset$_jsonPunctuation$comma$_reset';
    }
    return '$indent${_colorJsonValue(trimmed)}';
  }

  String _colorJsonValue(String value) {
    final hasComma = value.endsWith(',');
    final core = hasComma ? value.substring(0, value.length - 1) : value;
    final comma = hasComma ? ',' : '';
    if (core == 'null') {
      return '$_jsonNull$core$_reset$_jsonPunctuation$comma$_reset';
    }
    if (core == 'true' || core == 'false') {
      return '$_jsonBoolean$core$_reset$_jsonPunctuation$comma$_reset';
    }
    if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(core)) {
      return '$_jsonNumber$core$_reset$_jsonPunctuation$comma$_reset';
    }
    if (core.startsWith('"')) {
      return '$_jsonString$core$_reset$_jsonPunctuation$comma$_reset';
    }
    return '$_jsonPunctuation$value$_reset';
  }

  static void _printLine(String message) {
    // Printing each line separately avoids truncating large HTTP responses.
    // ignore: avoid_print
    print(message);
  }
}

class _RequestBuffer {
  const _RequestBuffer({
    required this.method,
    required this.uri,
    required this.headers,
    required this.formattedPayload,
    required this.timestamp,
  });

  final String method;
  final Uri uri;
  final Map<String, Object?> headers;
  final String formattedPayload;
  final DateTime timestamp;
}
