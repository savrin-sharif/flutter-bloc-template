import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

/// Continues the native launch screen: plays [animationAsset] once on the
/// native splash color, then replaces itself with the next route.
///
/// Neither a Material nor a Cupertino scaffold, so it renders identically
/// under both app roots.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.resolveNextRoute});

  static const animationAsset = 'assets/splash/splash_animation.json';
  static const fallbackImageAsset = 'assets/splash/logo.png';

  /// How long the logo is shown when the animation cannot be loaded.
  static const fallbackDelay = Duration(milliseconds: 750);

  /// Must match `color` and `color_dark` in `native_splash.yaml`, otherwise
  /// the hand-off from the native screen flashes.
  static const backgroundColor = Color(0xFF4054B2);
  static const darkBackgroundColor = Color(0xFF4054B2);

  /// Logical size of the native logo: a 960 px image rendered at 4x density.
  static const logoSize = 240.0;

  /// Resolves the destination while the animation plays. A `null` result, an
  /// error, or no resolver lands on [AppRoutes.playground].
  final Future<String?> Function()? resolveNextRoute;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Future<String?> _nextRoute;
  Timer? _fallbackTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener(_onAnimationStatusChanged);
    _nextRoute = _resolveSafely(widget.resolveNextRoute);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static Future<String?> _resolveSafely(
    Future<String?> Function()? resolveNextRoute,
  ) async {
    if (resolveNextRoute == null) return null;
    try {
      return await resolveNextRoute();
    } on Object {
      return null;
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _goToNextRoute();
  }

  void _scheduleFallback() {
    _fallbackTimer ??= Timer(SplashPage.fallbackDelay, _goToNextRoute);
  }

  Future<void> _goToNextRoute() async {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    final route = await _nextRoute;
    if (!mounted) return;
    context.go(route ?? AppRoutes.playground);
  }

  @override
  Widget build(BuildContext context) {
    final color = MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? SplashPage.darkBackgroundColor
        : SplashPage.backgroundColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUiOverlayStyle(
        ThemeData.estimateBrightnessForColor(color),
      ),
      child: ColoredBox(
        color: color,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox.square(
              dimension: constraints.maxWidth < SplashPage.logoSize
                  ? constraints.maxWidth
                  : SplashPage.logoSize,
              child: Lottie.asset(
                SplashPage.animationAsset,
                controller: _controller,
                fit: BoxFit.contain,
                onLoaded: (composition) {
                  _controller
                    ..duration = composition.duration
                    ..forward();
                },
                errorBuilder: (context, error, stackTrace) {
                  _scheduleFallback();
                  return Image.asset(
                    SplashPage.fallbackImageAsset,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
