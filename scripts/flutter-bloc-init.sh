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
WARNING='\033[38;5;214m'
MUTED='\033[38;5;245m'
BOLD='\033[1m'
RESET='\033[0m'
HIDE_CURSOR='\033[?25l'
SHOW_CURSOR='\033[?25h'
BLINK_CURSOR='\033[5 q'
DEFAULT_CURSOR='\033[0 q'
MODERN_UI=false
[[ -t 0 && -t 1 && "${TERM:-dumb}" != dumb && -z "${NO_COLOR:-}" ]] && MODERN_UI=true

warning() {
  if [[ "$MODERN_UI" == true ]]; then
    printf '%b⚠  %s%b\n' "$WARNING$BOLD" "$*" "$RESET" >&2
  else
    printf 'Warning: %s\n' "$*" >&2
  fi
}

restore_terminal() { [[ "$MODERN_UI" == true ]] && printf '%b%b' "$SHOW_CURSOR" "$DEFAULT_CURSOR"; }
exit_program() {
  restore_terminal
  printf '\nInitializer closed.\n'
  exit 0
}
interrupt_program() {
  restore_terminal
  printf '\nInitializer cancelled.\n' >&2
  exit 130
}
exit_if_requested() { [[ "${1:-}" == exit || "${1:-}" == quit ]] && exit_program || true; }
trap restore_terminal EXIT
trap interrupt_program INT TERM

