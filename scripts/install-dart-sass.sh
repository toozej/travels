#!/usr/bin/env bash
set -euo pipefail

DART_SASS_VERSION="${DART_SASS_VERSION:-1.108.2}"
INSTALL_PREFIX="${1:-/usr/local}"

case "$(uname -s)" in
    Linux) SASS_OS=linux ;;
    Darwin) SASS_OS=macos ;;
    *) echo "Dart Sass installation requires Linux or macOS." >&2; exit 1 ;;
esac

case "$(uname -m)" in
    x86_64|amd64) SASS_ARCH=x64 ;;
    aarch64|arm64) SASS_ARCH=arm64 ;;
    *) echo "Dart Sass installation requires an x64 or ARM64 processor." >&2; exit 1 ;;
esac

SASS_TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$SASS_TEMP_DIR"' EXIT

curl --fail --silent --show-error --location \
    "https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/dart-sass-${DART_SASS_VERSION}-${SASS_OS}-${SASS_ARCH}.tar.gz" \
    --output "${SASS_TEMP_DIR}/dart-sass.tar.gz"
tar -xzf "${SASS_TEMP_DIR}/dart-sass.tar.gz" -C "$SASS_TEMP_DIR"

mkdir -p "${INSTALL_PREFIX}/lib/dart-sass" "${INSTALL_PREFIX}/bin"
INSTALL_PREFIX="$(cd "$INSTALL_PREFIX" && pwd)"
cp -R "${SASS_TEMP_DIR}/dart-sass/." "${INSTALL_PREFIX}/lib/dart-sass/"
ln -sfn "${INSTALL_PREFIX}/lib/dart-sass/sass" "${INSTALL_PREFIX}/bin/sass"
"${INSTALL_PREFIX}/bin/sass" --version
