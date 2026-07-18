import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/home/data/datasources/template_local_data_source.dart';
import '../../features/home/data/repositories/template_repository_impl.dart';
import '../../features/home/domain/repositories/template_repository.dart';
import '../../features/home/domain/usecases/get_template_info.dart';
import '../../features/home/presentation/bloc/home_bloc.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  getIt
    ..registerLazySingleton<NetworkInfo>(NetworkInfo.new)
    ..registerLazySingleton<Dio>(createDioClient)
    ..registerLazySingleton<TemplateLocalDataSource>(
      TemplateLocalDataSourceImpl.new,
    )
    ..registerLazySingleton<TemplateRepository>(
      () => TemplateRepositoryImpl(getIt<TemplateLocalDataSource>()),
    )
    ..registerLazySingleton(() => GetTemplateInfo(getIt<TemplateRepository>()))
    ..registerFactory(() => HomeBloc(getIt<GetTemplateInfo>()));
}
