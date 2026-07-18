#!/usr/bin/env bash
# Creates a clean-architecture Flutter BLoC project from this template.

if [[ -z "${BASH_VERSION:-}" ]]; then
  exec /usr/bin/env bash "$0" "$@"
fi

set -euo pipefail

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

CYAN='\033[38;5;51m'
BLUE='\033[38;5;39m'
PURPLE='\033[38;5;141m'
GREEN='\033[38;5;84m'
RED='\033[38;5;203m'
MUTED='\033[38;5;245m'
BOLD='\033[1m'
RESET='\033[0m'
HIDE_CURSOR='\033[?25l'
SHOW_CURSOR='\033[?25h'
BLINK_CURSOR='\033[5 q'
DEFAULT_CURSOR='\033[0 q'
MODERN_UI=false
[[ -t 0 && -t 1 && "${TERM:-dumb}" != dumb && -z "${NO_COLOR:-}" ]] && MODERN_UI=true

restore_terminal() { [[ "$MODERN_UI" == true ]] && printf '%b%b' "$SHOW_CURSOR" "$DEFAULT_CURSOR"; }
trap restore_terminal EXIT INT TERM

show_intro() {
  [[ "$MODERN_UI" == true ]] || return 0

  if command -v durdraw >/dev/null 2>&1 &&
     [[ -n "${DURDRAW_INTRO_FILE:-}" ]] &&
     [[ -f "$DURDRAW_INTRO_FILE" ]]; then
    durdraw --256color --nomouse -x 1 -p "$DURDRAW_INTRO_FILE" || true
    return 0
  fi

  printf '\033[2J\033[H\n'
  printf '        %bF L U T T E R   B L O C%b\n' "$CYAN$BOLD" "$RESET"
  printf '        %bClean architecture. Your design system.%b\n\n' "$MUTED" "$RESET"
  printf '%b%b' "$SHOW_CURSOR" "$BLINK_CURSOR"
}

select_one() {
  local options=("$@") index=0 key first_render=true count=$# i
  printf '%b' "$HIDE_CURSOR"
  while true; do
    if [[ "$first_render" != true ]]; then printf '\033[%dA' "$count"; fi
    first_render=false
    for i in "${!options[@]}"; do
      printf '\033[2K'
      if [[ "$i" -eq "$index" ]]; then
        printf '        %b◆%b  %b%s%b\n' "$CYAN$BOLD" "$RESET" "$GREEN$BOLD" "${options[$i]}" "$RESET"
      else
        printf '        %b◇  %s%b\n' "$MUTED" "${options[$i]}" "$RESET"
      fi
    done

    IFS= read -rsn1 key
    [[ -z "$key" ]] && break
    if [[ "$key" == $'\x1b' ]]; then
      IFS= read -rsn1 _ || true
      IFS= read -rsn1 key || true
      [[ "$key" == A ]] && index=$(( (index - 1 + count) % count ))
      [[ "$key" == B ]] && index=$(( (index + 1) % count ))
    fi
  done
  SELECTED_INDEX="$index"
  printf '%b%b' "$SHOW_CURSOR" "$BLINK_CURSOR"
}

