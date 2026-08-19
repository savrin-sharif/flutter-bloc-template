import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc_template/features/welcome/domain/entities/welcome_info.dart';
import 'package:flutter_bloc_template/features/welcome/domain/repositories/welcome_repository.dart';
import 'package:flutter_bloc_template/features/welcome/domain/usecases/get_welcome_info.dart';
import 'package:flutter_bloc_template/features/welcome/presentation/bloc/welcome_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Repository implements WelcomeRepository {
  _Repository(this.result);

  final Future<WelcomeInfo> Function() result;

  @override
  Future<WelcomeInfo> getWelcomeInfo() => result();
}

void main() {
  const info = WelcomeInfo(title: 'Welcome!', description: 'Ready');

  blocTest<WelcomeBloc, WelcomeState>(
    'tracks keyed loading and clears it after success',
    build: () => WelcomeBloc(GetWelcomeInfo(_Repository(() async => info))),
    act: (bloc) => bloc.add(const WelcomeStarted()),
    expect: () => const <WelcomeState>[
      WelcomeState(
        status: WelcomeStatus.loading,
        activeOperations: {'load-welcome'},
      ),
      WelcomeState(status: WelcomeStatus.success, info: info),
    ],
    verify: (bloc) {
      expect(bloc.isAnyOperationLoading, isFalse);
      expect(bloc.isOperationLoading('load-welcome'), isFalse);
    },
  );

  blocTest<WelcomeBloc, WelcomeState>(
    'uses the backend message and marks connection failures',
    build: () => WelcomeBloc(
      GetWelcomeInfo(
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
    act: (bloc) => bloc.add(const WelcomeStarted()),
    expect: () => const <WelcomeState>[
      WelcomeState(
        status: WelcomeStatus.loading,
        activeOperations: {'load-welcome'},
      ),
      WelcomeState(
        status: WelcomeStatus.failure,
        errorMessage: 'Network connection unavailable',
        isConnectionError: true,
      ),
    ],
  );
}
