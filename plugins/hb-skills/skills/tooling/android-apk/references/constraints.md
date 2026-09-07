# Building against the framework alone

Read this before writing app code on the **OFFLINE** path. It does not apply if
the probe said GRADLE — there you have the whole ecosystem and should use it.

With Maven unreachable, the only code available is the Android framework plus
the Java standard library. That constrains the *app*, not just the build, so it
belongs in the spec rather than being discovered mid-implementation. The
framework is more capable than its reputation suggests: everything below has a
workable substitute, and none of them are much more code.

## What to use instead

| Not available | Use instead |
|---|---|
| ConstraintLayout | `LinearLayout` with `layout_weight`, `RelativeLayout`, `FrameLayout` |
| Material `Button` | `TextView` with a shape drawable background and `clickable="true"` |
| `CardView` | shape drawable with `<corners>` + `<stroke>`, plus `android:elevation` |
| `TabLayout` + `ViewPager2` | two panels in a `FrameLayout`, toggled with `setVisibility` |
| `RecyclerView` | `ListView` with a `BaseAdapter` (fine up to a few hundred rows) |
| `Snackbar` | `Toast` |
| AndroidX `Fragment` | `android.app.Fragment`, or just multiple `Activity` classes |
| Room | `SQLiteOpenHelper` from `android.database.sqlite` |
| Retrofit / OkHttp | `HttpURLConnection` + `org.json` — see `networking.md` |
| Gson / Moshi | `org.json.JSONObject` / `JSONArray` |
| Glide / Picasso | `BitmapFactory` on a background `Thread` |
| WorkManager | `AlarmManager`, `JobScheduler`, or a plain `Thread` |
| EncryptedSharedPreferences | plain `SharedPreferences` (private sandbox, not hardware-backed) or `AndroidKeyStore` |
| Jetpack Compose | not possible — build views in XML |
| Firebase, Maps, ML Kit, CameraX | not possible offline; say so during the spec |

`WebView`, `CookieManager`, `HttpURLConnection`, `org.json` and the whole
`android.graphics` stack are all framework, so a surprising amount of real app
still works.

For theming, `@android:style/Theme.Material.Light.NoActionBar` (API 21+) gives a
modern-looking baseline for free. Set `colorPrimary`, `colorPrimaryDark` and
`colorAccent` in a style and framework widgets follow.

## Java language limits

The Debian dexer is `dx` from the Android 10 era. It has no desugaring step, so
anything the compiler lowers to `invokedynamic` fails at the dex stage — long
after the code was written, with an error that names no construct.

**Avoid:**

- lambdas — `v -> doThing()`
- method references — `this::doThing`
- default and static methods on interfaces
- `java.util.stream` and `java.util.function`
- **compiling above `-source 8 -target 8`.** Easy to miss because it isn't a
  feature you chose: from Java 9 the compiler implements ordinary string
  concatenation with `invokedynamic`. Same failure, no visible cause.
  `build_apk.sh` pins it; keep it pinned.

**Fine:** generics, enhanced `for`, autoboxing, varargs, enums, inner and
anonymous classes, try-with-resources, `switch` on strings, `StringBuilder`.

So listeners are anonymous inner classes:

```java
saveButton.setOnClickListener(new View.OnClickListener() {
    public void onClick(View v) {
        saveNote();
    }
});
```

## Threading

`AsyncTask` is deprecated and best avoided. A plain `Thread` posting back to a
main-thread `Handler` is the framework-only pattern, and works everywhere:

```java
private final Handler main = new Handler(Looper.getMainLooper());

new Thread(new Runnable() {
    public void run() {
        final Result r = doNetworkWork();          // background
        main.post(new Runnable() {
            public void run() { render(r); }       // main thread
        });
    }
}).start();
```

Anything touching the network **must** be off the main thread or Android throws
`NetworkOnMainThreadException`.

## Compiling against an old android.jar

The available `android.jar` is API 23, so the compiler only knows APIs up to
Android 6. That is a *compile-time* ceiling, separate from `targetSdk`, which is
a manifest declaration — you compile against 23 and target 34, and both are
correct. See `install-gates.md` for why the target has to be high.

The consequence is that you must honour modern platform behaviour that the old
classpath will not force on you:

- **Storage is scoped.** Use `getFilesDir()` and `getExternalFilesDir()`. Don't
  write to arbitrary external paths; at a high targetSdk it fails at runtime.
- **Dangerous permissions are requested at runtime.** `requestPermissions()` is
  API 23, so it's available — use it rather than assuming a manifest grant.
- **Notifications need a channel** from targetSdk 26, but `NotificationChannel`
  isn't in an API 23 classpath at all. Either reach it by reflection or design
  the feature away. This is the most common hard wall — check for it early if
  the app has any notification requirement.
- **`PendingIntent` needs `FLAG_IMMUTABLE`** from targetSdk 31 or it throws.
  The constant landed in API 23, so it can be used unguarded.

For anything else newer than API 23, guard it and provide a fallback:

```java
if (Build.VERSION.SDK_INT >= 26) { /* reflection, or a newer-only path */ }
else { /* the API 23 way */ }
```

- **Home screen widgets** have their own, stricter rules — no custom views at
  all, a hard bitmap size ceiling, and the modern cell-sizing attributes are
  API 31 and won't link here. See `widgets.md` before building one.

## Small traps worth knowing in advance

- **`SimpleDateFormat` has no `X` pattern letter below API 24.** Parsing an
  ISO-8601 timestamp means normalising it by hand first: strip fractional
  seconds, and rewrite a trailing `Z` or `+01:00` into the `+0000` form that
  `Z` (the pattern letter) understands.
- **A styled `ProgressBar` needs the three-argument constructor**, because the
  style is a theme attribute rather than a settable property:
  `new ProgressBar(ctx, null, android.R.attr.progressBarStyleHorizontal)`.
- **`getResources().getColor(int)`** is deprecated at API 23 but present and
  working. The non-deprecated replacement needs a newer classpath; the
  deprecation warning is noise here.
- **Put pre-rendered art in `res/drawable-nodpi/`** when it must not be
  density-scaled — animation frames, sprites, anything pixel-exact. A plain
  `res/drawable/` PNG is treated as mdpi and resampled on every other density.
- **Generate PNGs rather than relying on `<vector>`.** Vector drawables are
  native from API 21, but their attributes resolve against whatever
  `android.jar` you link with; a build-time Pillow script has no such risk and
  gives you a preview image to inspect.

## Sanity checks before you build

- Every XML attribute you used exists at your `minSdk` — aapt2 catches
  attributes missing from the *linking* jar, but not ones added after it.
- No lambdas anywhere: `grep -rn -- '->' src/` is crude but effective.
- Every custom `View` used in XML has the `(Context, AttributeSet)`
  constructor, or inflation throws at runtime with a confusing message.