select_platforms() {
  local names=('Android' 'iOS' 'Web' 'Windows' 'macOS' 'Linux')
  local values=('android' 'ios' 'web' 'windows' 'macos' 'linux')
  local selected=(1 1 0 0 0 0) index=0 key first_render=true count=${#names[@]} i
  printf '        %b↑/↓ move  •  Space toggle  •  Enter continue%b\n\n' "$MUTED" "$RESET"
  printf '%b' "$HIDE_CURSOR"
  while true; do
    if [[ "$first_render" != true ]]; then printf '\033[%dA' "$count"; fi
    first_render=false
    for i in "${!names[@]}"; do
      local mark='○'
      [[ "${selected[$i]}" -eq 1 ]] && mark='●'
      printf '\033[2K'
      if [[ "$i" -eq "$index" ]]; then
        printf '        %b◆%b  ' "$CYAN$BOLD" "$RESET"
        if [[ "${selected[$i]}" -eq 1 ]]; then
          printf '%b%s  %s%b\n' "$GREEN$BOLD" "$mark" "${names[$i]}" "$RESET"
        else
          printf '%b%s  %s%b\n' "$CYAN$BOLD" "$mark" "${names[$i]}" "$RESET"
        fi
      elif [[ "${selected[$i]}" -eq 1 ]]; then
        printf '        %b◇%b  %b%s  %s%b\n' "$MUTED" "$RESET" "$GREEN$BOLD" "$mark" "${names[$i]}" "$RESET"
      else
        printf '        %b◇  %s  %s%b\n' "$MUTED" "$mark" "${names[$i]}" "$RESET"
      fi
    done

    IFS= read -rsn1 key
    [[ -z "$key" ]] && break
    if [[ "$key" == ' ' ]]; then
      selected[$index]=$((1 - selected[$index]))
    elif [[ "$key" == $'\x1b' ]]; then
      IFS= read -rsn1 _ || true
      IFS= read -rsn1 key || true
      [[ "$key" == A ]] && index=$(( (index - 1 + count) % count ))
      [[ "$key" == B ]] && index=$(( (index + 1) % count ))
    fi
  done

  SELECTED_PLATFORMS=''
  for i in "${!values[@]}"; do
    [[ "${selected[$i]}" -eq 1 ]] && SELECTED_PLATFORMS+="${values[$i]},"
  done
  SELECTED_PLATFORMS="${SELECTED_PLATFORMS%,}"
  [[ -n "$SELECTED_PLATFORMS" ]] || SELECTED_PLATFORMS='android,ios'
  printf '%b%b' "$SHOW_CURSOR" "$BLINK_CURSOR"
}

choose_language() {
  local role="$1" excluded="${2:-}" i selection
  local names=('English' 'Bengali' 'Spanish' 'Arabic' 'Hindi' 'French' 'German' 'Portuguese' 'Chinese' 'Japanese' 'Korean')
  local codes=('en' 'bn' 'es' 'ar' 'hi' 'fr' 'de' 'pt' 'zh' 'ja' 'ko')
  local menu_names=() menu_codes=()

  for i in "${!codes[@]}"; do
    if [[ "${codes[$i]}" != "$excluded" ]]; then
      menu_names+=("${names[$i]} — ${codes[$i]}")
      menu_codes+=("${codes[$i]}")
    fi
  done
  menu_names+=('Custom language or regional locale')
  menu_codes+=('custom')

  if [[ "$MODERN_UI" == true ]]; then
    printf '\n        %bChoose the %s language with ↑/↓ and Enter%b\n\n' "$MUTED" "$role" "$RESET"
    select_one "${menu_names[@]}"
    selection="$SELECTED_INDEX"
  else
    printf '\nChoose the %s language:\n' "$role"
    for i in "${!menu_names[@]}"; do printf '  %d) %s\n' "$((i + 1))" "${menu_names[$i]}"; done
    read -r -p 'Selection: ' selection
    [[ "$selection" =~ ^[0-9]+$ ]] || die 'Language selection must be a number.'
    selection=$((selection - 1))
    (( selection >= 0 && selection < ${#menu_codes[@]} )) || die 'Invalid language selection.'
  fi

  CHOSEN_LOCALE="${menu_codes[$selection]}"
  if [[ "$CHOSEN_LOCALE" == custom ]]; then
    if [[ "$MODERN_UI" == true ]]; then
      read_input 'Locale code (for example, it or en_US):'
      CHOSEN_LOCALE="$INPUT_VALUE"
    else
      read -r -p 'Locale code (for example, it or en_US): ' CHOSEN_LOCALE
    fi
    [[ "$CHOSEN_LOCALE" =~ ^[a-z]{2,3}(_[A-Z]{2})?$ ]] || die 'Invalid locale. Use en, bn, en_US, etc.'
    [[ "$CHOSEN_LOCALE" != "$excluded" ]] || die 'Primary and secondary languages must be different.'
  fi
}

section() {
  if [[ "$MODERN_UI" == true ]]; then
    printf '\n        %b%s%b  %s\n\n' "$PURPLE$BOLD" "$1" "$RESET" "$2"
  else
    printf '\n%s\n' "$2"
  fi
}

read_input() {
  local prompt="$1" value='' key cursor='▌'
  printf '%b%b' "$HIDE_CURSOR" "$BLINK_CURSOR"
  while true; do
    printf '\r\033[2K        %s %b%s%b%b%s%b' "$prompt" "$CYAN" "$value" "$RESET" "$CYAN" "$cursor" "$RESET"
    if IFS= read -rsn1 -t 1 key; then
      if [[ -z "$key" ]]; then
        break
      elif [[ "$key" == $'\x7f' || "$key" == $'\b' ]]; then
        [[ -n "$value" ]] && value="${value%?}"
      elif [[ "$key" != $'\x1b' ]]; then
        value+="$key"
      fi
      cursor='▌'
    else
      [[ "$cursor" == '▌' ]] && cursor=' ' || cursor='▌'
    fi
  done
  printf '\r\033[2K        %s %b%s%b\n' "$prompt" "$CYAN" "$value" "$RESET"
  printf '%b%b' "$SHOW_CURSOR" "$BLINK_CURSOR"
  INPUT_VALUE="$value"
}

run_step() {
  local label="$1"; shift
  if [[ "$MODERN_UI" != true ]]; then
    "$@"
    return
  fi

  local log_file="$TEMP_DIR/step.log" pid frame
  local frames=('◐' '◓' '◑' '◒')
  printf '%b' "$HIDE_CURSOR"
  "$@" >"$log_file" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    for frame in "${frames[@]}"; do
      kill -0 "$pid" 2>/dev/null || break
      printf '\r        %b%s%b  %-34s' "$CYAN" "$frame" "$RESET" "$label"
      sleep 0.09
    done
  done
  if wait "$pid"; then
    printf '\r        %b✓%b  %-34s\n' "$GREEN$BOLD" "$RESET" "$label"
  else
    printf '\r        %b✕%b  %s\n' "$RED$BOLD" "$RESET" "$label"
    tail -n 60 "$log_file" >&2
    exit 1
  fi
  printf '%b%b' "$SHOW_CURSOR" "$BLINK_CURSOR"
}

need flutter
need git
need perl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_TEMPLATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_REPO="${TEMPLATE_REPO:-https://github.com/savrin-sharif/flutter-bloc-template.git}"
TEMPLATE_BRANCH="${TEMPLATE_BRANCH:-main}"

show_intro
section '01' 'Name your Flutter playground'

if [[ "$MODERN_UI" == true ]]; then
  read_input 'Project name (for example, my_app):'
  PROJECT_NAME="$INPUT_VALUE"
else
  read -r -p 'Project name (for example, my_app): ' PROJECT_NAME
fi
[[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9_]*$ ]] || die 'Use lowercase letters, numbers, and underscores; start with a letter.'
[[ ! -e "$PROJECT_NAME" ]] || die "Folder '$PROJECT_NAME' already exists."

if [[ "$MODERN_UI" == true ]]; then
  read_input 'App title (for example, My Awesome App):'
  APP_TITLE="$INPUT_VALUE"
else
  read -r -p 'App title (for example, My Awesome App): ' APP_TITLE
fi
[[ -n "$APP_TITLE" ]] || die 'App title cannot be empty.'

if [[ "$MODERN_UI" == true ]]; then
  read_input 'PROD_URL [https://api.example.com]:'
  PROD_URL="$INPUT_VALUE"
  read_input 'DEV_URL [https://dev-api.example.com]:'
  DEV_URL="$INPUT_VALUE"
  read_input 'LOCAL_URL [http://localhost:8080]:'
  LOCAL_URL="$INPUT_VALUE"
else
  read -r -p 'PROD_URL [https://api.example.com]: ' PROD_URL
  read -r -p 'DEV_URL [https://dev-api.example.com]: ' DEV_URL
  read -r -p 'LOCAL_URL [http://localhost:8080]: ' LOCAL_URL
fi
PROD_URL="${PROD_URL:-https://api.example.com}"
DEV_URL="${DEV_URL:-https://dev-api.example.com}"
LOCAL_URL="${LOCAL_URL:-http://localhost:8080}"

section '02' 'Choose your design language'
if [[ "$MODERN_UI" == true ]]; then
  printf '        %bUse ↑/↓ and Enter%b\n\n' "$MUTED" "$RESET"
  select_one 'Material — MaterialApp + Scaffold' 'Cupertino — CupertinoApp + CupertinoPageScaffold'
  DESIGN_CHOICE=$((SELECTED_INDEX + 1))
else
  printf '  1) MaterialApp + Scaffold\n'
  printf '  2) CupertinoApp + CupertinoPageScaffold\n'
  read -r -p 'Selection [1]: ' DESIGN_CHOICE
fi
case "${DESIGN_CHOICE:-1}" in
  1|material|Material) DESIGN_STYLE='material' ;;
  2|cupertino|Cupertino) DESIGN_STYLE='cupertino' ;;
  *) die 'Design style must be 1 (Material) or 2 (Cupertino).' ;;
