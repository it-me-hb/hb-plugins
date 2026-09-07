---
name: android-apk
description: Build a real, installable Android APK from a plain-language app description — toolchain setup, build pipeline, and pre-install verification, end to end. Use this whenever someone wants an Android app, an .apk, a home screen widget, something to sideload onto a phone, or says things like "build me an app for my phone", "make an android app that…", "port this to Android", "can you compile this to an apk" — even if they never say the words "Android" or "APK". Also use when an existing Android build is failing at compile, dex, sign, align, or install. Works in locked-down sandboxes where Google's SDK servers and Maven are firewalled, by falling back to a Debian/Ubuntu-packaged toolchain.
---

# Building an installable Android APK

The goal is an APK the user can copy onto a phone, tap, and have it install and
run. Everything here exists to protect that outcome, because an APK can build
cleanly and still be refused by the installer for reasons that produce no
compile error at all.

## Work in four phases, in this order

The most common way these builds fail is designing the app first and discovering
the toolchain second. Half the design decisions — which UI widgets exist, whether
you can write a lambda, whether that library is reachable — are downstream of
what the environment can actually get to. Probe first, then let the answers
constrain the spec.

```
0. PROBE    scripts/probe_env.sh          what can this machine actually build?
1. SPEC     references/spec-template.md   agree what the app is, given those limits
2. BUILD    scripts/build_apk.sh          compile → dex → package → align → sign
3. VERIFY   scripts/verify_apk.sh         check the install gates before handing over
```

## Phase 0 — Probe

```bash
bash scripts/probe_env.sh
```

It tests the SDK and Maven hosts, checks for an installed toolchain, and prints
one of two verdicts.

**`VERDICT: GRADLE`** — Google and Maven are reachable. Take the normal path:
install the SDK with `sdkmanager`, build with Gradle and AGP, use AndroidX,
Material and Compose freely. Everything in `references/constraints.md` is
irrelevant to you; the file still worth reading is
`references/install-gates.md`, because those gates bite regardless of how the
APK was produced. Do not use the offline pipeline just because this skill
bundles one — Gradle is strictly better when it's available.

**`VERDICT: OFFLINE`** — Google and/or Maven are firewalled. No Gradle build is
possible, because the Android Gradle Plugin itself comes from Maven. Set up the
Debian-packaged toolchain instead:

```bash
sudo bash scripts/setup_toolchain.sh
```

That installs `aapt2`, a dexer, `zipalign`, `apksigner` and an API 23
`android.jar` from the Ubuntu/Debian `universe` repo — a completely separate
distribution channel from Google's, which is why it survives the firewall.

Two things about that toolchain that will otherwise cost you an hour:

- The dexer is packaged as **`dalvik-exchange`**. Not `d8`, which isn't packaged
  anywhere; and not `dx`, which in Ubuntu is OpenDX, an unrelated 1990s
  visualization suite. Searching by tool name finds nothing — the package only
  surfaces if you search the concept (`apt-cache search dalvik`). That
  generalises: when a tool seems missing, search for what it *does*, not what
  it's called.
- The `google-android-build-tools-*-installer` packages look like a rescue but
  are just downloader stubs pointing at the blocked host. Ignore them.

### Smoke-test the pipeline before writing any app code

```bash
cp -r assets/template ~/myapp && cd ~/myapp && bash <skill>/scripts/build_apk.sh
```

The template is a known-good minimal app. If it builds and verifies, the
toolchain is sound and every later failure is yours. If it doesn't, fix the
environment now — debugging a broken pipeline and unfamiliar app code
simultaneously is what turns a 20-minute job into a 2-hour one.

## Phase 1 — Spec

Read `references/spec-template.md` for the full question set. Ask only what
changes the build, and scale the questions to the app — don't interrogate
someone who wants a tip calculator. The ones that genuinely matter:

- **Does anything here need a third-party library?** The user can't answer this
  directly; infer it from what they described. On the OFFLINE path the answer
  has to be no. Say so at minute one — the same news at minute forty feels like
  a bait and switch.
- **Network, camera, location, or user-visible file storage?** Each adds a
  permission and a runtime flow. App-private storage needs none.
- **How does data persist?** Files via `getFilesDir()` for anything simple,
  `SQLiteOpenHelper` when there are real queries. Room is unavailable offline.
- **Minimum Android version.** minSdk 21 is a good default: near-universal
  device coverage, and it unlocks framework Material theming.

Write the spec down and show it to the user before building, with the
constraints as explicit clauses rather than as apologies afterwards.

### Porting an existing app

When the input is a working app for another platform, read its source before
designing anything. The thing you need from it isn't the UI — it's **where the
data comes from**, because that's what may not exist on Android. A desktop app
reading local files has no equivalent on a phone; one calling an HTTP API ports
directly. Find that boundary first, then port class for class and keep the
original's deliberate decisions (`references/networking.md` has the patterns for
auth and HTTP without any libraries).

