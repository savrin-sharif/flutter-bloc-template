import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_template/core/errors/failure.dart';
import 'package:flutter_bloc_template/core/presentation/mixins/async_controller_mixin.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Run {
  const _Run(this.key, this.task);

  final String key;
  final Future<String> Function() task;
}

final class _State {
  const _State({this.operations = const <String>{}, this.data, this.error});

  final Set<String> operations;
  final String? data;
  final ControllerError? error;

  _State copyWith({
    Set<String>? operations,
    String? data,
    ControllerError? error,
  }) => _State(
    operations: operations ?? this.operations,
    data: data ?? this.data,
    error: error ?? this.error,
  );
}

final class _Bloc extends Bloc<_Run, _State>
    with AsyncControllerMixin<_Run, _State> {
  _Bloc() : super(const _State()) {
    on<_Run>(
      (event, emit) => runControllerTask<String>(
        key: event.key,
        emit: emit,
        task: event.task,
        defaultErrorMessage: 'Fallback message',
        onLoadingChanged: (current, operations) =>
            current.copyWith(operations: operations),
        onSuccess: (current, data) => current.copyWith(data: data),
        onFailure: (current, error) => current.copyWith(error: error),
      ),
    );
  }
}

void main() {
  test('tracks concurrent operations independently', () async {
    final first = Completer<String>();
    final second = Completer<String>();
    final bloc = _Bloc()
      ..add(_Run('first', () => first.future))
      ..add(_Run('second', () => second.future));
    addTearDown(bloc.close);
    await pumpEventQueue();

    expect(bloc.state.operations, {'first', 'second'});

    first.complete('one');
    await pumpEventQueue();
    expect(bloc.state.operations, {'second'});
    expect(bloc.isOperationLoading('first'), isFalse);
    expect(bloc.isOperationLoading('second'), isTrue);

    second.complete('two');
    await pumpEventQueue();
    expect(bloc.state.operations, isEmpty);
    expect(bloc.state.data, 'two');
  });

  blocTest<_Bloc, _State>(
    'exposes a thrown Failure with its category and field errors',
    build: _Bloc.new,
    act: (bloc) => bloc.add(
      _Run(
        'save',
        () => throw const ValidationFailure(
          'Email is taken.',
          fieldErrors: {'email': 'Email is taken.'},
          statusCode: 422,
        ),
      ),
    ),
    verify: (bloc) {
      final error = bloc.state.error!;
      expect(error.message, 'Email is taken.');
      expect(error.fieldErrors, {'email': 'Email is taken.'});
      expect(error.statusCode, 422);
      expect(error.failure, isA<ValidationFailure>());
      expect(error.isConnectionError, isFalse);
      expect(bloc.state.operations, isEmpty);
    },
  );

  blocTest<_Bloc, _State>(
    'converts a DioException into a categorized error',
    build: _Bloc.new,
    act: (bloc) => bloc.add(
      _Run('load', () {
        final options = RequestOptions(path: '/items/7');
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 404,
            data: const {'detail': 'Item not found.'},
          ),
        );
      }),
    ),
    verify: (bloc) {
      final error = bloc.state.error!;
      expect(error.message, 'Item not found.');
      expect(error.statusCode, 404);
      expect(error.failure, isA<NotFoundFailure>());
    },
  );

  blocTest<_Bloc, _State>(
    'marks unreachable servers as connection errors',
    build: _Bloc.new,
    act: (bloc) => bloc.add(
      _Run(
        'load',
        () => throw DioException(
          requestOptions: RequestOptions(path: '/items'),
          type: DioExceptionType.connectionError,
        ),
      ),
    ),
    verify: (bloc) {
      expect(bloc.state.error!.isConnectionError, isTrue);
      expect(bloc.state.error!.message, Failure.connectionMessage);
    },
  );

  blocTest<_Bloc, _State>(
    'uses the default message for unexpected errors',
    build: _Bloc.new,
    act: (bloc) => bloc.add(_Run('load', () => throw StateError('bug'))),
    verify: (bloc) {
      final error = bloc.state.error!;
      expect(error.message, 'Fallback message');
      expect(error.failure, isNull);
      expect(bloc.state.operations, isEmpty);
    },
  );
}
