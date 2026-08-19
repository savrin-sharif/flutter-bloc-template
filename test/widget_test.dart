import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_template/core/config/app_config.dart';
import 'package:flutter_bloc_template/features/welcome/domain/entities/welcome_info.dart';
import 'package:flutter_bloc_template/features/welcome/domain/repositories/welcome_repository.dart';
import 'package:flutter_bloc_template/features/welcome/domain/usecases/get_welcome_info.dart';
import 'package:flutter_bloc_template/features/welcome/presentation/bloc/welcome_bloc.dart';
import 'package:flutter_bloc_template/features/welcome/presentation/pages/playground_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements WelcomeRepository {
  @override
  Future<WelcomeInfo> getWelcomeInfo() async => const WelcomeInfo(
    title: 'Welcome!',
    description: 'Your Flutter playground awaits... 🎯',
  );
}

void main() {
  for (final style in AppDesignStyle.values) {
    testWidgets('renders the playground in ${style.name} mode', (tester) async {
      dotenv.loadFromString(envString: 'APP_DESIGN_STYLE=${style.name}');
      final bloc = WelcomeBloc(GetWelcomeInfo(_FakeRepository()))
        ..add(const WelcomeStarted());

      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: style == AppDesignStyle.material
              ? const MaterialApp(home: PlaygroundPage())
              : const CupertinoApp(home: PlaygroundPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('Your Flutter playground awaits... 🎯'), findsOneWidget);
      expect(find.textContaining('counter'), findsNothing);
    });
  }
}
