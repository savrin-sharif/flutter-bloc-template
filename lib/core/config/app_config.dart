import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppDesignStyle { material, cupertino }

enum AppEnvironment { production, development, local }

abstract final class AppConfig {
  static String get appName => _read('APP_NAME') ?? 'Flutter BLoC Template';

  /// Release builds are always [AppEnvironment.production].
  ///
  /// Debug and profile builds use [AppEnvironment.local] with
  /// `--dart-define=APP_ENV=local`, or when `DEV_URL` is missing, empty, or
  /// commented out while `LOCAL_URL` is set. Otherwise they use
  /// [AppEnvironment.development].
  static AppEnvironment get environment {
    // A release build can never be redirected by APP_ENV.
    if (kReleaseMode) return AppEnvironment.production;

    const requested = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    if (requested.toLowerCase() == 'local') return AppEnvironment.local;
    if (_read('DEV_URL') == null && _read('LOCAL_URL') != null) {
      return AppEnvironment.local;
    }
    return AppEnvironment.development;
  }

  static String get baseUrl => switch (environment) {
    AppEnvironment.production => _read('PROD_URL') ?? 'https://api.example.com',
    AppEnvironment.development =>
      _read('DEV_URL') ?? 'https://dev-api.example.com',
    AppEnvironment.local => _read('LOCAL_URL') ?? 'http://localhost:8080',
  };

  /// Resolves an additional host, such as a socket or CDN, with the same
  /// environment rules as [baseUrl].
  ///
  /// For `environmentUrl('WS_URL')` this reads `PROD_WS_URL`, `DEV_WS_URL`, or
  /// `LOCAL_WS_URL`, then falls back to the shared `WS_URL`.
  static String? environmentUrl(String key) {
    final prefix = switch (environment) {
      AppEnvironment.production => 'PROD',
      AppEnvironment.development => 'DEV',
      AppEnvironment.local => 'LOCAL',
    };
    return _read('${prefix}_$key') ?? _read(key);
  }

  static AppDesignStyle get designStyle {
    final value = _read('APP_DESIGN_STYLE')?.toLowerCase();
    return value == 'cupertino'
        ? AppDesignStyle.cupertino
        : AppDesignStyle.material;
  }

  /// Blank values are treated as missing so `KEY=` behaves like an absent key.
  static String? _read(String key) {
    final value = dotenv.maybeGet(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
