# Agreeing what to build

Most people describing an app describe the screens. The things that actually
decide whether it can be built are invisible to them, so the job is to ask the
few questions that change the outcome and infer the rest.

Ask these **after** the probe, so the answers land against a real set of limits.
Ask them in one round, and scale them to the app — don't interrogate someone who
wants a tip calculator.

## The questions that change the build

**1. Does anything here need a third-party library?**
The most important question, and one the user can't answer directly — infer it
from what they've described. Maps, push notifications, barcode scanning,
sign-in, cloud sync, chat, video and ML all imply libraries. On the OFFLINE path
there are none. Say so immediately and offer the framework-only version of the
idea, or an honest "not in this environment". A user told at minute one takes it
fine; the same news at minute forty feels like a bait and switch.

**2. Does it need the network, camera, microphone, location, or contacts?**
Each adds a permission and a runtime request flow. Offline, network means
`HttpURLConnection` and `org.json` by hand — fine for a REST call, painful for
anything more. See `networking.md`.

**3. Where does the data live, and does the user ever need to see the files?**
- App-private (`getFilesDir()`) — no permissions, invisible to the user, deleted
  with the app. The right default.
- App-external (`getExternalFilesDir()`) — no permissions, survives in
  `Android/data/<pkg>/`, awkward to browse on Android 11+.
- Shared storage (Photos, Documents) — needs `MediaStore` and real care at high
  targetSdk. Only when the point is that the user gets the file.

**4. How much data, and does it need querying?**
A few values → `SharedPreferences`. A document or drawing → a file. Records that
need filtering or sorting → `SQLiteOpenHelper`. Room is unavailable offline.

**5. How many screens, and does state survive rotation?**
Panels toggled inside one Activity are simplest and avoid the Fragment
lifecycle. If rotation must preserve in-memory state, either declare
`android:configChanges="orientation|screenSize|keyboardHidden"` or implement
`onSaveInstanceState`. Deciding this late means rewriting.

**6. Minimum Android version.**
Default minSdk 21 — near-universal device coverage and framework Material
theming. Only go lower with a specific reason.

**7. Is there a home screen widget?**
Ask, because it changes the architecture rather than adding to it: the widget
renders in the launcher's process from cached data, so anything it displays has
to be persisted somewhere it can read. Read `widgets.md` before designing one.

## Write it down before building

A short spec, shown to the user, with the constraints as explicit clauses rather
than caveats afterwards:

```markdown
## <App name>
One sentence on what it's for.

### Screens
- <name> — what's on it, what the user does

### Data
- what is stored, where, and when it's written

### Permissions
- none / <permission> because <reason>

### Constraints accepted
- Framework widgets only (no Material library) because Maven is unreachable
- No <thing they asked for> — needs <library>, unavailable here.
  Doing <alternative> instead.

### minSdk / targetSdk
21 / 34
```

The "constraints accepted" section earns its place: it turns what would
otherwise look like shortcomings in the finished app into decisions the user
already agreed to.

## Then build in this order

Resources and manifest first, then the layout, then the code, then the icon.
Layout errors surface at `aapt2 link` in about a second; code errors take the
whole compile-dex cycle. Getting the cheap failures out of the way first makes
the expensive ones easier to read.
