# AfyaKit — Developer Commands

## 1. Overview

Run commands from the Flutter repository:

```bash
cd ~/dev/afyakit-ws/afyakit
```

AfyaKit uses a single Flutter codebase with multiple tenants and product experiences.

The application entry point is:

```text
lib/main.dart
```

Three boot defines determine the runtime identity:

| Define      | Purpose                        |
| ----------- | ------------------------------ |
| `APP`       | Runtime mode: `tenant` or `hq` |
| `TENANT_ID` | Data universe / tenant         |
| `APP_ID`    | Product experience             |

### Application identities

| Application | APP    | TENANT_ID | APP_ID      |
| ----------- | ------ | --------- | ----------- |
| DawaPap     | tenant | afya      | dawapap     |
| AfyaTracker | tenant | afya      | afyatracker |
| Occuwell    | tenant | afya      | occuwell    |
| Dana B TMC  | tenant | danabtmc  | danabtmc    |
| AfyaKit HQ  | hq     | hq        | hq          |

DawaPap, AfyaTracker and Occuwell share the `afya` data universe but provide separate application experiences.

HQ operates in its own runtime mode.

---

## 2. Command convention

The standard command structure is:

```bash
make <action> <tenantId> <appId>
```

**Always specify the tenant before the application.**

Examples:

```bash
make dev afya dawapap
make release afya afyatracker
make release afya occuwell
make release danabtmc danabtmc
make release hq hq
```

The explicit tenant prevents applications from silently falling back to the wrong data universe.

Use `make help` to inspect available commands.

---

## 3. Everyday commands

### Chrome development

```bash
make dev afya dawapap
make dev afya afyatracker
make dev afya occuwell

make dev danabtmc danabtmc

make dev hq hq
```

Default development port: `5000`.

To specify another port:

```bash
make dev afya occuwell WEB_PORT=5001
```

### Android development

```bash
make android afya dawapap
make android afya afyatracker
make android afya occuwell

make android danabtmc danabtmc
```

### Web builds

Build without deploying:

```bash
make build afya dawapap
make build afya afyatracker
make build afya occuwell

make build danabtmc danabtmc

make build hq hq
```

### Publish existing builds

Deploy an existing build without recompiling:

```bash
make publish afya afyatracker
make publish afya occuwell

make publish danabtmc danabtmc

make publish hq hq
```

**Important:** `publish` does not rebuild. Ensure the existing build belongs to the intended application.

### Full releases

Build, apply branding, verify and deploy:

```bash
make release afya afyatracker
make release afya occuwell

make release danabtmc danabtmc

make release hq hq
```

A release is the preferred command when publishing a new application version.

Do not release live DawaPap casually during its legacy-to-`afya` migration.

---

## 4. Explicit Make targets

The short commands above map to the underlying Make targets.

### Development

```bash
make run-web afya dawapap
make run-web afya afyatracker
make run-web afya occuwell

make run-android afya afyatracker
```

`run` remains an alias for Android development:

```bash
make run afya dawapap
```

### Web build and deployment

```bash
make web afya afyatracker

make deploy afya afyatracker

make release-web afya afyatracker
```

### HQ

```bash
make run-web-hq

make run-hq

make web-hq

make deploy-hq

make release-web-hq
```

The HQ-specific targets are retained for compatibility.

---

## 5. Batch commands

Use `APP_TARGETS`, with each entry expressed as:

```text
tenantId:appId
```

### Sequential releases

```bash
APP_TARGETS="afya:afyatracker afya:occuwell" make release-web-all
```

### Android development

```bash
APP_TARGETS="afya:afyatracker afya:occuwell" make run-android-all
```

### Important shared-build restriction

Tenant applications share:

```text
build/web
```

Consequently, `make web-all` does not preserve separate application builds. Each subsequent build replaces the preceding output.

**Do not run `web-all` followed by `deploy-all` for different applications.**

This could publish the final application's build to other Firebase Hosting sites.

Use `release-web-all`, which builds and deploys applications sequentially.

`run-web-all` remains disabled because applications share mutable Web branding assets.

Run one differently branded application at a time within the same working tree.

---

## 6. Firebase Hosting

### Hosting configuration

All maintained application Hosting configurations live in:

```text
firebase/hosting/
```

Directory structure:

```text
afyakit/
├── Makefile
├── firebase.json
│
├── firebase/
│   └── hosting/
│       ├── dawapap.json
│       ├── afyatracker.json
│       ├── occuwell.json
│       └── afyakit-hq.json
│
└── build/
    ├── web/
    └── web-hq/
```

The root `firebase.json` is retained but is not used as the application-specific configuration for normal multi-app releases.

