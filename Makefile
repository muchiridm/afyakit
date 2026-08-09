# ─────────────────────────────────────────────────────────────────────────────
# AfyaKit multi-tenant Makefile
#
# Tenant:
#   make run-web dawapap
#   make run-android dawapap
#   make release-web dawapap
#
# HQ:
#   make run-hq
#   make run-web-hq
#   make release-web-hq
# ─────────────────────────────────────────────────────────────────────────────

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ─────────────────────────────────────────────────────────────────────────────
# Core
# ─────────────────────────────────────────────────────────────────────────────

ENTRY ?= lib/main.dart

# Allow: make <target> <tenant>
TENANT ?= $(word 2,$(MAKECMDGOALS))
ifneq ($(TENANT),)
  .PHONY: $(TENANT)
  $(TENANT): ; @:
endif

TENANTS ?=

EXTRA      ?=
USE_FLAVOR ?= 1
LOAD_ENV   ?= 1

# ─────────────────────────────────────────────────────────────────────────────
# Outputs / hosts
# ─────────────────────────────────────────────────────────────────────────────

WEB_OUT    ?= build/web
WEB_OUT_HQ ?= build/web-hq

HQ_TENANT ?= hq
HQ_SITE   ?= afyakit-hq
HQ_HOST   ?= admin.afyakit.app

HOST ?= $(if $(filter dawapap,$(TENANT)),www.dawapap.com,\
        $(if $(filter afyakit,$(TENANT)),www.afyakit.app,\
        $(if $(filter danabtmc,$(TENANT)),www.danabtmc.com,\
        $(if $(filter hq,$(TENANT)),$(HQ_HOST),))))

APP_TITLE ?= $(if $(filter dawapap,$(TENANT)),DawaPap Pharmacy,\
             $(if $(filter afyakit,$(TENANT)),AfyaKit,\
             $(if $(filter danabtmc,$(TENANT)),Dana B TMC,\
             $(if $(filter hq,$(TENANT)),AfyaKit HQ,AfyaKit))))

APP_DESCRIPTION ?= $(if $(filter dawapap,$(TENANT)),Your Pharmacy. Anywhere. Anytime.,\
                   $(if $(filter afyakit,$(TENANT)),Digital healthcare management made simple.,\
                   $(if $(filter danabtmc,$(TENANT)),Healthcare services and medical support.,\
                   AfyaKit healthcare platform.)))

