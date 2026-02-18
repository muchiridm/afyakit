# AfyaKit — Developer Commands

This project uses a multi-tenant Flutter web architecture driven by a single
entry point (`lib/main.dart`) and controlled via `--dart-define`.

The Makefile standardizes development, release, and deployment flows for
tenant apps and HQ.

---

ONE-TIME SETUP (per shell)

export TENANTS="afyakit danabtmc dawapap"

This enables:

- run-web-all
- web-all
- deploy-all
- release-web-all

---

DEVELOPMENT — WEB (CHROME)

Run a single tenant (Chrome, fixed port :5000):

make run-web dawapap
make run-web afyakit
make run-web danabtmc

Run all tenants at once (each on its own port starting from 5000):

make run-web-all

Run HQ in Chrome:

make run-web-hq

Notes:

- Uses flutter run
- No service worker caching
- Fast reload
- Icons always render correctly in dev mode

---

DEVELOPMENT — ANDROID / DEVICE

Run a single tenant on Android/emulator:

make run dawapap
make run afyakit
make run danabtmc

Run all tenants sequentially on the same device:

make run-android-all

---

UTILITY COMMANDS

List connected devices:

make devices

Flutter diagnostics:

make doctor

Fetch dependencies:

make pubget

Inspect active environment and dart-defines:

make env-check dawapap

---

RELEASE — WEB (TENANT)

IMPORTANT:
Release builds enforce settings required for Chrome production:

- Material icon tree-shaking disabled
- CanvasKit renderer forced
- Deterministic asset output

Build web bundle only:

make web dawapap

Deploy existing build:

make deploy dawapap

Build + deploy (recommended):

make release-web dawapap
make release-web afyakit
make release-web danabtmc

---

RELEASE — WEB (ALL TENANTS)

Build all tenants:

make web-all

Deploy all tenants:

make deploy-all

Build + deploy all tenants:

make release-web-all

---

RELEASE — HQ

HQ uses the same entrypoint, switched by:

--dart-define=APP=hq

Build HQ web:

make web-hq

Deploy HQ:

make deploy-hq

Build + deploy HQ:

make release-web-hq

---

CLEAN / RECOVERY

If Chrome behaves badly (icons missing, fonts not loading, odd caching):

make web-clean
make release-web dawapap

---

MENTAL MODEL

If it works in `run-web` but fails in production Chrome, it is ALWAYS a
release build configuration issue — never your UI code.

Firefox is forgiving.
Chrome is not.

This Makefile exists to keep Chrome honest.
