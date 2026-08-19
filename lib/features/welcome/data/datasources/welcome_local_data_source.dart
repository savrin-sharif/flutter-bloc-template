import '../../domain/entities/welcome_info.dart';

abstract interface class WelcomeLocalDataSource {
  Future<WelcomeInfo> load();
}

class WelcomeLocalDataSourceImpl implements WelcomeLocalDataSource {
  @override
  Future<WelcomeInfo> load() async => const WelcomeInfo(
    title: 'Welcome!',
    description: 'Your Flutter playground awaits... 🎯',
  );
}
