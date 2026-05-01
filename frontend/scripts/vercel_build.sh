#!/usr/bin/env bash
# Vercel(Linux)에서 Flutter Web 빌드를 수행한다.
# 필수 환경변수: API_BASE_URL (예: https://your-app.up.railway.app)

set -euo pipefail

FRONTEND="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$FRONTEND"

if [ -z "${API_BASE_URL:-}" ]; then
  echo "ERROR: Vercel 프로젝트에 API_BASE_URL 환경 변수를 설정하세요 (백엔드 베이스 URL, 경로 제외)."
  exit 1
fi

FLUTTER_HOME="${FLUTTER_HOME:-/tmp/flutter-vega-ci}"
if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  rm -rf "$FLUTTER_HOME"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_HOME"
fi
export PATH="${FLUTTER_HOME}/bin:${PATH}"

flutter config --no-analytics
flutter precache --web
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="${API_BASE_URL}"
