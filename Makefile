# ─────────────────────────────────────────────────────────────────────────────
# AfyaKit multi-app Makefile
#
# Tenant app:
#   make run-web <tenantId> <appId>
#   make run-android <tenantId> <appId>
#   make release-web <tenantId> <appId>
#
# Examples:
#   make run-web afya dawapap
#   make run-web afya afyatracker
#   make release-web afya dawapap
#
# HQ:
#   make run-hq
#   make run-web-hq
#   make release-web-hq
#
# Bootstrap identity:
#   APP=tenant|hq
#   TENANT_ID=<data universe>
#   APP_ID=<product experience>
#
# Example:
#   APP=tenant TENANT_ID=afya APP_ID=dawapap
# ─────────────────────────────────────────────────────────────────────────────

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ─────────────────────────────────────────────────────────────────────────────
# Core
# ─────────────────────────────────────────────────────────────────────────────

ENTRY ?= lib/main.dart

# Runtime selectors used by Make/Firebase/branding commands.
# Allows: make <target> <tenantId> <appId>
TENANT_KEY ?= $(word 2,$(MAKECMDGOALS))
APP_KEY    ?= $(word 3,$(MAKECMDGOALS))

ifneq ($(TENANT_KEY),)
  .PHONY: $(TENANT_KEY)
  $(TENANT_KEY): ; @:
endif

ifneq ($(APP_KEY),)
  .PHONY: $(APP_KEY)
  $(APP_KEY): ; @:
endif

# Preferred batch list. Each entry is tenantId:appId.
# Example:
#   APP_TARGETS="afya:dawapap afya:afyatracker danabtmc:danabtmc"
APP_TARGETS ?=

EXTRA      ?=
USE_FLAVOR ?= 1
LOAD_ENV   ?= 1

# ─────────────────────────────────────────────────────────────────────────────
# Environment loader
# Order:
#   .env.<app>.web → .env.<app> → .env
# ─────────────────────────────────────────────────────────────────────────────

define resolve_env_file
$(strip $(shell \
  if [ "$(filter 1 yes true,$(LOAD_ENV))" = "1" ]; then \
    a="$(1)"; \
    if [ -n "$$a" ] && [ -f ".env.$$a.web" ]; then echo ".env.$$a.web"; \
    elif [ -n "$$a" ] && [ -f ".env.$$a" ]; then echo ".env.$$a"; \
    elif [ -f ".env" ]; then echo ".env"; \
    fi; \
  fi))
endef

define env_value
$(strip $(shell \
  f="$(1)"; key="$(2)"; \
  if [ -n "$$f" ] && [ -f "$$f" ]; then \
    awk -v wanted="$$key" 'BEGIN{FS="="} \
      /^[[:space:]]*#/ {next} \
      /^[[:space:]]*$$/ {next} \
      { \
        k=$$1; \
        sub(/^[[:space:]]+|[[:space:]]+$$/, "", k); \
        if (k != wanted) next; \
        v=substr($$0, index($$0,"=")+1); \
        sub(/^[[:space:]]+|[[:space:]]+$$/, "", v); \
        print v; \
        exit \
      }' "$$f"; \
  fi))
endef

# Canonical identity keys are emitted explicitly below, so omit them from the
# generic env-to-dart-define expansion. This avoids duplicate/legacy defines.
define defines_from_env
$(strip $(shell \
  f="$(1)"; \
  if [ -n "$$f" ] && [ -f "$$f" ]; then \
    awk 'BEGIN{FS="="} \
      /^[[:space:]]*#/ {next} \
      /^[[:space:]]*$$/ {next} \
      { \
        key=$$1; \
        sub(/^[[:space:]]+|[[:space:]]+$$/, "", key); \
        if (key == "APP" || key == "TENANT_ID" || key == "APP_ID" || key == "TENANT") next; \
        val=substr($$0, index($$0,"=")+1); \
        sub(/^[[:space:]]+|[[:space:]]+$$/, "", val); \
        if (key != "") printf "--dart-define=%s=%s ", key, val \
      }' "$$f"; \
  fi))
endef

ENV_FILE := $(call resolve_env_file,$(APP_KEY))

