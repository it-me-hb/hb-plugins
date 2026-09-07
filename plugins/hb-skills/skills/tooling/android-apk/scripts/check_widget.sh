#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Structural checks for an App Widget inside a built APK.
#
# verify_apk.sh knows nothing about widgets, and widget mistakes fail in ways
# that are especially hard to diagnose: the launcher just shows "Problem loading
# widget" with no attribution. These are the three that can be caught statically.
#
#   usage: check_widget.sh app.apk [widget_layout_name ...]
#
# With no layout names given it checks every res/layout/*widget*.xml in the APK.
# ---------------------------------------------------------------------------
set -uo pipefail

APK="${1:-}"
[ -f "$APK" ] || { echo "usage: check_widget.sh <app.apk> [layout ...]"; exit 1; }
shift || true

PASS=0; FAIL=0; WARN=0
pass() { printf '  \033[32m✓\033[0m %-46s %s\n' "$1" "${2:-}"; PASS=$((PASS+1)); }
fail() { printf '  \033[31m✗\033[0m %-46s %s\n' "$1" "${2:-}"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33m!\033[0m %-46s %s\n' "$1" "${2:-}"; WARN=$((WARN+1)); }

# Classes RemoteViews can inflate. Anything else — above all a custom View —
# cannot appear in a widget at any cost.
WHITELIST="FrameLayout LinearLayout RelativeLayout GridLayout TextView ImageView
Button ImageButton ProgressBar Chronometer AnalogClock TextClock ViewFlipper
ListView GridView StackView AdapterViewFlipper ViewStub"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
aapt dump resources "$APK" 2>/dev/null > "$TMP/res.txt" || true
# aapt prints "spec resource 0x7f040001 com.pkg:layout/w_compact: flags=..." —
# note the trailing colon, which will silently eat the whole name if you strip
# to the last ':' instead of the last '/'.
resolve() {
    grep -o "resource $1 [^ ]*" "$TMP/res.txt" 2>/dev/null | head -1 \
        | awk '{print $3}' | sed 's/:$//; s|.*/||'
}

# Which layouts are the widget's? initialLayout names one for certain. A
# provider that swaps layouts by size names the others only in code, so they
# can't be found by inspection — fall back to the sibling naming convention
# (widget_compact / widget_full) and let the caller override by argument.
discover_layouts() {
    local names="" hex n prefix
    for f in $(unzip -l "$APK" 2>/dev/null | grep -oE 'res/xml[^ ]*/[^ ]*\.xml'); do
        local tree
        tree=$(aapt dump xmltree "$APK" "$f" 2>/dev/null)
        grep -q "E: appwidget-provider" <<<"$tree" || continue
        hex=$(grep -oE 'android:initialLayout\(0x[0-9a-f]+\)=@(0x[0-9a-f]+)' <<<"$tree" \
              | sed 's/.*=@//' | head -1)
        [ -n "$hex" ] || continue
        n=$(resolve "$hex")
        [ -n "$n" ] || continue
        names="$names $n"
        prefix="${n%_*}"
        if [ "$prefix" != "$n" ]; then
            names="$names $(unzip -l "$APK" 2>/dev/null \
                | grep -oE "res/layout[^ ]*/${prefix}_[^ ]*\.xml" \
                | sed 's|.*/||; s|\.xml$||')"
        fi
    done
    names="$names $(unzip -l "$APK" 2>/dev/null | grep -oE 'res/layout[^ ]*/[^ ]*widget[^ ]*\.xml' \
                    | sed 's|.*/||; s|\.xml$||')"
    echo $names | tr ' ' '\n' | sort -u | tr '\n' ' '
}

if [ "$#" -gt 0 ]; then
    LAYOUTS=$(echo "$*")
else
    LAYOUTS=$(discover_layouts)
fi
LAYOUTS=$(echo $LAYOUTS)

echo
echo "=============================================================="
echo " Widget checks — $(basename "$APK")"
echo "=============================================================="

echo
echo "[1] Provider registration"
MANI=$(aapt dump xmltree "$APK" AndroidManifest.xml 2>/dev/null)
if grep -q "android.appwidget.provider" <<<"$MANI"; then
    pass "appwidget provider meta-data present"
else
    fail "appwidget provider meta-data" "receiver has no android.appwidget.provider"
fi
# 0xffffffff is how aapt renders boolean true.
if grep -A12 "E: receiver" <<<"$MANI" | grep -q "android:exported.*0xffffffff"; then
    pass "receiver exported=true" "AppWidgetHost is another process"
else
    fail "receiver exported=true" "the system cannot deliver updates to it"
fi
if grep -q "APPWIDGET_UPDATE" <<<"$MANI"; then
    pass "APPWIDGET_UPDATE intent filter"
else
    fail "APPWIDGET_UPDATE intent filter" "onUpdate will never fire"
fi

echo
echo "[2] Provider configuration"
INFO=$(unzip -l "$APK" 2>/dev/null | grep -oE 'res/xml[^ ]*/[^ ]*\.xml' | head -5)
FOUND_INFO=0
for f in $INFO; do
    TREE=$(aapt dump xmltree "$APK" "$f" 2>/dev/null)
    grep -q "E: appwidget-provider" <<<"$TREE" || continue
    FOUND_INFO=1
    grep -q "android:initialLayout" <<<"$TREE" \
        && pass "initialLayout declared" "$(basename "$f")" \
        || fail "initialLayout declared" "$(basename "$f") — widget cannot inflate"
    if grep -qE "targetCellWidth|targetCellHeight|maxResizeWidth|previewLayout" <<<"$TREE"; then
        warn "API 31 sizing attributes present" "won't link against an API 23 android.jar"
    fi
    grep -q "android:minWidth" <<<"$TREE" && grep -q "android:minHeight" <<<"$TREE" \
        && pass "minWidth/minHeight declared" "grid maths is 70*cells - 30" \
        || warn "minWidth/minHeight" "launcher will guess a size"
done
[ "$FOUND_INFO" = 1 ] || fail "appwidget-provider xml" "none found under res/xml/"

echo
echo "[3] Layouts — RemoteViews legality"
[ -n "$LAYOUTS" ] || warn "widget layouts" "none matched; pass names explicitly"
declare -A IDSETS
for lay in $LAYOUTS; do
    TREE=$(aapt dump xmltree "$APK" "res/layout/$lay.xml" 2>/dev/null)
    if [ -z "$TREE" ]; then
        fail "$lay" "not found in the APK"
        continue
    fi
    BAD=""
    for cls in $(grep -oE '^\s*E: [A-Za-z.]+' <<<"$TREE" | awk '{print $2}' | sort -u); do
        case " $WHITELIST " in
            *" $cls "*) ;;
            *) BAD="$BAD $cls" ;;
        esac
    done
    if [ -n "$BAD" ]; then
        fail "$lay uses illegal views" "$BAD"
    else
        pass "$lay — all views RemoteViews-legal"
    fi

    NAMES=""
    for hex in $(grep -oE 'android:id\(0x[0-9a-f]+\)=@(0x[0-9a-f]+)' <<<"$TREE" \
                 | sed 's/.*=@//' | sort -u); do
        n=$(resolve "$hex"); NAMES="$NAMES ${n:-$hex}"
    done
    IDSETS[$lay]=$(echo $NAMES | tr ' ' '\n' | sort | tr '\n' ' ')
