#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
[[ -f pubspec.yaml ]] || { echo 'Run from a generated Flutter project.' >&2; exit 1; }

current="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -1)"
[[ "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]] || { echo 'Version must use x.y.z+build.' >&2; exit 1; }
major="${BASH_REMATCH[1]}"; minor="${BASH_REMATCH[2]}"; patch="${BASH_REMATCH[3]}"; build="${BASH_REMATCH[4]}"
echo 'Bump: 1) major  2) minor  3) patch  4) custom'
read -r -p 'Selection [3]: ' choice
case "${choice:-3}" in
  1) version="$((major + 1)).0.0" ;;
  2) version="$major.$((minor + 1)).0" ;;
  3) version="$major.$minor.$((patch + 1))" ;;
  4) read -r -p 'Version (x.y.z): ' version; [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1 ;;
  *) echo 'Invalid selection.' >&2; exit 1 ;;
esac
build="$((build + 1))"; label="$version+$build"
perl -i.bak -pe "s/^version:.*/version: $label/" pubspec.yaml && rm -f pubspec.yaml.bak

flutter clean
flutter pub get
flutter analyze
flutter test
flutter build ipa --release --build-name="$version" --build-number="$build"

output="build/ios/releases/$label"; mkdir -p "$output"
for ipa in build/ios/ipa/*.ipa; do
  [[ -f "$ipa" ]] && cp "$ipa" "$output/$(basename "${ipa%.ipa}")-$label.ipa"
done
git log --pretty=format:'- %s' --no-merges -n 8 > "$output/RELEASE_NOTES.txt" 2>/dev/null || echo '- Performance improvements and bug fixes.' > "$output/RELEASE_NOTES.txt"
echo "IPA created under $output"