ENV_TENANT_ID := $(call env_value,$(ENV_FILE),TENANT_ID)
ENV_APP_ID    := $(call env_value,$(ENV_FILE),APP_ID)

# Canonical runtime identity.
# Positional selectors win for direct Make commands. Recursive/CI calls may
# still pass TENANT_ID / APP_ID explicitly. Environment files remain useful for
# non-identity configuration and as a fallback when selectors are omitted.
APP_MODE ?= tenant

ifneq ($(strip $(TENANT_KEY)),)
  TENANT_ID := $(TENANT_KEY)
else
  TENANT_ID ?= $(ENV_TENANT_ID)
endif

ifneq ($(strip $(APP_KEY)),)
  APP_ID := $(APP_KEY)
else
  APP_ID ?= $(ENV_APP_ID)
endif

DART_DEFINES := $(call defines_from_env,$(ENV_FILE))
APP_BOOT_DEFINES := \
  --dart-define=APP=$(APP_MODE) \
  --dart-define=TENANT_ID=$(TENANT_ID) \
  --dart-define=APP_ID=$(APP_ID)

# HQ uses the same entrypoint but a different runtime mode.
HQ_TENANT_ID ?= hq
HQ_APP_ID    ?= hq
HQ_DEFINES := \
  --dart-define=APP=hq \
  --dart-define=TENANT_ID=$(HQ_TENANT_ID) \
  --dart-define=APP_ID=$(HQ_APP_ID)

# ─────────────────────────────────────────────────────────────────────────────
# Outputs / hosts
# ─────────────────────────────────────────────────────────────────────────────

WEB_OUT    ?= build/web
WEB_OUT_HQ ?= build/web-hq

HQ_SITE ?= afyakit-hq
HQ_HOST ?= admin.afyakit.app

HOST ?= $(if $(filter dawapap,$(APP_ID)),www.dawapap.com,\
        $(if $(filter afyakit,$(APP_ID)),www.afyakit.app,\
        $(if $(filter danabtmc,$(APP_ID)),www.danabtmc.com,\
        $(if $(filter hq,$(APP_ID)),$(HQ_HOST),))))

APP_TITLE ?= $(if $(filter dawapap,$(APP_ID)),DawaPap Pharmacy,\
             $(if $(filter afyakit,$(APP_ID)),AfyaKit,\
             $(if $(filter danabtmc,$(APP_ID)),Dana B TMC,\
             $(if $(filter afyatracker,$(APP_ID)),AfyaTracker,\
             $(if $(filter hq,$(APP_ID)),AfyaKit HQ,AfyaKit)))))

APP_DESCRIPTION ?= $(if $(filter dawapap,$(APP_ID)),Your Pharmacy. Anywhere. Anytime.,\
                   $(if $(filter afyakit,$(APP_ID)),Digital healthcare management made simple.,\
                   $(if $(filter danabtmc,$(APP_ID)),Healthcare services and medical support.,\
                   $(if $(filter afyatracker,$(APP_ID)),Your longitudinal health and care record.,\
                   AfyaKit healthcare platform.))))