esac

section '03' 'Configure language support'
if [[ "$MODERN_UI" == true ]]; then
  printf '        %bUse ↑/↓ and Enter%b\n\n' "$MUTED" "$RESET"
  select_one 'Yes — generate ARB + gen-l10n' 'Later — stay dependency-light'
  [[ "$SELECTED_INDEX" -eq 0 ]] && BILINGUAL_CHOICE=y || BILINGUAL_CHOICE=n
else
  read -r -p 'Enable a bilingual localization system? [y/N]: ' BILINGUAL_CHOICE
fi
case "${BILINGUAL_CHOICE:-n}" in
  y|Y|yes|YES)
    ENABLE_BILINGUAL=true
    choose_language primary
    PRIMARY_LOCALE="$CHOSEN_LOCALE"
    choose_language secondary "$PRIMARY_LOCALE"
    SECONDARY_LOCALE="$CHOSEN_LOCALE"
    ;;
  n|N|no|NO|'') ENABLE_BILINGUAL=false ;;
  *) die 'Bilingual selection must be yes or no.' ;;
esac

section '04' 'Choose target platforms'
if [[ "$MODERN_UI" == true ]]; then
  select_platforms
  PLATFORMS="$SELECTED_PLATFORMS"
else
  read -r -p 'Platforms, comma-separated [android,ios]: ' PLATFORMS
  PLATFORMS="${PLATFORMS:-android,ios}"
