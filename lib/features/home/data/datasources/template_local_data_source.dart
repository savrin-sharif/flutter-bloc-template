import '../../domain/entities/template_info.dart';

abstract interface class TemplateLocalDataSource {
  Future<TemplateInfo> load();
}

class TemplateLocalDataSourceImpl implements TemplateLocalDataSource {
  @override
  Future<TemplateInfo> load() async => const TemplateInfo(
    title: 'Welcome!',
    description: 'Your Flutter playground awaits... 🎯',
  );
}
