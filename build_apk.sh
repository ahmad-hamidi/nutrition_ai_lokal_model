#!/usr/bin/env bash
set -euo pipefail
flutter pub get
flutter analyze
flutter test
flutter build apk --release
printf '\nAPK: build/app/outputs/flutter-apk/app-release.apk\n'
