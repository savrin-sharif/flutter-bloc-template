# Flutter BLoC Template

A deliberately small, production-minded Flutter starter using BLoC and clean architecture. Its generator asks whether the new project should use Material or Cupertino while keeping one navigation graph for either choice.

## Included

- Feature-first clean architecture (`data`, `domain`, `presentation`)
- `flutter_bloc` for predictable state management
- A reusable async-controller mixin with keyed loading and normalized Dio errors
- `go_router` shared by `MaterialApp.router` and `CupertinoApp.router`
- Native `Scaffold`/Material controls and `CupertinoPageScaffold`/Cupertino controls
- Material/Cupertino design choice during project generation
- Optional two-language ARB/gen-l10n setup during project generation
- Optional static or Lottie-animated native splash screen during project generation
- `get_it` dependency composition in one place
- Configurable environment values with `flutter_dotenv`
- A configured Dio client with an interceptor slot for authentication
- Typed `Failure`s (connection, unauthorized, validation with field errors, not found, conflict, server) parsed from common REST error bodies
- An app-wide `ConnectivityService` that confirms "offline" reports with a reachability probe and recovers when the server answers
- A debug-only HTTP logger that redacts tokens, passwords, cookies, and API keys, including inside JSON strings and multipart fields
- Material and Cupertino widget tests
- Android, iOS, web, Windows, macOS, and Linux runners

The reference GetX project also contains Firebase services, attachment and image pickers, searchable dropdowns, custom form controls, snack bars, and app-specific validation. They are intentionally omitted here: a template should not force unused SDKs, permissions, UI abstractions, or regional business rules into every app.

## Generate a project

From this repository, run:

```sh
./scripts/flutter-bloc-init.sh
```

The initializer prompts for the project name, app title, production/development/local URLs, optional complete package identifier, design style, optional bilingual support, target platforms, and an optional splash screen. The package step can retain Flutter's generated `com.example.<project_name>` default or accept an exact reverse-domain identifier such as `app.rydr.drive`; the project name is not appended to a custom identifier. When bilingual support is selected, human-readable menus are shown for the primary and secondary languages; locale codes are assigned automatically. A custom-locale option supports additional languages and regional variants. The generator then creates ARB files and Flutter localization wiring, upgrades dependencies, and runs formatting, analysis, and tests.

The entered app title is the single display-name source: it is written to `APP_NAME` and synchronized with the generated Android, iOS, macOS, web, Windows, and Linux metadata.

Each generated `pubspec.yaml` receives its Dart SDK constraint from the active Flutter toolchain instead of retaining the template's minimum SDK version. For example, an installed Dart `3.13.0` produces `sdk: ^3.13.0`.

Interactive terminals receive the color interface, blinking input cursor, keyboard menus, and animated progress indicators. During initial text setup, ↑ or ← returns to the previous field. Every later menu provides access to completed configuration sections, allowing individual values to be changed without clearing other selections. Use ↑/↓ and Enter for menu choices; the platform checklist uses Space to toggle and B to edit previous configuration. Before generation, a review screen also lets users revisit any section repeatedly. Press Esc or Ctrl+C to exit at any time. Failed Git or Flutter steps show Retry and Exit choices instead of terminating immediately. CI and plain output provide equivalent editing, review, retry, and exit prompts.

The design prompt offers:

1. `MaterialApp.router` with Material `Scaffold` and controls
2. `CupertinoApp.router` with `CupertinoPageScaffold` and Cupertino controls

The choice is written to `APP_DESIGN_STYLE`; there is intentionally no runtime settings page or settings state dependency.

If bilingual support is declined, no localization dependencies are installed. The app remains localization-ready through its centralized app root and presentation boundaries; follow `docs/ADDING_LOCALIZATION.md` to add it later.

The splash prompt offers:

1. **None** (default): the platform launch screen; no splash dependencies.
2. **Static**: a native launch screen with a logo on a brand color, kept visible until startup finishes.
3. **Animated**: a color-only native launch screen followed by a fullscreen Flutter `SplashPage` that plays a Lottie animation once, then navigates.