show_intro() {
  [[ "$MODERN_UI" == true ]] || return 0

  printf '\033[2J\033[H'
  printf '%b╭──────────────────────────────────────────╮%b\n' "$CYAN" "$RESET"
  printf '%b│                                          │%b\n' "$CYAN" "$RESET"
  printf '%b│          F L U T T E R   B L O C         │%b\n' "$CYAN$BOLD" "$RESET"
  printf '%b│                                          │%b\n' "$CYAN" "$RESET"
  printf '%b╰──────────────────────────────────────────╯%b\n' "$CYAN" "$RESET"
  printf '%bGenerate a configurable clean-architecture Flutter BLoC project.%b\n\n' "$MUTED" "$RESET"
  printf '%bEsc or Ctrl+C exits at any time.%b\n\n' "$MUTED" "$RESET"
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
      if ! IFS= read -rsn1 -t 1 _; then exit_program; fi
      if ! IFS= read -rsn1 -t 1 key; then exit_program; fi
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
  printf '        %b↑/↓ move  •  Space toggle  •  Enter continue  •  B edit previous%b\n\n' "$MUTED" "$RESET"
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
    elif [[ "$key" == b || "$key" == B ]]; then
      edit_previous_configuration
      printf '\n        %b↑/↓ move  •  Space toggle  •  Enter continue  •  B edit previous%b\n\n' "$MUTED" "$RESET"
      first_render=true
    elif [[ "$key" == $'\x1b' ]]; then
      if ! IFS= read -rsn1 -t 1 _; then exit_program; fi
      if ! IFS= read -rsn1 -t 1 key; then exit_program; fi
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
  menu_names+=('← Edit project details' 'Exit initializer')
  menu_codes+=('back' 'exit')

  if [[ "$MODERN_UI" == true ]]; then
    printf '\n        %bChoose the %s language with ↑/↓ and Enter%b\n\n' "$MUTED" "$role" "$RESET"
    select_one "${menu_names[@]}"
    selection="$SELECTED_INDEX"
else
    printf '\nChoose the %s language (0 exits):\n' "$role"
    for i in "${!menu_names[@]}"; do printf '  %d) %s\n' "$((i + 1))" "${menu_names[$i]}"; done
    while true; do
      read -r -p 'Selection: ' selection
      [[ "$selection" == 0 ]] && exit_program
      if [[ "$selection" =~ ^[0-9]+$ ]]; then
        selection=$((selection - 1))
        (( selection >= 0 && selection < ${#menu_codes[@]} )) && break
      fi
      warning 'Invalid selection. Please try again.'
    done
  fi

  CHOSEN_LOCALE="${menu_codes[$selection]}"
  if [[ "$CHOSEN_LOCALE" == back ]]; then
    edit_project_details
    choose_language "$role" "$excluded"
    return
  fi
  [[ "$CHOSEN_LOCALE" == exit ]] && exit_program
  if [[ "$CHOSEN_LOCALE" == custom ]]; then
    while true; do
      if [[ "$MODERN_UI" == true ]]; then
        read_input 'Locale code (for example, it or en_US):'
        [[ "$INPUT_ACTION" == back ]] && { edit_project_details; continue; }
        CHOSEN_LOCALE="$INPUT_VALUE"
      else
        read -r -p 'Locale code (or "exit"): ' CHOSEN_LOCALE
        exit_if_requested "$CHOSEN_LOCALE"
      fi
      if [[ "$CHOSEN_LOCALE" =~ ^[a-z]{2,3}(_[A-Z]{2})?$ && "$CHOSEN_LOCALE" != "$excluded" ]]; then break; fi
      warning 'Invalid or duplicate locale. Please try again.'
    done
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
  local prompt="$1" value="${2:-}" key cursor='▌'
  INPUT_ACTION='value'
  printf '%b%b' "$HIDE_CURSOR" "$BLINK_CURSOR"
  while true; do
    printf '\r\033[2K        %s %b%s%b%b%s%b' "$prompt" "$CYAN" "$value" "$RESET" "$CYAN" "$cursor" "$RESET"
    if IFS= read -rsn1 -t 1 key; then
      if [[ -z "$key" ]]; then
        break
      elif [[ "$key" == $'\x7f' || "$key" == $'\b' ]]; then
        [[ -n "$value" ]] && value="${value%?}"
      elif [[ "$key" == $'\x1b' ]]; then
        if IFS= read -rsn1 -t 1 key && [[ "$key" == '[' ]] && IFS= read -rsn1 -t 1 key; then
          if [[ "$key" == A || "$key" == D ]]; then
            printf '\r\033[2K%b%b' "$SHOW_CURSOR" "$BLINK_CURSOR"
            INPUT_ACTION='back'
            INPUT_VALUE=''
            return
          fi
        else
          exit_program
        fi
      else
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

rewind_input_line() {
  [[ "$MODERN_UI" == true ]] && printf '\033[1A\r\033[2K'
}

render_compact_screen() {
  local context="$1"
  [[ "$MODERN_UI" == true ]] || return 0
  printf '\033[2J\033[H'
  printf '%bF L U T T E R   B L O C%b  %b/%b  %s\n\n' "$CYAN$BOLD" "$RESET" "$MUTED" "$RESET" "$context"
}

render_completed_sections() {
  case "$CURRENT_SECTION_NUMBER" in
    02|03|04|05)
      printf '        %b01%b  %bProject details%b  %s  •  %s\n' \
        "$PURPLE$BOLD" "$RESET" "$MUTED" "$RESET" "$PROJECT_NAME" "$APP_TITLE"
      printf '            %bPROD%b %s  %bDEV%b %s  %bLOCAL%b %s\n\n' \
        "$MUTED" "$RESET" "$PROD_URL" "$MUTED" "$RESET" "$DEV_URL" "$MUTED" "$RESET" "$LOCAL_URL"
      ;;
  esac

  case "$CURRENT_SECTION_NUMBER" in
    03|04|05)
      printf '        %b02%b  %bApp package%b      %s\n\n' \
        "$PURPLE$BOLD" "$RESET" "$MUTED" "$RESET" \
        "$([[ "$USE_CUSTOM_ORG" == true ]] && printf '%s.%s' "$APP_ORG" "$PROJECT_NAME" || printf 'com.example.%s' "$PROJECT_NAME")"
      ;;
  esac

  case "$CURRENT_SECTION_NUMBER" in
    04|05)
      printf '        %b03%b  %bDesign language%b  %s\n\n' \
        "$PURPLE$BOLD" "$RESET" "$MUTED" "$RESET" "$DESIGN_STYLE"
      ;;
  esac

  if [[ "$CURRENT_SECTION_NUMBER" == 05 ]]; then
    printf '        %b04%b  %bLanguage support%b %s\n\n' \
      "$PURPLE$BOLD" "$RESET" "$MUTED" "$RESET" \
      "$([[ "$ENABLE_BILINGUAL" == true ]] && printf '%s + %s' "$PRIMARY_LOCALE" "$SECONDARY_LOCALE" || printf 'Add later')"
  fi
}

restore_current_section() {
  [[ "$MODERN_UI" == true ]] || return 0
  render_compact_screen "$CURRENT_SECTION_TITLE"
  render_completed_sections
  section "$CURRENT_SECTION_NUMBER" "$CURRENT_SECTION_TITLE"
}

edit_project_details() {
  local action value field
  while true; do
    if [[ "$MODERN_UI" == true ]]; then
      render_compact_screen 'Edit project details'
      printf '        %bChoose one field to update. Everything else stays unchanged.%b\n\n' "$MUTED" "$RESET"
      select_one \
        "Project name — $PROJECT_NAME" \
        "App title — $APP_TITLE" \
        "PROD_URL — $PROD_URL" \
        "DEV_URL — $DEV_URL" \
        "LOCAL_URL — $LOCAL_URL" \
        '← Return to configuration' \
        'Exit initializer'
      action="$SELECTED_INDEX"
    else
      printf '\n  1) Project name — %s\n  2) App title — %s\n  3) PROD_URL — %s\n  4) DEV_URL — %s\n  5) LOCAL_URL — %s\n  6) Return\n  0) Exit\n' \
        "$PROJECT_NAME" "$APP_TITLE" "$PROD_URL" "$DEV_URL" "$LOCAL_URL"
      read -r -p 'Detail to edit: ' action
      [[ "$action" == 0 ]] && exit_program
      [[ "$action" =~ ^[1-6]$ ]] || { warning 'Invalid selection. Please retry.'; continue; }
      action=$((action - 1))
    fi

    if [[ "$action" -eq 5 ]]; then
      restore_current_section
      return
    fi
    [[ "$action" -eq 6 ]] && exit_program
    case "$action" in
      0) field='PROJECT_NAME' ;;
      1) field='APP_TITLE' ;;
      2) field='PROD_URL' ;;
      3) field='DEV_URL' ;;
      4) field='LOCAL_URL' ;;
    esac
    value="${!field}"
    if [[ "$MODERN_UI" == true ]]; then
      read_input "${field}:" "$value"
      [[ "$INPUT_ACTION" == back ]] && continue
      value="$INPUT_VALUE"
    else
      read -r -p "$field [$value] (or back): " replacement
      [[ "$replacement" == back ]] && continue
      value="${replacement:-$value}"
    fi

    if [[ "$field" == PROJECT_NAME ]]; then
      if [[ ! "$value" =~ ^[a-z][a-z0-9_]*$ || ( "$value" != "$PROJECT_NAME" && -e "$value" ) ]]; then
        warning 'Invalid or existing project name. Value unchanged.'
        continue
      fi
    elif [[ "$field" == APP_TITLE && -z "$value" ]]; then
      warning 'App title cannot be empty. Value unchanged.'
      continue
    fi
    printf -v "$field" '%s' "$value"
  done
}

