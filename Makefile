# ─────────────────────────────────────────────────────────────────────────────
# AfyaKit multi-app Makefile
#
# Canonical commands use tenant first, then app:
#   make dev afya dawapap
#   make android afya occuwell
#   make build afya afyatracker
#   make publish afya dawapap
#   make release afya dawapap
#   make release danabtmc danabtmc
#   make release hq
#
# Explicit CI selectors are also supported:
#   make release-web TENANT_ID=afya APP_ID=dawapap APP_KEY=dawapap
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
# Core selectors
# ─────────────────────────────────────────────────────────────────────────────

ENTRY ?= lib/main.dart

# Tenant-first positional syntax: make <action> <tenantId> <appId>
# HQ also supports: make <action> hq
TENANT_KEY ?= $(if $(word 3,$(MAKECMDGOALS)),$(word 2,$(MAKECMDGOALS)),)
APP_KEY ?= $(if $(word 3,$(MAKECMDGOALS)),$(word 3,$(MAKECMDGOALS)),$(if $(filter hq,$(word 2,$(MAKECMDGOALS))),hq,))

# Make interprets positional selectors as targets; consume them as no-ops.
POSITIONAL_ARGS := $(sort $(wordlist 2,3,$(MAKECMDGOALS)))
ifneq ($(strip $(POSITIONAL_ARGS)),)
.PHONY: $(POSITIONAL_ARGS)
$(POSITIONAL_ARGS): ; @:
endif

# Batch list, each entry tenantId:appId.
# Example:
#   APP_TARGETS="afya:dawapap afya:afyatracker danabtmc:danabtmc"
APP_TARGETS ?=

EXTRA ?=
USE_FLAVOR ?= 1
LOAD_ENV ?= 1

# ─────────────────────────────────────────────────────────────────────────────
# Environment loader
#
# Order:
#   .env.<app>.web -> .env.<app> -> .env
#
# Canonical identity keys are never read from env files. APP, TENANT_ID,
# APP_ID and legacy TENANT are supplied explicitly by this Makefile.
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
        if (key != "") printf "--dart-define=%s=%s ", key, val; \
      }' "$$f"; \
  fi))
endef

ENV_FILE := $(call resolve_env_file,$(APP_KEY))
DART_DEFINES := $(call defines_from_env,$(ENV_FILE))

# ─────────────────────────────────────────────────────────────────────────────
# Canonical runtime identity
# ─────────────────────────────────────────────────────────────────────────────

APP_MODE ?= tenant
TENANT_ID ?= $(TENANT_KEY)
APP_ID ?= $(APP_KEY)

ifeq ($(APP_KEY),hq)
APP_MODE := hq
TENANT_ID := hq
APP_ID := hq
endif

# Keep these on one logical Make line. These are compile-time Flutter values
# and MUST reach every run/build command unchanged.
APP_BOOT_DEFINES = --dart-define=APP=$(APP_MODE) --dart-define=TENANT_ID=$(TENANT_ID) --dart-define=APP_ID=$(APP_ID)

HQ_TENANT_ID ?= hq
HQ_APP_ID ?= hq
HQ_DEFINES = --dart-define=APP=hq --dart-define=TENANT_ID=$(HQ_TENANT_ID) --dart-define=APP_ID=$(HQ_APP_ID)

# ─────────────────────────────────────────────────────────────────────────────
# Outputs / Firebase Hosting
# ─────────────────────────────────────────────────────────────────────────────

WEB_OUT ?= build/web
WEB_OUT_HQ ?= build/web-hq

HOSTING_CONFIG_DIR ?= firebase/hosting
FIREBASE_PROJECT ?= afyakit-api

# Canonical Firebase Hosting site for each product.
# This is deliberately explicit so an app cannot be deployed to another
# product's site by an accidental firebase.json/.firebaserc change.
HOSTING_SITE = $(strip \
  $(if $(filter dawapap,$(APP_ID)),dawapap-app,\
  $(if $(filter afyakit,$(APP_ID)),afyakit,\
  $(if $(filter danabtmc,$(APP_ID)),danabtmc-app,\
  $(if $(filter afyatracker,$(APP_ID)),afyatracker-app,\
  $(if $(filter occuwell,$(APP_ID)),occuwell-app,\
  $(if $(filter rpmoc,$(APP_ID)),rpmoc,\
  $(if $(filter hq,$(APP_ID)),afyakit-hq,))))))))

