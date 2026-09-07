# Home screen widgets (App Widgets)

Read this when the app needs a home screen widget. A widget looks like a small
extra screen but it isn't: the views are inflated and drawn **in the launcher's
process**, and your code never holds a reference to any of them. Every change is
a batch of commands packed into a `RemoteViews` object and shipped across a
Binder boundary. Almost every widget bug traces back to forgetting that.

Run `scripts/check_widget.sh app.apk` after building — it catches the three
structural mistakes statically.

## What you can put in a widget

Only these classes inflate through `RemoteViews`:

`FrameLayout`, `LinearLayout`, `RelativeLayout`, `GridLayout`, `TextView`,
`ImageView`, `Button`, `ImageButton`, `ProgressBar`, `Chronometer`,
`AnalogClock`, `TextClock`, `ViewFlipper`, `ListView`, `GridView`, `StackView`,
`AdapterViewFlipper`, `ViewStub`.

**A custom `View` subclass cannot appear in a widget.** If the app draws
something custom, render it to a `Bitmap` and push that into an `ImageView` with
`setImageViewBitmap`. Also unavailable: `<include>`, `<merge>`, and anything
from AndroidX.

## Bitmaps have a hard size ceiling

`RemoteViews` travels over a Binder transaction capped around 1 MB and shared
across the process. A screen-sized `ARGB_8888` bitmap is several megabytes and
will exceed it — and the failure is not an exception you can catch, it's the
launcher quietly showing **"Problem loading widget"**.

Downscale before sending, and drop to `RGB_565` when the content allows (line
art, screenshots, anything without alpha or subtle gradients):

```java
BitmapFactory.Options probe = new BitmapFactory.Options();
probe.inJustDecodeBounds = true;
BitmapFactory.decodeFile(path, probe);

int sample = 1;
while (probe.outWidth / sample > 384 || probe.outHeight / sample > 384) sample *= 2;

BitmapFactory.Options opts = new BitmapFactory.Options();
opts.inSampleSize = sample;
opts.inPreferredConfig = Bitmap.Config.RGB_565;   // halves the payload
Bitmap bm = BitmapFactory.decodeFile(path, opts);
```

384px on the longest edge is a safe default for a small-to-medium widget.

## Animation without code

Widgets can't run code in the launcher, so there is no animator to drive. The
way to get motion is `ViewFlipper` — one of the few whitelisted views — cycling
pre-rendered frames on its own:

```xml
<ViewFlipper android:id="@+id/anim"
    android:autoStart="true"
    android:flipInterval="140"
    android:animateFirstView="false"
    android:inAnimation="@anim/none"
    android:outAnimation="@anim/none">
    <ImageView android:src="@drawable/frame_00" ... />
    <ImageView android:src="@drawable/frame_01" ... />
    <!-- … -->
</ViewFlipper>
```

Two details make this work. The frames must be **`@drawable` references**, not
bitmaps you push — the launcher then resolves them from resources itself and
nothing crosses the Binder boundary. And `ViewFlipper` crossfades between
children by default, which smears pixel art into mush; a zero-duration no-op
animation makes each frame a hard cut:

```xml
<!-- res/anim/none.xml -->
<alpha xmlns:android="http://schemas.android.com/apk/res/android"
    android:fromAlpha="1.0" android:toAlpha="1.0" android:duration="0" />
```

Budget the memory: every frame is an ImageView holding a decoded bitmap in the
launcher's process. Frame count × width × height × 4 bytes adds up fast — 16
frames at 300×80 is about 1.5 MB, which is reasonable; the same count at 480×96
is nearly 3 MB, which is not. Put the frames in `res/drawable-nodpi/` so they
aren't density-resampled.

Some launchers throttle `autoStart`. Design so a static first frame still looks
intentional, and tell the user this is a known unknown.

## Interaction is a broadcast round trip

There are no click listeners. `setOnClickPendingIntent` is the only input
mechanism, so an in-place toggle means: PendingIntent → broadcast → your
`onReceive` → mutate stored state → re-render → `updateAppWidget`.

Two things bite here.

**`FLAG_IMMUTABLE` is mandatory** from targetSdk 31. Omit it and the app throws
the moment it builds the intent. It was added in API 23, so it's available even
against an old `android.jar` — use it unguarded.

**PendingIntent identity ignores extras.** Two widgets whose intents differ only
by an extra collapse into the same PendingIntent and act together. Give each a
distinct `requestCode` and a per-widget data URI:

