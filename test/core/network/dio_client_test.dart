import 'package:flutter_bloc_template/core/logging/http_logger_interceptor.dart';
import 'package:flutter_bloc_template/core/logging/logger_service.dart';
import 'package:flutter_bloc_template/core/network/dio_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configures the custom HTTP logger interceptor', () {
    dotenv.loadFromString(envString: 'DEV_URL=https://api.example.com');
    final logger = LoggerService.forTesting(output: (_) {});
    final dio = createDioClient(logger);

    expect(dio.interceptors.whereType<HttpLoggerInterceptor>(), hasLength(1));
  });
}
