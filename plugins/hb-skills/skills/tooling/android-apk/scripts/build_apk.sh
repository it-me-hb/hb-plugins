#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Builds a signed, installable APK without Gradle.
#
#   res/*.xml   --aapt2 compile--> flat resources
#               --aapt2 link----> base APK + R.java
#   src/*.java  --javac---------> .class
#               --dexer---------> classes.dex   (injected into the APK)
#   APK         --zipalign------> --apksigner (v1+v2+v3) --> installable APK
#
# Run from a project root containing apk.conf.
# ---------------------------------------------------------------------------
set -euo pipefail

PROJ="$(pwd)"
BUILD="$PROJ/build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- config ---------------------------------------------------------------
APP_NAME="App"; PACKAGE=""; VERSION_NAME="1.0"; VERSION_CODE="1"
MIN_SDK="21"; TARGET_SDK="34"; KEYSTORE_PASS="android"
# shellcheck disable=SC1091
[ -f "$PROJ/apk.conf" ] && source "$PROJ/apk.conf"

[ -n "$PACKAGE" ] || { echo "ERROR: PACKAGE must be set in apk.conf"; exit 1; }
[ -f "$PROJ/AndroidManifest.xml" ] || { echo "ERROR: no AndroidManifest.xml here"; exit 1; }

# The manifest owns the package name at runtime; apk.conf only names it for the
# build. If they drift you get a build that succeeds and an app that can't find
# its own R class, so fail loudly here instead.
MANIFEST_PKG=$(sed -n 's/.*package="\([^"]*\)".*/\1/p' "$PROJ/AndroidManifest.xml" | head -1)
if [ -n "$MANIFEST_PKG" ] && [ "$MANIFEST_PKG" != "$PACKAGE" ]; then
    echo "ERROR: package mismatch"
    echo "  apk.conf            PACKAGE=$PACKAGE"
    echo "  AndroidManifest.xml package=\"$MANIFEST_PKG\""
    echo "  Make them identical, and put sources under src/${PACKAGE//.//}/"
    exit 1
fi

SAFE_NAME="${APP_NAME// /}"
APK="$SAFE_NAME-$VERSION_NAME.apk"
ANDROID_JAR="${ANDROID_JAR:-$(ls -d /usr/lib/android-sdk/platforms/android-*/android.jar 2>/dev/null | sort -V | tail -1)}"
[ -n "$ANDROID_JAR" ] || { echo "ERROR: no android.jar — run setup_toolchain.sh"; exit 1; }

DEXER=$(command -v dalvik-exchange || command -v d8 || true)
[ -n "$DEXER" ] || { echo "ERROR: no dexer — apt install dalvik-exchange"; exit 1; }

quiet() { grep -v "^Picked up JAVA_TOOL_OPTIONS" || true; }

echo "==> $APP_NAME $VERSION_NAME ($PACKAGE)  minSdk $MIN_SDK / targetSdk $TARGET_SDK"
rm -rf "$BUILD"; mkdir -p "$BUILD/gen" "$BUILD/classes"

# --- 1. resources ---------------------------------------------------------
echo "==> 1/7 compiling resources"
if [ -d "$PROJ/res" ]; then
    aapt2 compile --dir "$PROJ/res" -o "$BUILD/res.zip"
    RES_ARG=("$BUILD/res.zip")
else
    RES_ARG=()
fi

echo "==> 2/7 linking resources + manifest"
aapt2 link \
    -o "$BUILD/base.apk" \
    -I "$ANDROID_JAR" \
    --manifest "$PROJ/AndroidManifest.xml" \
    --java "$BUILD/gen" \
    --version-code "$VERSION_CODE" \
    --version-name "$VERSION_NAME" \
    --min-sdk-version "$MIN_SDK" \
    --target-sdk-version "$TARGET_SDK" \
    --auto-add-overlay \
    "${RES_ARG[@]}"

