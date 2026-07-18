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

2. Add `l10n.yaml` and ARB files under `lib/l10n/`.
3. Run `flutter gen-l10n`.
4. Add the generated `localizationsDelegates` and `supportedLocales` to both branches in `lib/app/app.dart`.
5. Read translated presentation text with `AppLocalizations.of(context)`. Keep translated strings out of domain entities and data sources.

You can also rerun `scripts/flutter-bloc-init.sh` for a new project and answer **yes** to its bilingual prompt to generate this setup automatically.