Static and Animated ask for a splash color (default `#4054B2`, the theme seed), a dark-mode color, and an optional 960×960 logo PNG; a placeholder logo and animation are used otherwise. The generator writes `native_splash.yaml` and runs `flutter_native_splash` for the selected Android, iOS, and web targets. The splash sources live in `modules/splash/` and are copied only into projects that select them.

## Run this template directly

```sh
flutter pub get
flutter run
```

Configuration lives in `assets/envs/.env`:

```dotenv
APP_NAME=Flutter BLoC Template
PROD_URL=https://api.example.com
DEV_URL=https://dev-api.example.com
LOCAL_URL=http://localhost:8080
APP_DESIGN_STYLE=material
```

Set `APP_DESIGN_STYLE` to `material` or `cupertino`. Normally the initializer writes this value based on the user's design prompt.

Endpoint selection is build-safe:

- Release builds always use `PROD_URL`, even if an `APP_ENV` override is supplied.
- Debug and profile builds use `DEV_URL` by default.
- Use the local server in a non-release build with `flutter run --dart-define=APP_ENV=local`, or comment out `DEV_URL` while `LOCAL_URL` is set.
- Blank values (`DEV_URL=`) are treated as missing.

Additional hosts, such as a socket server or CDN, follow the same rules through `AppConfig.environmentUrl('WS_URL')`, which reads `PROD_WS_URL`, `DEV_WS_URL`, or `LOCAL_WS_URL` and falls back to a shared `WS_URL`.

On an Android emulator, `localhost` points to the emulator itself; set `LOCAL_URL` to `http://10.0.2.2:<port>` when the server runs on the host machine.

## Structure

```text
lib/
├── app/                         # Root app and app-wide state
├── core/
│   ├── config/                  # Environment-backed configuration
│   ├── di/                      # Composition root
│   ├── errors/                  # Typed failures
│   ├── logging/                 # LoggerService and HTTP logger interceptor
│   ├── network/                 # Dio, API error parsing, and connectivity
│   ├── presentation/mixins/     # Reusable, UI-independent BLoC behavior
│   ├── router/                  # Style-agnostic route graph
│   └── theme/                   # Material and Cupertino themes
├── features/
│   ├── welcome/                 # Generic generated-project landing feature
│   │   ├── data/                # Data sources and repository implementations
│   │   ├── domain/              # Entities, contracts, and use cases
│   │   └── presentation/        # BLoCs and pages
├── bootstrap.dart               # Async startup
└── main.dart                    # Entry point
```

Dependencies point inward: presentation uses domain; data implements domain contracts; domain does not import Flutter or infrastructure. `core/di/injection.dart` is the only place that assembles implementations.

Feature BLoCs can use `AsyncControllerMixin` to run named operations with immutable loading snapshots and guaranteed cleanup. Failures reach the BLoC as a `ControllerError` with a user-safe message, `isConnectionError`, per-field `fieldErrors`, the HTTP `statusCode`, and the typed `failure`. Repositories may throw a `Failure` directly; a raw `DioException` is converted with `Failure.fromDioException`. The mixin intentionally does not show snack bars, validate forms, or own `TextEditingController`s; those remain UI responsibilities.

`ConnectivityService.isOnline` is a `ValueListenable<bool>` for offline banners and retry prompts. Every server response, including error statuses, marks the app as online.

## Add a feature

1. Create `features/<name>/domain` first: entities, repository interfaces, and focused use cases.
2. Add implementations under `data`, keeping JSON/network details out of domain entities.
3. Add BLoCs and pages under `presentation`.
4. Register constructors in `core/di/injection.dart` and routes in `core/router/app_router.dart`.
5. Test use cases/BLoCs without Flutter, then test both visual modes for adaptive pages.

Avoid creating a shared widget merely because a Flutter widget is used twice. Promote it only when it represents stable app-wide behavior or design language.

## AI agent instructions

[`AGENTS.md`](AGENTS.md) holds the architecture, API, UI, and testing rules for AI coding agents. Cursor, Codex, and other agents that support the `AGENTS.md` convention load it automatically; for other tools, paste it into the model first. Include the real endpoint documentation and acceptance criteria with each feature request so the agent follows the API contract instead of inventing request or response fields.

The initializer stamps the generated `AGENTS.md` with the reviewed project name, app title, package identifier, Material/Cupertino selection, localization choice, target platforms, splash screen mode, and Dart SDK constraint.

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
