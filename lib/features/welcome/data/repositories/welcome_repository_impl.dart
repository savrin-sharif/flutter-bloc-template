import '../../domain/entities/welcome_info.dart';
import '../../domain/repositories/welcome_repository.dart';
import '../datasources/welcome_local_data_source.dart';

class WelcomeRepositoryImpl implements WelcomeRepository {
  const WelcomeRepositoryImpl(this._localDataSource);
  final WelcomeLocalDataSource _localDataSource;

  @override
  Future<WelcomeInfo> getWelcomeInfo() => _localDataSource.load();
}