APP_URL ?= $(if $(HOST),https://$(HOST)/,)

# Keep the current DawaPap production image during the storage-path transition.
APP_IMAGE ?= $(if $(filter dawapap,$(APP_ID)),\
https://firebasestorage.googleapis.com/v0/b/afyakit-api.firebasestorage.app/o/public%2Fdawapap%2Fbranding%2Fweb%2Ficon-512.png?alt=media,\
$(APP_URL)favicon.png)

HASH := \#
THEME_COLOR ?= $(if $(filter dawapap,$(APP_ID)),$(HASH)00A86B,$(HASH)2196F3)

# ─────────────────────────────────────────────────────────────────────────────
# Flutter / device
# ─────────────────────────────────────────────────────────────────────────────

DEVICE ?= $(shell flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}')
ifeq ($(strip $(DEVICE)),)
  DEVICE := chrome
endif

WEB_PORT_BASE ?= 5000
WEB_PORT      ?= $(WEB_PORT_BASE)

WEB_ICON_FLAGS ?= --no-tree-shake-icons

PWA_STRATEGY ?= none
PWA_STRATEGY_FLAG := --pwa-strategy=$(PWA_STRATEGY)

WEB_STRIP_SERVICE_WORKER ?= $(if $(filter none,$(PWA_STRATEGY)),1,0)
WEB_SERVICE_WORKER_FILES := flutter_service_worker.js flutter_service_worker.js.map

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

WEB_RENDERER ?= canvaskit

HAS_WEB_RENDERER_BUILD := $(shell flutter build web -h 2>/dev/null | grep -q -- '--web-renderer' && echo 1 || echo 0)
HAS_WEB_RENDERER_RUN   := $(shell flutter run -h 2>/dev/null | grep -q -- '--web-renderer' && echo 1 || echo 0)

WEB_RENDERER_BUILD_FLAG := $(if $(filter 1,$(HAS_WEB_RENDERER_BUILD)),--web-renderer=$(WEB_RENDERER),)
WEB_RENDERER_RUN_FLAG   := $(if $(filter 1,$(HAS_WEB_RENDERER_RUN)),--web-renderer=$(WEB_RENDERER),)

# Android flavor remains tied to the app/product build selector, not TENANT_ID.
FLAVOR_FLAG := $(if $(filter 1 yes true,$(USE_FLAVOR)),$(if $(APP_KEY),--flavor $(APP_KEY),),)

# ─────────────────────────────────────────────────────────────────────────────
# Guards
# ─────────────────────────────────────────────────────────────────────────────

define assert_app
	@if [ -z "$(TENANT_ID)" ] || [ -z "$(APP_ID)" ]; then \
	  echo "❌ Missing tenantId or appId."; \
	  echo "   Usage: make $@ <tenantId> <appId>"; \
	  echo "   Example: make $@ afya dawapap"; \
	  exit 2; \
	fi
endef

define assert_apps
	@if [ -z "$(APP_TARGETS)" ]; then \
	  echo '❌ APP_TARGETS is empty.'; \
	  echo '   Example: APP_TARGETS="afya:dawapap afya:afyatracker" make $@'; \
	  exit 2; \
	fi
endef

# ─────────────────────────────────────────────────────────────────────────────
# Shared web build
# $(1) output dir
# $(2) label
# $(3) dart defines
# $(4) app used for web branding
# ─────────────────────────────────────────────────────────────────────────────

define flutter_web_build
	@rm -rf "$(1)"
	@echo "$(2)"
	flutter build web --release \
	  $(WEB_ICON_FLAGS) \
	  $(PWA_STRATEGY_FLAG) \
	  $(WEB_RENDERER_BUILD_FLAG) \
	  -t "$(ENTRY)" \
	  -o "$(1)" \
	  $(EXTRA) \
	  $(3)
	@$(MAKE) web-brand \
	  APP_KEY="$(4)" \
	  APP_ID="$(APP_ID)" \
	  TENANT_ID="$(TENANT_ID)" \
	  WEB_OUT="$(1)" \
	  HOST="$(HOST)" \
	  APP_TITLE="$(APP_TITLE)" \
	  APP_DESCRIPTION="$(APP_DESCRIPTION)" \
	  APP_URL="$(APP_URL)" \
	  APP_IMAGE="$(APP_IMAGE)" \
	  THEME_COLOR="$(THEME_COLOR)"
	@$(MAKE) web-strip-service-worker \
	  WEB_OUT="$(1)" \
	  PWA_STRATEGY="$(PWA_STRATEGY)" \
	  WEB_STRIP_SERVICE_WORKER="$(WEB_STRIP_SERVICE_WORKER)"
	@$(MAKE) web-verify \
	  APP_KEY="$(4)" \
	  WEB_OUT="$(1)"
endef

# ─────────────────────────────────────────────────────────────────────────────
# Help / diagnostics
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help env-check devices doctor outdated pubget

help:
	@echo "Targets:"
	@echo "  run / run-android / run-web           — run one tenant app"
	@echo "  run-web-all / run-android-all         — run APP_TARGETS"
	@echo "  web / deploy / release-web            — build/deploy one tenant app"
	@echo "  web-all / deploy-all / release-web-all— build/deploy APP_TARGETS"
	@echo "  web-verify / deploy-verify            — local/live web checks"
	@echo "  run-hq / run-web-hq                   — run HQ"
	@echo "  web-hq / deploy-hq / release-web-hq   — build/deploy HQ"
	@echo ""
	@echo "Bootstrap: APP=tenant|hq TENANT_ID=<data universe> APP_ID=<product>"
	@echo ""
	@echo "Examples:"
	@echo "  make run-web afya dawapap"
	@echo "  make run-web afya afyatracker"
	@echo "  make release-web afya dawapap"
	@echo '  APP_TARGETS="afya:dawapap afya:afyatracker" make release-web-all'

env-check:
	@$(call assert_app)
	@echo "TENANT_KEY=$(TENANT_KEY)"
	@echo "APP_KEY=$(APP_KEY)"
	@echo "APP_TARGETS=$(APP_TARGETS)"
	@echo "APP_MODE=$(APP_MODE)"
	@echo "TENANT_ID=$(TENANT_ID)"
	@echo "APP_ID=$(APP_ID)"
	@echo "ENV_FILE=$(ENV_FILE)"
	@echo "DART_DEFINES=$(DART_DEFINES)"
	@echo "APP_BOOT_DEFINES=$(APP_BOOT_DEFINES)"
	@echo "HOST=$(HOST)"
	@echo "APP_TITLE=$(APP_TITLE)"
	@echo "APP_DESCRIPTION=$(APP_DESCRIPTION)"
	@echo "APP_URL=$(APP_URL)"
	@echo "APP_IMAGE=$(APP_IMAGE)"
	@echo "THEME_COLOR=$(THEME_COLOR)"
	@echo "WEB_PORT=$(WEB_PORT)"
	@echo "PWA_STRATEGY=$(PWA_STRATEGY)"
	@echo "WEB_RENDERER_BUILD_FLAG=$(WEB_RENDERER_BUILD_FLAG)"
	@echo "WEB_RENDERER_RUN_FLAG=$(WEB_RENDERER_RUN_FLAG)"

devices:
	flutter devices

doctor:
	flutter doctor -v

outdated:
	flutter pub outdated || true

pubget:
	flutter pub get

# ─────────────────────────────────────────────────────────────────────────────
# Run: one app
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: run run-android run-web

run: run-android

run-web:
	@$(call assert_app)
	@echo "🌐 Running $(APP_ID) [tenant=$(TENANT_ID)] on Chrome :$(WEB_PORT)…"
	./scripts/run_web_tenant.sh "$(APP_KEY)" -- \
	  flutter run \
	    -d chrome \
	    --web-port="$(WEB_PORT)" \
	    $(WEB_RENDERER_RUN_FLAG) \
	    -t "$(ENTRY)" \
	    $(EXTRA) \
	    $(DART_DEFINES) \
	    $(APP_BOOT_DEFINES)

run-android:
	@$(call assert_app)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then \
	  echo "❌ No Android device/emulator found."; \
	  exit 2; \
	fi; \
	echo "🤖 Running $(APP_ID) [tenant=$(TENANT_ID)] on '$$ANDROID'…"; \
	flutter run \
	  -d "$$ANDROID" \
	  $(FLAVOR_FLAG) \
	  -t "$(ENTRY)" \
	  $(EXTRA) \
	  $(DART_DEFINES) \
	  $(APP_BOOT_DEFINES)

# ─────────────────────────────────────────────────────────────────────────────
# Run: many apps
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: run-web-all run-android-all

run-web-all:
	@$(call assert_apps)
	@PORT=$(WEB_PORT_BASE); \
	for target in $(APP_TARGETS); do \
	  tenant="$${target%%:*}"; \
	  app="$${target#*:}"; \
	  if [ -z "$$tenant" ] || [ -z "$$app" ] || [ "$$tenant" = "$$app" -a "$$target" != "$$tenant:$$app" ]; then \
	    echo "❌ Invalid APP_TARGETS entry: $$target (expected tenantId:appId)"; \
	    exit 2; \
	  fi; \
	  echo "🌐 Launch $$app [tenant=$$tenant] on Chrome :$$PORT…"; \
	  ($(MAKE) run-web TENANT_ID="$$tenant" APP_ID="$$app" APP_KEY="$$app" WEB_PORT="$$PORT" &) ; \
	  PORT=$$((PORT + 1)); \
	done; \
	echo "ℹ️ Started $(words $(APP_TARGETS)) Chrome debuggers."

run-android-all:
	@$(call assert_apps)
	@for target in $(APP_TARGETS); do \
	  tenant="$${target%%:*}"; \
	  app="$${target#*:}"; \
	  if [ -z "$$tenant" ] || [ -z "$$app" ] || [ "$$target" = "$$tenant" ]; then \
	    echo "❌ Invalid APP_TARGETS entry: $$target (expected tenantId:appId)"; \
	    exit 2; \
	  fi; \
	  $(MAKE) run-android TENANT_ID="$$tenant" APP_ID="$$app" APP_KEY="$$app"; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# Web: build / branding / verification
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: web web-brand web-strip-service-worker web-verify
.PHONY: web-clean flutter-clean

web:
	@$(call assert_app)
	$(call flutter_web_build,$(WEB_OUT),🌐 Release build: $(APP_ID) [tenant=$(TENANT_ID)] → $(WEB_OUT),$(DART_DEFINES) $(APP_BOOT_DEFINES),$(APP_KEY))

web-brand:
	@echo "🎨 Applying web branding for $(APP_ID)…"
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
	node -e 'const fs=require("fs"); const p=process.env.WEB_INDEX; const r={"__APP_TITLE__":process.env.APP_TITLE,"__APP_DESCRIPTION__":process.env.APP_DESCRIPTION,"__APP_URL__":process.env.APP_URL,"__APP_IMAGE__":process.env.APP_IMAGE,"__THEME_COLOR__":process.env.THEME_COLOR}; let s=fs.readFileSync(p,"utf8"); for(const [k,v] of Object.entries(r)) s=s.split(k).join(v||""); fs.writeFileSync(p,s);'
	@app_dir="web/apps/$(APP_ID)"; \
	legacy_dir="web/tenants/$(APP_ID)"; \
	if [ -d "$$app_dir" ]; then \
	  branding_dir="$$app_dir"; \
	elif [ -d "$$legacy_dir" ]; then \
	  branding_dir="$$legacy_dir"; \
	  echo "⚠️ Using legacy branding overlay $$legacy_dir"; \
	else \
	  branding_dir=""; \
	fi; \
	if [ -n "$$branding_dir" ]; then \
	  echo "🎨 Overlaying $$branding_dir → $(WEB_OUT)"; \
	  [ ! -f "$$branding_dir/favicon.png" ] || cp "$$branding_dir/favicon.png" "$(WEB_OUT)/favicon.png"; \
	  if [ -f "$$branding_dir/manifest.webmanifest" ]; then \
	    cp "$$branding_dir/manifest.webmanifest" "$(WEB_OUT)/manifest.webmanifest"; \
	  elif [ -f "$$branding_dir/manifest.json" ]; then \
	    cp "$$branding_dir/manifest.json" "$(WEB_OUT)/manifest.webmanifest"; \
	  fi; \
	  if [ -d "$$branding_dir/icons" ]; then \
	    mkdir -p "$(WEB_OUT)/icons"; \
	    cp -a "$$branding_dir/icons/." "$(WEB_OUT)/icons/"; \
	  fi; \
	else \
	  echo "ℹ️ No app web overlay for $(APP_ID); using defaults."; \
	fi
	@echo "   app:    $(APP_ID)"
	@echo "   tenant: $(TENANT_ID)"
	@echo "   title:  $(APP_TITLE)"
	@echo "   URL:    $(APP_URL)"
	@echo "   image:  $(APP_IMAGE)"

web-strip-service-worker:
	@if [ "$(WEB_STRIP_SERVICE_WORKER)" = "1" ]; then \
	  for f in $(WEB_SERVICE_WORKER_FILES); do \
	    [ ! -f "$(WEB_OUT)/$$f" ] || { \
	      echo "🧹 Removing $(WEB_OUT)/$$f"; \
	      rm -f "$(WEB_OUT)/$$f"; \
	    }; \
	  done; \
	fi

web-verify:
	@echo "🔎 Verifying web output…"
	@test -d "$(WEB_OUT)" || { echo "❌ Missing $(WEB_OUT)"; exit 2; }
	@for f in $(WEB_REQUIRED_FILES); do \
	  test -f "$(WEB_OUT)/$$f" || { echo "❌ Missing $(WEB_OUT)/$$f"; exit 2; }; \
	done
	@for f in $(WEB_JSON_FILES); do \
	  node -e "JSON.parse(require('fs').readFileSync('$(WEB_OUT)/' + process.argv[1], 'utf8'))" "$$f" \
	    || { echo "❌ Invalid JSON: $(WEB_OUT)/$$f"; exit 2; }; \
	done
	@test -f "$(WEB_OUT)/manifest.webmanifest" || { \
	  echo "❌ Missing $(WEB_OUT)/manifest.webmanifest"; \
	  exit 2; \
	}
	@node -e "JSON.parse(require('fs').readFileSync('$(WEB_OUT)/manifest.webmanifest','utf8'))" \
	  || { echo "❌ Invalid manifest.webmanifest"; exit 2; }
	@if grep -q '\$$FLUTTER_BASE_HREF' "$(WEB_OUT)/index.html"; then \
	  echo '❌ index.html still contains $$FLUTTER_BASE_HREF'; \
	  exit 2; \
	fi
	@if grep -qE '__APP_|__THEME_COLOR__|Loading…|Loading\.\.\.' "$(WEB_OUT)/index.html"; then \
	  echo "❌ Unresolved branding metadata in $(WEB_OUT)/index.html"; \
	  exit 2; \
	fi
	@grep -q '<meta property="og:title"' "$(WEB_OUT)/index.html" || { echo "❌ Missing og:title"; exit 2; }
	@grep -q '<meta property="og:image"' "$(WEB_OUT)/index.html" || { echo "❌ Missing og:image"; exit 2; }
	@if [ "$(PWA_STRATEGY)" = "none" ] && [ -f "$(WEB_OUT)/flutter_service_worker.js" ]; then \
	  echo "❌ flutter_service_worker.js should have been stripped"; \
	  exit 2; \
	fi
	@if grep -R "flutter_service_worker.js" $(addprefix "$(WEB_OUT)/,$(addsuffix ",$(WEB_SW_CHECK_FILES))) >/dev/null 2>&1; then \
	  echo "⚠️ Boot assets still contain an inert flutter_service_worker.js reference."; \
	fi
	@echo "✅ Web build verified"

