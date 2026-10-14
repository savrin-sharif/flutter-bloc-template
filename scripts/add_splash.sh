#!/usr/bin/env bash
# Adds a static or Lottie-animated native splash screen to a project generated
# from flutter-bloc-template, including projects created before the initializer
# offered one. Run with --help for options.

if [[ -z "${BASH_VERSION:-}" ]]; then
  exec /usr/bin/env bash "$0" "$@"
fi

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/add_splash.sh [options]

Adds a native splash screen to a project generated from flutter-bloc-template.

  --style static|animated  static: native logo on a brand color.
                           animated: native color, then a fullscreen Flutter
                           SplashPage that plays a Lottie animation once.
  --color '#RRGGBB'        Splash color (default #4054B2).
  --dark-color '#RRGGBB'   Dark-mode splash color (default: the splash color).
  --logo PATH              960x960 PNG with the artwork inside the central
                           640 px circle (default: a placeholder logo).
  --project DIR            Project root (default: the current directory).
  --template DIR           flutter-bloc-template checkout that provides
                           modules/splash (default: this script's checkout,
                           $FLUTTER_BLOC_TEMPLATE, or a fresh clone).
  --skip-pub               Only edit files; skip pub get, native splash
                           generation, and formatting.
  -y, --yes                Use defaults for omitted options without prompting.
  -h, --help               Show this help.

Example:
  scripts/add_splash.sh --style animated --color '#1F2A5C'
EOF
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
warning() { printf 'Warning: %s\n' "$*" >&2; }
step() { printf '• %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_REPO="${TEMPLATE_REPO:-https://github.com/savrin-sharif/flutter-bloc-template.git}"
TEMPLATE_BRANCH="${TEMPLATE_BRANCH:-main}"
DEFAULT_COLOR='#4054B2'

STYLE=''
COLOR=''
DARK_COLOR=''
LOGO=''
LOGO_GIVEN=false
PROJECT_DIR="$PWD"
TEMPLATE_ARG=''
SKIP_PUB=false
ASSUME_DEFAULTS=false

while (( $# > 0 )); do
  case "$1" in
    --style|--color|--dark-color|--logo|--project|--template)
      (( $# >= 2 )) || die "$1 needs a value."
      case "$1" in
        --style) STYLE="$2" ;;
        --color) COLOR="$2" ;;
        --dark-color) DARK_COLOR="$2" ;;
        --logo) LOGO="$2"; LOGO_GIVEN=true ;;
        --project) PROJECT_DIR="$2" ;;
        --template) TEMPLATE_ARG="$2" ;;
      esac
      shift 2
      ;;
    --skip-pub) SKIP_PUB=true; shift ;;
    -y|--yes) ASSUME_DEFAULTS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown option: $1" ;;
  esac
done

INTERACTIVE=false
[[ -t 0 && "$ASSUME_DEFAULTS" != true ]] && INTERACTIVE=true

ask() {
  local label="$1" default="$2"
  read -r -p "$label [$default]: " ANSWER
  ANSWER="${ANSWER:-$default}"
}

show_cursor() {
  if [[ -t 1 ]]; then printf '\033[?25h'; fi
}
trap show_cursor EXIT

# Arrow-key menu: ↑/↓ move, Enter selects, Esc cancels. Sets MENU_INDEX.
select_one() {
  local options=("$@") count=$# index=0 key i first_render=true
  printf '\033[?25l'
  while true; do
    [[ "$first_render" == true ]] || printf '\033[%dA' "$count"
    first_render=false
    for i in "${!options[@]}"; do
      if (( i == index )); then
        printf '\033[2K  \033[1;36m❯ %s\033[0m\n' "${options[$i]}"
      else
        printf '\033[2K    %s\n' "${options[$i]}"
      fi
    done
    IFS= read -rsn1 key
    [[ -z "$key" ]] && break
    if [[ "$key" == $'\x1b' ]]; then
      if ! IFS= read -rsn1 -t 1 _ || ! IFS= read -rsn1 -t 1 key; then
        printf '\nCancelled.\n'
        exit 130
      fi
      [[ "$key" == A ]] && index=$(( (index - 1 + count) % count ))
      [[ "$key" == B ]] && index=$(( (index + 1) % count ))
    fi
  done
  show_cursor
  MENU_INDEX="$index"
}

