import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../core/config/app_config.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.designStyle == AppDesignStyle.cupertino) {
      return CupertinoApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.cupertino,
        // Material widgets used inside Cupertino routes (text fields,
        // date pickers, etc.) require MaterialLocalizations from material_ui.
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: appRouter,
        builder: AppTheme.withSystemUiOverlay,
      );
    }

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.materialLight,
      darkTheme: AppTheme.materialDark,
      routerConfig: appRouter,
      builder: AppTheme.withSystemUiOverlay,
    );
  }
}