web-clean:
	@echo "🧹 Cleaning web outputs…"
	rm -rf "$(WEB_OUT)" "$(WEB_OUT_HQ)"

flutter-clean: web-clean
	flutter clean

# ─────────────────────────────────────────────────────────────────────────────
# Web: deploy / release
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: deploy deploy-verify release-web

deploy:
	@$(call assert_app)
	@$(MAKE) web-verify APP_KEY="$(APP_KEY)" APP_ID="$(APP_ID)" TENANT_ID="$(TENANT_ID)" WEB_OUT="$(WEB_OUT)"
	@echo "🚀 Deploy hosting:$(APP_ID) from $(WEB_OUT)…"
	@cfg="firebase.$(APP_ID).json"; \
	[ -f "$$cfg" ] || cfg="firebase.json"; \
	[ -f "$$cfg" ] || { echo "❌ Missing Firebase config for $(APP_ID)."; exit 2; }; \
	echo "   → using $$cfg"; \
	firebase deploy --config "$$cfg" --only hosting:$(APP_ID)
	@$(MAKE) deploy-verify \
	  APP_KEY="$(APP_KEY)" \
	  APP_ID="$(APP_ID)" \
	  TENANT_ID="$(TENANT_ID)" \
	  HOST="$(HOST)" \
	  APP_TITLE="$(APP_TITLE)"

