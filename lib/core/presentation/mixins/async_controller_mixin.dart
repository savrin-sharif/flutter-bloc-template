import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A presentation-safe error produced while a BLoC controller task is running.
final class ControllerError {
  const ControllerError({
    required this.message,
    required this.isConnectionError,
  });

  final String message;
  final bool isConnectionError;
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
    String defaultErrorMessage = 'Something went wrong. Please try again.',
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
    } on DioException catch (error) {
      final settledState = _settleOperation(key, onLoadingChanged);
      emit(
        onFailure(
          settledState,
          _toControllerError(_extractDioMessage(error) ?? defaultErrorMessage),
        ),
      );
    } on Object {
      final settledState = _settleOperation(key, onLoadingChanged);
      emit(onFailure(settledState, _toControllerError(defaultErrorMessage)));
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

  ControllerError _toControllerError(String message) {
    final normalized = message.toLowerCase();
    final isConnectionError =
        normalized.contains('no internet') ||
        normalized.contains('connection') ||
        normalized.contains('network') ||
        normalized.contains('failed host lookup');
    return ControllerError(
      message: message,
      isConnectionError: isConnectionError,
    );
  }

  String? _extractDioMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<Object?, Object?>) {
      for (final key in const ['message', 'detail', 'error']) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      final errors = data['errors'];
      if (errors is List<Object?> && errors.isNotEmpty) {
        return errors.first?.toString();
      }
      if (errors is Map<Object?, Object?> && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List<Object?> && first.isNotEmpty) {
          return first.first?.toString();
        }
        return first?.toString();
      }
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    final message = error.message?.trim();
    return message == null || message.isEmpty ? null : message;
  }
}
