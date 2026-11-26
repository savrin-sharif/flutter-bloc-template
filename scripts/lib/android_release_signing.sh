#!/usr/bin/env bash
# Shared Android Play release-signing helpers for release_aab.sh.
# Source this file; do not execute it directly.
#
# Creates android/upload-keystore.jks + android/key.properties and expects
# android/app/build.gradle.kts to load that file for the release signingConfig.

android_key_properties_path() {
  echo "android/key.properties"
}

android_keystore_path() {
  echo "android/upload-keystore.jks"
}

is_android_release_signing_configured() {
  local props
  local store
  props="$(android_key_properties_path)"
  store="$(android_keystore_path)"
  [ -f "$props" ] && [ -f "$store" ]
}

# True when release buildType still hard-codes the debug signingConfig.
android_release_uses_debug_signing() {
  local gradle="android/app/build.gradle.kts"
  [ -f "$gradle" ] || return 0
  grep -Eq 'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)' "$gradle"
}

require_keytool() {
  if ! command -v keytool >/dev/null 2>&1; then
    echo "❌ keytool not found. Install a JDK (Temurin 17+) and ensure keytool is on PATH."
    exit 1
  fi
}

# Interactive first-time Play upload keystore + key.properties setup.
setup_android_release_signing() {
  local props store alias dname
  local store_password key_password confirm
  local app_name cn

  require_keytool

  props="$(android_key_properties_path)"
  store="$(android_keystore_path)"
  alias="upload"

  if is_android_release_signing_configured; then
    echo "✅ Release signing already configured:"
    echo "   $store"
    echo "   $props"
    return 0
  fi

  if [ -f "$store" ] && [ ! -f "$props" ]; then
    echo "⚠️ Found keystore at $store but missing $props."
    echo "   Recreate key.properties to point at the existing keystore, or move the keystore aside."
  fi

  echo ""
  echo "🔐 Setting up Android release signing for Play Store uploads."
  echo "   Keep the keystore and passwords safe — losing them blocks app updates."
  echo ""

  if command -v resolve_app_name >/dev/null 2>&1; then
    app_name="$(resolve_app_name)"
  else
    app_name="My App"
  fi
  cn="${app_name}"

  read -r -p "Key alias [$alias]: " alias_input
  alias="${alias_input:-$alias}"

  read -r -p "Certificate CN / app name [$cn]: " cn_input
  cn="${cn_input:-$cn}"
  dname="CN=${cn}, OU=Mobile, O=${cn}, L=Unknown, ST=Unknown, C=GB"

  while true; do
    read -r -s -p "Keystore password (min 6 chars): " store_password
    echo ""
    if [ "${#store_password}" -lt 6 ]; then
      echo "❌ Password too short."
      continue
    fi
    read -r -s -p "Confirm keystore password: " confirm
    echo ""
    if [ "$store_password" != "$confirm" ]; then
      echo "❌ Passwords did not match."
      continue
    fi
    break
  done

  read -r -s -p "Key password (press Enter to reuse keystore password): " key_password
  echo ""
  key_password="${key_password:-$store_password}"

  mkdir -p android

  if [ -f "$store" ]; then
    echo "ℹ️ Reusing existing keystore file: $store"
  else
    echo "🛠️ Creating upload keystore at $store ..."
    keytool -genkeypair \
      -v \
      -storetype JKS \
      -keyalg RSA \
      -keysize 2048 \
      -validity 10000 \
      -alias "$alias" \
      -keystore "$store" \
      -storepass "$store_password" \
      -keypass "$key_password" \
      -dname "$dname"
  fi

  cat > "$props" <<EOF
storePassword=$store_password
keyPassword=$key_password
keyAlias=$alias
storeFile=upload-keystore.jks
EOF

  chmod 600 "$props" "$store" 2>/dev/null || true

  echo ""
  echo "✅ Wrote $props"
  echo "✅ Keystore ready: $store"
  echo ""
  echo "📌 Upload-key certificate fingerprints (add SHA-1 to Firebase / Google Sign-In if needed):"
  keytool -list -v -keystore "$store" -alias "$alias" -storepass "$store_password" 2>/dev/null \
    | grep -E 'SHA1:|SHA256:' || true
  echo ""
  echo "⚠️ Back up $store and the passwords offline. Do not commit them."
}

# Ask whether this is the first Play release; set up signing when needed.
# Aborts if release signing is still missing after the prompt.
ensure_android_release_signing() {
  local first_answer=""
  local setup_answer=""

  if [ ! -d android ]; then
    echo "❌ android/ folder not found. Run this from the Flutter project root."
    exit 1
  fi

  if android_release_uses_debug_signing; then
    echo "⚠️ android/app/build.gradle.kts still hard-codes debug signing for release."
    echo "   Update it to load android/key.properties (template already includes this)."
    exit 1
  fi

  echo ""
  read -r -p "🆕 Is this the first Play Store release for this app? (y/n): " first_answer
  case "$first_answer" in
    y|Y|yes|YES)
      if is_android_release_signing_configured; then
        echo "✅ Release signing is already set up — continuing."
      else
        setup_android_release_signing
      fi
      ;;
    *)
      if is_android_release_signing_configured; then
        echo "✅ Using existing release keystore."
      else
        echo "❌ Release signing is not configured."
        echo "   Play Console rejects AABs signed in debug mode."
        read -r -p "Set up Android release signing now? (y/n): " setup_answer
        case "$setup_answer" in
          y|Y|yes|YES) setup_android_release_signing ;;
          *)
            echo "🛑 Aborting. Configure signing, then re-run."
            exit 1
            ;;
        esac
      fi
      ;;
  esac

  if ! is_android_release_signing_configured; then
    echo "❌ Release signing still missing after setup."
    exit 1
  fi
}

# Fail the release if the built AAB is still debug-signed.
verify_aab_release_signed() {
  local aab_path="$1"
  local cert_info=""

  if [ ! -f "$aab_path" ]; then
    echo "❌ AAB not found for signing check: $aab_path"
    exit 1
  fi

  if ! command -v jarsigner >/dev/null 2>&1; then
    echo "⚠️ jarsigner not found — skipping debug-signature check."
    return 0
  fi

  cert_info=$(jarsigner -verify -verbose -certs "$aab_path" 2>/dev/null || true)
  if echo "$cert_info" | grep -qi 'CN=Android Debug'; then
    echo "❌ AAB is signed with the Android debug key."
    echo "   Play Console will reject it. Fix release signing and rebuild."
    exit 1
  fi

  echo "✅ AAB is not debug-signed."
}