## Phase 2 — Build

Lay the project out the way `build_apk.sh` expects:

```
myapp/
├── apk.conf                    APP_NAME, PACKAGE, VERSION_NAME, MIN_SDK, TARGET_SDK
├── AndroidManifest.xml         no <uses-sdk>; apk.conf owns the SDK levels
├── res/                        layout/, values/, drawable/, mipmap-*/, xml/, anim/
└── src/<package path>/*.java   any depth, discovered automatically
```

Then `bash scripts/build_apk.sh` from the project root. It compiles and links
resources, compiles Java, dexes, packages, aligns, generates a keystore on first
run, and signs with v1+v2+v3.

On the OFFLINE path you're writing against the **framework only**, and against a
2019-era dexer. Read `references/constraints.md` before writing code — it lists
what to use instead of each AndroidX component and the Java features that
compile fine and then fail at the dex step. The two that catch everyone:

- **No lambdas, method references, or default interface methods.** The dexer
  can't desugar `invokedynamic`. Use anonymous inner classes.
- **Keep `-source 8 -target 8`** (the build script does). Not just about class
  file version: from Java 9 the compiler implements ordinary string
  concatenation with `invokedynamic` too, which dexes just as badly as a lambda.

Compiling against API 23 does not stop you *targeting* 34 — see Phase 3.

### Look at what you built

You can't run the app, so the one feedback loop you do have is rendering things
as images and actually looking at them. Generate the launcher icon and open it.
Mock up the widget or a dense screen at its real dp size and open that too.

This is not a nicety — in this skill's own history, rendering a widget preview
at true size revealed that the fixed columns left about 15dp of space for the
content that was supposed to fill the middle. That was a genuine layout bug,
invisible in every build log, caught by looking at a picture. `make_icon.py`
writes a preview PNG for exactly this reason.

## Phase 3 — Verify

```bash
bash scripts/verify_apk.sh build/YourApp-1.0.apk
```

This matters most, because install-time failures are silent at build time.
`references/install-gates.md` explains each; the script checks them all. The
highest-value ones:

- **`targetSdkVersion`** must be ≥ 24 or Android 15+ refuses to install. This is
  independent of what you compiled against: the installer reads the manifest,
  not the classpath. An API 23 `android.jar` with `targetSdkVersion="34"` is
  exactly right — it's what makes the offline toolchain viable at all. It does
  mean honouring modern behaviour (scoped storage, runtime permissions) that the
  old classpath won't force on you.
- **`resources.arsc` stored uncompressed** for targetSdk ≥ 30, or you get
  `INSTALL_PARSE_FAILED_RESOURCES_ARSC_COMPRESSED`.
- **A v2 signature** is required for targetSdk ≥ 30. Align *then* sign; the
  reverse invalidates the signature.
- **`android:exported`** explicit on any component with an intent filter from
  API 31.

If the app has a home screen widget, also run `scripts/check_widget.sh` — widgets
have their own failure modes that `verify_apk.sh` knows nothing about.

Then do a static API-level pass, since nothing here catches it: every framework
class, method and XML attribute must exist at your `minSdk`. Guard anything
newer with `Build.VERSION.SDK_INT`.

## Handing it over

Send the APK and a zip of the source, and tell the user plainly:

- **The app has never been run.** There is no emulator on the offline path —
  system images come from the blocked host, Robolectric from Maven. The
  verification is structural: valid dex, correct alignment, signatures verify,
  install gates satisfied. That is not the same as "it works", and saying so is
  what keeps their trust when something misbehaves.
- Name the *most likely* failure point specifically rather than hedging in
  general. A network call you couldn't test, an animation the launcher may
  throttle — a named risk is something they can check in ten seconds.
- They'll need to allow installs from unknown sources, since it's signed with a
  self-generated key.
- Where the keystore is, and that updates must reuse it or Android will refuse
  to install over the top.

Then ask them to sideload it and report back — the human is the test harness, so
make it easy for them to tell you what happened. Design error states with this
in mind: surface the actual HTTP status or exception in the UI rather than a
generic "something went wrong", because that string is your only debugger.

## Reference map

| File | Read it when |
|---|---|
| `references/spec-template.md` | Phase 1, agreeing what to build |
| `references/constraints.md` | Before writing a line of app code, on the OFFLINE path |
| `references/install-gates.md` | Phase 3, and any time an APK builds but won't install |
| `references/widgets.md` | The app needs a home screen widget — read it first, widgets break most of the normal rules |
| `references/networking.md` | The app talks to an HTTP API, or needs a logged-in session |
| `assets/template/` | Smoke-testing, or as the skeleton for a new app |
