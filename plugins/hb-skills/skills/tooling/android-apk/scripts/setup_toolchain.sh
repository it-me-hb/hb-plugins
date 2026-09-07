#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Installs an Android build toolchain from the Debian/Ubuntu archive.
#
# Why this works when dl.google.com is blocked: Debian repackages the AOSP build
# tools independently, so they arrive over a completely different distribution
# channel. Older than what Google ships, but it produces APKs that install and
# run on current Android.
#
# Run as root (or under sudo). Safe to re-run.
# ---------------------------------------------------------------------------
set -euo pipefail

PKGS=(
    aapt                     # ships aapt2, the resource compiler/linker
    android-sdk-build-tools  # zipalign and friends
    android-sdk-common
    android-sdk-platform-23  # provides android.jar
    apksigner                # v1/v2/v3 APK signing
    dalvik-exchange          # THE DEXER. Not 'd8' (unpackaged), not 'dx' (OpenDX)
    default-jdk-headless     # javac + keytool
    zip
    python3-pil              # launcher icons and layout mockups
)

echo "==> installing: ${PKGS[*]}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq "${PKGS[@]}"

echo
echo "==> verifying"
fail=0
check() {
    if command -v "$1" >/dev/null 2>&1; then
        printf '  ✓ %-18s %s\n' "$1" "$(command -v "$1")"
    else
        printf '  ✗ %-18s MISSING\n' "$1"; fail=1
    fi
}
for t in aapt2 zipalign apksigner dalvik-exchange javac keytool zip; do check "$t"; done

JAR=$(ls -d /usr/lib/android-sdk/platforms/android-*/android.jar 2>/dev/null | sort -V | tail -1)
if [ -n "$JAR" ]; then
    printf '  ✓ %-18s %s\n' "android.jar" "$JAR"
else
    printf '  ✗ %-18s MISSING\n' "android.jar"; fail=1
fi
python3 -c "import PIL" 2>/dev/null \
    && printf '  ✓ %-18s ok\n' "Pillow" \
    || printf '  ! %-18s missing (icons only)\n' "Pillow"

echo
if [ "$fail" = 0 ]; then
    echo "Toolchain ready."
    echo "Smoke-test it before writing app code:"
    echo "    cp -r assets/template ~/smoketest && cd ~/smoketest && bash scripts/build_apk.sh"
else
    echo "Toolchain incomplete — see the ✗ lines above."
    exit 1
fi
