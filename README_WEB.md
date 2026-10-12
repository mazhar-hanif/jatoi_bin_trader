# Jatoi Bin Trader web deployment

## Important demo limitation

The app stores all data in the visitor's own browser. Orders placed on one device are
**not visible to the admin on another device**. This is an offline demo, not a live
store, until a shared backend is connected. Do not advertise it as a live ordering
service before adding backend authentication, shared storage, and server-side order
validation. Benefit Pay is a manual payment option; no payment API is integrated.

## Run and build

```powershell
flutter config --enable-web
flutter pub get
flutter run -d chrome --no-web-resources-cdn
flutter build web --release --no-web-resources-cdn
dart run tool/verify_no_web_cdn.dart
```

Preview the production output locally:

```powershell
cd build\web
py -m http.server 8081
```

Open `http://localhost:8081`. The startup indicator becomes a bilingual diagnostic
page after 25 seconds, or immediately on a captured script/bootstrap error. It
reports the failing resource when the browser exposes it. To show the dismissible demo notice, add
`--dart-define=DEMO=true` to `flutter run` or `flutter build web`. Clean path URLs are
the default. Set `--dart-define=HASH_URLS=true` for hosts that cannot rewrite paths.
The optional `PUBLIC_CATALOG=true` build define permits signed-out visitors to browse
read-only product pages; it is disabled by default.

To test the live debug server using local web resources:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --no-web-resources-cdn
```

Open `http://localhost:8080`. As a CDN-enabled alternative, omit
`--no-web-resources-cdn`; that build can require Google-hosted CanvasKit resources.
`flutter build web --release` without that flag remains available as the standard
alternative. A successful launch is visible in DevTools when the DOM contains
`flutter-view` (or `flt-glass-pane`) and the loading screen has disappeared; there is
no backend `/health` endpoint.
For a headless CanvasKit check, keep GPU acceleration enabled; on the tested Windows
host, adding `--disable-gpu` caused the startup watchdog to appear. Flutter's generic
loader includes a dormant CDN fallback string, but the verification script checks
that the generated build configuration selects local CanvasKit and that app assets
do not reference the CDN.

## Netlify

`netlify.toml` and `_redirects` install pinned Flutter stable when missing, build
`build/web`, use Flutter's local CanvasKit/font resources, configure the SPA fallback,
and set security/cache headers. Connect the repository in
Netlify or deploy the output with the Netlify CLI:

```powershell
flutter build web --release --no-web-resources-cdn
dart run tool/verify_no_web_cdn.dart
npx netlify deploy --prod --dir=build/web
```

Configure a custom domain in **Site configuration → Domain management**, then add
the DNS records Netlify provides and enable its TLS certificate.

## Firebase Hosting

Only Firebase Hosting is configured; no Firebase app service or backend is enabled.
After installing the Firebase CLI (`npm install -g firebase-tools`), `firebase login`,
and `firebase use --add` to select/create a Hosting site, run:

```powershell
flutter build web --release --no-web-resources-cdn
dart run tool/verify_no_web_cdn.dart
firebase deploy --only hosting
```

The `firebase.json` rewrite serves Flutter for app paths. Configure a custom domain
in **Firebase Console → Hosting → Add custom domain** and follow its DNS verification
and TLS steps.

## GitHub Pages

Enable Pages with **GitHub Actions** as the build and deployment source. The workflow
in `.github/workflows/deploy-web.yml` checks analyze/tests and deploys on pushes to
`main`. Set the optional repository variable `WEB_REPO_NAME` if the Pages project
path differs from the repository name. Otherwise it uses the GitHub repository name.
The build uses local web resources (`--no-web-resources-cdn`) and hash URLs, which work reliably under a repository subpath; the app's
default clean path URLs need server rewrites. `web/404.html` also preserves unknown
deep-link paths and query strings for the Pages SPA fallback. Hash mode avoids that
server-side rewrite for normal app navigation.

For a custom domain, add the domain in **Repository settings → Pages**, configure
the DNS records shown by GitHub, and commit a `CNAME` file under `web/` containing
the domain.

## Headers and browser behavior

Netlify and Firebase headers include content-type sniffing protection, a restrictive
referrer policy, disabled unused device permissions, and a CSP. Flutter's generated
bootstrap/runtime currently needs inline scripts and eval/wasm-related execution in
supported renderers, so `unsafe-inline`, `unsafe-eval`, `wasm-unsafe-eval`, and blob workers are permitted
for scripts/workers. Tighten these after validating a nonce-compatible bootstrap.
The bundled service worker provides offline caching; the page displays an update hint
when the active service worker takes control.
GitHub Pages cannot set arbitrary HTTP response headers. Its `index.html` therefore
also declares CSP in a meta tag; X-Content-Type-Options, Referrer-Policy, and
Permissions-Policy require a fronting CDN/proxy if they are mandatory.

SharedPreferences persists in browser storage. If access fails at startup, the app
falls back to in-memory preferences and displays a bilingual warning. File selection
uses in-memory bytes; locally saved files are not uploaded anywhere. Invoice PDF
uses the `printing` browser flow, but Arabic PDF shaping is not supported because no
Arabic font is bundled. Flutter's Material icon font is generated locally and
tree-shaken; no Google font is required by the app. The `--no-web-resources-cdn` flag
bundles CanvasKit resources under `build/web/canvaskit`. For stale offline assets, use
Chrome DevTools → Application → Storage → Clear site data, then hard refresh with
Ctrl+Shift+R. Lighthouse scores, physical-size/browser matrix testing, and
cross-device persistence are not claimed or measured by this README.
