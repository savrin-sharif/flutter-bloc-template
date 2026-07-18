import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/bloc/home_bloc.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../di/injection.dart';

abstract final class AppRoutes {
  static const home = '/';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<HomeBloc>()..add(const HomeStarted()),
        child: const HomePage(),
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