### Application Hosting configuration

| Application | Build directory | Hosting JSON                        | Firebase site     |
| ----------- | --------------- | ----------------------------------- | ----------------- |
| DawaPap     | `build/web`     | `firebase/hosting/dawapap.json`     | As configured     |
| AfyaTracker | `build/web`     | `firebase/hosting/afyatracker.json` | `afyatracker-app` |
| Occuwell    | `build/web`     | `firebase/hosting/occuwell.json`    | `occuwell-app`    |
| HQ          | `build/web-hq`  | `firebase/hosting/afyakit-hq.json`  | `afyakit-hq`      |

The JSON must use `hosting.site`, not `hosting.target`.

### Deployment configuration

For a tenant application:

```json
{
  "hosting": {
    "site": "occuwell-app",
    "public": "build/web"
  }
}
```

For HQ:

```json
{
  "hosting": {
    "site": "afyakit-hq",
    "public": "build/web-hq"
  }
}
```

These examples show the required identity and output fields. Existing headers, redirects, rewrites and security policies remain in the full configurations.

### How deployment works

The Makefile:

1. Selects the application-specific JSON from `firebase/hosting/`.
2. Validates the Hosting site and public directory.
3. Temporarily stages the configuration at the project root.
4. Deploys the intended build to Firebase Hosting.
5. Removes the temporary configuration after deployment.

This preserves the organised configuration directory while allowing Firebase to resolve build paths correctly.

The Firebase project is:

```text
afyakit-api
```

---

## 7. Web branding

Tenant branding is selected using:

```text
TENANT_ID / APP_ID
```

For example:

```text
web/tenants/afya/apps/dawapap/
web/tenants/afya/apps/afyatracker/
web/tenants/afya/apps/occuwell/
```

HQ uses its HQ-specific branding identity and source directory.

The branding process applies application-specific metadata, favicons, icons and Web manifest assets.

Every build should apply the appropriate branding before deployment.

**HQ branding must target `build/web-hq`, not the shared `build/web` directory.**

---

## 8. Build outputs and PWA behaviour

Tenant applications:

```text
build/web
```

HQ:

```text
build/web-hq
```

The standard Web build uses:

```bash
flutter build web \
  --release \
  --no-tree-shake-icons \
  --pwa-strategy=none
```

The Makefile supplies the relevant entry point, output directory and Dart defines.

With `PWA_STRATEGY=none`, the generated Flutter service worker is stripped.

Firebase Messaging may still register its own separate service worker.

WebAssembly dry-run warnings do not necessarily indicate a failed standard JavaScript Web build.

---

## 9. Diagnostics and maintenance

### Makefile diagnostics

```bash
make help

make devices

make doctor

make pubget

make outdated
```

### Verify application identity

```bash
make env-check afya dawapap

make env-check afya afyatracker

make env-check afya occuwell

make env-check hq hq
```

`env-check` displays the selected tenant, application, environment configuration and Dart defines.

Review its output before sharing because environment defines may contain sensitive configuration.

### Web verification

```bash
make web-verify
```

For HQ:

```bash
make web-verify WEB_OUT=build/web-hq
```

### Cleaning

```bash
make web-clean

make flutter-clean
```

Cleaning removes generated build output. Rebuild before publishing.

### Standard Flutter checks

```bash
flutter analyze

flutter test
```

A successful build does not by itself prove that the correct application, tenant, API routes, branding or Hosting site has been deployed.

---

## 10. Backend — separate repository

The TypeScript API lives in:

```bash
cd ~/dev/afyakit-ws/afyakit-api
```

Inspect available scripts:

```bash
npm run
```

Build if supported:

```bash
npm run build
```

Do not use Flutter Web release commands to deploy backend changes.

Use the backend repository's own verified build and deployment workflow.

---

## 11. Quick reference

| Action              | Command                         |
| ------------------- | ------------------------------- |
| Develop DawaPap     | `make dev afya dawapap`         |
| Develop AfyaTracker | `make dev afya afyatracker`     |
| Develop Occuwell    | `make dev afya occuwell`        |
| Develop HQ          | `make dev hq hq`                |
| Build AfyaTracker   | `make build afya afyatracker`   |
| Publish AfyaTracker | `make publish afya afyatracker` |
| Release AfyaTracker | `make release afya afyatracker` |
| Release Occuwell    | `make release afya occuwell`    |
| Release HQ          | `make release hq hq`            |
| Check identity      | `make env-check afya occuwell`  |
| Check commands      | `make help`                     |

**Core rule: Tenant first. App second. Build deliberately. Deploy to the correct Hosting site.**