deploy-verify:
	@if [ -z "$(HOST)" ]; then \
	  echo "ℹ️ HOST empty; skipping live verification."; \
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
	    *AssetManifest.json*application/json*|\
	    *FontManifest.json*application/json*|\
	    *main.dart.js*javascript*|\
	    *flutter_bootstrap.js*javascript*|\
	    *manifest.webmanifest*manifest+json*) ;; \
	    *) echo "❌ Unexpected content type for $$path"; exit 2 ;; \
	  esac; \
	done
	@html=$$(curl -fsSL "https://$(HOST)/"); \
	echo "$$html" | grep -Fq "<title>$(APP_TITLE)</title>" || { \
	  echo "❌ Live HTML has the wrong title"; \
	  exit 2; \
	}; \
	echo "$$html" | grep -q 'property="og:image"' || { \
	  echo "❌ Live HTML is missing og:image"; \
	  exit 2; \
	}; \
	echo "✅ Live web verified"

release-web:
	@$(call assert_app)
	@$(MAKE) web TENANT_ID="$(TENANT_ID)" APP_ID="$(APP_ID)" APP_KEY="$(APP_ID)" EXTRA="$(EXTRA)"
	@$(MAKE) deploy TENANT_ID="$(TENANT_ID)" APP_ID="$(APP_ID)" APP_KEY="$(APP_ID)"

