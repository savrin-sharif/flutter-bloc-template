import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/welcome/data/datasources/welcome_local_data_source.dart';
import '../../features/welcome/data/repositories/welcome_repository_impl.dart';
import '../../features/welcome/domain/repositories/welcome_repository.dart';
import '../../features/welcome/domain/usecases/get_welcome_info.dart';
import '../../features/welcome/presentation/bloc/welcome_bloc.dart';
import '../logging/logger_service.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  getIt
    ..registerLazySingleton<NetworkInfo>(NetworkInfo.new)
    ..registerLazySingleton<LoggerService>(LoggerService.new)
    ..registerLazySingleton<Dio>(() => createDioClient(getIt<LoggerService>()))
    ..registerLazySingleton<WelcomeLocalDataSource>(
      WelcomeLocalDataSourceImpl.new,
    )
    ..registerLazySingleton<WelcomeRepository>(
      () => WelcomeRepositoryImpl(getIt<WelcomeLocalDataSource>()),
    )
    ..registerLazySingleton(() => GetWelcomeInfo(getIt<WelcomeRepository>()))
    ..registerFactory(() => WelcomeBloc(getIt<GetWelcomeInfo>()));
}
