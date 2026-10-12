import 'package:dio/dio.dart';

import 'logger_service.dart';

/// Connects Dio request lifecycle events to [LoggerService].
class HttpLoggerInterceptor extends Interceptor {
  HttpLoggerInterceptor(this._logger);

  static const _requestKeyExtra = '__http_logger_request_key__';

  final LoggerService _logger;
  var _nextRequestId = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = '${DateTime.now().microsecondsSinceEpoch}-${_nextRequestId++}';
    options.extra[_requestKeyExtra] = key;
    _logger.logRequest(
      options.method,
      options.uri,
      headers: options.headers,
      payload: options.data,
      key: key,
      startedAt: DateTime.now(),
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.logResponse(
      response.statusCode,
      response.data,
      key: _requestKey(response.requestOptions),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.logResponse(
      err.response?.statusCode,
      err.response?.data ??
          <String, Object?>{'error': err.message, 'type': err.type.name},
      key: _requestKey(err.requestOptions),
    );
    handler.next(err);
  }

  Object _requestKey(RequestOptions options) =>
      options.extra[_requestKeyExtra] ?? options.uri.toString();
}
