#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "\n=== Firebase integration helper script ===\n"

# Config values (from user)
FIREBASE_PROJECT_ID="districtfood-e0f9b"
ANDROID_PACKAGE="com.mycompany.districttakeaway"
IOS_BUNDLE_ID="com.mycompany.districttakeaway"
ANDROID_SHA1="9b:bb:31:86:b2:18:9e:f1:6d:8f:27:2b:da:b5:93:62:c3:95:cb:b4"
ANDROID_SHA256="07:b9:2e:02:75:d5:e2:f3:b3:51:ef:6c:44:c5:a6:74:c3:6b:e6:f4:36:9f:01:e0:13:34:af:a3:7b:6d:6e:ef"

echo "Project dir: $PROJECT_DIR"

echo "\n1) Checking for Flutter..."
if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter not found on PATH. Install Flutter first: https://flutter.dev/docs/get-started/install"
  exit 1
fi

echo "Flutter found: $(flutter --version | head -n1)"

if ! command -v dart >/dev/null 2>&1; then
  echo "WARNING: dart not found on PATH. dart is required for flutterfire CLI. On most setups dart is bundled with Flutter; ensure 'dart' is on PATH (e.g. export PATH=\"\$PATH:\$HOME/.pub-cache/bin\")."
fi

echo "\n2) Ensure project platform folders exist (android/ios). Running 'flutter create .' if needed..."
if [ ! -d android ] || [ ! -d ios ]; then
  echo "android or ios folders missing — running: flutter create ."
  flutter create .
else
  echo "android & ios folders exist."
fi

echo "\n3) Fetching pub dependencies"
flutter pub get

echo "\n4) Installing flutterfire CLI (dart pub global activate flutterfire_cli)"
dart pub global activate flutterfire_cli || true

# Ensure pub-cache bin on PATH for this session
export PATH="$PATH:$HOME/.pub-cache/bin"

echo "\n5) Running flutterfire configure for project: $FIREBASE_PROJECT_ID (interactive)"
echo "When prompted by flutterfire configure, choose/create Android app with package name: $ANDROID_PACKAGE and iOS app with bundle id: $IOS_BUNDLE_ID."
echo "If asked for SHA fingerprints, provide these values:\n  SHA-1: $ANDROID_SHA1\n  SHA-256: $ANDROID_SHA256\n"

# Run configure - interactive. The user will need to follow prompts. This command often writes lib/firebase_options.dart and platform files.
flutterfire configure --project "$FIREBASE_PROJECT_ID" --platforms android,ios || {
  echo "\nflutterfire configure failed or was interrupted. Check the output above for guidance."
  exit 1
}

echo "\n6) Post-config: fetching packages again"
flutter pub get

cat <<EOF

DONE (interactive step completed if flutterfire configure finished successfully).

Next manual steps you may need to complete in the Firebase Console or locally:

- Verify that lib/firebase_options.dart was generated and contains your Firebase configuration.
  Path: lib/firebase_options.dart

- Android:
  - Verify android/app/google-services.json exists. If missing, download it from Firebase Console > Project settings > Your apps > Android app and place it in android/app/
  - Add SHA fingerprints to the Android app in Firebase Console if flutterfire configure did not add them.
  - Ensure android/build.gradle project-level has the Google services classpath in buildscript dependencies:
      classpath 'com.google.gms:google-services:4.3.15'
  - Ensure android/app/build.gradle applies the google services plugin at the bottom:
      apply plugin: 'com.google.gms.google-services'

- iOS:
  - Verify ios/Runner/GoogleService-Info.plist exists. If missing, download it and add to ios/Runner in Xcode.
  - Ensure the reversed client ID from the plist is reflected in ios/Runner/Info.plist if using Google Sign-In.

- Firebase Console:
  - Go to Authentication > Sign-in method and enable Email/Password and Google sign-in.
  - If enabling Google sign-in, ensure OAuth client is configured and Android SHA fingerprints are set.

To run the app locally now:
  flutter run

If you want me to review the generated lib/firebase_options.dart, paste its contents or confirm it's present and I'll update any placeholder code and finalize any small fixes in the repo.

EOF

exit 0