edit_app_package() {
  local choice
  while true; do
    if [[ "$MODERN_UI" == true ]]; then
      render_compact_screen 'Edit app package'
      printf '        %bCurrent package: %s%b\n\n' "$MUTED" \
        "$([[ "$USE_CUSTOM_ORG" == true ]] && printf '%s.%s' "$APP_ORG" "$PROJECT_NAME" || printf 'com.example.%s' "$PROJECT_NAME")" "$RESET"
      select_one 'Keep Flutter default — com.example' 'Use a custom organization identifier' '← Return' 'Exit initializer'
      choice="$SELECTED_INDEX"
    else
      read -r -p 'Package [default/custom/back/exit]: ' choice
      exit_if_requested "$choice"
      [[ "$choice" == back ]] && return
      [[ "$choice" == default ]] && choice=0
      [[ "$choice" == custom ]] && choice=1
    fi
    [[ "$choice" -eq 2 ]] && return
    [[ "$choice" -eq 3 ]] && exit_program
    if [[ "$choice" -eq 0 ]]; then
      USE_CUSTOM_ORG=false
      return
    fi
    while true; do
      if [[ "$MODERN_UI" == true ]]; then
        read_input 'Organization identifier:' "${APP_ORG:-com.company}"
        [[ "$INPUT_ACTION" == back ]] && break
        APP_ORG="$INPUT_VALUE"
      else
        read -r -p 'Organization identifier: ' APP_ORG
      fi
      if [[ "$APP_ORG" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]]; then
        USE_CUSTOM_ORG=true
        return
      fi
      warning 'Use a lowercase reverse-domain value such as com.company. Please retry.'
    done
  done
}

