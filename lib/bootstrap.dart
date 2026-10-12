import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'core/di/injection.dart';
import 'core/logging/logger_service.dart';
import 'core/network/connectivity_service.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/envs/.env');
  await configureDependencies();
  await _startService(
    'Connectivity',
    () => getIt<ConnectivityService>().start(),
  );
  runApp(const App());
}

/// A failing optional service is logged instead of preventing app launch.
Future<void> _startService(String name, Future<void> Function() start) async {
  try {
    await start();
  } on Object catch (error, stackTrace) {
    getIt<LoggerService>().error('$name startup failed.', error, stackTrace);
  }
}
