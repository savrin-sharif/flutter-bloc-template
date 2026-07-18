import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppDesignStyle { material, cupertino }

abstract final class AppConfig {
  static String get appName =>
      dotenv.maybeGet('APP_NAME') ?? 'Flutter BLoC Template';
  static String get baseUrl {
    // A release build can never be redirected by APP_ENV.
    if (kReleaseMode) {
      return dotenv.maybeGet('PROD_URL') ?? 'https://api.example.com';
    }

    const environment = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    if (environment.toLowerCase() == 'local') {
      return dotenv.maybeGet('LOCAL_URL') ?? 'http://localhost:8080';
    }
    return dotenv.maybeGet('DEV_URL') ?? 'https://dev-api.example.com';
  }

  static AppDesignStyle get designStyle {
    final value = dotenv.maybeGet('APP_DESIGN_STYLE')?.toLowerCase();
    return value == 'cupertino'
        ? AppDesignStyle.cupertino
        : AppDesignStyle.material;
  }
}