edit_design_language() {
  if [[ "$MODERN_UI" == true ]]; then
    render_compact_screen 'Edit design language'
    select_one 'Material — MaterialApp + Scaffold' 'Cupertino — CupertinoApp + CupertinoPageScaffold' '← Return' 'Exit initializer'
    [[ "$SELECTED_INDEX" -eq 2 ]] && return
    [[ "$SELECTED_INDEX" -eq 3 ]] && exit_program
    [[ "$SELECTED_INDEX" -eq 0 ]] && DESIGN_STYLE=material || DESIGN_STYLE=cupertino
  else
    read -r -p 'Design [material/cupertino/back/exit]: ' value
    exit_if_requested "$value"
    [[ "$value" == back ]] && return
    [[ "$value" == material || "$value" == cupertino ]] && DESIGN_STYLE="$value"
  fi
}

edit_language_support() {
  if [[ "$MODERN_UI" == true ]]; then
    render_compact_screen 'Edit language support'
    select_one 'Yes — generate ARB + gen-l10n' 'Later — stay dependency-light' '← Return' 'Exit initializer'
    [[ "$SELECTED_INDEX" -eq 2 ]] && return
    [[ "$SELECTED_INDEX" -eq 3 ]] && exit_program
    [[ "$SELECTED_INDEX" -eq 0 ]] && ENABLE_BILINGUAL=true || ENABLE_BILINGUAL=false
  else
    read -r -p 'Bilingual support [y/N/back/exit]: ' value
    exit_if_requested "$value"
    [[ "$value" == back ]] && return
    [[ "$value" =~ ^[Yy]$ ]] && ENABLE_BILINGUAL=true || ENABLE_BILINGUAL=false
  fi
  if [[ "$ENABLE_BILINGUAL" == true ]]; then
    choose_language primary; PRIMARY_LOCALE="$CHOSEN_LOCALE"
    choose_language secondary "$PRIMARY_LOCALE"; SECONDARY_LOCALE="$CHOSEN_LOCALE"
  fi
}

edit_previous_configuration() {
  local choice
  while true; do
    render_compact_screen 'Edit previous configuration'
    case "$CURRENT_SECTION_NUMBER" in
      03)
        select_one '01 — Project details and URLs' '02 — App package' '← Return to current step' 'Exit initializer'
        choice="$SELECTED_INDEX"
        [[ "$choice" -eq 2 ]] && break
        [[ "$choice" -eq 3 ]] && exit_program
        ;;
      04)
        select_one '01 — Project details and URLs' '02 — App package' '03 — Design language' '← Return to current step' 'Exit initializer'
        choice="$SELECTED_INDEX"
        [[ "$choice" -eq 3 ]] && break
        [[ "$choice" -eq 4 ]] && exit_program
        ;;
      05)
        select_one '01 — Project details and URLs' '02 — App package' '03 — Design language' '04 — Language support' '← Return to current step' 'Exit initializer'
        choice="$SELECTED_INDEX"
        [[ "$choice" -eq 4 ]] && break
        [[ "$choice" -eq 5 ]] && exit_program
        ;;
      *) edit_project_details; return ;;
    esac
    case "$choice" in
      0) edit_project_details ;;
      1) edit_app_package ;;
      2) edit_design_language ;;
      3) edit_language_support ;;
    esac
  done
  restore_current_section
}

run_step() {
  local label="$1"; shift
  if [[ "$MODERN_UI" != true ]]; then
    while true; do
      if "$@"; then return; fi
      printf '\nStep failed: %s\n' "$label" >&2
      read -r -p 'Retry or exit? [r/E]: ' retry_choice
      case "${retry_choice:-e}" in
        r|R|retry|RETRY) ;;
        *) exit_program ;;
      esac
    done
  fi

  local log_file="$TEMP_DIR/step.log" pid frame
  local frames=('◐' '◓' '◑' '◒')
  while true; do
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
      printf '%b%b' "$SHOW_CURSOR" "$BLINK_CURSOR"
      return
    fi

    printf '\r        %b✕%b  %s\n' "$RED$BOLD" "$RESET" "$label"
    tail -n 20 "$log_file" >&2
    printf '%b%b' "$SHOW_CURSOR" "$BLINK_CURSOR"
    printf '\n        %bThe step failed. Choose what to do:%b\n\n' "$RED" "$RESET"
    select_one 'Retry this step' 'Exit initializer'
    [[ "$SELECTED_INDEX" -eq 0 ]] || exit_program
  done
}

