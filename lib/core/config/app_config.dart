import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppDesignStyle { material, cupertino }

abstract final class AppConfig {
  static String get appName =>
      dotenv.maybeGet('APP_NAME') ?? 'Flutter BLoC Template';
  static String get baseUrl =>
      dotenv.maybeGet('BASE_URL') ?? 'https://example.com';

  static AppDesignStyle get designStyle {
    final value = dotenv.maybeGet('APP_DESIGN_STYLE')?.toLowerCase();
    return value == 'cupertino'
        ? AppDesignStyle.cupertino
        : AppDesignStyle.material;
  }
}