HQ_SITE ?= afyakit-hq
HQ_HOST ?= admin.afyakit.app

HOST ?= $(strip \
  $(if $(filter dawapap,$(APP_ID)),www.dawapap.com,\
  $(if $(filter afyakit,$(APP_ID)),www.afyakit.app,\
  $(if $(filter danabtmc,$(APP_ID)),www.danabtmc.com,\
  $(if $(filter afyatracker,$(APP_ID)),www.afyatracker.com,\
  $(if $(filter occuwell,$(APP_ID)),app.occuwell.co.ke,\
  $(if $(filter hq,$(APP_ID)),$(HQ_HOST),)))))))

APP_TITLE ?= $(strip \
  $(if $(filter dawapap,$(APP_ID)),DawaPap Pharmacy,\
  $(if $(filter afyakit,$(APP_ID)),AfyaKit,\
  $(if $(filter danabtmc,$(APP_ID)),Dana B TMC,\
  $(if $(filter afyatracker,$(APP_ID)),AfyaTracker,\
  $(if $(filter occuwell,$(APP_ID)),Occuwell,\
  $(if $(filter hq,$(APP_ID)),AfyaKit HQ,AfyaKit)))))))

APP_DESCRIPTION ?= $(strip \
  $(if $(filter dawapap,$(APP_ID)),Your Pharmacy. Anywhere. Anytime.,\
  $(if $(filter afyakit,$(APP_ID)),Digital healthcare management made simple.,\
  $(if $(filter danabtmc,$(APP_ID)),Healthcare services and medical support.,\
  $(if $(filter afyatracker,$(APP_ID)),Your longitudinal health and care record.,\
  $(if $(filter occuwell,$(APP_ID)),Occupational Health and Wellness.,\
  AfyaKit healthcare platform.))))))

APP_URL ?= $(if $(HOST),https://$(HOST)/,)

# Canonical migrated DawaPap public branding path.
APP_IMAGE ?= $(strip \
  $(if $(filter dawapap,$(APP_ID)),https://firebasestorage.googleapis.com/v0/b/afyakit-api.firebasestorage.app/o/public%2Fafya%2Fdawapap%2Fbranding%2Fweb%2Ficon-512.png?alt=media,\
  $(APP_URL)favicon.png))

HASH := \#
THEME_COLOR ?= $(if $(filter dawapap,$(APP_ID)),$(HASH)00A86B,$(HASH)2196F3)

# ─────────────────────────────────────────────────────────────────────────────
# Flutter / web settings
# ─────────────────────────────────────────────────────────────────────────────

DEVICE ?= $(shell flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}')
ifeq ($(strip $(DEVICE)),)
DEVICE := chrome
endif

WEB_PORT_BASE ?= 5000
WEB_PORT ?= $(WEB_PORT_BASE)

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
HAS_WEB_RENDERER_RUN := $(shell flutter run -h 2>/dev/null | grep -q -- '--web-renderer' && echo 1 || echo 0)

WEB_RENDERER_BUILD_FLAG := $(if $(filter 1,$(HAS_WEB_RENDERER_BUILD)),--web-renderer=$(WEB_RENDERER),)
WEB_RENDERER_RUN_FLAG := $(if $(filter 1,$(HAS_WEB_RENDERER_RUN)),--web-renderer=$(WEB_RENDERER),)

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

define assert_boot_identity
	@if [ -z "$(strip $(APP_BOOT_DEFINES))" ]; then \
	  echo "❌ APP_BOOT_DEFINES is empty."; \
	  exit 2; \
	fi; \
	case " $(APP_BOOT_DEFINES) " in \
	  *" --dart-define=TENANT_ID=$(TENANT_ID) "*) ;; \
	  *) echo "❌ TENANT_ID compile-time define missing."; exit 2 ;; \
	esac; \
	case " $(APP_BOOT_DEFINES) " in \
	  *" --dart-define=APP_ID=$(APP_ID) "*) ;; \
	  *) echo "❌ APP_ID compile-time define missing."; exit 2 ;; \
	esac
endef

# ─────────────────────────────────────────────────────────────────────────────
# Shared Flutter Web build
# $(1) output dir
# $(2) label
# $(3) dart defines
# $(4) app selector
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
	  APP_MODE="$(APP_MODE)" \
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
	  APP_ID="$(APP_ID)" \
	  TENANT_ID="$(TENANT_ID)" \
	  WEB_OUT="$(1)"
endef