review_configuration() {
  local action
  while true; do
    CURRENT_SECTION_NUMBER='06'
    CURRENT_SECTION_TITLE='Review and edit your configuration'
    if [[ "$MODERN_UI" == true ]]; then
      render_compact_screen 'Review configuration'
    fi
    section "$CURRENT_SECTION_NUMBER" "$CURRENT_SECTION_TITLE"
    if [[ "$MODERN_UI" == true ]]; then
      printf '        %bProject%b       %s\n' "$MUTED" "$RESET" "$PROJECT_NAME"
      printf '        %bApp title%b     %s\n' "$MUTED" "$RESET" "$APP_TITLE"
      printf '        %bPackage%b       %s\n' "$MUTED" "$RESET" "$([[ "$USE_CUSTOM_ORG" == true ]] && printf '%s.%s' "$APP_ORG" "$PROJECT_NAME" || printf 'com.example.%s' "$PROJECT_NAME")"
      printf '        %bDesign%b        %s\n' "$MUTED" "$RESET" "$DESIGN_STYLE"
      if [[ "$ENABLE_BILINGUAL" == true ]]; then
        printf '        %bLanguages%b     %s + %s\n' "$MUTED" "$RESET" "$PRIMARY_LOCALE" "$SECONDARY_LOCALE"
      else
        printf '        %bLanguages%b     Add later\n' "$MUTED" "$RESET"
      fi
      printf '        %bPlatforms%b     %s\n\n' "$MUTED" "$RESET" "$PLATFORMS"
      printf '        %bSelect an item to continue or go back and edit:%b\n\n' "$MUTED" "$RESET"
      select_one \
        'Create project with these settings' \
        '← Edit project details and URLs' \
        '← Edit app package' \
        '← Edit design language' \
        '← Edit language support' \
        '← Edit target platforms' \
        'Exit initializer'
      action="$SELECTED_INDEX"
    else
      printf 'Project: %s\nPackage: %s\nDesign: %s\nPlatforms: %s\n' \
        "$PROJECT_NAME" \
        "$([[ "$USE_CUSTOM_ORG" == true ]] && printf '%s.%s' "$APP_ORG" "$PROJECT_NAME" || printf 'com.example.%s' "$PROJECT_NAME")" \
        "$DESIGN_STYLE" "$PLATFORMS"
      printf '\n  1) Create project\n  2) Edit project details and URLs\n  3) Edit app package\n  4) Edit design language\n  5) Edit language support\n  6) Edit target platforms\n  0) Exit\n'
      read -r -p 'Selection: ' action
      [[ "$action" == 0 ]] && exit_program
      [[ "$action" =~ ^[1-6]$ ]] || { warning 'Invalid selection. Please retry.'; continue; }
      action=$((action - 1))
    fi

    case "$action" in
      0) return ;;
      1) edit_project_details ;;
      2)
        if [[ "$MODERN_UI" == true ]]; then
          render_compact_screen 'Edit app package'
          printf '        %bChoose the package identity for this app.%b\n\n' "$MUTED" "$RESET"
          select_one 'Keep Flutter default — com.example' 'Use a custom organization identifier' '← Back to review'
          [[ "$SELECTED_INDEX" -eq 2 ]] && continue
          PACKAGE_CHOICE="$SELECTED_INDEX"
        else
          read -r -p 'Use custom organization? [y/N/back]: ' value
          [[ "$value" == back ]] && continue
          [[ "$value" =~ ^[Yy]$ ]] && PACKAGE_CHOICE=1 || PACKAGE_CHOICE=0
        fi
        USE_CUSTOM_ORG=false
        if [[ "$PACKAGE_CHOICE" -eq 1 ]]; then
          while true; do
            if [[ "$MODERN_UI" == true ]]; then read_input 'Organization identifier:'; APP_ORG="$INPUT_VALUE"; else read -r -p 'Organization identifier: ' APP_ORG; fi
            [[ "$APP_ORG" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]] && { USE_CUSTOM_ORG=true; break; }
            warning 'Use a value such as com.company. Please retry.'
          done
        fi
        ;;
      3)
        if [[ "$MODERN_UI" == true ]]; then
          render_compact_screen 'Edit design language'
          printf '        %bChoose the visual system the generated app will use.%b\n\n' "$MUTED" "$RESET"
          select_one 'Material — MaterialApp + Scaffold' 'Cupertino — CupertinoApp + CupertinoPageScaffold' '← Back to review'
          [[ "$SELECTED_INDEX" -eq 2 ]] && continue
          [[ "$SELECTED_INDEX" -eq 0 ]] && DESIGN_STYLE=material || DESIGN_STYLE=cupertino
        else
          read -r -p 'Design [material/cupertino/back]: ' value
          [[ "$value" == back ]] && continue
          [[ "$value" == material || "$value" == cupertino ]] && DESIGN_STYLE="$value" || warning 'Invalid design; unchanged.'
        fi
        ;;
      4)
        if [[ "$MODERN_UI" == true ]]; then
          render_compact_screen 'Edit language support'
          printf '        %bLocalization can be generated now or added later.%b\n\n' "$MUTED" "$RESET"
          select_one 'Yes — generate ARB + gen-l10n' 'Later — stay dependency-light' '← Back to review'
          [[ "$SELECTED_INDEX" -eq 2 ]] && continue
          [[ "$SELECTED_INDEX" -eq 0 ]] && ENABLE_BILINGUAL=true || ENABLE_BILINGUAL=false
        else
          read -r -p 'Bilingual support [y/N/back]: ' value
          [[ "$value" == back ]] && continue
          [[ "$value" =~ ^[Yy]$ ]] && ENABLE_BILINGUAL=true || ENABLE_BILINGUAL=false
        fi
        if [[ "$ENABLE_BILINGUAL" == true ]]; then
          choose_language primary; PRIMARY_LOCALE="$CHOSEN_LOCALE"
          choose_language secondary "$PRIMARY_LOCALE"; SECONDARY_LOCALE="$CHOSEN_LOCALE"
        fi
        ;;
      5)
        if [[ "$MODERN_UI" == true ]]; then
          render_compact_screen 'Edit target platforms'
          select_platforms; PLATFORMS="$SELECTED_PLATFORMS"
        else
          read -r -p "Platforms [$PLATFORMS] or back: " value
          [[ "$value" == back ]] && continue
          [[ -n "$value" ]] && PLATFORMS="$value"
        fi
        ;;
      6) exit_program ;;
    esac
  done
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
  printf '        %bEnter confirms  •  ↑/← goes back  •  Esc exits%b\n\n' "$MUTED" "$RESET"
