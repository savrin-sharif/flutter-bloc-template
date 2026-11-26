# Adding localization later

The template keeps routing, themes, dependency injection, and features independent from localization, so enabling it later does not require restructuring the application.

1. Add Flutter's SDK localization package and `intl`:

   ```yaml
   dependencies:
     flutter_localizations:
       sdk: flutter
     intl: any

   flutter:
     generate: true
   ```

2. Add `l10n.yaml` and ARB files under `lib/l10n/`. Until Flutter's
   `gen-l10n` emits standalone design-package delegates, include:

   ```yaml
   header: '// ignore_for_file: deprecated_member_use'
   ```

3. Run `flutter gen-l10n`.
4. In both branches of `lib/app/app.dart`, pass
   `[AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates]`
   (from `package:material_ui`) plus `AppLocalizations.supportedLocales`.
   Do not use `AppLocalizations.localizationsDelegates` on Flutter 3.50 —
   that list still wires deprecated `flutter_localizations` Material/Cupertino
   delegates that do not satisfy `material_ui` / `cupertino_ui`.
5. Read translated presentation text with `AppLocalizations.of(context)`. Keep translated strings out of domain entities and data sources.

You can also use the template initializer to create a new project and answer **yes** to its bilingual prompt to generate this setup automatically. The initializer itself is intentionally not copied into generated projects.