done

echo
echo "[4] Layouts — id parity"
# RemoteViews throws if an action targets an id absent from the layout it
# inflated. Any provider that swaps layouts by size must therefore expose an
# identical id set in every one of them.
COUNT=$(echo $LAYOUTS | wc -w)
if [ "$COUNT" -lt 2 ]; then
    pass "single widget layout" "nothing to reconcile"
else
    FIRST=$(echo $LAYOUTS | awk '{print $1}')
    SAME=1
    for lay in $LAYOUTS; do
        if [ "${IDSETS[$lay]}" != "${IDSETS[$FIRST]}" ]; then
            SAME=0
            echo "      $lay: ${IDSETS[$lay]}"
        fi
    done
    if [ "$SAME" = 1 ]; then
        pass "all $COUNT layouts expose identical ids" "${IDSETS[$FIRST]}"
    else
        fail "layouts have different id sets" "RemoteViews will throw on the odd one"
        echo "      $FIRST: ${IDSETS[$FIRST]}"
    fi
fi

echo
echo "=============================================================="
printf " %d passed, %d warnings, %d failed\n" "$PASS" "$WARN" "$FAIL"
echo "=============================================================="
echo
echo " Not checkable here — verify by reading the code:"
echo "   • Every Bitmap sent via setImageViewBitmap must be downscaled;"
echo "     RemoteViews shares a ~1MB Binder transaction budget."
echo "   • Every PendingIntent needs FLAG_IMMUTABLE (targetSdk 31+) and a"
echo "     distinct requestCode + data URI, or multiple widgets collapse into one."
echo
[ "$FAIL" -gt 0 ] && exit 1
exit 0
