# Why a good APK still won't install

These checks are applied by the package installer, not the compiler. Each
produces a clean build and then a refusal, and the on-device errors are mostly
unhelpful. `scripts/verify_apk.sh` checks all of them; this explains what they
mean and how to fix each.

They apply to **any** APK, including ones built with Gradle.

## targetSdkVersion floor

Android refuses to install apps targeting too-old API levels:

| Device Android version | Minimum `targetSdkVersion` |
|---|---|
| 14 (API 34) | 23 |
| 15 (API 35) | 24 |

`targetSdk` is a manifest declaration and is **completely independent of what
you compiled against**. The installer reads the manifest; it has no idea which
`android.jar` was on your classpath. Compiling against API 23 while declaring
`targetSdkVersion="34"` is valid, normal, and the single thing that makes an old
offline toolchain usable on a current phone.

The trade is that you've opted into modern runtime behaviour — scoped storage,
runtime permissions, background limits — without a compiler that knows about any
of it. `constraints.md` covers what that means in practice.

*Symptom:* install fails immediately, sometimes `INSTALL_FAILED_DEPRECATED_SDK_VERSION`.
*Fix:* raise `targetSdkVersion` to 34 and make the code behave accordingly.

## resources.arsc must be stored uncompressed

From targetSdk 30 the resource table has to be stored (not deflated) and 4-byte
aligned, so the platform can mmap it directly.

*Symptom:* `INSTALL_PARSE_FAILED_RESOURCES_ARSC_COMPRESSED`.
*Fix:* aapt2 stores it correctly by default — this usually breaks when something
rebuilds or re-zips the APK afterwards. Check with `unzip -v` and compare the
raw and compressed sizes: they must be equal.

## A v2 signature is required

From targetSdk 30, v1 (JAR) signing alone is rejected. Sign with v1+v2+v3: v1
still matters below API 24, v2 satisfies the requirement, v3 allows key rotation
later.

*Symptom:* `INSTALL_PARSE_FAILED_NO_CERTIFICATES` or a generic parse failure.
*Fix:* `apksigner sign --v1-signing-enabled true --v2-signing-enabled true
--v3-signing-enabled true`.

## Align before signing

`zipalign` rewrites entry offsets. Doing it after signing invalidates the v2/v3
signatures, which cover the archive's physical layout. The order is always
**align, then sign**.

*Symptom:* `apksigner verify` fails, or install fails with no clear reason.
*Fix:* rebuild in the right order.

## android:exported must be explicit

From API 31, any `activity`, `service` or `receiver` with an `intent-filter`
must state `android:exported` explicitly. There is no default any more.

*Symptom:* the app installs but won't launch, or aapt reports a manifest error.
*Fix:* `android:exported="true"` on the launcher activity and on any widget
receiver; `false` on anything that shouldn't be reachable from other apps.

## Signing key identity

Android will not install an update over an app signed with a different key. The
keystore generated on the first build is the only way to ship a version 2.

*Symptom:* `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
*Fix:* reuse the original keystore, or uninstall the old app first — which loses
its data, so warn the user before suggesting it.

## Package visibility

From targetSdk 30, `getLaunchIntentForPackage()` and similar return nothing for
apps you haven't declared in a `<queries>` element. Often the cleaner answer is
to skip package targeting entirely: send an `ACTION_VIEW` intent for the
relevant `https://` URL and let whichever app has claimed that domain take it,
falling back to the browser. No declaration needed, and it degrades sensibly.

## Unknown sources

Not a defect, but it's what most people hit first: a self-signed APK arriving
outside the Play Store requires the user to allow "install unknown apps" for
whichever app opens the file. Mention it when handing over, or it reads as a
broken build.

## What none of this catches

Verification is structural. It says the package is well-formed, correctly signed
and acceptable to the installer. It says nothing about whether the app runs. A
`NoSuchMethodError` from calling an API above `minSdk`, or a crash inflating a
layout, passes every check here and dies on launch.

On the offline path there is no emulator — system images come from the blocked
Google host, Robolectric from Maven — so the only real test is a human with a
phone. Be explicit about that when handing over, and make it easy for them to
report back.
