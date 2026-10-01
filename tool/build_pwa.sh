#!/usr/bin/env bash
# Builds the app as a PWA and publishes it into moncampus, which serves it at /campus-app/ - the
# same origin as the API, so the app needs no API_BASE_URL (lib/services/api_config.dart) and no
# CORS. Never pass --dart-define=API_BASE_URL here: a web build always calls its own origin.
#
#   tool/build_pwa.sh [<moncampus repo>]
#
# CanvasKit is served from moncampus rather than Google's CDN: the app must open on a school
# network that filters it, and offline to say so. Only the files the CanvasKit renderer loads are
# kept - not the skwasm renderer, not the debug symbols, not Flutter's own service worker
# (replaced by campus_sw.js, see there why). Same recipe as e-CO's tool/build_pwa.sh.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MONCAMPUS_REPO="${1:-/Users/Shared/Projets/Symfony/moncampus}"
TARGET="$MONCAMPUS_REPO/public/campus-app"
FLUTTER=$(command -v flutter || echo /Users/Shared/flutter/bin/flutter)

if [ ! -d "$MONCAMPUS_REPO/public" ]; then
	echo "No public/ under $MONCAMPUS_REPO" >&2
	exit 1
fi

cd "$APP_DIR"
"$FLUTTER" pub get
"$FLUTTER" build web --release --web-renderer canvaskit --no-web-resources-cdn --base-href /campus-app/ --no-source-maps

OUT="$APP_DIR/build/web"
rm -f "$OUT/flutter_service_worker.js" "$OUT/.last_build_id"
rm -f "$OUT"/canvaskit/skwasm.*
find "$OUT/canvaskit" -name '*.symbols' -delete

mkdir -p "$TARGET"
rsync -a --delete --exclude README.md "$OUT/" "$TARGET/"

echo "PWA $(grep -m1 '^version:' pubspec.yaml | awk '{print $2}') published to $TARGET ($(du -sh "$TARGET" | cut -f1))."
