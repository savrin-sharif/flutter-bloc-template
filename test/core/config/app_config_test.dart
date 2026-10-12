import 'package:flutter_bloc_template/core/config/app_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.baseUrl in debug', () {
    test('uses DEV_URL when it is set', () {
      dotenv.loadFromString(
        envString:
            'DEV_URL=https://dev.example.com\n'
            'LOCAL_URL=http://192.168.0.10:9090',
      );

      expect(AppConfig.environment, AppEnvironment.development);
      expect(AppConfig.baseUrl, 'https://dev.example.com');
    });

    test('falls back to LOCAL_URL when DEV_URL is commented out', () {
      dotenv.loadFromString(
        envString:
            '# DEV_URL=https://dev.example.com\n'
            'LOCAL_URL=http://192.168.0.10:9090',
      );

      expect(AppConfig.environment, AppEnvironment.local);
      expect(AppConfig.baseUrl, 'http://192.168.0.10:9090');
    });

    test('falls back to LOCAL_URL when DEV_URL is blank', () {
      dotenv.loadFromString(
        envString: 'DEV_URL=  \nLOCAL_URL=http://192.168.0.10:9090',
      );

      expect(AppConfig.baseUrl, 'http://192.168.0.10:9090');
    });

    test('uses the development default when no URL is configured', () {
      dotenv.loadFromString(envString: 'APP_NAME=Demo');

      expect(AppConfig.environment, AppEnvironment.development);
      expect(AppConfig.baseUrl, 'https://dev-api.example.com');
    });
  });

  group('AppConfig.environmentUrl', () {
    const env =
        'WS_URL=wss://socket.example.com\n'
        'LOCAL_URL=http://192.168.0.10:9090\n'
        'LOCAL_WS_URL=ws://192.168.0.10:3000';

    test('prefers the environment-specific key', () {
      dotenv.loadFromString(envString: '# DEV_URL=\n$env');

      expect(AppConfig.environmentUrl('WS_URL'), 'ws://192.168.0.10:3000');
    });

    test('falls back to the shared key', () {
      dotenv.loadFromString(envString: 'DEV_URL=https://dev.example.com\n$env');

      expect(AppConfig.environmentUrl('WS_URL'), 'wss://socket.example.com');
    });

    test('returns null when neither key is configured', () {
      dotenv.loadFromString(envString: 'DEV_URL=https://dev.example.com');

      expect(AppConfig.environmentUrl('CDN_URL'), isNull);
    });
  });

  test('treats blank values as missing', () {
    dotenv.loadFromString(envString: 'APP_NAME=   \nAPP_DESIGN_STYLE= ');

    expect(AppConfig.appName, 'Flutter BLoC Template');
    expect(AppConfig.designStyle, AppDesignStyle.material);
  });
}