APP_URL ?= $(if $(HOST),https://$(HOST)/,)

APP_IMAGE ?= $(if $(filter dawapap,$(TENANT)),\
https://firebasestorage.googleapis.com/v0/b/afyakit-api.firebasestorage.app/o/public%2Fdawapap%2Fbranding%2Fweb%2Ficon-512.png?alt=media,\
$(APP_URL)favicon.png)

HASH := \#
THEME_COLOR ?= $(if $(filter dawapap,$(TENANT)),$(HASH)00A86B,$(HASH)2196F3)

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

FLAVOR_FLAG := $(if $(filter 1 yes true,$(USE_FLAVOR)),$(if $(TENANT),--flavor $(TENANT),),)
TENANT_DEF  := $(if $(TENANT),--dart-define=TENANT=$(TENANT),)

HQ_DEFINES := --dart-define=APP=hq --dart-define=TENANT=$(HQ_TENANT)

# ─────────────────────────────────────────────────────────────────────────────
# Environment loader
# Order:
#   .env.<tenant>.web → .env.<tenant> → .env
# ─────────────────────────────────────────────────────────────────────────────

define resolve_env_file
$(strip $(shell \
  if [ "$(filter 1 yes true,$(LOAD_ENV))" = "1" ]; then \
    t="$(1)"; \
    if [ -n "$$t" ] && [ -f ".env.$$t.web" ]; then echo ".env.$$t.web"; \
    elif [ -n "$$t" ] && [ -f ".env.$$t" ]; then echo ".env.$$t"; \
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
        val=substr($$0, index($$0,"=")+1); \
        sub(/^[[:space:]]+|[[:space:]]+$$/, "", val); \
        if (key != "") printf "--dart-define=%s=%s ", key, val \
      }' "$$f"; \
  fi))
endef

ENV_FILE     := $(call resolve_env_file,$(TENANT))
DART_DEFINES := $(call defines_from_env,$(ENV_FILE))

define dart_defines_for_tenant
$(call defines_from_env,$(call resolve_env_file,$(1)))
endef

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
	  echo '❌ TENANTS is empty. Example: TENANTS="afyakit danabtmc dawapap" make $@'; \
	  exit 2; \
	fi
endef

# ─────────────────────────────────────────────────────────────────────────────
# Shared web build
# $(1) output dir
# $(2) label
# $(3) dart defines
# $(4) tenant used for web branding
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
	  TENANT="$(4)" \
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
	  TENANT="$(4)" \
	  WEB_OUT="$(1)"
endef

# ─────────────────────────────────────────────────────────────────────────────
# Help / diagnostics
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: help env-check devices doctor outdated pubget

help:
	@echo "Targets:"
	@echo "  run / run-android / run-web           — run one tenant"
	@echo "  run-web-all / run-android-all         — run many tenants"
	@echo "  web / deploy / release-web            — build/deploy one tenant"
	@echo "  web-all / deploy-all / release-web-all— build/deploy many tenants"
	@echo "  web-verify / deploy-verify            — local/live web checks"
	@echo "  run-hq / run-web-hq                   — run HQ"
	@echo "  web-hq / deploy-hq / release-web-hq   — build/deploy HQ"
	@echo ""
	@echo "Examples:"
	@echo "  make run-web dawapap"
	@echo "  make release-web dawapap"
	@echo '  TENANTS="afyakit danabtmc dawapap" make release-web-all'

env-check:
	@echo "TENANT=$(TENANT)"
	@echo "TENANTS=$(TENANTS)"
	@echo "ENV_FILE=$(ENV_FILE)"
	@echo "DART_DEFINES=$(DART_DEFINES)"
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
# Run: one tenant
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: run run-android run-web

run: run-android

run-web:
	@$(call assert_tenant)
	@echo "🌐 Running $(TENANT) on Chrome :$(WEB_PORT)…"
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
	if [ -z "$$ANDROID" ]; then \
	  echo "❌ No Android device/emulator found."; \
	  exit 2; \
	fi; \
	echo "🤖 Running $(TENANT) on '$$ANDROID'…"; \
	flutter run \
	  -d "$$ANDROID" \
	  $(FLAVOR_FLAG) \
	  -t "$(ENTRY)" \
	  $(EXTRA) \
	  $(DART_DEFINES) \
	  $(TENANT_DEF)

# ─────────────────────────────────────────────────────────────────────────────
# Run: many tenants
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: run-web-all run-android-all

run-web-all:
	@$(call assert_tenants)
	@PORT=$(WEB_PORT_BASE); \
	for t in $(TENANTS); do \
	  defs='$(call dart_defines_for_tenant,$$t)'; \
	  echo "🌐 Launch $$t on Chrome :$$PORT…"; \
	  (flutter run \
	    -d chrome \
	    --web-port="$$PORT" \
	    $(WEB_RENDERER_RUN_FLAG) \
	    -t "$(ENTRY)" \
	    $(EXTRA) \
	    $$defs \
	    --dart-define=TENANT=$$t &) ; \
	  PORT=$$((PORT + 1)); \
	done; \
	echo "ℹ️ Started $(words $(TENANTS)) Chrome debuggers."

run-android-all:
	@$(call assert_tenants)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then \
	  echo "❌ No Android device/emulator found."; \
	  exit 2; \
	fi; \
	for t in $(TENANTS); do \
	  defs='$(call dart_defines_for_tenant,$$t)'; \
	  flavor=""; \
	  if [ "$(filter 1 yes true,$(USE_FLAVOR))" = "1" ]; then flavor="--flavor $$t"; fi; \
	  echo "🤖 Launch $$t on '$$ANDROID'…"; \
	  flutter run \
	    -d "$$ANDROID" \
	    $$flavor \
	    -t "$(ENTRY)" \
	    $(EXTRA) \
	    $$defs \
	    --dart-define=TENANT=$$t; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# Web: build / branding / verification
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: web web-brand web-strip-service-worker web-verify
.PHONY: web-clean flutter-clean

web:
	@$(call assert_tenant)
	$(call flutter_web_build,$(WEB_OUT),🌐 Release build: $(TENANT) → $(WEB_OUT),$(DART_DEFINES) $(TENANT_DEF),$(TENANT))

web-brand:
	@echo "🎨 Applying web branding for $(TENANT)…"
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
	@tenant_dir="web/tenants/$(TENANT)"; \
	if [ -d "$$tenant_dir" ]; then \
	  echo "🎨 Overlaying $$tenant_dir → $(WEB_OUT)"; \
	  [ ! -f "$$tenant_dir/favicon.png" ] || cp "$$tenant_dir/favicon.png" "$(WEB_OUT)/favicon.png"; \
	  if [ -f "$$tenant_dir/manifest.webmanifest" ]; then \
	    cp "$$tenant_dir/manifest.webmanifest" "$(WEB_OUT)/manifest.webmanifest"; \
	  elif [ -f "$$tenant_dir/manifest.json" ]; then \
	    cp "$$tenant_dir/manifest.json" "$(WEB_OUT)/manifest.webmanifest"; \
	  fi; \
	  if [ -d "$$tenant_dir/icons" ]; then \
	    mkdir -p "$(WEB_OUT)/icons"; \
	    cp -a "$$tenant_dir/icons/." "$(WEB_OUT)/icons/"; \
	  fi; \
	else \
	  echo "ℹ️ No tenant web overlay at $$tenant_dir; using defaults."; \
	fi
	@echo "   title: $(APP_TITLE)"
	@echo "   URL:   $(APP_URL)"
	@echo "   image: $(APP_IMAGE)"

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
	@$(call assert_tenant)
	@$(MAKE) web-verify TENANT="$(TENANT)" WEB_OUT="$(WEB_OUT)"
	@echo "🚀 Deploy hosting:$(TENANT) from $(WEB_OUT)…"
	@cfg="firebase.$(TENANT).json"; \
	[ -f "$$cfg" ] || cfg="firebase.json"; \
	[ -f "$$cfg" ] || { echo "❌ Missing Firebase config for $(TENANT)."; exit 2; }; \
	echo "   → using $$cfg"; \
	firebase deploy --config "$$cfg" --only hosting:$(TENANT)
	@$(MAKE) deploy-verify \
	  TENANT="$(TENANT)" \
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
	@$(call assert_tenant)
	@$(MAKE) web TENANT="$(TENANT)" EXTRA="$(EXTRA)"
	@$(MAKE) deploy TENANT="$(TENANT)"

# ─────────────────────────────────────────────────────────────────────────────
# Web: many tenants
# ─────────────────────────────────────────────────────────────────────────────

.PHONY: web-all deploy-all release-web-all

web-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do $(MAKE) web TENANT="$$t"; done

deploy-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do $(MAKE) deploy TENANT="$$t"; done

release-web-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do $(MAKE) release-web TENANT="$$t"; done

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
web-hq:
	$(call flutter_web_build,$(WEB_OUT_HQ),🏢🌐 Release build HQ → $(WEB_OUT_HQ),$(HQ_DEFINES),$(HQ_TENANT))

deploy-hq:
	@$(MAKE) web-verify TENANT="$(HQ_TENANT)" WEB_OUT="$(WEB_OUT_HQ)"
	@echo "🚀 Deploy HQ hosting:$(HQ_SITE) from $(WEB_OUT_HQ)…"
	@test -f firebase.hq.json || { echo "❌ Missing firebase.hq.json"; exit 2; }
	firebase deploy --config firebase.hq.json --only hosting:$(HQ_SITE)
	@$(MAKE) deploy-verify \
	  TENANT="$(HQ_TENANT)" \
	  HOST="$(HQ_HOST)" \
	  APP_TITLE="AfyaKit HQ"

release-web-hq: LOAD_ENV=0
release-web-hq:
	@$(MAKE) web-hq EXTRA="$(EXTRA)"
	@$(MAKE) deploy-hq