fi
[[ "$PLATFORMS" =~ ^(android|ios|web|windows|macos|linux)(,(android|ios|web|windows|macos|linux))*$ ]] || die 'Invalid platform list.'

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/flutter-bloc-init.XXXXXX")"
trap 'restore_terminal; rm -rf "$TEMP_DIR"' EXIT INT TERM

if [[ -f "$LOCAL_TEMPLATE_DIR/pubspec.yaml" && -d "$LOCAL_TEMPLATE_DIR/lib" ]]; then
  TEMPLATE_DIR="$LOCAL_TEMPLATE_DIR"
else
  TEMPLATE_DIR="$TEMP_DIR/template"
  run_step 'Downloading template' git clone --depth 1 --branch "$TEMPLATE_BRANCH" "$TEMPLATE_REPO" "$TEMPLATE_DIR"
fi

section '05' 'Building your playground'
run_step 'Creating Flutter project' flutter create --platforms="$PLATFORMS" --project-name="$PROJECT_NAME" "$PROJECT_NAME"

for path in lib assets test scripts docs analysis_options.yaml README.md pubspec.yaml; do
  if [[ -e "$TEMPLATE_DIR/$path" ]]; then
    rm -rf "$PROJECT_NAME/$path"
    cp -R "$TEMPLATE_DIR/$path" "$PROJECT_NAME/$path"
  fi
done
if [[ "$MODERN_UI" == true ]]; then
  printf '        %b✓%b  %-34s\n' "$GREEN$BOLD" "$RESET" 'Applying clean architecture'
fi

perl -i -pe "s/^name: flutter_bloc_template\$/name: $PROJECT_NAME/" "$PROJECT_NAME/pubspec.yaml"
find "$PROJECT_NAME/lib" "$PROJECT_NAME/test" -type f -name '*.dart' -print0 |
  xargs -0 perl -i -pe "s/package:flutter_bloc_template/package:$PROJECT_NAME/g"

mkdir -p "$PROJECT_NAME/assets/envs"
cat > "$PROJECT_NAME/assets/envs/.env" <<EOF
APP_NAME=$APP_TITLE
PROD_URL=$PROD_URL
DEV_URL=$DEV_URL
LOCAL_URL=$LOCAL_URL
APP_DESIGN_STYLE=$DESIGN_STYLE
EOF

if [[ "$ENABLE_BILINGUAL" == true ]]; then
  [[ "$MODERN_UI" != true ]] && printf 'Adding %s/%s localization...\n' "$PRIMARY_LOCALE" "$SECONDARY_LOCALE"
  APP_TITLE_JSON="$(perl -MJSON::PP -e 'print encode_json($ARGV[0])' "$APP_TITLE")"

  perl -0777 -i -pe 's/(  flutter:\n    sdk: flutter\n)/$1  flutter_localizations:\n    sdk: flutter\n/' "$PROJECT_NAME/pubspec.yaml"
  perl -0777 -i -pe 's/(  flutter_dotenv:[^\n]*\n)/$1  intl: any\n/' "$PROJECT_NAME/pubspec.yaml"
  perl -0777 -i -pe 's/^flutter:\n/flutter:\n  generate: true\n/m' "$PROJECT_NAME/pubspec.yaml"

  mkdir -p "$PROJECT_NAME/lib/l10n"
  cat > "$PROJECT_NAME/l10n.yaml" <<EOF
