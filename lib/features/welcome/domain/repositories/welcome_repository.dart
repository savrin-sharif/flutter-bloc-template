import '../entities/welcome_info.dart';

abstract interface class WelcomeRepository {
  Future<WelcomeInfo> getWelcomeInfo();
}