```java
Intent i = new Intent(ctx, MyWidget.class);
i.setAction(ACTION_TOGGLE);
i.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id);
i.setData(Uri.parse("myapp://widget/" + id));      // makes it unique
PendingIntent pi = PendingIntent.getBroadcast(ctx, id, i,
        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
```

Per-widget state belongs in `SharedPreferences` keyed by widget id, because the
provider is a `BroadcastReceiver` and holds no memory between invocations. Clean
those keys up in `onDeleted`.

## Doing real work from a widget

A receiver is killed the moment `onReceive` returns, which aborts anything you
started. `goAsync()` holds the process open until you call `finish()`:

```java
final PendingResult pending = goAsync();
new Thread(new Runnable() {
    public void run() {
        try { refreshData(app); renderAll(app); }
        finally { pending.finish(); }
    }
}).start();
```

The budget is generous for a background broadcast (tens of seconds), so an HTTP
call with sane timeouts fits — but keep those timeouts sane.

`updatePeriodMillis` is throttled to 30 minutes minimum and wakes the device.
Note that it only triggers a **re-render**: if the data itself needs refetching,
do it in `onUpdate` when the cache is stale, or the numbers sit frozen while
only the "5m ago" text ticks over.

## Sizing, offline

Declare size in dp in `res/xml/<name>_info.xml`. The launcher grid maths is
**`70 * cells - 30`**:

| Cells | dp |
|---|---|
| 1 | 40 |
| 2 | 110 |
| 3 | 180 |
| 4 | 250 |
| 5 | 320 |

So a 2-column × 3-row widget is `minWidth="110dp" minHeight="180dp"`.

The modern cell-based attributes — `targetCellWidth`, `targetCellHeight`,
`maxResizeWidth`, `previewLayout`, `description` — are **API 31 and unusable on
the offline path**. aapt2 resolves attribute names against the `android.jar` it
links with, so referencing them against an API 23 jar is a hard build failure,
not a warning. The dp form works correctly on current Android; the launcher just
rounds it to its own grid. Set `resizeMode="horizontal|vertical"` so the user
can adjust it regardless.

## Responsive widgets, and the id trap that comes with them

A widget can adapt to the size it was actually given. `getAppWidgetOptions(id)`
returns `OPTION_APPWIDGET_MIN_HEIGHT` and friends in dp, and
`onAppWidgetOptionsChanged` fires on resize — both API 16, so both available:

```java
int layout = R.layout.widget_compact;
Bundle opts = mgr.getAppWidgetOptions(id);
if (opts != null && opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) >= 90) {
    layout = R.layout.widget_full;
}
```

This is often the right answer when the user is unsure what size they want — one
widget that works from 2×1 up beats guessing.

**But every alternative layout must declare an identical set of view ids.**
`RemoteViews` resolves each action's id against the layout it actually inflated
and throws if the id isn't there. A field that only exists in the roomy layout
will crash the compact one. Give the compact layout the same view with
`android:visibility="gone"` — far cheaper than branching every call site.
`check_widget.sh` compares the id sets across layouts for exactly this reason.

Text has to shrink too, not just move. A 4×1 widget is ~250dp wide and the fixed
columns eat most of it; a status line that fits comfortably in the tall layout
can leave nothing for anything else. Have the render method take a `compact`
flag and abbreviate.

## Wiring it up

The receiver **must** be `exported="true"` — the system's AppWidgetHost is a
different process and has to deliver broadcasts to it:

```xml
<receiver android:name=".MyWidget" android:exported="true" android:label="@string/widget_label">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
        <action android:name="com.example.app.TOGGLE_FACE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/my_widget_info" />
</receiver>
```

Custom actions need listing in the filter too. Call `super.onReceive()` before
handling your own action, or the framework's `onUpdate`/`onDeleted` dispatch
never happens.

To refresh placed widgets after the app changes data:

```java
AppWidgetManager mgr = AppWidgetManager.getInstance(ctx);
int[] ids = mgr.getAppWidgetIds(new ComponentName(ctx, MyWidget.class));
for (int i = 0; i < ids.length; i++) render(ctx, mgr, ids[i]);
```

## Verifying without a device

```bash
bash scripts/check_widget.sh app.apk [layout ...]
```

It confirms the receiver is exported with the appwidget meta-data attached, that
the provider info declares `initialLayout` and sane dimensions, that every view
in every widget layout is on the whitelist, and that all the layouts expose
identical ids. It cannot check bitmap sizes or PendingIntent uniqueness — read
those in the code.

Also render a mockup of the widget at its true dp size and look at it. Widget
space is unforgiving and a picture will show you a squeeze that no log reports.
