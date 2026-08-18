#!/bin/bash
set -e

# -----------------------------
# 🚀 Flutter iOS Release Builder (IPA via Xcode Archive) + Release Name
# Choose REUSE interactively, or pass --reuse-version for a non-interactive build.
# Commands used:
#   flutter clean
#   flutter pub get
#   flutter build ios --release
# -----------------------------

reuse_pubspec_version=false
dry_run=false
for argument in "$@"; do
  case "$argument" in
    --reuse-version) reuse_pubspec_version=true ;;
    --dry-run) dry_run=true ;;
  esac
done

if [ "$reuse_pubspec_version" = true ] || [ "${REUSE_PUBSPEC_VERSION:-}" = "1" ]; then
  reuse_pubspec_version=true
  bump_level="REUSE"
  echo "♻️ Reusing the version currently in pubspec.yaml."
else
  # 0. Ask user for version bump type
  echo "🔢 Select version bump type:"
  select bump_type in "AUTO" "MAJOR" "MINOR" "PATCH" "Custom" "REUSE current version"; do
    case $bump_type in
      AUTO) bump_level="AUTO"; break ;;
      MAJOR) bump_level="MAJOR"; break ;;
      MINOR) bump_level="MINOR"; break ;;
      PATCH) bump_level="PATCH"; break ;;
      Custom) bump_level="CUSTOM"; break ;;
      "REUSE current version")
        reuse_pubspec_version=true
        bump_level="REUSE"
        echo "♻️ Reusing the version currently in pubspec.yaml."
        break
        ;;
      *) echo "❌ Invalid option. Please choose again." ;;
    esac
  done
fi

# 1. New app version (if Custom)
if [ "$bump_level" == "CUSTOM" ]; then
  read -r -p "📝 Enter custom version (e.g., 2.1.0): " new_version
fi

# 2. Read current version and build number
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ pubspec.yaml not found. Run this from your Flutter project root."
  exit 1
fi

current_version_line=$(grep '^version:' pubspec.yaml || true)
if [ -z "$current_version_line" ]; then
  echo "❌ Could not find 'version:' in pubspec.yaml"
  exit 1
fi

current_version=$(echo "$current_version_line" | sed -E 's/version: ([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+/\1/')
current_build_number=$(echo "$current_version_line" | sed -E 's/.*\+([0-9]+)/\1/')

echo "📋 Current version: $current_version +$current_build_number"

if [ "$reuse_pubspec_version" = true ]; then
  next_version="$current_version"
  next_build_number="$current_build_number"
  echo "♻️ Using version: $next_version+$next_build_number"
else
  # 2.1 Resolve AUTO baseline from last iOS bump tag
  auto_base_version="$current_version"
  auto_base_build="$current_build_number"
  auto_detected_bump="PATCH"
  ios_last_bump_tag=""

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ios_last_bump_tag=$(git tag --list --sort=-creatordate \
      | grep -E '^ios-v[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' \
      | head -n 1)
  fi

  if [ "$bump_level" == "AUTO" ]; then
  if [ -n "$ios_last_bump_tag" ]; then
    auto_base_version=$(echo "$ios_last_bump_tag" | sed -E 's/^ios-v([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$/\1/')
    auto_base_build=$(echo "$ios_last_bump_tag" | sed -E 's/^ios-v[0-9]+\.[0-9]+\.[0-9]+\+([0-9]+)$/\1/')
    auto_log=$(git log "$ios_last_bump_tag"..HEAD --pretty=format:"%s%n%b" --no-merges 2>/dev/null || true)

    if echo "$auto_log" | grep -Eqi 'BREAKING CHANGE|^[[:alpha:]][[:alnum:]_-]*(\([^)]+\))?!:'; then
      auto_detected_bump="MAJOR"
    elif echo "$auto_log" | grep -Eqi '^feat(\([^)]+\))?:'; then
      auto_detected_bump="MINOR"
    else
      auto_detected_bump="PATCH"
    fi

    echo "🤖 AUTO base tag: $ios_last_bump_tag (detected $auto_detected_bump bump)"
  else
    echo "🤖 AUTO: No iOS bump tag found. Falling back to PATCH from pubspec version."
  fi
  fi

