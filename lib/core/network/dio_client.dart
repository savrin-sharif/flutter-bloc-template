import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../logging/http_logger_interceptor.dart';
import '../logging/logger_service.dart';

/// Creates the app's REST client for [AppConfig.baseUrl].
///
/// [interceptors] run before the debug logger so the log shows the final
/// request, including headers added by an authentication interceptor.
Dio createDioClient(
  LoggerService logger, {
  VoidCallback? onServerReached,
  Iterable<Interceptor> interceptors = const <Interceptor>[],
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {'Accept': 'application/json'},
    ),
  );

  if (onServerReached != null) {
    dio.interceptors.add(ServerReachedInterceptor(onServerReached));
  }
  dio.interceptors.addAll(interceptors);
  if (kDebugMode) {
    dio.interceptors.add(HttpLoggerInterceptor(logger));
  }
  return dio;
}

/// Reports every server answer, error statuses included; only transport
/// failures (no response) say nothing about connectivity.
class ServerReachedInterceptor extends Interceptor {
  ServerReachedInterceptor(this._onServerReached);

  final VoidCallback _onServerReached;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _onServerReached();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) _onServerReached();
    handler.next(err);
  }
}