fi

IDENTITY_STEP=1
while (( IDENTITY_STEP <= 5 )); do
  case "$IDENTITY_STEP" in
    1)
      if [[ "$MODERN_UI" == true ]]; then
        read_input 'Project name (for example, my_app):'; PROJECT_NAME="$INPUT_VALUE"
        [[ "$INPUT_ACTION" == back ]] && continue
      else
        read -r -p 'Project name (or "exit"): ' PROJECT_NAME
        exit_if_requested "$PROJECT_NAME"
      fi
      if [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
        warning 'Use lowercase letters, numbers, and underscores; start with a letter. Please retry.'
      elif [[ -e "$PROJECT_NAME" ]]; then
        warning "Folder '$PROJECT_NAME' already exists. Choose another name."
      else
        IDENTITY_STEP=2
      fi
      ;;
    2)
      if [[ "$MODERN_UI" == true ]]; then
        read_input 'App title (for example, My Awesome App):'
        [[ "$INPUT_ACTION" == back ]] && { rewind_input_line; IDENTITY_STEP=1; continue; }
        APP_TITLE="$INPUT_VALUE"
      else
        read -r -p 'App title ("back" or "exit"): ' APP_TITLE
        exit_if_requested "$APP_TITLE"
        [[ "$APP_TITLE" == back ]] && { IDENTITY_STEP=1; continue; }
      fi
      if [[ -n "$APP_TITLE" ]]; then IDENTITY_STEP=3; else warning 'App title cannot be empty. Please retry.'; fi
      ;;
    3|4|5)
      if [[ "$IDENTITY_STEP" -eq 3 ]]; then field='PROD_URL'; default='https://api.example.com';
      elif [[ "$IDENTITY_STEP" -eq 4 ]]; then field='DEV_URL'; default='https://dev-api.example.com';
      else field='LOCAL_URL'; default='http://localhost:8080'; fi
      if [[ "$MODERN_UI" == true ]]; then
        read_input "$field [$default]:"
        [[ "$INPUT_ACTION" == back ]] && { rewind_input_line; IDENTITY_STEP=$((IDENTITY_STEP - 1)); continue; }
        value="${INPUT_VALUE:-$default}"
      else
        read -r -p "$field [$default] (or back/exit): " value
        exit_if_requested "$value"
        [[ "$value" == back ]] && { IDENTITY_STEP=$((IDENTITY_STEP - 1)); continue; }
        value="${value:-$default}"
      fi
      printf -v "$field" '%s' "$value"
      IDENTITY_STEP=$((IDENTITY_STEP + 1))
      ;;
  esac
