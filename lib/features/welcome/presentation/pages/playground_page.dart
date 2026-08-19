import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../bloc/welcome_bloc.dart';

class PlaygroundPage extends StatelessWidget {
  const PlaygroundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isCupertino = AppConfig.designStyle == AppDesignStyle.cupertino;
    final body = const SafeArea(child: _WelcomeBody());

    if (isCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(AppConfig.appName)),
        child: body,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppConfig.appName)),
      body: body,
    );
  }
}

class _WelcomeBody extends StatelessWidget {
  const _WelcomeBody();

  @override
  Widget build(BuildContext context) {
    final isCupertino = AppConfig.designStyle == AppDesignStyle.cupertino;
    return BlocBuilder<WelcomeBloc, WelcomeState>(
      builder: (context, state) {
        if (state.status == WelcomeStatus.loading ||
            state.status == WelcomeStatus.initial) {
          return Center(
            child: isCupertino
                ? const CupertinoActivityIndicator()
                : const CircularProgressIndicator(),
          );
        }
        if (state.status == WelcomeStatus.failure) {
          return Center(
            child: Text(
              state.errorMessage ?? 'Unable to load the welcome page.',
            ),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.info!.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(state.info!.description, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
