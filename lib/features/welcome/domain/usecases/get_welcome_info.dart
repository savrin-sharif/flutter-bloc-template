import '../entities/welcome_info.dart';
import '../repositories/welcome_repository.dart';

class GetWelcomeInfo {
  const GetWelcomeInfo(this._repository);
  final WelcomeRepository _repository;

  Future<WelcomeInfo> call() => _repository.getWelcomeInfo();
}
