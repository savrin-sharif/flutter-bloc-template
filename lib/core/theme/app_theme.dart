import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF4054B2);

  static final materialLight = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      systemOverlayStyle: systemUiOverlayStyle(Brightness.light),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

  static final materialDark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      systemOverlayStyle: systemUiOverlayStyle(Brightness.dark),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

  static const cupertino = CupertinoThemeData(
    primaryColor: _seedColor,
    brightness: Brightness.light,
  );

  /// Status and navigation bar icons that stay legible on a background of
  /// [backgroundBrightness].
  static SystemUiOverlayStyle systemUiOverlayStyle(
    Brightness backgroundBrightness,
  ) => backgroundBrightness == Brightness.dark
      ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
      : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

  /// App `builder` that keeps a persistent system UI style under every route.
  ///
  /// Cupertino sheets temporarily paint their own [SystemUiOverlayStyle];
  /// without a region underneath, the icons keep the sheet's style after it
  /// is dismissed.
  static Widget withSystemUiOverlay(BuildContext context, Widget? child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle(CupertinoTheme.brightnessOf(context)),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
