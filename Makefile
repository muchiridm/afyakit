# ─────────────────────────────────────────────────────────────────────────────
# AfyaKit multi-tenant Makefile (Tenant + HQ via APP mode)
#
# Tenant mode:
#   - lib/main.dart + --dart-define=TENANT=<tenantId>
#
# HQ mode:
#   - lib/main.dart + --dart-define=APP=hq + --dart-define=TENANT=hq
# ─────────────────────────────────────────────────────────────────────────────
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# Tenant shortcut: allow `make run-web dawapap`
TENANT ?= $(word 2,$(MAKECMDGOALS))
ifneq ($(TENANT),)
  .PHONY: $(TENANT)
  $(TENANT): ; @:
endif

# Prefer Android if present; fallback chrome
DEVICE ?= $(shell flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}')
ifeq ($(strip $(DEVICE)),)
  DEVICE := chrome
endif

# Entry (single)
ENTRY ?= lib/main.dart

# Outputs
WEB_OUT     ?= build/web
WEB_OUT_HQ  ?= build/web-hq

# Hosting site for HQ (Firebase hosting target)
HQ_SITE     ?= afyakit-hq
HQ_HOST     ?= admin.afyakit.app

# Production host used for post-deploy smoke checks.
HOST ?= $(if $(filter dawapap,$(TENANT)),www.dawapap.com,$(if $(filter afyakit,$(TENANT)),www.afyakit.app,$(if $(filter danabtmc,$(TENANT)),www.danabtmc.com,$(if $(filter hq,$(TENANT)),$(HQ_HOST),))))

# Static metadata embedded in index.html for crawlers that do not run JavaScript.
APP_TITLE ?= $(if $(filter dawapap,$(TENANT)),DawaPap Pharmacy,$(if $(filter afyakit,$(TENANT)),AfyaKit,$(if $(filter danabtmc,$(TENANT)),Dana B TMC,$(if $(filter hq,$(TENANT)),AfyaKit HQ,AfyaKit))))

APP_DESCRIPTION ?= $(if $(filter dawapap,$(TENANT)),Your Pharmacy. Anywhere. Anytime.,$(if $(filter afyakit,$(TENANT)),Digital healthcare management made simple.,$(if $(filter danabtmc,$(TENANT)),Healthcare services and medical support.,AfyaKit healthcare platform.)))

