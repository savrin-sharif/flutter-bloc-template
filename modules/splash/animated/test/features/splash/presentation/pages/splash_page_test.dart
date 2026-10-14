import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc_template/core/theme/app_theme.dart';
import 'package:flutter_bloc_template/features/splash/presentation/pages/splash_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

const _animationDuration = Duration(milliseconds: 1500);
const _splash = '/splash';
const _next = '/next';
const _home = '/home';

void main() {
  // Loading inside a widget test's fake-async zone never completes, so the
  // composition is cached here, the same way bootstrap prewarms it.
  setUp(() => AssetLottie(SplashPage.animationAsset).load());

  for (final cupertino in [false, true]) {
    final root = cupertino ? 'Cupertino' : 'Material';

    testWidgets('$root: stays until the animation ends, then navigates', (
      tester,
    ) async {
      var resolveCalls = 0;
      final router = _splashRouter(() async {
        resolveCalls++;
        return _home;
      });
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router, cupertino: cupertino));
      await tester.pump();
      expect(resolveCalls, 1);

      await tester.pump(_animationDuration - const Duration(milliseconds: 100));
      expect(_location(router), _splash);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(_location(router), _home);
      expect(find.text('home'), findsOneWidget);
    });
  }

  for (final (description, resolver) in [
    ('returns null', () async => null),
    ('throws', () async => throw StateError('offline')),
  ]) {
    testWidgets('lands on nextRoute when the resolver $description', (
      tester,
    ) async {
      final router = _splashRouter(resolver);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pump();
      await tester.pump(_animationDuration);
      await tester.pumpAndSettle();

      expect(find.text('next'), findsOneWidget);
    });
  }

  testWidgets('lands on nextRoute without a resolver', (tester) async {
    final router = _splashRouter(null);
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pump();
    await tester.pump(_animationDuration);
    await tester.pumpAndSettle();

    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('shows the logo and navigates when the animation fails', (
    tester,
  ) async {
    Lottie.cache.evict(AssetLottie(SplashPage.animationAsset));
    final router = _splashRouter(() async => _home);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _MissingAnimationBundle(),
        child: _app(router),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(_location(router), _splash);

    await tester.pump(SplashPage.fallbackDelay);
    await tester.pumpAndSettle();
    expect(_location(router), _home);
  });

  for (final brightness in Brightness.values) {
    testWidgets('matches the native ${brightness.name} splash color', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final router = _splashRouter(null);
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pump();

      final background = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(SplashPage),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(
        background.color,
        brightness == Brightness.dark
            ? SplashPage.darkBackgroundColor
            : SplashPage.backgroundColor,
      );

      await tester.pump(_animationDuration);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('hides system bars during the splash and restores them after', (
    tester,
  ) async {
    final modes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final router = _splashRouter(null);
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pump();
    expect(modes, [SystemUiMode.immersiveSticky.toString()]);
    expect(
      SystemChrome.latestStyle,
      AppTheme.systemUiOverlayStyle(
        ThemeData.estimateBrightnessForColor(SplashPage.backgroundColor),
      ),
    );

    await tester.pump(_animationDuration);
    await tester.pumpAndSettle();

    expect(modes, [
      SystemUiMode.immersiveSticky.toString(),
      SystemUiMode.edgeToEdge.toString(),
    ]);
    expect(
      SystemChrome.latestStyle,
      AppTheme.systemUiOverlayStyle(Brightness.light),
    );
  });
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

Widget _app(GoRouter router, {bool cupertino = false}) => cupertino
    ? CupertinoApp.router(
        routerConfig: router,
        builder: AppTheme.withSystemUiOverlay,
      )
    : MaterialApp.router(
        routerConfig: router,
        builder: AppTheme.withSystemUiOverlay,
      );

GoRouter _splashRouter(Future<String?> Function()? resolveNextRoute) =>
    GoRouter(
      initialLocation: _splash,
      routes: [
        GoRoute(
          path: _splash,
          builder: (context, state) =>
              SplashPage(nextRoute: _next, resolveNextRoute: resolveNextRoute),
        ),
        for (final (path, label) in [(_next, 'next'), (_home, 'home')])
          GoRoute(
            path: path,
            builder: (context, state) => Center(child: Text(label)),
          ),
      ],
    );

final class _MissingAnimationBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key == SplashPage.animationAsset) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return rootBundle.load(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      utf8.decode((await load(key)).buffer.asUint8List());
}
