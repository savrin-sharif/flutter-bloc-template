import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/welcome/presentation/bloc/welcome_bloc.dart';
import '../../features/welcome/presentation/pages/playground_page.dart';
import '../di/injection.dart';

abstract final class AppRoutes {
  static const playground = '/play-ground';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.playground,
  routes: [
    GoRoute(
      path: AppRoutes.playground,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<WelcomeBloc>()..add(const WelcomeStarted()),
        child: const PlaygroundPage(),
      ),
    ),
  ],
  errorBuilder: (context, state) => ErrorPage(message: state.error.toString()),
);

class ErrorPage extends StatelessWidget {
  const ErrorPage({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}
