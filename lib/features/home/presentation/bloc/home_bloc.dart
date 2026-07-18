import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/mixins/async_controller_mixin.dart';
import '../../domain/entities/template_info.dart';
import '../../domain/usecases/get_template_info.dart';

sealed class HomeEvent extends Equatable {
  const HomeEvent();
  @override
  List<Object?> get props => [];
}

final class HomeStarted extends HomeEvent {
  const HomeStarted();
}

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.info,
    this.errorMessage,
    this.isConnectionError = false,
    this.activeOperations = const <String>{},
  });

  final HomeStatus status;
  final TemplateInfo? info;
  final String? errorMessage;
  final bool isConnectionError;
  final Set<String> activeOperations;

  bool get isLoading => activeOperations.isNotEmpty;

  HomeState copyWith({
    HomeStatus? status,
    TemplateInfo? info,
    String? errorMessage,
    bool? isConnectionError,
    Set<String>? activeOperations,
  }) => HomeState(
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

class HomeBloc extends Bloc<HomeEvent, HomeState>
    with AsyncControllerMixin<HomeEvent, HomeState> {
  HomeBloc(this._getTemplateInfo) : super(const HomeState()) {
    on<HomeStarted>(_onStarted);
  }

  final GetTemplateInfo _getTemplateInfo;

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    await runControllerTask<TemplateInfo>(
      key: 'load-home',
      emit: emit,
      task: _getTemplateInfo.call,
      onLoadingChanged: (current, operations) => current.copyWith(
        status: operations.isEmpty ? current.status : HomeStatus.loading,
        activeOperations: operations,
      ),
      onSuccess: (current, info) => current.copyWith(
        status: HomeStatus.success,
        info: info,
        isConnectionError: false,
      ),
      onFailure: (current, error) => current.copyWith(
        status: HomeStatus.failure,
        errorMessage: error.message,
        isConnectionError: error.isConnectionError,
      ),
    );
  }
}
