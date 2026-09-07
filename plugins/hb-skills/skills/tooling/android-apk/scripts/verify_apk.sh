#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Checks an APK against the gates the Android package installer applies.
#
# Every one of these produces a clean build and then a refused install, usually
# with an error naming none of the actual causes. Checking here is the
# difference between "it works" and "it built".
#
#   usage: verify_apk.sh path/to/app.apk
# ---------------------------------------------------------------------------
set -uo pipefail

APK="${1:-}"
[ -f "$APK" ] || { echo "usage: verify_apk.sh <app.apk>"; exit 1; }

PASS=0; FAIL=0; WARN=0
pass() { printf '  \033[32m✓\033[0m %-46s %s\n' "$1" "${2:-}"; PASS=$((PASS+1)); }
fail() { printf '  \033[31m✗\033[0m %-46s %s\n' "$1" "${2:-}"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33m!\033[0m %-46s %s\n' "$1" "${2:-}"; WARN=$((WARN+1)); }
quiet() { grep -v "^Picked up JAVA_TOOL_OPTIONS" || true; }

BADGING=$(aapt dump badging "$APK" 2>/dev/null | quiet)
[ -n "$BADGING" ] || { echo "Cannot parse $APK — it is not a valid APK."; exit 1; }

# aapt uses two shapes in the same dump: "key:'value'" on its own line, and
# "key='value'" inside a line. Anchor each so sdkVersion can't match
# targetSdkVersion and application-label can't match application-label-en.
line_field() { sed -n "s/^$1:'\([^']*\)'.*/\1/p" <<<"$BADGING" | head -1; }
attr_field() { sed -n "s/.*[^-a-zA-Z]$1='\([^']*\)'.*/\1/p" <<<"$BADGING" | head -1; }

TGT=$(line_field "targetSdkVersion")
MIN=$(line_field "sdkVersion")
LABEL=$(line_field "application-label")
PKG=$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<<"$BADGING" | head -1)
VNAME=$(attr_field "versionName")
LAUNCH=$(sed -n "s/^launchable-activity: name='\([^']*\)'.*/\1/p" <<<"$BADGING" | head -1)

echo
echo "=============================================================="
echo " $LABEL $VNAME — $PKG"
echo " minSdk $MIN / targetSdk $TGT"
echo "=============================================================="
echo
echo "[1] Manifest"

if [ -z "$TGT" ]; then
    fail "targetSdkVersion declared" "missing"
elif [ "$TGT" -ge 24 ]; then
    pass "targetSdkVersion >= 24" "installs on Android 15+"
elif [ "$TGT" -ge 23 ]; then
    warn "targetSdkVersion is $TGT" "Android 15+ will REFUSE this; raise to 24+"
else
    fail "targetSdkVersion is $TGT" "Android 14+ refuses anything below 23"
fi

[ -n "$PKG" ] && pass "package name" "$PKG" || fail "package name" "missing"
[ -n "$LAUNCH" ] \
    && pass "launcher activity" "$LAUNCH" \
    || fail "launcher activity" "no LAUNCHER intent filter — app won't appear"
grep -q "application-icon" <<<"$BADGING" \
    && pass "launcher icon" \
    || warn "launcher icon" "none declared; a blank icon looks broken"

if [ -n "$TGT" ] && [ "$TGT" -ge 31 ]; then
    warn "android:exported" "required on filtered components from API 31 — confirm it's set"
fi

echo
echo "[2] Packaging"
ARSC=$(unzip -v "$APK" 2>/dev/null | awk '$0 ~ /resources\.arsc/ {print $1, $3}')
if [ -z "$ARSC" ]; then
    warn "resources.arsc" "absent (no resources?)"
else
    RAW=$(awk '{print $1}' <<<"$ARSC"); CMP=$(awk '{print $2}' <<<"$ARSC")
    [ "$RAW" = "$CMP" ] \
        && pass "resources.arsc stored uncompressed" \
        || fail "resources.arsc is COMPRESSED" "targetSdk>=30 rejects this"
fi

unzip -l "$APK" 2>/dev/null | grep -q "classes.dex" \
    && pass "classes.dex present" || fail "classes.dex present" "no code in the APK"

DEXMAGIC=$(unzip -p "$APK" classes.dex 2>/dev/null | head -c 4 | tr -d '\0')
[ "$DEXMAGIC" = "dex" ] && pass "classes.dex is valid dex" || fail "classes.dex is valid dex"

if zipalign -c -p 4 "$APK" >/dev/null 2>&1; then
    pass "zipalign 4-byte"
else
    fail "zipalign 4-byte" "align before signing, not after"
fi

echo
echo "[3] Signing"
SIG=$(apksigner verify --verbose "$APK" 2>&1 | quiet)
grep -q "^Verifies" <<<"$SIG" && pass "signature verifies" || fail "signature verifies" "UNSIGNED or corrupt"
grep -q "v1 scheme (JAR signing): true" <<<"$SIG" \
    && pass "v1 signature" || warn "v1 signature" "needed below API 24"
if grep -q "v2 scheme (APK Signature Scheme v2): true" <<<"$SIG"; then
    pass "v2 signature" "required for targetSdk >= 30"
else
    fail "v2 signature" "targetSdk >= 30 will refuse to install"
fi
grep -q "v3 scheme (APK Signature Scheme v3): true" <<<"$SIG" \
    && pass "v3 signature" || warn "v3 signature" "optional but preferred"

echo
echo "=============================================================="
printf " %d passed, %d warnings, %d failed\n" "$PASS" "$WARN" "$FAIL"
echo "=============================================================="
echo
if [ "$FAIL" -gt 0 ]; then
    echo " Do NOT hand this over — it will fail to install."
    echo " See references/install-gates.md for what each gate means."
    exit 1
fi
echo " Structurally sound and installable."
echo
echo " Still outstanding, because no static check can cover them:"
echo "   • Every framework API and XML attribute used must exist at minSdk $MIN."
echo "     Guard anything newer with Build.VERSION.SDK_INT."
if unzip -l "$APK" 2>/dev/null | grep -q "res/xml/"; then
echo "   • This APK has res/xml/ — if it declares a widget, also run"
echo "     check_widget.sh, which verify_apk.sh knows nothing about."
fi
echo "   • The app has not been run. Say so when handing it over, and ask the"
echo "     user to sideload it and report back."
echo