normalize_color() {
  local value="$1"
  [[ "$value" == \#* ]] || value="#$value"
  [[ "$value" =~ ^#[0-9A-Fa-f]{6}$ ]] || return 1
  printf '%s' "$value" | tr '[:lower:]' '[:upper:]'
}

if [[ -z "$STYLE" ]]; then
  [[ "$INTERACTIVE" == true ]] || die '--style static|animated is required.'
  if [[ -t 1 ]]; then
    printf 'Splash style (↑/↓ to move, Enter to select, Esc to cancel):\n'
    select_one \
      'Animated — native color, then a Lottie splash page' \
      'Static — native logo on a brand color'
    if (( MENU_INDEX == 0 )); then STYLE=animated; else STYLE=static; fi
  else
    ask 'Splash style (static/animated)' 'animated'
    STYLE="$ANSWER"
  fi
fi
[[ "$STYLE" == static || "$STYLE" == animated ]] || die "Unknown style '$STYLE'; use static or animated."

if [[ -z "$COLOR" && "$INTERACTIVE" == true ]]; then
  ask 'Splash color' "$DEFAULT_COLOR"
  COLOR="$ANSWER"
fi
COLOR="$(normalize_color "${COLOR:-$DEFAULT_COLOR}")" || die 'Use a six-digit hex color such as #4054B2.'

if [[ -z "$DARK_COLOR" && "$INTERACTIVE" == true ]]; then
  ask 'Dark mode splash color' "$COLOR"
  DARK_COLOR="$ANSWER"
fi
DARK_COLOR="$(normalize_color "${DARK_COLOR:-$COLOR}")" || die 'Use a six-digit hex dark color such as #101820.'

if [[ "$LOGO_GIVEN" != true && "$INTERACTIVE" == true ]]; then
  read -r -p 'Logo PNG path (empty for the placeholder): ' LOGO
fi
if [[ -n "$LOGO" ]]; then
  LOGO="${LOGO/#\~/$HOME}"
  [[ -f "$LOGO" && ( "$LOGO" == *.png || "$LOGO" == *.PNG ) ]] || die "Logo '$LOGO' is not an existing .png file."
  LOGO="$(cd "$(dirname "$LOGO")" && pwd)/$(basename "$LOGO")"
fi

need perl
[[ -f "$PROJECT_DIR/pubspec.yaml" ]] || die "No pubspec.yaml in $PROJECT_DIR; run from the project root or pass --project."
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
[[ -d "$PROJECT_DIR/modules/splash" ]] && die 'This is the template itself; pass --project with a generated project.'
[[ -e "$PROJECT_DIR/native_splash.yaml" || -e "$PROJECT_DIR/lib/features/splash" ]] &&
  die 'This project already has a splash screen (native_splash.yaml or lib/features/splash).'
PACKAGE_NAME="$(perl -ne 'if (/^name:\s*(\S+)/) { print $1; exit }' "$PROJECT_DIR/pubspec.yaml")"
[[ -n "$PACKAGE_NAME" ]] || die 'Unable to read the package name from pubspec.yaml.'

BOOTSTRAP='lib/bootstrap.dart'
ROUTER='lib/core/router/app_router.dart'
[[ -f "$PROJECT_DIR/$BOOTSTRAP" ]] || die "Missing $BOOTSTRAP."
[[ "$STYLE" == static || -f "$PROJECT_DIR/$ROUTER" ]] || die "Missing $ROUTER."

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/add-splash.XXXXXX")"
APPLYING=false
CREATED=()

rollback() {
  local path
  printf 'Restoring the project files changed so far.\n' >&2
  for path in ${CREATED[@]+"${CREATED[@]}"}; do rm -rf "${PROJECT_DIR:?}/$path"; done
  [[ -d "$WORK_DIR/backup" ]] && cp -R "$WORK_DIR/backup/." "$PROJECT_DIR/"
}

on_exit() {
  local status=$?
  if [[ "$APPLYING" == true && "$status" -ne 0 ]]; then rollback; fi
  rm -rf "$WORK_DIR"
  show_cursor
}
trap on_exit EXIT

TEMPLATE_ROOT=''
for candidate in "$TEMPLATE_ARG" "${FLUTTER_BLOC_TEMPLATE:-}" "$SCRIPT_DIR/.."; do
  if [[ -n "$candidate" && -d "$candidate/modules/splash" ]]; then
    TEMPLATE_ROOT="$(cd "$candidate" && pwd)"
    break
  fi
done
if [[ -z "$TEMPLATE_ROOT" ]]; then
  [[ -z "$TEMPLATE_ARG" ]] || die "--template $TEMPLATE_ARG has no modules/splash."
  need git
  step "Downloading the splash module from $TEMPLATE_REPO"
  git clone --quiet --depth 1 --branch "$TEMPLATE_BRANCH" "$TEMPLATE_REPO" "$WORK_DIR/template" ||
    die 'Unable to download the template; pass --template with a local checkout.'
  TEMPLATE_ROOT="$WORK_DIR/template"
  [[ -d "$TEMPLATE_ROOT/modules/splash" ]] || die "Template branch '$TEMPLATE_BRANCH' has no modules/splash."
fi
MODULE_DIR="$TEMPLATE_ROOT/modules/splash"

backup_file() {
  [[ -f "$PROJECT_DIR/$1" ]] || return 0
  mkdir -p "$WORK_DIR/backup/$(dirname "$1")"
  cp "$PROJECT_DIR/$1" "$WORK_DIR/backup/$1"
}

track_created() {
  [[ -e "$PROJECT_DIR/$1" ]] || CREATED+=("$1")
}

# Applies a perl substitution to a project file and reports whether it matched.
try_patch() {
  perl -0777 -i -pe "\$n += ($2); END { exit(\$n ? 0 : 1) }" "$PROJECT_DIR/$1"
}

patch() {
  try_patch "$1" "$3" ||
    die "Could not $2 in $1. All changes were reverted; see AGENTS.md (Splash screen) to apply it by hand."
}

# Inserts the import alphabetically among imports of the same kind (dart:,
# package:, or relative), or after the last import when it is the first of its
# kind.
add_import() {
  local file="$1"
  grep -qF -- "$2" "$PROJECT_DIR/$file" && return 0
  export IMPORT_LINE="$2"
  perl -0777 -i -pe '
    sub kind { $_[0] =~ /^import \x27dart:/ ? 0 : $_[0] =~ /^import \x27package:/ ? 1 : 2 }
    my $new = "$ENV{IMPORT_LINE}\n";
    my @lines = split /(?<=\n)/;
    my ($before, $after_same, $after_any);
    for my $i (0 .. $#lines) {
      next unless $lines[$i] =~ /^import \x27/;
      $after_any = $i;
      next unless kind($lines[$i]) == kind($new);
      $after_same = $i;
      $before //= $i if $lines[$i] gt $new;
    }
    die "no imports\n" unless defined $after_any;
    my $at = defined $before ? $before : 1 + ($after_same // $after_any);
    splice @lines, $at, 0, $new;
    $_ = join q(), @lines;
  ' "$PROJECT_DIR/$file" || die "Could not add an import to $file."
}

add_dependency() {
  grep -qE "^  $1:" "$PROJECT_DIR/pubspec.yaml" && return 0
  export DEPENDENCY_LINE="  $1: $2"
  try_patch pubspec.yaml 's{^(dependencies:[ \t]*\n(?:[ \t]+[^\n]*\n)*)}{$1$ENV{DEPENDENCY_LINE}\n}m' ||
    patch pubspec.yaml "add $1" 's{^(dependencies:[ \t]*\n)}{$1$ENV{DEPENDENCY_LINE}\n}m'
}

platform_enabled() {
  [[ -d "$PROJECT_DIR/$1" ]] && printf 'true' || printf 'false'
}

splash_summary() {
  local style='Static' logo='placeholder logo'
  [[ "$STYLE" == animated ]] && style='Animated'
  [[ -n "$LOGO" ]] && logo="$(basename "$LOGO")"
  printf '%s — %s, dark %s, %s' "$style" "$COLOR" "$DARK_COLOR" "$logo"
}

update_agents_md() {
  local file="$PROJECT_DIR/AGENTS.md" section
  [[ -f "$file" ]] || return 0
  export SPLASH_ROW="| Splash screen | $(splash_summary) |"
  if grep -q '^| Splash screen |' "$file"; then
    perl -i -pe 's/^\| Splash screen \|.*$/$ENV{SPLASH_ROW}/' "$file"
  else
    perl -0777 -i -pe 's/^(\| Dart SDK constraint \|)/$ENV{SPLASH_ROW}\n$1/m' "$file"
  fi
  grep -q '^## Splash screen$' "$file" && return 0
  section="$(perl -0777 -ne 'print $1 if /^(## Splash screen\n.*?)\n+(?=^## )/ms' "$TEMPLATE_ROOT/AGENTS.md")"
  if [[ -z "$section" ]]; then
    warning 'The template AGENTS.md has no Splash screen section to copy.'
    return 0
  fi
  export SPLASH_SECTION="$section"
  perl -0777 -i -pe '
    $n = s/^(## (?:Dependency injection and routing|Keeping this file current)\n)/$ENV{SPLASH_SECTION}\n\n$1/m;
    $_ .= "\n$ENV{SPLASH_SECTION}\n" unless $n;
  ' "$file"
}

for file in pubspec.yaml "$BOOTSTRAP" "$ROUTER" AGENTS.md; do backup_file "$file"; done
APPLYING=true

step "Adding the $STYLE splash to $PACKAGE_NAME"
track_created assets/splash
mkdir -p "$PROJECT_DIR/assets/splash"
if [[ -n "$LOGO" ]]; then
  track_created assets/splash/logo.png
  cp "$LOGO" "$PROJECT_DIR/assets/splash/logo.png"
elif [[ ! -f "$PROJECT_DIR/assets/splash/logo.png" ]]; then
  track_created assets/splash/logo.png
  cp "$MODULE_DIR/logo.png" "$PROJECT_DIR/assets/splash/logo.png"
fi

add_dependency flutter_native_splash '^2.4.8'
add_import "$BOOTSTRAP" "import 'package:flutter_native_splash/flutter_native_splash.dart';"
patch "$BOOTSTRAP" 'keep the native splash during startup' \
  's{^([ \t]*)(?:final\s+(\w+)\s*=\s*)?WidgetsFlutterBinding\.ensureInitialized\(\);}{my $b = $2 // "widgetsBinding"; "$1final $b = WidgetsFlutterBinding.ensureInitialized();\n$1FlutterNativeSplash.preserve(widgetsBinding: $b);"}me'
patch "$BOOTSTRAP" 'remove the native splash after runApp' \
  's{^([ \t]*)(runApp\([^;]*\);)}{$1$2\n$1FlutterNativeSplash.remove();}m'

image_line=''
android_12_image_line=''
if [[ "$STYLE" == static ]]; then
  image_line=$'\n  image: assets/splash/logo.png'
  android_12_image_line=$'\n    image: assets/splash/logo.png'
else
  for path in lib/features/splash test/features/splash assets/splash/splash_animation.json; do
    track_created "$path"
  done
  cp -R "$MODULE_DIR/animated/." "$PROJECT_DIR/"
  export PACKAGE_NAME
  perl -i -pe 's/package:flutter_bloc_template\//package:$ENV{PACKAGE_NAME}\//g' \
    "$PROJECT_DIR/test/features/splash/presentation/pages/splash_page_test.dart"

  page='lib/features/splash/presentation/pages/splash_page.dart'
  export COLOR_LITERAL="Color(0xFF${COLOR#\#})" DARK_COLOR_LITERAL="Color(0xFF${DARK_COLOR#\#})"
  patch "$page" 'set the splash color' \
    's{(static const backgroundColor = )Color\(0xFF[0-9A-F]{6}\)}{$1$ENV{COLOR_LITERAL}}'
  patch "$page" 'set the dark splash color' \
    's{(static const darkBackgroundColor = )Color\(0xFF[0-9A-F]{6}\)}{$1$ENV{DARK_COLOR_LITERAL}}'

  add_dependency lottie '^3.3.1'
  if ! grep -qE '^    - assets/splash/?[ \t]*$' "$PROJECT_DIR/pubspec.yaml"; then
    try_patch pubspec.yaml 's{^(flutter:[ \t]*\n(?:(?:[ \t]+[^\n]*)?\n)*?  assets:[ \t]*\n(?:    -[^\n]*\n)*)}{$1    - assets/splash/\n}m' ||
      patch pubspec.yaml 'declare assets/splash/' 's{^(flutter:[ \t]*\n)}{$1  assets:\n    - assets/splash/\n}m'
  fi

  add_import "$BOOTSTRAP" "import 'package:lottie/lottie.dart';"
  add_import "$BOOTSTRAP" "import 'features/splash/presentation/pages/splash_page.dart';"
  try_patch "$BOOTSTRAP" 's{^([ \t]*)await (dotenv\.load\([^;]*\));}{$1await Future.wait<void>([\n$1  $2,\n$1  _prewarmSplashAnimation(),\n$1]);}m' ||
    patch "$BOOTSTRAP" 'prewarm the splash animation' \
      's{^([ \t]*)(FlutterNativeSplash\.preserve\([^;]*\);)}{$1$2\n$1await _prewarmSplashAnimation();}m'
  cat >> "$PROJECT_DIR/$BOOTSTRAP" <<'EOF'

/// Fills the shared Lottie cache so [SplashPage] receives its decoded
/// composition on its first frame instead of flashing an empty logo box.
Future<void> _prewarmSplashAnimation() async {
  try {
    await AssetLottie(SplashPage.animationAsset).load();
  } on Object {
    // SplashPage loads the asset itself and owns the failure fallback.
  }
}
EOF

  splash_path="'/splash'"
  if grep -q '^abstract final class AppRoutes {' "$PROJECT_DIR/$ROUTER"; then
    splash_path='AppRoutes.splash'
    patch "$ROUTER" 'add AppRoutes.splash' \
      's{^(abstract final class AppRoutes \{\n)}{$1  static const splash = \x27/splash\x27;\n}m'
  fi
  export SPLASH_PATH="$splash_path"
  next_route="$(perl -0777 -ne 'print $1 if /\binitialLocation:\s*([^,\n]+?)\s*,/' "$PROJECT_DIR/$ROUTER")"
  if [[ -n "$next_route" ]]; then
    patch "$ROUTER" 'start at the splash route' \
      's{\binitialLocation:\s*[^,\n]+?\s*,}{initialLocation: $ENV{SPLASH_PATH},}'
  else
    next_route="'/'"
    patch "$ROUTER" 'start at the splash route' \
      's{(\bGoRouter\()}{$1\n  initialLocation: $ENV{SPLASH_PATH},}'
  fi
  const_route_pattern="^(AppRoutes\.[A-Za-z_][A-Za-z0-9_]*|'[^']*')$"
  const_keyword=''
  [[ "$next_route" =~ $const_route_pattern ]] && const_keyword='const '
  export SPLASH_ROUTE="    GoRoute(
      path: $splash_path,
      builder: (context, state) => ${const_keyword}SplashPage(nextRoute: $next_route),
    ),
"
  patch "$ROUTER" 'register the splash route' 's{(\broutes:\s*\[[ \t]*\n)}{$1$ENV{SPLASH_ROUTE}}'
  add_import "$ROUTER" "import '../../features/splash/presentation/pages/splash_page.dart';"
fi

track_created native_splash.yaml
cat > "$PROJECT_DIR/native_splash.yaml" <<EOF
# Native launch screen shown while Flutter starts. After editing, regenerate the
# platform files with:
#   dart run flutter_native_splash:create --path=native_splash.yaml
flutter_native_splash:
  color: "$COLOR"
  color_dark: "$DARK_COLOR"$image_line
  android: $(platform_enabled android)
  ios: $(platform_enabled ios)
  web: $(platform_enabled web)
  fullscreen: false
  android_12:
    color: "$COLOR"
    color_dark: "$DARK_COLOR"$android_12_image_line
EOF

update_agents_md
APPLYING=false

if [[ "$SKIP_PUB" == true ]]; then
  step 'Files updated; skipped pub get and native splash generation.'
  exit 0
fi

need flutter
need dart
cd "$PROJECT_DIR"
step 'Resolving dependencies'
flutter pub get
if [[ -d android || -d ios || -d web ]]; then
  step 'Generating native launch screens'
  dart run flutter_native_splash:create --path=native_splash.yaml
else
  warning 'No Android, iOS, or web folder; native_splash.yaml was written but not applied.'
fi
dart_files=("$BOOTSTRAP")
[[ "$STYLE" == animated ]] && dart_files+=("$ROUTER" lib/features/splash test/features/splash)
dart format "${dart_files[@]}" >/dev/null

step "Added the $STYLE splash. Next: flutter analyze && flutter test"
[[ -z "$LOGO" ]] && step 'Replace assets/splash/logo.png (960x960) with the product logo, then rerun the native generation command in native_splash.yaml.'
[[ "$STYLE" == animated ]] && step 'Replace assets/splash/splash_animation.json with the product animation.'
exit 0