done
PROD_URL="${PROD_URL:-https://api.example.com}"
DEV_URL="${DEV_URL:-https://dev-api.example.com}"
LOCAL_URL="${LOCAL_URL:-http://localhost:8080}"

CURRENT_SECTION_NUMBER='02'
CURRENT_SECTION_TITLE='Configure the app package'
section "$CURRENT_SECTION_NUMBER" "$CURRENT_SECTION_TITLE"
if [[ "$MODERN_UI" == true ]]; then
  while true; do
    printf '        %bUse ↑/↓ and Enter%b\n\n' "$MUTED" "$RESET"
    select_one 'Keep Flutter default — com.example' 'Use a custom organization identifier' '← Edit project details' 'Exit initializer'
    PACKAGE_CHOICE="$SELECTED_INDEX"
    [[ "$PACKAGE_CHOICE" -eq 2 ]] && { edit_project_details; continue; }
    [[ "$PACKAGE_CHOICE" -eq 3 ]] && exit_program
    break
  done
else
  while true; do
    printf '  0) Exit\n  1) Keep Flutter default — com.example\n  2) Use a custom organization identifier\n  b) Edit project details\n'
    read -r -p 'Selection [1]: ' PACKAGE_CHOICE
    [[ "$PACKAGE_CHOICE" == 0 ]] && exit_program
    [[ "$PACKAGE_CHOICE" == b || "$PACKAGE_CHOICE" == back ]] && { edit_project_details; continue; }
    case "${PACKAGE_CHOICE:-1}" in
      1) PACKAGE_CHOICE=0; break ;;
      2) PACKAGE_CHOICE=1; break ;;
      *) warning 'Invalid package selection. Please retry.' ;;
    esac
  done
fi

USE_CUSTOM_ORG=false
if [[ "$PACKAGE_CHOICE" -eq 1 ]]; then
  while true; do
    if [[ "$MODERN_UI" == true ]]; then
      read_input 'Organization identifier (for example, com.company):'
      [[ "$INPUT_ACTION" == back ]] && { edit_project_details; continue; }
      APP_ORG="$INPUT_VALUE"
    else
      read -r -p 'Organization identifier (or "exit"): ' APP_ORG
      exit_if_requested "$APP_ORG"
    fi
    if [[ "$APP_ORG" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]]; then
      USE_CUSTOM_ORG=true
      break
    fi
    warning 'Use a lowercase reverse-domain value such as com.company. Please retry.'
  done
fi

CURRENT_SECTION_NUMBER='03'
CURRENT_SECTION_TITLE='Choose your design language'
section "$CURRENT_SECTION_NUMBER" "$CURRENT_SECTION_TITLE"
while true; do
  if [[ "$MODERN_UI" == true ]]; then
    printf '        %bUse ↑/↓ and Enter%b\n\n' "$MUTED" "$RESET"
    select_one 'Material — MaterialApp + Scaffold' 'Cupertino — CupertinoApp + CupertinoPageScaffold' '← Edit previous configuration' 'Exit initializer'
    [[ "$SELECTED_INDEX" -eq 2 ]] && { edit_previous_configuration; continue; }
    [[ "$SELECTED_INDEX" -eq 3 ]] && exit_program
    DESIGN_CHOICE=$((SELECTED_INDEX + 1))
  else
    printf '  0) Exit\n  1) MaterialApp + Scaffold\n  2) CupertinoApp + CupertinoPageScaffold\n  b) Edit project details\n'
    read -r -p 'Selection [1]: ' DESIGN_CHOICE
    [[ "$DESIGN_CHOICE" == 0 ]] && exit_program
    [[ "$DESIGN_CHOICE" == b || "$DESIGN_CHOICE" == back ]] && { edit_project_details; continue; }
  fi
  case "${DESIGN_CHOICE:-1}" in
    1|material|Material) DESIGN_STYLE='material'; break ;;
    2|cupertino|Cupertino) DESIGN_STYLE='cupertino'; break ;;
    *) warning 'Invalid design selection. Please retry.' ;;
  esac
