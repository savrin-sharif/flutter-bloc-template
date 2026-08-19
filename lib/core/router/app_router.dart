import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/welcome/presentation/bloc/welcome_bloc.dart';
import '../../features/welcome/presentation/pages/welcome_page.dart';
import '../di/injection.dart';

abstract final class AppRoutes {
  static const welcome = '/';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<WelcomeBloc>()..add(const WelcomeStarted()),
        child: const WelcomePage(),
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