# ─────────────────────────────────────────────────────────────────────────────
# Web: many apps
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: web-all deploy-all release-web-all

web-all:
	@$(call assert_apps)
	@for target in $(APP_TARGETS); do \
	  tenant="$${target%%:*}"; \
	  app="$${target#*:}"; \
	  [ "$$target" != "$$tenant" ] || { echo "❌ Invalid APP_TARGETS entry: $$target"; exit 2; }; \
	  $(MAKE) web TENANT_ID="$$tenant" APP_ID="$$app" APP_KEY="$$app"; \
	done

deploy-all:
	@$(call assert_apps)
	@for target in $(APP_TARGETS); do \
	  tenant="$${target%%:*}"; \
	  app="$${target#*:}"; \
	  [ "$$target" != "$$tenant" ] || { echo "❌ Invalid APP_TARGETS entry: $$target"; exit 2; }; \
	  $(MAKE) deploy TENANT_ID="$$tenant" APP_ID="$$app" APP_KEY="$$app"; \
	done

release-web-all:
	@$(call assert_apps)
	@for target in $(APP_TARGETS); do \
	  tenant="$${target%%:*}"; \
	  app="$${target#*:}"; \
	  [ "$$target" != "$$tenant" ] || { echo "❌ Invalid APP_TARGETS entry: $$target"; exit 2; }; \
	  $(MAKE) release-web TENANT_ID="$$tenant" APP_ID="$$app" APP_KEY="$$app"; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# HQ
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: run-hq run-web-hq web-hq deploy-hq release-web-hq

