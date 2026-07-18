import '../../domain/entities/template_info.dart';
import '../../domain/repositories/template_repository.dart';
import '../datasources/template_local_data_source.dart';

class TemplateRepositoryImpl implements TemplateRepository {
  const TemplateRepositoryImpl(this._localDataSource);
  final TemplateLocalDataSource _localDataSource;

  @override
  Future<TemplateInfo> getTemplateInfo() => _localDataSource.load();
}
