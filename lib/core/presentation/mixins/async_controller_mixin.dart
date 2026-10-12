import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../errors/failure.dart';

/// A presentation-safe error produced while a BLoC controller task is running.
final class ControllerError {
  const ControllerError({
    required this.message,
    required this.isConnectionError,
    this.fieldErrors = const <String, String>{},
    this.statusCode,
    this.failure,
  });

  factory ControllerError.fromFailure(Failure failure) => ControllerError(
    message: failure.message,
    isConnectionError: failure is ConnectionFailure,
    fieldErrors: switch (failure) {
      ValidationFailure(:final fieldErrors) => fieldErrors,
      _ => const <String, String>{},
    },
    statusCode: failure.statusCode,
    failure: failure,
  );

  final String message;
  final bool isConnectionError;

  /// Field name to its first validation message returned by the API.
  final Map<String, String> fieldErrors;

  /// HTTP status of the failed response, when the failure came from one.
  final int? statusCode;

  /// The categorized failure, or `null` for unexpected errors.
  final Failure? failure;
}

/// Shared async-controller behavior for feature BLoCs.
///
/// Loading is tracked by operation key, so independent requests can run without
/// incorrectly hiding each other's progress. UI concerns such as snack bars and
/// form keys deliberately stay outside the BLoC.
mixin AsyncControllerMixin<Event, State> on Bloc<Event, State> {
  final Set<String> _activeOperations = <String>{};

  Set<String> get activeOperations =>
      Set<String>.unmodifiable(_activeOperations);

  bool get isAnyOperationLoading => _activeOperations.isNotEmpty;

  bool isOperationLoading(String key) => _activeOperations.contains(key);

  Future<void> runControllerTask<T>({
    required String key,
    required Emitter<State> emit,
    required Future<T> Function() task,
    required State Function(State current, T data) onSuccess,
    required State Function(State current, ControllerError error) onFailure,
    required State Function(State current, Set<String> activeOperations)
    onLoadingChanged,
    String defaultErrorMessage = Failure.defaultMessage,
  }) async {
    _setOperationLoading(
      key: key,
      loading: true,
      emit: emit,
      onLoadingChanged: onLoadingChanged,
    );

    try {
      final data = await task();
      final settledState = _settleOperation(key, onLoadingChanged);
      emit(onSuccess(settledState, data));
    } on Failure catch (failure) {
      final settledState = _settleOperation(key, onLoadingChanged);
      emit(onFailure(settledState, ControllerError.fromFailure(failure)));
    } on DioException catch (error) {
      final settledState = _settleOperation(key, onLoadingChanged);
      final failure = Failure.fromDioException(
        error,
        fallbackMessage: defaultErrorMessage,
      );
      emit(onFailure(settledState, ControllerError.fromFailure(failure)));
    } on Object {
      final settledState = _settleOperation(key, onLoadingChanged);
      emit(
        onFailure(
          settledState,
          ControllerError(
            message: defaultErrorMessage,
            isConnectionError: false,
          ),
        ),
      );
    } finally {
      if (_activeOperations.remove(key)) {
        emit(onLoadingChanged(state, activeOperations));
      }
    }
  }

  State _settleOperation(
    String key,
    State Function(State current, Set<String> activeOperations)
    onLoadingChanged,
  ) {
    _activeOperations.remove(key);
    return onLoadingChanged(state, activeOperations);
  }

  void _setOperationLoading({
    required String key,
    required bool loading,
    required Emitter<State> emit,
    required State Function(State current, Set<String> activeOperations)
    onLoadingChanged,
  }) {
    loading ? _activeOperations.add(key) : _activeOperations.remove(key);
    emit(onLoadingChanged(state, activeOperations));
  }
}