done

CURRENT_SECTION_NUMBER='04'
CURRENT_SECTION_TITLE='Configure language support'
section "$CURRENT_SECTION_NUMBER" "$CURRENT_SECTION_TITLE"
while true; do
  if [[ "$MODERN_UI" == true ]]; then
    printf '        %bUse ↑/↓ and Enter%b\n\n' "$MUTED" "$RESET"
    select_one 'Yes — generate ARB + gen-l10n' 'Later — stay dependency-light' '← Edit previous configuration' 'Exit initializer'
    [[ "$SELECTED_INDEX" -eq 2 ]] && { edit_previous_configuration; continue; }
    [[ "$SELECTED_INDEX" -eq 3 ]] && exit_program
    [[ "$SELECTED_INDEX" -eq 0 ]] && BILINGUAL_CHOICE=y || BILINGUAL_CHOICE=n
  else
    read -r -p 'Enable bilingual support? [y/N/back/exit]: ' BILINGUAL_CHOICE
    exit_if_requested "$BILINGUAL_CHOICE"
    [[ "$BILINGUAL_CHOICE" == back || "$BILINGUAL_CHOICE" == b ]] && { edit_project_details; continue; }
  fi
  case "${BILINGUAL_CHOICE:-n}" in
    y|Y|yes|YES) ENABLE_BILINGUAL=true; break ;;
    n|N|no|NO|'') ENABLE_BILINGUAL=false; break ;;
    *) warning 'Choose yes, no, or exit.' ;;
  esac
done
if [[ "$ENABLE_BILINGUAL" == true ]]; then
  choose_language primary
  PRIMARY_LOCALE="$CHOSEN_LOCALE"
  choose_language secondary "$PRIMARY_LOCALE"
  SECONDARY_LOCALE="$CHOSEN_LOCALE"
fi

CURRENT_SECTION_NUMBER='05'
CURRENT_SECTION_TITLE='Choose target platforms'
section "$CURRENT_SECTION_NUMBER" "$CURRENT_SECTION_TITLE"
if [[ "$MODERN_UI" == true ]]; then
  select_platforms
  PLATFORMS="$SELECTED_PLATFORMS"
else
  while true; do
    read -r -p 'Platforms [android,ios] or "exit": ' PLATFORMS
    exit_if_requested "$PLATFORMS"
    [[ "$PLATFORMS" == back || "$PLATFORMS" == b ]] && { edit_project_details; continue; }
    PLATFORMS="${PLATFORMS:-android,ios}"
    [[ "$PLATFORMS" =~ ^(android|ios|web|windows|macos|linux)(,(android|ios|web|windows|macos|linux))*$ ]] && break
    warning 'Invalid platform list. Please retry.'
  done
fi

review_configuration

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/flutter-bloc-init.XXXXXX")"
cleanup_all() {
  restore_terminal
  rm -rf "$TEMP_DIR"
}
trap cleanup_all EXIT

if [[ -f "$LOCAL_TEMPLATE_DIR/pubspec.yaml" && -d "$LOCAL_TEMPLATE_DIR/lib" ]]; then
  TEMPLATE_DIR="$LOCAL_TEMPLATE_DIR"
else
  TEMPLATE_DIR="$TEMP_DIR/template"
  run_step 'Downloading template' git clone --depth 1 --branch "$TEMPLATE_BRANCH" "$TEMPLATE_REPO" "$TEMPLATE_DIR"
fi

section '07' 'Building your playground'
CREATE_ARGS=(create --platforms="$PLATFORMS" --project-name="$PROJECT_NAME")
if [[ "$USE_CUSTOM_ORG" == true ]]; then CREATE_ARGS+=(--org="$APP_ORG"); fi
run_step 'Creating Flutter project' flutter "${CREATE_ARGS[@]}" "$PROJECT_NAME"

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
  printf '        %b│  ✓  Your Flutter playground is ready.    │%b\n' "$GREEN$BOLD" "$RESET"
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
