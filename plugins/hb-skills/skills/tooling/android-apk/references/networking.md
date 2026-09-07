# HTTP, JSON and logged-in sessions, without libraries

Read this when the app talks to an HTTP API. Retrofit, OkHttp and Gson all come
from Maven, so on the OFFLINE path you use `HttpURLConnection` and `org.json` —
both framework, both perfectly adequate for a REST call.

Add the permission or every request fails with a confusing IO error:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

## The request

```java
HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
conn.setRequestMethod("GET");
conn.setConnectTimeout(15000);
conn.setReadTimeout(20000);
conn.setRequestProperty("Accept", "application/json");

int code = conn.getResponseCode();
if (code == 401 || code == 403) throw new Unauthorized();
if (code < 200 || code > 299) {
    // Read the ERROR stream, not the input stream — the input stream is empty
    // on a failure and you lose the server's explanation of what went wrong.
    throw new Exception("HTTP " + code + ": " + readAll(conn.getErrorStream()));
}
String body = readAll(conn.getInputStream());
conn.disconnect();
```

Always run this off the main thread (see the threading section of
`constraints.md`), and always `disconnect()` in a `finally`.

Put the response body of a failure into the message. You can't attach a
debugger, so that string is the entire diagnostic channel — see "Design for
remote diagnosis" below.

## Parsing

`org.json` is in the framework. It's verbose but complete:

```java
JSONObject root = new JSONObject(body);
JSONArray items = root.optJSONArray("items");
for (int i = 0; i < items.length(); i++) {
    JSONObject o = items.optJSONObject(i);
    String name = o.optString("name", "");
    double pct = o.optDouble("utilization", 0);
}
```

Prefer the `opt*` family over `get*`: they take a default instead of throwing,
so one unexpected null doesn't take down the whole parse.

**Parse loosely where the payload is someone else's.** Iterating
`root.keys()` and treating every object carrying a particular field as an entry
is more durable than hard-coding the key names — services rename and add things,
and a loose parser picks up new entries without a code change:

```java
Iterator<String> keys = root.keys();
while (keys.hasNext()) {
    String key = keys.next();
    JSONObject o = root.optJSONObject(key);
    if (o == null || !o.has("utilization")) continue;
    // treat as an entry
}
```

## Logging in with a WebView

For a service with no public API token, the workable pattern is to show the real
login page in a `WebView` and capture the session cookies afterwards. All
framework: `WebView`, `WebSettings`, `CookieManager`.

```java
CookieManager cookies = CookieManager.getInstance();
cookies.setAcceptCookie(true);
cookies.setAcceptThirdPartyCookies(web, true);   // SSO redirects need this

WebSettings settings = web.getSettings();
settings.setJavaScriptEnabled(true);
settings.setDomStorageEnabled(true);
web.setWebViewClient(new WebViewClient());       // keep navigation in-app
web.loadUrl("https://example.com/login");
```

`setWebViewClient` matters: without it the first redirect hands off to the
system browser and the cookies land in the wrong jar.

Then, when the user confirms they're logged in:

```java
String jar = CookieManager.getInstance().getCookie("https://example.com");
CookieManager.getInstance().flush();             // persist before relying on it
```

Three decisions worth copying:

**Don't guess which cookie is the auth one.** Capture the whole header string
for the domain and replay it verbatim. Services rename and add auth cookies;
a whole-jar capture survives that, a hard-coded name doesn't.

**Don't auto-detect success.** SSO flows bounce through several domains and the
"logged in" URL changes. A Continue button the user presses once they can see
their account is more robust than any heuristic, and easier to explain.

**Capture the WebView's user agent and reuse it** for the API calls:

```java
AuthStore.save(jar, web.getSettings().getUserAgentString());
// later
conn.setRequestProperty("Cookie", jar);
conn.setRequestProperty("User-Agent", savedUa);
conn.setRequestProperty("Referer", "https://example.com/");
```

A browser session suddenly replayed by a client with a default Java user agent
is exactly the shape bot protection looks for.

## Storing the session

`EncryptedSharedPreferences` is AndroidX and unavailable. Plain
`SharedPreferences` is the fallback: inside the app's private sandbox and
unreadable by other apps on a non-rooted device, but not hardware-backed. State
that plainly when handing over rather than implying Keychain-grade storage. If
it needs to be stronger, `AndroidKeyStore` is API 23 and can wrap the value.

Cache the parsed result too, not just the credentials — a widget renders from
cache, and an app that paints last-known numbers instantly beats one that shows
a spinner on every launch.

On a 401/403, clear the session and send the user back to login rather than
retrying forever against a dead cookie.

## Design for remote diagnosis

This is the part people skip. You cannot run the app, and the user reporting a
failure is your only instrument. So:

- Surface the **actual** HTTP status and response snippet in the UI, not
  "Something went wrong". One screenshot then tells you everything.
- Keep the last good data visible when a refresh fails, and show the error
  beside it. A transient failure shouldn't blank the screen.
- Name the network path as the likely failure point when you hand over. Bot
  protection in front of a service is the single most common reason this pattern
  fails, and it fails at runtime on a real device — the one place you never got
  to look.