# ─────────────────────────────────────────────────────────────────────────────
# Help / diagnostics
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help env-check devices doctor outdated pubget

help:
	@echo "AfyaKit multi-app commands"
	@echo ""
	@echo "  make dev <tenantId> <appId>          Run Web development"
	@echo "  make android <tenantId> <appId>      Run Android development"
	@echo "  make build <tenantId> <appId>        Build Web"
	@echo "  make publish <tenantId> <appId>      Deploy existing Web build"
	@echo "  make release <tenantId> <appId>      Build + deploy Web"
	@echo ""
	@echo "Examples:"
	@echo "  make dev afya dawapap"
	@echo "  make release afya dawapap"
	@echo "  make release afya afyatracker"
	@echo "  make release danabtmc danabtmc"
	@echo "  make release hq"
	@echo ""
	@echo 'Batch: APP_TARGETS="afya:dawapap afya:afyatracker" make release-web-all'

env-check:
	$(call assert_app)
	@printf '%s\n' \
	  "TENANT_KEY=$(TENANT_KEY)" \
	  "APP_KEY=$(APP_KEY)" \
	  "APP_TARGETS=$(APP_TARGETS)" \
	  "APP_MODE=$(APP_MODE)" \
	  "TENANT_ID=$(TENANT_ID)" \
	  "APP_ID=$(APP_ID)" \
	  "ENV_FILE=$(ENV_FILE)" \
	  "DART_DEFINES=$(DART_DEFINES)" \
	  "APP_BOOT_DEFINES=$(APP_BOOT_DEFINES)" \
	  "FIREBASE_PROJECT=$(FIREBASE_PROJECT)" \
	  "HOSTING_SITE=$(HOSTING_SITE)" \
	  "HOSTING_CONFIG_DIR=$(HOSTING_CONFIG_DIR)" \
	  "HOST=$(HOST)" \
	  "APP_TITLE=$(APP_TITLE)" \
	  "APP_DESCRIPTION=$(APP_DESCRIPTION)" \
	  "APP_URL=$(APP_URL)" \
	  "APP_IMAGE=$(APP_IMAGE)" \
	  "THEME_COLOR=$(THEME_COLOR)" \
	  "WEB_PORT=$(WEB_PORT)" \
	  "PWA_STRATEGY=$(PWA_STRATEGY)" \
	  "WEB_RENDERER_BUILD_FLAG=$(WEB_RENDERER_BUILD_FLAG)" \
	  "WEB_RENDERER_RUN_FLAG=$(WEB_RENDERER_RUN_FLAG)"

devices:
	flutter devices

doctor:
	flutter doctor -v

outdated:
	flutter pub outdated || true

pubget:
	flutter pub get

# ─────────────────────────────────────────────────────────────────────────────
# Short commands
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: dev android build publish release

ifeq ($(APP_KEY),hq)
dev: run-web-hq
android: run-hq
build: web-hq
publish: deploy-hq
release: release-web-hq
else
dev: run-web
android: run-android
build: web
publish: deploy
release: release-web
endif

# ─────────────────────────────────────────────────────────────────────────────
# Run: one app
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: run run-android run-web

run: run-android

run-web:
	$(call assert_app)
	$(call assert_boot_identity)
	@echo "🌐 Running $(APP_ID) [tenant=$(TENANT_ID)] on Chrome :$(WEB_PORT)…"
	./scripts/run_web_tenant.sh "$(TENANT_ID)" "$(APP_ID)" -- \
	  flutter run \
	    -d chrome \
	    --web-port="$(WEB_PORT)" \
	    $(WEB_RENDERER_RUN_FLAG) \
	    -t "$(ENTRY)" \
	    $(EXTRA) \
	    $(DART_DEFINES) \
	    $(APP_BOOT_DEFINES)

run-android:
	$(call assert_app)
	$(call assert_boot_identity)
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
	@echo "❌ Concurrent Flutter Web runs share Web branding assets." >&2
	@echo "   Run one app at a time: make dev <tenantId> <appId>" >&2
	@exit 2

run-android-all:
	$(call assert_apps)
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

.PHONY: web web-brand web-strip-service-worker web-verify web-clean flutter-clean

web:
	$(call assert_app)
	$(call assert_boot_identity)
	$(call flutter_web_build,$(WEB_OUT),🌐 Release build: $(APP_ID) [tenant=$(TENANT_ID)] → $(WEB_OUT),$(DART_DEFINES) $(APP_BOOT_DEFINES),$(APP_KEY))