# Those flags only fill in a MISSING <uses-sdk>; a manifest that declares its own
# silently wins, and a wrong targetSdk stays invisible until the phone refuses to
# install. So assert on the linked output rather than trusting the inputs.
LINKED=$(aapt dump badging "$BUILD/base.apk" 2>/dev/null | quiet)
GOT_MIN=$(sed -n "s/^sdkVersion:'\([^']*\)'.*/\1/p" <<<"$LINKED" | head -1)
GOT_TGT=$(sed -n "s/^targetSdkVersion:'\([^']*\)'.*/\1/p" <<<"$LINKED" | head -1)
if [ "$GOT_MIN" != "$MIN_SDK" ] || [ "$GOT_TGT" != "$TARGET_SDK" ]; then
    echo "ERROR: SDK levels in the built APK don't match apk.conf"
    echo "  apk.conf says  minSdk=$MIN_SDK  targetSdk=$TARGET_SDK"
    echo "  APK contains   minSdk=${GOT_MIN:-none}  targetSdk=${GOT_TGT:-none}"
    echo "  A <uses-sdk> element in AndroidManifest.xml overrides these flags."
    echo "  Remove it and let apk.conf be the single source of truth."
    exit 1
fi

# --- 2. java --------------------------------------------------------------
echo "==> 3/7 compiling java"
SOURCES=$(find "$PROJ/src" "$BUILD/gen" -name '*.java' 2>/dev/null)
[ -n "$SOURCES" ] || { echo "ERROR: no .java sources under src/"; exit 1; }

CP="$ANDROID_JAR"
LIBS=$(ls "$PROJ"/libs/*.jar 2>/dev/null || true)
for j in $LIBS; do CP="$CP:$j"; done

# -source/-target 8 is load-bearing, not cosmetic: on 9+ javac compiles string
# concatenation to invokedynamic, which this dexer cannot handle.
# shellcheck disable=SC2086
javac -source 8 -target 8 -nowarn -encoding UTF-8 \
    -bootclasspath "$ANDROID_JAR" -classpath "$CP" \
    -d "$BUILD/classes" $SOURCES 2>&1 | quiet

echo "==> 4/7 dexing"
# shellcheck disable=SC2086
"$DEXER" --dex --min-sdk-version="$MIN_SDK" \
    --output="$BUILD/classes.dex" "$BUILD/classes" $LIBS 2>&1 | quiet
[ -f "$BUILD/classes.dex" ] || {
    echo "ERROR: dexing produced nothing."
    echo "  The usual cause is invokedynamic: a lambda, a method reference, a"
    echo "  default interface method, or string concat compiled at Java 9+."
    echo "  See references/constraints.md."
    exit 1; }

# --- 3. package, align, sign ---------------------------------------------
echo "==> 5/7 packaging dex"
( cd "$BUILD" && zip -q -j base.apk classes.dex )

echo "==> 6/7 aligning"
# Align BEFORE signing. Aligning afterwards rewrites entry offsets and
# invalidates the v2/v3 signatures, which then fail at install with no useful
# message.
zipalign -f -p 4 "$BUILD/base.apk" "$BUILD/aligned.apk"

echo "==> 7/7 signing"
KS="$PROJ/${SAFE_NAME}.keystore"
if [ ! -f "$KS" ]; then
    echo "    generating keystore (keep it — updates must reuse the same key)"
    keytool -genkeypair -v -keystore "$KS" -alias "$SAFE_NAME" \
        -keyalg RSA -keysize 2048 -validity 10950 \
        -storepass "$KEYSTORE_PASS" -keypass "$KEYSTORE_PASS" \
        -dname "CN=$APP_NAME, O=$APP_NAME, C=US" 2>&1 | quiet
fi
apksigner sign --ks "$KS" \
    --ks-pass "pass:$KEYSTORE_PASS" --key-pass "pass:$KEYSTORE_PASS" \
    --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
    --min-sdk-version "$MIN_SDK" \
    --out "$BUILD/$APK" "$BUILD/aligned.apk" 2>&1 | quiet

rm -f "$BUILD/base.apk" "$BUILD/aligned.apk" "$BUILD/classes.dex" "$BUILD/res.zip"
echo
echo "BUILT  $BUILD/$APK  ($(du -h "$BUILD/$APK" | cut -f1))"
echo
echo "Now verify it before handing it over:"
echo "    bash $SCRIPT_DIR/verify_apk.sh $BUILD/$APK"
