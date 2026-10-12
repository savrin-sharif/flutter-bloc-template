import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../features/welcome/data/datasources/welcome_local_data_source.dart';
import '../../features/welcome/data/repositories/welcome_repository_impl.dart';
import '../../features/welcome/domain/repositories/welcome_repository.dart';
import '../../features/welcome/domain/usecases/get_welcome_info.dart';
import '../../features/welcome/presentation/bloc/welcome_bloc.dart';
import '../config/app_config.dart';
import '../logging/logger_service.dart';
import '../network/connectivity_service.dart';
import '../network/dio_client.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  getIt
    ..registerLazySingleton<LoggerService>(LoggerService.new)
    ..registerLazySingleton<ConnectivityService>(
      () => ConnectivityService(
        probe: kIsWeb
            ? null
            : socketReachabilityProbe(() => Uri.parse(AppConfig.baseUrl)),
      ),
      dispose: (service) => service.dispose(),
    )
    ..registerLazySingleton<Dio>(
      () => createDioClient(
        getIt<LoggerService>(),
        onServerReached: () => getIt<ConnectivityService>().reportReachable(),
      ),
    )
    ..registerLazySingleton<WelcomeLocalDataSource>(
      WelcomeLocalDataSourceImpl.new,
    )
    ..registerLazySingleton<WelcomeRepository>(
      () => WelcomeRepositoryImpl(getIt<WelcomeLocalDataSource>()),
    )
    ..registerLazySingleton(() => GetWelcomeInfo(getIt<WelcomeRepository>()))
    ..registerFactory(() => WelcomeBloc(getIt<GetWelcomeInfo>()));
}