BRANDING_TENANT_ID = $(if $(filter hq,$(APP_MODE)),hq,$(TENANT_ID))
BRANDING_APP_ID = $(if $(filter hq,$(APP_MODE)),afyakit,$(APP_ID))

web-brand:
	@echo "🎨 Applying web branding: $(BRANDING_TENANT_ID)/$(BRANDING_APP_ID) → $(WEB_OUT)"
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
	@./scripts/apply_web_branding.sh \
	  "$(BRANDING_TENANT_ID)" \
	  "$(BRANDING_APP_ID)" \
	  "$(WEB_OUT)"
	@echo "✅ Web branding complete: $(BRANDING_TENANT_ID)/$(BRANDING_APP_ID)"

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
	$(call assert_app)
	@$(MAKE) web-verify \
		APP_KEY="$(APP_KEY)" \
		APP_ID="$(APP_ID)" \
		TENANT_ID="$(TENANT_ID)" \
		WEB_OUT="$(WEB_OUT)"
	@echo "🚀 Deploy $(APP_ID) [tenant=$(TENANT_ID)] from $(WEB_OUT)…"
	@cfg="$(HOSTING_CONFIG_DIR)/$(APP_ID).json"; \
	expected_site="$(HOSTING_SITE)"; \
	[ -n "$$expected_site" ] || { \
		echo "❌ No canonical Firebase Hosting site configured for app: $(APP_ID)"; \
		exit 2; \
	}; \
	[ -f "$$cfg" ] || { \
		echo "❌ Missing Hosting config: $$cfg"; \
		exit 2; \
	}; \
	resolved_site=$$(node -e 'const fs=require("fs"); const cfg=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); const h=cfg.hosting; const expectedPublic=process.argv[2]; const app=process.argv[3]; const expectedSite=process.argv[4]; if (!h || h.public!==expectedPublic) process.exit(2); if (!!h.site === !!h.target) process.exit(2); if (h.site) { if (h.site!==expectedSite) process.exit(2); console.log(h.site); process.exit(0); } if (h.target!==app) process.exit(2); const rc=JSON.parse(fs.readFileSync(".firebaserc","utf8")); const project=rc.projects && rc.projects.default; const sites=rc.targets && rc.targets[project] && rc.targets[project].hosting && rc.targets[project].hosting[h.target]; if (!Array.isArray(sites) || sites.length!==1 || sites[0]!==expectedSite) process.exit(2); console.log(sites[0]);' "$$cfg" "$(WEB_OUT)" "$(APP_ID)" "$$expected_site") || { \
		echo "❌ Hosting config invalid or mapped to the wrong site: $$cfg"; \
		echo "   Expected site: $$expected_site"; \
		exit 2; \
	}; \
	echo "   → config: $$cfg"; \
	echo "   → Firebase Hosting site: $$resolved_site"; \
	tmp=$$(mktemp "./.firebase-deploy-$(APP_ID)-XXXXXXXX.json"); \
	trap 'rm -f "$$tmp"' EXIT; \
	cp "$$cfg" "$$tmp"; \
	if grep -q '"target"' "$$tmp"; then \
		firebase deploy \
			--project "$(FIREBASE_PROJECT)" \
			--config "$$tmp" \
			--only "hosting:$(APP_ID)"; \
	else \
		firebase deploy \
			--project "$(FIREBASE_PROJECT)" \
			--config "$$tmp" \
			--only hosting; \
	fi; \
	$(MAKE) deploy-verify \
		HOST="$$resolved_site.web.app" \
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
	$(call assert_app)
	@$(MAKE) web TENANT_ID="$(TENANT_ID)" APP_ID="$(APP_ID)" APP_KEY="$(APP_ID)" APP_MODE="$(APP_MODE)" EXTRA="$(EXTRA)"
	@$(MAKE) deploy TENANT_ID="$(TENANT_ID)" APP_ID="$(APP_ID)" APP_KEY="$(APP_ID)" APP_MODE="$(APP_MODE)"

# ─────────────────────────────────────────────────────────────────────────────
# Web: many apps
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: web-all deploy-all release-web-all

web-all:
	$(call assert_apps)
	@for target in $(APP_TARGETS); do \
	  tenant="$${target%%:*}"; \
	  app="$${target#*:}"; \
	  [ "$$target" != "$$tenant" ] || { echo "❌ Invalid APP_TARGETS entry: $$target"; exit 2; }; \
	  $(MAKE) web TENANT_ID="$$tenant" APP_ID="$$app" APP_KEY="$$app" APP_MODE=tenant; \
	done

