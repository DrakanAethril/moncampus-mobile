#!/usr/bin/env bash
# Retired on 2026-11-04. This script used to build the app for the web and publish it into
# moncampus's public/campus-app/, served at /campus-app/. That web version no longer exists: the
# Formatool site itself is now the installable app « beaup-app », and moncampus's public/campus-app/
# holds only campus_sw.js, the kill switch that cleans the phones which had installed the old web
# build (every other /campus-app/ address redirects to /). Publishing a build there would overwrite
# the kill switch and put the retired app back online, so this script refuses to run.
#
# The Android/iOS apps are unaffected. The web-only code (lib/services/platform_bridge_web.dart,
# web/campus_web.js, web/campus_sw.js) stays for now; it simply has no build that ships it.
set -euo pipefail

echo "tool/build_pwa.sh is retired: the Campus PWA was replaced by the installable Formatool site (beaup-app)." >&2
echo "Do not publish anything into moncampus/public/campus-app/ - it holds the kill-switch service worker." >&2
exit 1