# 3. Determine next version
  resolved_bump_level="$bump_level"
  version_seed="$current_version"
  if [ "$bump_level" == "AUTO" ]; then
    resolved_bump_level="$auto_detected_bump"
    version_seed="$auto_base_version"
  fi

  IFS='.' read -r major minor patch <<< "$version_seed"

  if [ "$resolved_bump_level" == "MAJOR" ]; then
  major=$((major + 1)); minor=0; patch=0
  next_version="$major.$minor.$patch"
  if [ "$bump_level" == "AUTO" ]; then
    echo "🤖 AUTO resolved to MAJOR: $version_seed ➜ $next_version"
  else
    echo "🚀 MAJOR bump: $current_version ➜ $next_version"
  fi
  elif [ "$resolved_bump_level" == "MINOR" ]; then
  minor=$((minor + 1)); patch=0
  next_version="$major.$minor.$patch"
  if [ "$bump_level" == "AUTO" ]; then
    echo "🤖 AUTO resolved to MINOR: $version_seed ➜ $next_version"
  else
    echo "✨ MINOR bump: $current_version ➜ $next_version"
  fi
  elif [ "$resolved_bump_level" == "PATCH" ]; then
  patch=$((patch + 1))
  next_version="$major.$minor.$patch"
  if [ "$bump_level" == "AUTO" ]; then
    echo "🤖 AUTO resolved to PATCH: $version_seed ➜ $next_version"
  else
    echo "🔧 PATCH bump: $current_version ➜ $next_version"
  fi
  elif [ "$bump_level" == "CUSTOM" ]; then
  if ! echo "$new_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ Invalid custom version format. Use x.y.z (e.g., 2.1.0)"
    exit 1
  fi
  next_version="$new_version"
  echo "📝 Custom version set: $current_version ➜ $next_version"
  fi

# 4. Always increment build number
  build_seed="$current_build_number"
  if [ "$bump_level" == "AUTO" ] && [ "$auto_base_build" -gt "$build_seed" ]; then
    build_seed="$auto_base_build"
  fi
  next_build_number=$((build_seed + 1))
  echo "🔼 Build number incremented: $build_seed ➜ $next_build_number"
fi

# Preview the release version and notes without changing project or Git state.
if [ "$dry_run" = true ]; then
  preview_last_tag=""
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    preview_last_tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
  fi

  if [ -n "$preview_last_tag" ]; then
    preview_log=$(git log "$preview_last_tag"..HEAD --pretty=format:"%s" --no-merges 2>/dev/null || true)
  else
    preview_log=""
  fi

  preview_filtered=$(echo "$preview_log" | grep -Ev \
    '^(🔖|chore:|refactor:|build:|ci:|style:|test:|docs:|bump|version|format|lint|pub get|clean|signing|release signing|update gradle)' \
    || true)
  preview_user_facing=$(echo "$preview_filtered" | grep -E \
    '^(feat:|fix:|perf:|improvement:|ui:|ux:|hotfix:|security:)' \
    || true)
  [ -n "$preview_user_facing" ] || preview_user_facing="$preview_filtered"
  preview_list=$(echo "$preview_user_facing" \
    | sed -E 's/^(feat:|fix:|perf:|improvement:|ui:|ux:|hotfix:|security:)[ ]*//I' \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
    | awk 'NF && !seen[$0]++' | head -n 8)

  if [ -z "$preview_last_tag" ]; then
    preview_heading="Initial Release"
    preview_intro="Welcome to Protocol People."
    preview_list="Mark daily attendance with a simple swipe
View attendance history and monthly overview
Apply for leave and track request status
View payslips and salary details
Receive announcements and in-app notifications
Manage notification preferences and app settings"
  else
    preview_heading="What's New"
    preview_intro="Thanks for using Protocol People."
    [ -n "$preview_list" ] || preview_list="Performance improvements and bug fixes."
  fi

  echo ""
  echo "🔎 DRY RUN — no files, builds, commits, tags, or remote branches will be changed."
  echo "Would use version: $next_version+$next_build_number"
  echo ""
  echo "**Version $next_version — $preview_heading**"
  echo ""
  echo "$preview_intro"
  echo ""
  echo "$preview_list" | sed 's/^/- /'
  exit 0
fi

# 4.1 Release name (App Store Connect - internal)
read -r -p "🏷️ Enter release name (press Enter for auto): " custom_release_name
if [ -n "$custom_release_name" ]; then
  release_name="$custom_release_name"
else
  release_name="iOS Production v$next_version+$next_build_number"
fi
echo "✅ Release Name: $release_name"

# ──────────────────────────────────────────────────────────────────────────────
# FIX: Capture the last tag BEFORE we create a new one in step 9.
#      Use `git describe --tags --abbrev=0` against HEAD (not HEAD^) so we get
#      the most-recent existing tag on any ancestor commit.
#      Leave it empty when no prior iOS tag exists so we can generate the
#      dedicated initial-release notes.
# ──────────────────────────────────────────────────────────────────────────────
last_tag=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  last_tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
fi

# 5. Update pubspec.yaml only when this build owns the version bump.
if [ "$reuse_pubspec_version" = false ]; then
  sed -i.bak -E "s/^version: .*/version: $next_version+$next_build_number/" pubspec.yaml
  rm -f pubspec.yaml.bak
fi

# 6. Clean + pub get (as requested)
echo "🧹 flutter clean..."
flutter clean

