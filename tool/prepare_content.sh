#!/usr/bin/env bash
# Builds assets/db/content.db and content.version from data-source/ and verifies it. Run before flutter run/build.
set -euo pipefail
cd "$(dirname "$0")/.."
dart run tool/build_content_db.dart
dart run tool/verify_content_db.dart --full