APP_URL ?= $(if $(HOST),https://$(HOST)/,)

APP_IMAGE ?= $(if $(filter dawapap,$(TENANT)),https://firebasestorage.googleapis.com/v0/b/afyakit-api.firebasestorage.app/o/public%2Fdawapap%2Fbranding%2Fweb%2Ficon-512.png?alt=media,$(APP_URL)favicon.png)

HASH := \#
THEME_COLOR ?= $(if $(filter dawapap,$(TENANT)),$(HASH)00A86B,$(HASH)2196F3)

# Extras
EXTRA         ?=
USE_FLAVOR    ?= 1
WEB_PORT_BASE ?= 5000
WEB_PORT      ?= $(WEB_PORT_BASE)
TENANTS       ?=

# ✅ Web release icon fix (Material Icons tree-shaking)
WEB_ICON_FLAGS ?= --no-tree-shake-icons

# ✅ Current Flutter web builds should not ship an active service worker
PWA_STRATEGY ?= none
PWA_STRATEGY_FLAG := --pwa-strategy=$(PWA_STRATEGY)

# Flutter can still emit flutter_service_worker.js on some versions even when
# --pwa-strategy=none is used. For non-PWA releases, strip it from build output
# and warn if Flutter still leaves inert filename references in boot assets.
WEB_STRIP_SERVICE_WORKER ?= $(if $(filter none,$(PWA_STRATEGY)),1,0)
WEB_SERVICE_WORKER_FILES := \
  flutter_service_worker.js \
  flutter_service_worker.js.map

# Files that must exist before deploying a Flutter web build.
WEB_REQUIRED_FILES := \
  index.html \
  flutter_bootstrap.js \
  main.dart.js \
  assets/AssetManifest.json \
  assets/FontManifest.json

WEB_JSON_FILES := \
  assets/AssetManifest.json \
  assets/FontManifest.json

WEB_SW_CHECK_FILES := \
  index.html \
  flutter_bootstrap.js \
  main.dart.js

# ✅ Optional renderer forcing (ONLY when supported by your Flutter)
WEB_RENDERER ?= canvaskit
HAS_WEB_RENDERER_BUILD := $(shell flutter build web -h 2>/dev/null | grep -q -- '--web-renderer' && echo 1 || echo 0)
WEB_RENDERER_BUILD_FLAG := $(if $(filter 1,$(HAS_WEB_RENDERER_BUILD)),--web-renderer=$(WEB_RENDERER),)

HAS_WEB_RENDERER_RUN := $(shell flutter run -h 2>/dev/null | grep -q -- '--web-renderer' && echo 1 || echo 0)
WEB_RENDERER_RUN_FLAG := $(if $(filter 1,$(HAS_WEB_RENDERER_RUN)),--web-renderer=$(WEB_RENDERER),)

# Flavor is only meaningful for device builds; web ignores flavors in your workflow.
FLAVOR_FLAG  := $(if $(filter 1 yes true,$(USE_FLAVOR)),$(if $(TENANT),--flavor $(TENANT),),)

TENANT_DEF   := $(if $(TENANT),--dart-define=TENANT=$(TENANT),)

# HQ must be explicit (boot requires TENANT in HQ mode)
HQ_TENANT     ?= hq
TENANT_DEF_HQ := --dart-define=TENANT=$(HQ_TENANT)
APP_DEF_HQ    := --dart-define=APP=hq
HQ_DEFINES    := $(APP_DEF_HQ) $(TENANT_DEF_HQ)

# ─────────────────────────────────────────────────────────────────────────────
# .env loader (optional; safe when absent)
#  - looks for .env.<tenant>.web, .env.<tenant>, .env
#  - if none exist → DART_DEFINES becomes empty (no-op)
# ─────────────────────────────────────────────────────────────────────────────
LOAD_ENV ?= 1

# Find env file (for single-tenant targets)
ENV_FILE :=
ifeq ($(filter 1 yes true,$(LOAD_ENV)),1)
  ifneq ($(TENANT),)
    ifeq ($(shell test -f .env.$(TENANT).web && echo 1),1)
      ENV_FILE := .env.$(TENANT).web
    else ifeq ($(shell test -f .env.$(TENANT) && echo 1),1)
      ENV_FILE := .env.$(TENANT)
    endif
  endif
  ifeq ($(ENV_FILE),)
    ifeq ($(shell test -f .env && echo 1),1)
      ENV_FILE := .env
    endif
  endif
endif

# Convert ENV_FILE -> --dart-define=KEY=VALUE ...
# Notes:
# - ignores comments/blank lines
# - trims key/value whitespace
# - keeps "=" in values by taking substr from first value token onward
DART_DEFINES := $(shell \
  if [ -n "$(ENV_FILE)" ]; then \
    awk 'BEGIN{FS="="} \
      /^[[:space:]]*#/ {next} \
      /^[[:space:]]*$$/ {next} \
      {key=$$1; sub(/^[[:space:]]+|[[:space:]]+$$/, "", key); \
       val=substr($$0, index($$0,$$2)); \
       sub(/^[[:space:]]+|[[:space:]]+$$/, "", val); \
       if (key != "") printf "--dart-define=%s=%s ", key, val}' $(ENV_FILE); \
  fi)

# Per-tenant env defines for matrix runs (prevents sharing one ENV_FILE across all)
define dart_defines_for_tenant
$(shell \
  t="$(1)"; \
  f=""; \
  if [ "$(filter 1 yes true,$(LOAD_ENV))" = "1" ]; then \
    if [ -f ".env.$$t.web" ]; then f=".env.$$t.web"; \
    elif [ -f ".env.$$t" ]; then f=".env.$$t"; \
    elif [ -f ".env" ]; then f=".env"; \
    fi; \
  fi; \
  if [ -n "$$f" ]; then \
    awk 'BEGIN{FS="="} \
      /^[[:space:]]*#/ {next} \
      /^[[:space:]]*$$/ {next} \
      {key=$$1; sub(/^[[:space:]]+|[[:space:]]+$$/, "", key); \
       val=substr($$0, index($$0,$$2)); \
       sub(/^[[:space:]]+|[[:space:]]+$$/, "", val); \
       if (key != "") printf "--dart-define=%s=%s ", key, val}' "$$f"; \
  fi)
endef

.PHONY: env-check
env-check:
	@echo "ENV_FILE=$(ENV_FILE)"
	@echo "LOAD_ENV=$(LOAD_ENV)"
	@echo "DART_DEFINES=$(DART_DEFINES)"
	@echo "TENANT=$(TENANT)"
	@echo "TENANTS=$(TENANTS)"
	@echo "HOST=$(HOST)"
	@echo "HQ_TENANT=$(HQ_TENANT)"
	@echo "HQ_HOST=$(HQ_HOST)"
	@echo "HQ_DEFINES=$(HQ_DEFINES)"
	@echo "APP_TITLE=$(APP_TITLE)"
	@echo "APP_DESCRIPTION=$(APP_DESCRIPTION)"
	@echo "APP_URL=$(APP_URL)"
	@echo "APP_IMAGE=$(APP_IMAGE)"
	@echo "THEME_COLOR=$(THEME_COLOR)"
	@echo "WEB_PORT=$(WEB_PORT)"
	@echo "WEB_ICON_FLAGS=$(WEB_ICON_FLAGS)"
	@echo "PWA_STRATEGY=$(PWA_STRATEGY)"
	@echo "PWA_STRATEGY_FLAG=$(PWA_STRATEGY_FLAG)"
	@echo "HAS_WEB_RENDERER_BUILD=$(HAS_WEB_RENDERER_BUILD)"
	@echo "WEB_RENDERER_BUILD_FLAG=$(WEB_RENDERER_BUILD_FLAG)"
	@echo "HAS_WEB_RENDERER_RUN=$(HAS_WEB_RENDERER_RUN)"
	@echo "WEB_RENDERER_RUN_FLAG=$(WEB_RENDERER_RUN_FLAG)"

# ─────────────────────────────────────────────────────────────────────────────
# Guards
# ─────────────────────────────────────────────────────────────────────────────
define assert_tenant
	@if [ -z "$(TENANT)" ]; then \
	  echo "❌ Missing tenantId. Usage: make $@ <tenantId>"; \
	  exit 2; \
	fi
endef

define assert_tenants
	@if [ -z "$(TENANTS)" ]; then \
	  echo "❌ TENANTS is empty. Example: TENANTS=\"afyakit danabtmc dawapap\" make $@"; \
	  exit 2; \
	fi
endef

define flutter_web_build
	@rm -rf "$(1)"
	@echo "$(2)"
	flutter build web --release \
	  $(WEB_ICON_FLAGS) \
	  $(PWA_STRATEGY_FLAG) \
	  $(WEB_RENDERER_BUILD_FLAG) \
	  -t $(ENTRY) \
	  -o "$(1)" \
	  $(EXTRA) \
	  $(3)
	@$(MAKE) web-brand \
	  TENANT="$(TENANT)" \
	  HOST="$(HOST)" \
	  WEB_OUT="$(1)" \
	  APP_TITLE="$(APP_TITLE)" \
	  APP_DESCRIPTION="$(APP_DESCRIPTION)" \
	  APP_URL="$(APP_URL)" \
	  APP_IMAGE="$(APP_IMAGE)" \
	  THEME_COLOR="$(THEME_COLOR)"
	@$(MAKE) web-strip-service-worker \
	  WEB_OUT="$(1)" \
	  PWA_STRATEGY="$(PWA_STRATEGY)" \
	  WEB_STRIP_SERVICE_WORKER="$(WEB_STRIP_SERVICE_WORKER)"
	@$(MAKE) web-verify WEB_OUT="$(1)"
endef

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help devices doctor outdated pubget
help:
	@echo "Targets:"
	@echo "  run-android / run-web                — run ONE tenant"
	@echo "  run-web-all / run-android-all        — run MANY tenants"
	@echo "  web / deploy / release-web           — build & deploy ONE tenant"
	@echo "  web-verify / deploy-verify           — local and live web checks"
	@echo "  web-all / deploy-all / release-web-all— build/deploy MANY tenants"
	@echo "  run-hq / run-web-hq / web-hq / deploy-hq"
	@echo ""
	@echo "Notes:"
	@echo "  - Tenant mode uses:  --dart-define=TENANT=<tenantId>"
	@echo "  - HQ mode uses:      --dart-define=APP=hq --dart-define=TENANT=$(HQ_TENANT)"
	@echo "  - Web release uses:  $(WEB_ICON_FLAGS) $(PWA_STRATEGY_FLAG)"
	@echo "  - Web renderer flag is conditional based on your Flutter SDK."
devices:;  flutter devices
doctor:;   flutter doctor -v
outdated:; flutter pub outdated || true
pubget:;   flutter pub get

# ─────────────────────────────────────────────────────────────────────────────
# Tenant app: run (ONE)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run run-android run-web

# Keep "run" as a friendly alias for android (most common)
run: run-android

run-web:
	@$(call assert_tenant)
	@echo "🌐 Running (web) $(TENANT) on Chrome :$(WEB_PORT) …"
	./scripts/run_web_tenant.sh "$(TENANT)" -- \
	  flutter run \
	    -d chrome \
	    --web-port="$(WEB_PORT)" \
	    $(WEB_RENDERER_RUN_FLAG) \
	    -t "$(ENTRY)" \
	    $(EXTRA) \
	    $(DART_DEFINES) \
	    $(TENANT_DEF)

run-android:
	@$(call assert_tenant)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	echo "🤖 Running $(TENANT) on '$$ANDROID'…"; \
	flutter run -d $$ANDROID $(FLAVOR_FLAG) \
	  -t $(ENTRY) \
	  $(EXTRA) \
	  $(DART_DEFINES) \
	  $(TENANT_DEF)

# ─────────────────────────────────────────────────────────────────────────────
# Matrix runs
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run-web-all run-android-all

run-web-all:
	@$(call assert_tenants)
	@PORT=$(WEB_PORT_BASE); \
	for t in $(TENANTS); do \
	  defs='$(call dart_defines_for_tenant,'$$t')'; \
	  echo "🌐 Launch $$t on Chrome :$${PORT} …"; \
	  (flutter run -d chrome -t $(ENTRY) \
	    $(WEB_RENDERER_RUN_FLAG) \
	    $(EXTRA) \
	    $$defs \
	    --dart-define=TENANT=$$t \
	    --web-port=$${PORT} &) ; \
	  PORT=$$((PORT+1)); \
	done; \
	echo "ℹ️ Started $(words $(TENANTS)) Chrome debuggers on ports $(WEB_PORT_BASE)..$$((PORT-1))."

run-android-all:
	@$(call assert_tenants)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	for t in $(TENANTS); do \
	  defs='$(call dart_defines_for_tenant,'$$t')'; \
	  flavor=$$(if [ "$(filter 1 yes true,$(USE_FLAVOR))" = "1" ]; then echo "--flavor $$t"; fi); \
	  echo "🤖 Launch $$t on '$$ANDROID'…"; \
	  flutter run -d $$ANDROID $$flavor -t $(ENTRY) \
	    $(EXTRA) \
	    $$defs \
	    --dart-define=TENANT=$$t; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# Web build / verify / deploy (ONE tenant)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: web deploy deploy-verify release-web web-brand web-strip-service-worker web-verify web-clean flutter-clean

web:
	@$(call assert_tenant)
	$(call flutter_web_build,$(WEB_OUT),🌐 Release build: $(TENANT) → $(WEB_OUT),$(DART_DEFINES) $(TENANT_DEF))

web-brand:
	@echo "🎨 Applying static web branding for $(TENANT)…"
	@test -f "$(WEB_OUT)/index.html" || { \
	  echo "❌ Missing $(WEB_OUT)/index.html"; \
	  exit 2; \
	}
	@APP_TITLE='$(APP_TITLE)' \
	APP_DESCRIPTION='$(APP_DESCRIPTION)' \
	APP_URL='$(APP_URL)' \
	APP_IMAGE='$(APP_IMAGE)' \
	THEME_COLOR='$(THEME_COLOR)' \
	WEB_INDEX='$(WEB_OUT)/index.html' \
	node -e 'const fs=require("fs"); const path=process.env.WEB_INDEX; const replacements={"__APP_TITLE__":process.env.APP_TITLE,"__APP_DESCRIPTION__":process.env.APP_DESCRIPTION,"__APP_URL__":process.env.APP_URL,"__APP_IMAGE__":process.env.APP_IMAGE,"__THEME_COLOR__":process.env.THEME_COLOR}; let html=fs.readFileSync(path,"utf8"); for(const [token,value] of Object.entries(replacements)){html=html.split(token).join(value||"");} fs.writeFileSync(path,html);'
	@echo "   title: $(APP_TITLE)"
	@echo "   URL:   $(APP_URL)"
	@echo "   image: $(APP_IMAGE)"

web-strip-service-worker:
	@if [ "$(WEB_STRIP_SERVICE_WORKER)" = "1" ]; then \
	  for f in $(WEB_SERVICE_WORKER_FILES); do \
	    if [ -f "$(WEB_OUT)/$$f" ]; then \
	      echo "🧹 Removing non-PWA artifact: $(WEB_OUT)/$$f"; \
	      rm -f "$(WEB_OUT)/$$f"; \
	    fi; \
	  done; \
	fi

web-verify:
	@echo "🔎 Verifying web output…"
	@test -d "$(WEB_OUT)" || (echo "❌ Missing $(WEB_OUT)"; exit 2)
	@for f in $(WEB_REQUIRED_FILES); do \
	  test -f "$(WEB_OUT)/$$f" || { echo "❌ Missing $(WEB_OUT)/$$f"; exit 2; }; \
	done
	@for f in $(WEB_JSON_FILES); do \
	  node -e "JSON.parse(require('fs').readFileSync('$(WEB_OUT)/' + process.argv[1], 'utf8'))" "$$f" \
	    || { echo "❌ Invalid JSON: $(WEB_OUT)/$$f"; exit 2; }; \
	done
	@if [ "$(PWA_STRATEGY)" = "none" ] && [ -f "$(WEB_OUT)/flutter_service_worker.js" ]; then \
	  echo "⚠️ flutter_service_worker.js exists even though PWA_STRATEGY=none"; \
	  echo "   Set WEB_STRIP_SERVICE_WORKER=1 to remove it automatically."; \
	fi
	@if grep -R "flutter_service_worker.js" $(addprefix "$(WEB_OUT)/,$(addsuffix ",$(WEB_SW_CHECK_FILES))) >/dev/null 2>&1; then \
	  echo "⚠️ Build assets still mention flutter_service_worker.js"; \
	  echo "   This is tolerated because PWA_STRATEGY=none strips the emitted service worker."; \
	fi
	@if grep -q '\$$FLUTTER_BASE_HREF' "$(WEB_OUT)/index.html"; then \
	  echo "❌ index.html still contains \$$FLUTTER_BASE_HREF"; \
	  echo "   This usually means the raw web/index.html was deployed instead of build/web."; \
	  exit 2; \
	fi
	@if grep -qE '__APP_|__THEME_COLOR__|Loading…|Loading\.\.\.' "$(WEB_OUT)/index.html"; then \
	  echo "❌ Unresolved or invalid branding metadata in $(WEB_OUT)/index.html"; \
	  grep -nE '__APP_|__THEME_COLOR__|Loading…|Loading\.\.\.' "$(WEB_OUT)/index.html" || true; \
	  exit 2; \
	fi
	@grep -q '<meta property="og:title"' "$(WEB_OUT)/index.html" || { \
	  echo "❌ Missing og:title"; \
	  exit 2; \
	}
	@grep -q '<meta property="og:image"' "$(WEB_OUT)/index.html" || { \
	  echo "❌ Missing og:image"; \
	  exit 2; \
	}
	@echo "✅ Static branding metadata present"
	@ls -lh "$(WEB_OUT)/assets/fonts" 2>/dev/null || true
	@if [ -f "$(WEB_OUT)/assets/fonts/MaterialIcons-Regular.otf" ]; then \
	  echo "✅ MaterialIcons-Regular.otf present:"; \
	  ls -lh "$(WEB_OUT)/assets/fonts/MaterialIcons-Regular.otf"; \
	else \
	  echo "⚠️ MaterialIcons-Regular.otf not found (can be OK on some Flutter versions)"; \
	fi

web-clean:
	@echo "🧹 Cleaning web output…"
	rm -rf "$(WEB_OUT)" "$(WEB_OUT_HQ)"

flutter-clean: web-clean
	@echo "🧹 Running flutter clean…"
	flutter clean

deploy:
	@$(call assert_tenant)
	@$(MAKE) web-verify TENANT=$(TENANT) WEB_OUT="$(WEB_OUT)"
	@echo "🚀 Deploy hosting:$(TENANT) from $(WEB_OUT)…"
	@cfg="firebase.$(TENANT).json"; \
	if [ ! -f "$$cfg" ]; then cfg="firebase.json"; fi; \
	if [ ! -f "$$cfg" ]; then echo "❌ Missing firebase config for $(TENANT)."; exit 2; fi; \
	echo "   → using $$cfg"; \
	firebase deploy --config "$$cfg" --only hosting:$(TENANT)
	@$(MAKE) deploy-verify \
	  TENANT="$(TENANT)" \
	  HOST="$(HOST)" \
	  APP_TITLE="$(APP_TITLE)" \
	  APP_DESCRIPTION="$(APP_DESCRIPTION)" \
	  APP_URL="$(APP_URL)" \
	  APP_IMAGE="$(APP_IMAGE)"

deploy-verify:
	@if [ -z "$(HOST)" ]; then \
	  echo "ℹ️ Skipping live verification; HOST is empty."; \
	  exit 0; \
	fi
	@echo "🔎 Verifying live host: https://$(HOST)"
	@for path in \
	  /assets/AssetManifest.json \
	  /assets/FontManifest.json \
	  /main.dart.js \
	  /flutter_bootstrap.js \
	  /manifest.webmanifest; do \
	  ct=$$(curl -fsSI "https://$(HOST)$$path" | awk 'BEGIN{IGNORECASE=1} /^content-type:/ {print $$0; exit}'); \
	  echo "   $$path → $$ct"; \
	  case "$$path:$$ct" in \
	    *AssetManifest.json*application/json*|*FontManifest.json*application/json*|*main.dart.js*javascript*|*flutter_bootstrap.js*javascript*|*manifest.webmanifest*manifest+json*) ;; \
	    *) echo "❌ Unexpected content type for $$path"; exit 2 ;; \
	  esac; \
	done
	@html=$$(curl -fsSL "https://$(HOST)/"); \
	echo "$$html" | grep -Fq "<title>$(APP_TITLE)</title>" || { \
	  echo "❌ Live HTML has the wrong title"; \
	  echo "$$html" | grep -o '<title>[^<]*</title>' | head -1 || true; \
	  exit 2; \
	}; \
	echo "$$html" | grep -q 'property="og:image"' || { \
	  echo "❌ Live HTML is missing og:image"; \
	  exit 2; \
	}; \
	echo "✅ Live social metadata verified"

