#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  sdk_dir="${HOME}/flutter"
  if [ ! -x "${sdk_dir}/bin/flutter" ]; then
    archive="$(mktemp)"
    trap 'rm -f "$archive"' EXIT
    curl --fail --location --silent --show-error \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      --output "$archive"
    tar -xJf "$archive" -C "$HOME"
  fi
  export PATH="${sdk_dir}/bin:${PATH}"
fi

flutter config --enable-web
flutter pub get
flutter build web --release --no-web-resources-cdn
dart run tool/verify_no_web_cdn.dart
