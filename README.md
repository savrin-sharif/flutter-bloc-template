# Flutter BLoC Template

A deliberately small, production-minded Flutter starter using BLoC and clean architecture. Its generator asks whether the new project should use Material or Cupertino while keeping one navigation graph for either choice.

## Included

- Feature-first clean architecture (`data`, `domain`, `presentation`)
- `flutter_bloc` for predictable state management
- `go_router` shared by `MaterialApp.router` and `CupertinoApp.router`
- Native `Scaffold`/Material controls and `CupertinoPageScaffold`/Cupertino controls
- Material/Cupertino design choice during project generation
- Optional two-language ARB/gen-l10n setup during project generation
- `get_it` dependency composition in one place
- Configurable environment values with `flutter_dotenv`
- A configured Dio client and connectivity abstraction
- Material and Cupertino widget tests
- Android, iOS, web, Windows, macOS, and Linux runners

The reference GetX project also contains Firebase services, attachment and image pickers, searchable dropdowns, custom form controls, snack bars, and app-specific validation. They are intentionally omitted here: a template should not force unused SDKs, permissions, UI abstractions, or regional business rules into every app.

## Generate a project

From this repository, run:

```sh
./scripts/flutter-bloc-init.sh
```

The initializer prompts for the project name, app title, base URL, design style, optional bilingual support, and target platforms. When bilingual support is selected, it asks for primary and secondary locale codes and generates ARB files plus Flutter localization wiring. It then upgrades dependencies and runs formatting, analysis, and tests.

Interactive terminals receive the animated color interface and progress indicators. CI, redirected output, `TERM=dumb`, and `NO_COLOR=1` automatically use plain output. Durdraw is optional; set `DURDRAW_INTRO_FILE=/path/to/intro.dur` to replace the built-in intro with a custom Durdraw animation.

The design prompt offers:

1. `MaterialApp.router` with Material `Scaffold` and controls
2. `CupertinoApp.router` with `CupertinoPageScaffold` and Cupertino controls

The choice is written to `APP_DESIGN_STYLE`; there is intentionally no runtime settings page or settings state dependency.

If bilingual support is declined, no localization dependencies are installed. The app remains localization-ready through its centralized app root and presentation boundaries; follow `docs/ADDING_LOCALIZATION.md` to add it later.

## Run this template directly

```sh
flutter pub get
flutter run
```

Configuration lives in `assets/envs/.env`:

```dotenv
APP_NAME=Flutter BLoC Template
BASE_URL=https://example.com
APP_DESIGN_STYLE=material
```

Set `APP_DESIGN_STYLE` to `material` or `cupertino`. Normally the initializer writes this value based on the user's design prompt.

## Structure

```text
lib/
├── app/                         # Root app and app-wide state
├── core/
│   ├── config/                  # Environment-backed configuration
│   ├── di/                      # Composition root
│   ├── errors/                  # Shared failure types
│   ├── network/                 # Dio and connectivity infrastructure
│   ├── router/                  # Style-agnostic route graph
│   └── theme/                   # Material and Cupertino themes
├── features/
│   ├── home/
│   │   ├── data/                # Data sources and repository implementations
│   │   ├── domain/              # Entities, contracts, and use cases
│   │   └── presentation/        # BLoCs and pages
├── bootstrap.dart               # Async startup
└── main.dart                    # Entry point
```

Dependencies point inward: presentation uses domain; data implements domain contracts; domain does not import Flutter or infrastructure. `core/di/injection.dart` is the only place that assembles implementations.

## Add a feature

1. Create `features/<name>/domain` first: entities, repository interfaces, and focused use cases.
2. Add implementations under `data`, keeping JSON/network details out of domain entities.
3. Add BLoCs and pages under `presentation`.
4. Register constructors in `core/di/injection.dart` and routes in `core/router/app_router.dart`.
5. Test use cases/BLoCs without Flutter, then test both visual modes for adaptive pages.

Avoid creating a shared widget merely because a Flutter widget is used twice. Promote it only when it represents stable app-wide behavior or design language.

## Verify

```sh
flutter analyze
flutter test
```

## Release scripts

- `scripts/release_aab.sh` bumps the version and builds a Play Store AAB.
- `scripts/release_bumper.sh` bumps the version and builds split-per-ABI APKs.
- `scripts/release_ios.sh` bumps the version and builds an IPA.

Each script is standalone. They run analysis and tests first and generate release notes. They do not commit, tag, or push automatically.