release-web:
	@$(call assert_tenant)
	@$(MAKE) web TENANT=$(TENANT) EXTRA="$(EXTRA)" DART_DEFINES="$(DART_DEFINES)"
	@$(MAKE) deploy TENANT=$(TENANT)

# ─────────────────────────────────────────────────────────────────────────────
# Web build / deploy (MANY tenants)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: web-all deploy-all release-web-all

web-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do \
	  $(MAKE) web TENANT=$$t; \
	done

deploy-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do \
	  $(MAKE) deploy TENANT=$$t; \
	done

release-web-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do \
	  $(MAKE) release-web TENANT=$$t; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# HQ app (same entry, APP=hq + TENANT=hq)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run-hq run-web-hq web-hq deploy-hq release-web-hq

run-hq: LOAD_ENV=0
run-hq:
	@echo "🏢 Running HQ on '$(DEVICE)'…"
	flutter run -d $(DEVICE) -t $(ENTRY) $(HQ_DEFINES) $(EXTRA)

run-web-hq: LOAD_ENV=0
run-web-hq:
	@echo "🏢🌐 Running HQ on Chrome :$(WEB_PORT) …"
	flutter run -d chrome --web-port=$(WEB_PORT) \
	  $(WEB_RENDERER_RUN_FLAG) \
	  -t $(ENTRY) \
	  $(HQ_DEFINES) \
	  $(EXTRA)

web-hq: LOAD_ENV=0
web-hq:
	$(call flutter_web_build,$(WEB_OUT_HQ),🏢🌐 Release build HQ → $(WEB_OUT_HQ),$(HQ_DEFINES))

deploy-hq:
	@$(MAKE) web-verify TENANT=$(HQ_TENANT) WEB_OUT="$(WEB_OUT_HQ)"
	@echo "🚀 Deploy HQ hosting:$(HQ_SITE) from $(WEB_OUT_HQ)…"
	@cfg="firebase.hq.json"; \
	if [ ! -f "$$cfg" ]; then \
	  echo "❌ Missing $$cfg (expected in repo root)."; \
	  exit 2; \
	fi; \
	echo "   → using $$cfg"; \
	firebase deploy --config "$$cfg" --only hosting:$(HQ_SITE)
	@$(MAKE) deploy-verify TENANT=hq HOST="$(HQ_HOST)"

release-web-hq: LOAD_ENV=0
release-web-hq:
	@$(MAKE) web-hq EXTRA="$(EXTRA)"
	@$(MAKE) deploy-hq