run-hq: LOAD_ENV=0
run-hq:
	@echo "🏢 Running HQ on '$(DEVICE)'…"
	flutter run -d "$(DEVICE)" -t "$(ENTRY)" $(HQ_DEFINES) $(EXTRA)

run-web-hq: LOAD_ENV=0
run-web-hq:
	@echo "🏢🌐 Running HQ on Chrome :$(WEB_PORT)…"
	flutter run \
	  -d chrome \
	  --web-port="$(WEB_PORT)" \
	  $(WEB_RENDERER_RUN_FLAG) \
	  -t "$(ENTRY)" \
	  $(HQ_DEFINES) \
	  $(EXTRA)

web-hq: LOAD_ENV=0
web-hq: APP_ID=$(HQ_APP_ID)
web-hq: TENANT_ID=$(HQ_TENANT_ID)
web-hq:
	$(call flutter_web_build,$(WEB_OUT_HQ),🏢🌐 Release build HQ → $(WEB_OUT_HQ),$(HQ_DEFINES),hq)

deploy-hq:
	@$(MAKE) web-verify APP_KEY="hq" APP_ID="$(HQ_APP_ID)" TENANT_ID="$(HQ_TENANT_ID)" WEB_OUT="$(WEB_OUT_HQ)"
	@echo "🚀 Deploy HQ hosting:$(HQ_SITE) from $(WEB_OUT_HQ)…"
	@test -f firebase.hq.json || { echo "❌ Missing firebase.hq.json"; exit 2; }
	firebase deploy --config firebase.hq.json --only hosting:$(HQ_SITE)
	@$(MAKE) deploy-verify \
	  APP_KEY="hq" \
	  APP_ID="$(HQ_APP_ID)" \
	  TENANT_ID="$(HQ_TENANT_ID)" \
	  HOST="$(HQ_HOST)" \
	  APP_TITLE="AfyaKit HQ"

release-web-hq: LOAD_ENV=0
release-web-hq:
	@$(MAKE) web-hq EXTRA="$(EXTRA)"
	@$(MAKE) deploy-hq