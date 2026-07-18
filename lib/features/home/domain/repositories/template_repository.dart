import '../entities/template_info.dart';

abstract interface class TemplateRepository {
  Future<TemplateInfo> getTemplateInfo();
}