arb-dir: lib/l10n
template-arb-file: app_$PRIMARY_LOCALE.arb
output-dir: lib/l10n/generated
output-localization-file: app_localizations.dart
nullable-getter: false
EOF

  cat > "$PROJECT_NAME/lib/l10n/app_$PRIMARY_LOCALE.arb" <<EOF
{
  "@@locale": "$PRIMARY_LOCALE",
  "appTitle": $APP_TITLE_JSON,
  "welcomeTitle": "Welcome!",
  "welcomeMessage": "Your Flutter playground awaits... 🎯"
}
EOF
  cat > "$PROJECT_NAME/lib/l10n/app_$SECONDARY_LOCALE.arb" <<EOF
{
  "@@locale": "$SECONDARY_LOCALE",
  "appTitle": $APP_TITLE_JSON,
  "welcomeTitle": "TODO: translate Welcome!",
  "welcomeMessage": "TODO: translate Your Flutter playground awaits... 🎯"
}
EOF

  cat > "$PROJECT_NAME/lib/app/app.dart" <<EOF
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:$PROJECT_NAME/l10n/generated/app_localizations.dart';

import '../core/config/app_config.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.designStyle == AppDesignStyle.cupertino) {
      return CupertinoApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.cupertino,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: appRouter,
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.materialLight,
      darkTheme: AppTheme.materialDark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
EOF

  perl -0777 -i -pe "s|(import '../../../../core/config/app_config.dart';)|import 'package:$PROJECT_NAME/l10n/generated/app_localizations.dart';\n\n\$1|" "$PROJECT_NAME/lib/features/home/presentation/pages/home_page.dart"
  perl -i -pe 's/state\.info!\.title/AppLocalizations.of(context).welcomeTitle/g; s/state\.info!\.description/AppLocalizations.of(context).welcomeMessage/g' "$PROJECT_NAME/lib/features/home/presentation/pages/home_page.dart"

  perl -0777 -i -pe "s|(import 'package:flutter_dotenv/flutter_dotenv.dart';)|import 'package:$PROJECT_NAME/l10n/generated/app_localizations.dart';\n\$1|" "$PROJECT_NAME/test/widget_test.dart"
  perl -0777 -i -pe 's/const MaterialApp\(home: HomePage\(\)\)/MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: const HomePage())/g; s/const CupertinoApp\(home: HomePage\(\)\)/CupertinoApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: const HomePage())/g' "$PROJECT_NAME/test/widget_test.dart"

  cat >> "$PROJECT_NAME/assets/envs/.env" <<EOF
PRIMARY_LOCALE=$PRIMARY_LOCALE
SECONDARY_LOCALE=$SECONDARY_LOCALE
EOF
fi

finalize_project() {
  cd "$PROJECT_NAME"
  flutter pub upgrade --major-versions
  if [[ "$ENABLE_BILINGUAL" == true ]]; then flutter gen-l10n; fi
  dart format lib test
  flutter analyze
  flutter test
}

run_step 'Resolving, analyzing, and testing' finalize_project

if [[ "$MODERN_UI" == true ]]; then
  printf '\n        %b╭──────────────────────────────────────────╮%b\n' "$GREEN" "$RESET"
  printf '        %b│  ✓  Your Flutter playground is ready.  │%b\n' "$GREEN$BOLD" "$RESET"
  printf '        %b╰──────────────────────────────────────────╯%b\n\n' "$GREEN" "$RESET"
  printf '        %b%s%b  •  %s' "$CYAN$BOLD" "$PROJECT_NAME" "$RESET" "$DESIGN_STYLE"
else
  printf '\nCreated %s successfully.\nDesign style: %s' "$PROJECT_NAME" "$DESIGN_STYLE"
fi
if [[ "$ENABLE_BILINGUAL" == true ]]; then
  printf '  •  %s + %s\n' "$PRIMARY_LOCALE" "$SECONDARY_LOCALE"
else
  printf '  •  localization-ready\n'
fi
if [[ "$MODERN_UI" == true ]]; then
  printf '        %bNext:%b cd %s && flutter run\n\n' "$MUTED" "$RESET" "$PROJECT_NAME"
else
  printf 'Run: cd %s && flutter run\n' "$PROJECT_NAME"
fi