deploy-all:
	$(call assert_apps)
	@for target in $(APP_TARGETS); do \
	  tenant="$${target%%:*}"; \
	  app="$${target#*:}"; \
	  [ "$$target" != "$$tenant" ] || { echo "❌ Invalid APP_TARGETS entry: $$target"; exit 2; }; \
	  $(MAKE) deploy TENANT_ID="$$tenant" APP_ID="$$app" APP_KEY="$$app" APP_MODE=tenant; \
	done

release-web-all:
	$(call assert_apps)
	@for target in $(APP_TARGETS); do \
	  tenant="$${target%%:*}"; \
	  app="$${target#*:}"; \
	  [ "$$target" != "$$tenant" ] || { echo "❌ Invalid APP_TARGETS entry: $$target"; exit 2; }; \
	  $(MAKE) release-web TENANT_ID="$$tenant" APP_ID="$$app" APP_KEY="$$app" APP_MODE=tenant; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# HQ
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: run-hq run-web-hq web-hq deploy-hq release-web-hq

run-hq: LOAD_ENV=0
run-hq:
	@echo "🏢 Running HQ on '$(DEVICE)'…"
	flutter run \
	  -d "$(DEVICE)" \
	  -t "$(ENTRY)" \
	  $(HQ_DEFINES) \
	  $(EXTRA)

run-web-hq: LOAD_ENV=0
run-web-hq:
	@echo "🏢🌐 Running HQ on Chrome :$(WEB_PORT)…"
	./scripts/run_web_tenant.sh hq afyakit -- \
	  flutter run \
	    -d chrome \
	    --web-port="$(WEB_PORT)" \
	    $(WEB_RENDERER_RUN_FLAG) \
	    -t "$(ENTRY)" \
	    $(HQ_DEFINES) \
	    $(EXTRA)

web-hq: LOAD_ENV=0
web-hq: APP_MODE=hq
web-hq: APP_ID=$(HQ_APP_ID)
web-hq: TENANT_ID=$(HQ_TENANT_ID)
web-hq: HOST=$(HQ_HOST)
web-hq: APP_TITLE=AfyaKit HQ
web-hq: APP_DESCRIPTION=AfyaKit administration portal.
web-hq:
	$(call flutter_web_build,$(WEB_OUT_HQ),🏢🌐 Release build HQ → $(WEB_OUT_HQ),$(HQ_DEFINES),hq)

deploy-hq:
	@$(MAKE) web-verify \
	  APP_KEY="hq" \
	  APP_ID="$(HQ_APP_ID)" \
	  TENANT_ID="$(HQ_TENANT_ID)" \
	  WEB_OUT="$(WEB_OUT_HQ)"
	@echo "🚀 Deploy HQ hosting:$(HQ_SITE) from $(WEB_OUT_HQ)…"
	@cfg="$(HOSTING_CONFIG_DIR)/afyakit-hq.json"; \
	[ -f "$$cfg" ] || { \
	  echo "❌ Missing HQ Hosting config: $$cfg"; \
	  exit 2; \
	}; \
	site=$$(node -e ' \
	  const fs=require("fs"); \
	  const h=JSON.parse(fs.readFileSync(process.argv[1],"utf8")).hosting; \
	  if (!h || h.site!==process.argv[2] || h.target || h.public!==process.argv[3]) process.exit(2); \
	  console.log(h.site); \
	' "$$cfg" "$(HQ_SITE)" "$(WEB_OUT_HQ)") || { \
	  echo "❌ HQ Hosting config invalid: $$cfg"; \
	  exit 2; \
	}; \
	echo "   → $$cfg (site: $$site)"; \
	tmp=$$(mktemp "./.firebase-deploy-hq-XXXXXXXX.json"); \
	trap 'rm -f "$$tmp"' EXIT; \
	cp "$$cfg" "$$tmp"; \
	firebase deploy \
	  --project "$(FIREBASE_PROJECT)" \
	  --config "$$tmp" \
	  --only hosting; \
	$(MAKE) deploy-verify \
	  HOST="$$site.web.app" \
	  APP_TITLE="AfyaKit HQ"

release-web-hq: LOAD_ENV=0
release-web-hq:
	@$(MAKE) web-hq EXTRA="$(EXTRA)"
	@$(MAKE) deploy-hq
