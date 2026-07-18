import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  });

  final HomeStatus status;
  final TemplateInfo? info;
  final String? errorMessage;

  HomeState copyWith({
    HomeStatus? status,
    TemplateInfo? info,
    String? errorMessage,
  }) => HomeState(
    status: status ?? this.status,
    info: info ?? this.info,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [status, info, errorMessage];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(this._getTemplateInfo) : super(const HomeState()) {
    on<HomeStarted>(_onStarted);
  }

  final GetTemplateInfo _getTemplateInfo;

  Future<void> _onStarted(HomeStarted event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      emit(
        state.copyWith(
          status: HomeStatus.success,
          info: await _getTemplateInfo(),
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          status: HomeStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
