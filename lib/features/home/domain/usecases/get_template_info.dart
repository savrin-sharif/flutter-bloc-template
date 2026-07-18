import '../entities/template_info.dart';
import '../repositories/template_repository.dart';

class GetTemplateInfo {
  const GetTemplateInfo(this._repository);
  final TemplateRepository _repository;

  Future<TemplateInfo> call() => _repository.getTemplateInfo();
}
