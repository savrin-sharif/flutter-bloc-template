import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bloc_template/core/config/app_config.dart';
import 'package:flutter_bloc_template/features/home/domain/entities/template_info.dart';
import 'package:flutter_bloc_template/features/home/domain/repositories/template_repository.dart';
import 'package:flutter_bloc_template/features/home/domain/usecases/get_template_info.dart';
import 'package:flutter_bloc_template/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter_bloc_template/features/home/presentation/pages/home_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements TemplateRepository {
  @override
  Future<TemplateInfo> getTemplateInfo() async => const TemplateInfo(
    title: 'Welcome!',
    description: 'Your Flutter playground awaits... 🎯',
  );
}

void main() {
  for (final style in AppDesignStyle.values) {
    testWidgets('renders the playground in ${style.name} mode', (tester) async {
      dotenv.loadFromString(envString: 'APP_DESIGN_STYLE=${style.name}');
      final bloc = HomeBloc(GetTemplateInfo(_FakeRepository()))
        ..add(const HomeStarted());

      await tester.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: style == AppDesignStyle.material
              ? const MaterialApp(home: HomePage())
              : const CupertinoApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('Your Flutter playground awaits... 🎯'), findsOneWidget);
      expect(find.textContaining('counter'), findsNothing);
    });
  }
}
