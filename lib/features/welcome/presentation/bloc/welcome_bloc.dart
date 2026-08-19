import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/mixins/async_controller_mixin.dart';
import '../../domain/entities/welcome_info.dart';
import '../../domain/usecases/get_welcome_info.dart';

sealed class WelcomeEvent extends Equatable {
  const WelcomeEvent();
  @override
  List<Object?> get props => [];
}

final class WelcomeStarted extends WelcomeEvent {
  const WelcomeStarted();
}

enum WelcomeStatus { initial, loading, success, failure }

class WelcomeState extends Equatable {
  const WelcomeState({
    this.status = WelcomeStatus.initial,
    this.info,
    this.errorMessage,
    this.isConnectionError = false,
    this.activeOperations = const <String>{},
  });

  final WelcomeStatus status;
  final WelcomeInfo? info;
  final String? errorMessage;
  final bool isConnectionError;
  final Set<String> activeOperations;

  bool get isLoading => activeOperations.isNotEmpty;

  WelcomeState copyWith({
    WelcomeStatus? status,
    WelcomeInfo? info,
    String? errorMessage,
    bool? isConnectionError,
    Set<String>? activeOperations,
  }) => WelcomeState(
    status: status ?? this.status,
    info: info ?? this.info,
    errorMessage: errorMessage,
    isConnectionError: isConnectionError ?? this.isConnectionError,
    activeOperations: activeOperations ?? this.activeOperations,
  );

  @override
  List<Object?> get props => [
    status,
    info,
    errorMessage,
    isConnectionError,
    activeOperations,
  ];
}

class WelcomeBloc extends Bloc<WelcomeEvent, WelcomeState>
    with AsyncControllerMixin<WelcomeEvent, WelcomeState> {
  WelcomeBloc(this._getWelcomeInfo) : super(const WelcomeState()) {
    on<WelcomeStarted>(_onStarted);
  }

  final GetWelcomeInfo _getWelcomeInfo;

  Future<void> _onStarted(
    WelcomeStarted event,
    Emitter<WelcomeState> emit,
  ) async {
    await runControllerTask<WelcomeInfo>(
      key: 'load-welcome',
      emit: emit,
      task: _getWelcomeInfo.call,
      onLoadingChanged: (current, operations) => current.copyWith(
        status: operations.isEmpty ? current.status : WelcomeStatus.loading,
        activeOperations: operations,
      ),
      onSuccess: (current, info) => current.copyWith(
        status: WelcomeStatus.success,
        info: info,
        isConnectionError: false,
      ),
      onFailure: (current, error) => current.copyWith(
        status: WelcomeStatus.failure,
        errorMessage: error.message,
        isConnectionError: error.isConnectionError,
      ),
    );
  }
}
