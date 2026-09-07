#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Capability probe for Android builds.
#
# Answers one question: can this machine reach Google's SDK servers and Maven?
# If yes, a normal Gradle build works and you should use it. If no, the entire
# modern Android stack is unavailable and the app has to be written against the
# framework alone — a design constraint, not just a build one, which is why this
# runs before anything gets specified.
# ---------------------------------------------------------------------------
set -uo pipefail

TIMEOUT=15
ok()   { printf '  \033[32m✓\033[0m %-34s %s\n' "$1" "${2:-}"; }
bad()  { printf '  \033[31m✗\033[0m %-34s %s\n' "$1" "${2:-}"; }
warn() { printf '  \033[33m!\033[0m %-34s %s\n' "$1" "${2:-}"; }

# True only for a real HTTP answer. A proxy refusal (403) or a dead connection
# (000) both mean "you cannot get there from here".
reach() {
    local code
    code=$(curl -sS -o /dev/null -m "$TIMEOUT" -w '%{http_code}' "$1" 2>/dev/null)
    [ -n "$code" ] && [ "$code" != "000" ] && [ "$code" != "403" ]
}

echo
echo "=============================================================="
echo " Android build capability probe"
echo "=============================================================="

echo
echo "[1] Toolchain hosts"
GOOGLE=0; MAVEN=0
reach https://dl.google.com/android/repository/repository2-3.xml \
    && { ok "dl.google.com" "Android SDK downloads"; GOOGLE=1; } \
    || bad "dl.google.com" "BLOCKED — no sdkmanager, no emulator images"
reach https://repo1.maven.org/maven2/ \
    && { ok "repo1.maven.org" "Maven Central"; MAVEN=1; } \
    || bad "repo1.maven.org" "BLOCKED — no AndroidX, no third-party libs"
reach https://maven.google.com/ \
    && ok "maven.google.com" "Google Maven" \
    || bad "maven.google.com" "BLOCKED — no AndroidX / AGP"
reach https://services.gradle.org/distributions/ \
    && ok "services.gradle.org" "Gradle distributions" \
    || bad "services.gradle.org" "BLOCKED"

echo
echo "[2] Fallback sources"
APT=0
reach http://archive.ubuntu.com/ubuntu/ \
    && { ok "archive.ubuntu.com" "Debian-packaged toolchain"; APT=1; } \
    || bad "archive.ubuntu.com" "BLOCKED"
reach https://registry.npmjs.org/ && ok "registry.npmjs.org" || bad "registry.npmjs.org"
reach https://pypi.org/ && ok "pypi.org" || bad "pypi.org"
reach https://raw.githubusercontent.com/github/gitignore/main/Android.gitignore \
    && ok "raw.githubusercontent.com" "single files" \
    || bad "raw.githubusercontent.com"
# Probe git separately: clone and release-asset downloads frequently work in
# environments where github.com's own HTML is refused. Don't infer one from
# the other.
if git ls-remote --heads https://github.com/github/gitignore.git >/dev/null 2>&1; then
    ok "git clone (https)" "arbitrary public repos"
else
    bad "git clone (https)"
fi

echo
echo "[3] Installed tools"
have() { command -v "$1" >/dev/null 2>&1; }
for t in java javac aapt2 zipalign apksigner; do
    if have "$t"; then ok "$t" "$(command -v "$t")"; else bad "$t" "missing"; fi
done
if have dalvik-exchange; then ok "dalvik-exchange" "the dexer"
elif have d8;             then ok "d8" "$(command -v d8)"
else bad "dexer" "missing — install dalvik-exchange, NOT the 'dx' package"; fi

JAR=$(ls -d /usr/lib/android-sdk/platforms/android-*/android.jar 2>/dev/null | sort -V | tail -1)
[ -n "$JAR" ] && ok "android.jar" "$JAR" || bad "android.jar" "missing"
have gradle && ok "gradle" "$(gradle --version 2>/dev/null | awk '/^Gradle/{print $2}')" \
             || warn "gradle" "not installed"

echo
echo "=============================================================="
if [ "$GOOGLE" = 1 ] && [ "$MAVEN" = 1 ]; then
    echo " VERDICT: GRADLE"
    echo "=============================================================="
    echo
    echo " Google and Maven are both reachable, so use the normal path:"
    echo " install the SDK with sdkmanager and build with Gradle/AGP."
    echo " AndroidX, Material and Compose are all available to you."
    echo
    echo " Ignore references/constraints.md — it only applies offline."
    echo " Still read references/install-gates.md: those failures happen"
    echo " no matter how the APK was produced."
elif [ "$APT" = 1 ]; then
    echo " VERDICT: OFFLINE"
    echo "=============================================================="
    echo
    echo " Google and/or Maven are firewalled, so no Gradle build is"
    echo " possible — the Android Gradle Plugin itself lives on Maven."
    echo " Use the Debian-packaged toolchain instead:"
    echo
    echo "     sudo bash scripts/setup_toolchain.sh"
    echo
    echo " This constrains the APP, not just the build: framework widgets"
    echo " only, and no lambdas. Read references/constraints.md BEFORE"
    echo " designing the UI or writing code."
else
    echo " VERDICT: BLOCKED"
    echo "=============================================================="
    echo
    echo " Neither Google/Maven nor the Ubuntu archive is reachable, and"
    echo " no toolchain is installed. Nothing here can build an APK."
    echo " Say so plainly rather than attempting a build that cannot work."
fi
echo
