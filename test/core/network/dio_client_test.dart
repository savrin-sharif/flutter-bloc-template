import 'package:dio/dio.dart';
import 'package:flutter_bloc_template/core/logging/http_logger_interceptor.dart';
import 'package:flutter_bloc_template/core/logging/logger_service.dart';
import 'package:flutter_bloc_template/core/network/dio_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

final class _MarkerInterceptor extends Interceptor {}

void main() {
  late LoggerService logger;

  setUp(() {
    dotenv.loadFromString(envString: 'DEV_URL=https://api.example.com');
    logger = LoggerService.forTesting(output: (_) {});
  });

  test('targets the configured base URL with the debug HTTP logger', () {
    final dio = createDioClient(logger);

    expect(dio.options.baseUrl, 'https://api.example.com');
    expect(dio.interceptors.whereType<HttpLoggerInterceptor>(), hasLength(1));
  });

  test('runs extra interceptors before the logger', () {
    final dio = createDioClient(
      logger,
      onServerReached: () {},
      interceptors: [_MarkerInterceptor()],
    );
    final interceptors = dio.interceptors.toList();

    expect(
      interceptors.indexWhere((i) => i is ServerReachedInterceptor),
      lessThan(interceptors.indexWhere((i) => i is _MarkerInterceptor)),
    );
    expect(
      interceptors.indexWhere((i) => i is _MarkerInterceptor),
      lessThan(interceptors.indexWhere((i) => i is HttpLoggerInterceptor)),
    );
  });

  group('ServerReachedInterceptor', () {
    late int reached;
    late Dio dio;

    setUp(() {
      reached = 0;
      dio = Dio()..interceptors.add(ServerReachedInterceptor(() => reached++));
    });

    test('reports successful and error responses', () async {
      dio.httpClientAdapter = _StatusAdapter(500);
      await expectLater(dio.get<Object?>('/x'), throwsA(isA<DioException>()));
      dio.httpClientAdapter = _StatusAdapter(200);
      await dio.get<Object?>('/x');

      expect(reached, 2);
    });

    test('stays silent for transport failures', () async {
      dio.httpClientAdapter = _FailingAdapter();
      await expectLater(dio.get<Object?>('/x'), throwsA(isA<DioException>()));

      expect(reached, 0);
    });
  });
}

final class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', statusCode);

  @override
  void close({bool force = false}) {}
}

final class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => Future.error(
    DioException.connectionError(
      requestOptions: options,
      reason: 'Network is unreachable',
    ),
  );

  @override
  void close({bool force = false}) {}
}
