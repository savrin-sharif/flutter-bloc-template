import 'package:dio/dio.dart';

/// Reads user-facing messages and field errors from common REST error bodies.
///
/// Supported shapes include `{"message": "..."}`, `{"detail": "..."}`,
/// `{"error": {"message": "..."}}`, `{"errors": [{"field": "email",
/// "message": "..."}]}`, `{"errors": {"email": ["..."]}}`, and field arrays
/// at the top level such as `{"email": ["..."]}`.
abstract final class ApiErrorParser {
  static const _messageKeys = ['message', 'detail', 'error'];
  static const _nonFieldKeys = {
    'message',
    'detail',
    'error',
    'errors',
    'non_field_errors',
  };

  /// Field name to first validation message. Empty when none were returned.
  static Map<String, String> fieldErrors(Object? data) {
    if (data is! Map<Object?, Object?>) return const <String, String>{};

    final errors = data['errors'];
    if (errors is List<Object?>) {
      final mapped = <String, String>{};
      for (final item in errors) {
        if (item is! Map<Object?, Object?>) continue;
        final field = _text(item['field']);
        final message = _text(item['message']);
        if (field != null && message != null) {
          mapped.putIfAbsent(field, () => message);
        }
      }
      if (mapped.isNotEmpty) return Map.unmodifiable(mapped);
    }

    if (errors is Map<Object?, Object?>) {
      return _fieldMessages(errors, acceptsPlainStrings: true);
    }
    // Top-level plain strings are messages such as "detail", not fields.
    return _fieldMessages(data, acceptsPlainStrings: false);
  }

  /// The most specific human-readable message in [data], if any.
  static String? message(Object? data) {
    if (data is String) {
      final text = data.trim();
      // HTML error pages from proxies are not user-facing messages.
      return text.isEmpty || text.startsWith('<') ? null : text;
    }
    if (data is! Map<Object?, Object?>) return null;

    final errors = data['errors'];
    if (errors is List<Object?> && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map<Object?, Object?>
          ? _text(first['message'])
          : _text(first);
      if (message != null) return message;
    }
    if (errors is Map<Object?, Object?> && errors.isNotEmpty) {
      final first = errors.values.first;
      final message = first is List<Object?>
          ? _text(first.firstOrNull)
          : _text(first);
      if (message != null) return message;
    }

    for (final key in _messageKeys) {
      final value = data[key];
      if (value is Map<Object?, Object?>) {
        final nested = _firstMessageIn(value);
        if (nested != null) return nested;
        continue;
      }
      final message = _text(value);
      if (message != null) return message;
    }

    for (final value in data.values) {
      if (value is List<Object?>) {
        final message = _text(value.firstOrNull);
        if (message != null) return message;
      }
    }
    return null;
  }

  /// Whether [error] means the server could not be reached at all.
  static bool isConnectionError(DioException error) {
    if (error.response != null) return false;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.unknown => _looksLikeConnectionError(error.error),
      _ => false,
    };
  }

  static Map<String, String> _fieldMessages(
    Map<Object?, Object?> source, {
    required bool acceptsPlainStrings,
  }) {
    final mapped = <String, String>{};
    for (final entry in source.entries) {
      final field = _text(entry.key);
      if (field == null || _nonFieldKeys.contains(field)) continue;
      final value = entry.value;
      final message = value is List<Object?>
          ? _text(value.firstOrNull)
          : acceptsPlainStrings
          ? _text(value)
          : null;
      if (message != null) mapped.putIfAbsent(field, () => message);
    }
    return mapped.isEmpty ? const <String, String>{} : Map.unmodifiable(mapped);
  }

  static String? _firstMessageIn(Map<Object?, Object?> value) {
    for (final key in _messageKeys) {
      final message = _text(value[key]);
      if (message != null) return message;
    }
    for (final nested in value.values) {
      final message = nested is List<Object?>
          ? _text(nested.firstOrNull)
          : nested is String
          ? _text(nested)
          : null;
      if (message != null) return message;
    }
    return null;
  }

  static bool _looksLikeConnectionError(Object? cause) {
    if (cause == null) return false;
    final description = cause.toString().toLowerCase();
    return description.contains('socketexception') ||
        description.contains('failed host lookup') ||
        description.contains('network is unreachable') ||
        description.contains('connection refused') ||
        description.contains('connection reset');
  }

  static String? _text(Object? value) {
    if (value == null || value is Map || value is List) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
