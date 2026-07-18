import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc_template/features/home/domain/entities/template_info.dart';
import 'package:flutter_bloc_template/features/home/domain/repositories/template_repository.dart';
import 'package:flutter_bloc_template/features/home/domain/usecases/get_template_info.dart';
import 'package:flutter_bloc_template/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Repository implements TemplateRepository {
  _Repository(this.result);

  final Future<TemplateInfo> Function() result;

  @override
  Future<TemplateInfo> getTemplateInfo() => result();
}

void main() {
  const info = TemplateInfo(title: 'Welcome!', description: 'Ready');

  blocTest<HomeBloc, HomeState>(
    'tracks keyed loading and clears it after success',
    build: () => HomeBloc(GetTemplateInfo(_Repository(() async => info))),
    act: (bloc) => bloc.add(const HomeStarted()),
    expect: () => const <HomeState>[
      HomeState(status: HomeStatus.loading, activeOperations: {'load-home'}),
      HomeState(status: HomeStatus.success, info: info),
    ],
    verify: (bloc) {
      expect(bloc.isAnyOperationLoading, isFalse);
      expect(bloc.isOperationLoading('load-home'), isFalse);
    },
  );

  blocTest<HomeBloc, HomeState>(
    'uses the backend message and marks connection failures',
    build: () => HomeBloc(
      GetTemplateInfo(
        _Repository(
          () => throw DioException(
            requestOptions: RequestOptions(),
            response: Response<Map<String, Object?>>(
              requestOptions: RequestOptions(),
              data: const {'message': 'Network connection unavailable'},
            ),
          ),
        ),
      ),
    ),
    act: (bloc) => bloc.add(const HomeStarted()),
    expect: () => const <HomeState>[
      HomeState(status: HomeStatus.loading, activeOperations: {'load-home'}),
      HomeState(
        status: HomeStatus.failure,
        errorMessage: 'Network connection unavailable',
        isConnectionError: true,
      ),
    ],
  );
}