echo "🔄 flutter pub get..."
flutter pub get

# 7. Build iOS release (as requested)
echo "🛠️ Building iOS --release..."
# Note: This produces an Xcode archive/build; IPA export is typically done from Xcode or xcodebuild export.
flutter build ios --release --build-number="$next_build_number" --build-name="$next_version"

# 8. Collect artifacts (best-effort)
# Flutter doesn't always output an .ipa directly with `flutter build ios --release`.
# We'll capture the main output folder + any generated archive/ipa if present.
release_folder="build/ios/releases/$next_version+$next_build_number"
mkdir -p "$release_folder"

# Common output locations (varies by workflow/tooling)
candidates=(
  "build/ios/iphoneos/Runner.app"
  "build/ios/archive/Runner.xcarchive"
  "build/ios/ipa/Runner.ipa"
)

found_any=false
for p in "${candidates[@]}"; do
  if [ -e "$p" ]; then
    found_any=true
    name=$(basename "$p")
    echo "📦 Found artifact: $p"
    # Use cp -R for folders, cp for files
    if [ -d "$p" ]; then
      cp -R "$p" "$release_folder/$name"
    else
      cp "$p" "$release_folder/$name"
    fi
  fi
done

if [ "$found_any" = false ]; then
  echo "⚠️ No standard iOS artifacts found (Runner.app / Runner.xcarchive / Runner.ipa)."
  echo "   Build succeeded, but export may be needed via Xcode Organizer (Archive -> Distribute) or xcodebuild -exportArchive."
fi

echo "📁 iOS release folder: $release_folder"

# 9. Git operations (commit + tag)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git add pubspec.yaml

  if git diff --cached --quiet; then
    echo "ℹ️ No staged changes to commit."
  else
    git commit -m "🔖 Bump version to $next_version+$next_build_number"
  fi

  tag_name="ios-v$next_version+$next_build_number"

  if git rev-parse "$tag_name" >/dev/null 2>&1; then
    echo "⚠️ Tag already exists: $tag_name (skipping tag creation)"
  else
    git tag "$tag_name"
    echo "🏷️ Created tag: $tag_name"
  fi
else
  echo "⚠️ Not a git repository. Skipping git commit/tag."
fi

# 10. Generate store-ready release notes from user-facing Git commits.
release_notes_file="$release_folder/RELEASE_NOTES.txt"

echo "🧾 Generating release notes since: ${last_tag:-'(beginning of history)'} ..."

if [ -n "$last_tag" ]; then
  raw_log=$(git log "$last_tag"..HEAD --pretty=format:"%s" --no-merges 2>/dev/null || true)
else
  raw_log=""
fi

filtered_log=$(echo "$raw_log" | grep -Ev \
  '^(🔖|chore:|refactor:|build:|ci:|style:|test:|docs:|bump|version|format|lint|pub get|clean|signing|release signing|update gradle)' \
  || true)

user_facing=$(echo "$filtered_log" | grep -E \
  '^(feat:|fix:|perf:|improvement:|ui:|ux:|hotfix:|security:)' \
  || true)

if [ -z "$user_facing" ]; then
  user_facing="$filtered_log"
fi

cleaned=$(echo "$user_facing" \
  | sed -E 's/^(feat:|fix:|perf:|improvement:|ui:|ux:|hotfix:|security:)[ ]*//I' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
  | awk 'NF')

deduped=$(echo "$cleaned" | awk '!seen[$0]++')
final_list=$(echo "$deduped" | head -n 8)

if [ -z "$last_tag" ]; then
  release_heading="Initial Release"
  release_intro="Welcome to Protocol People."
  final_list="Mark daily attendance with a simple swipe
View attendance history and monthly overview
Apply for leave and track request status
View payslips and salary details
Receive announcements and in-app notifications
Manage notification preferences and app settings"
else
  release_heading="What's New"
  release_intro="Thanks for using Protocol People."
  if [ -z "$final_list" ]; then
    final_list="Performance improvements and bug fixes."
  fi
fi

bullets=$(echo "$final_list" | sed 's/^/- /')

cat > "$release_notes_file" <<EOL
**Version $next_version — $release_heading**

$release_intro

$bullets
EOL

echo "✅ Release notes saved at: $release_notes_file"

# 11. Optional push
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  read -r -p "🚀 Push commit and tags to remote repository? (y/n): " push_answer
  if [ "$push_answer" = "y" ]; then
    git push
    git push --tags
    echo "✅ Changes and tag pushed to remote."
  else
    echo "🛑 Skipped pushing to remote."
  fi
fi

# 12. Done
echo "🎯 iOS release finished: Version $next_version+$next_build_number"
echo "🏷️ Release Name: $release_name"
echo "📁 Output folder: $release_folder"
echo "📝 Notes: $release_notes_file"
