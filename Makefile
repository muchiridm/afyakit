# ─────────────────────────────────────────────────────────────────────────────
# AfyaKit multi-tenant Makefile (Tenant + HQ via APP mode)
#   - Tenant mode: lib/main.dart + --dart-define=TENANT=<slug>
#   - HQ mode:     lib/main.dart + --dart-define=APP=hq + --dart-define=TENANT=hq
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

# Extras
EXTRA         ?=
USE_FLAVOR    ?= 1
WEB_PORT_BASE ?= 5000
WEB_PORT      ?= $(WEB_PORT_BASE)
TENANTS       ?=

# ✅ Web release icon fix (Material Icons tree-shaking)
WEB_ICON_FLAGS ?= --no-tree-shake-icons

# ✅ Optional renderer forcing (ONLY when supported by your Flutter)
# Some Flutter versions support --web-renderer on `run` but not on `build`.
# We'll detect support and only apply when available.
WEB_RENDERER ?= canvaskit
HAS_WEB_RENDERER_BUILD := $(shell flutter build web -h 2>/dev/null | grep -q -- '--web-renderer' && echo 1 || echo 0)
WEB_RENDERER_BUILD_FLAG := $(if $(filter 1,$(HAS_WEB_RENDERER_BUILD)),--web-renderer=$(WEB_RENDERER),)

# For `flutter run`, the flag is more commonly supported
HAS_WEB_RENDERER_RUN := $(shell flutter run -h 2>/dev/null | grep -q -- '--web-renderer' && echo 1 || echo 0)
WEB_RENDERER_RUN_FLAG := $(if $(filter 1,$(HAS_WEB_RENDERER_RUN)),--web-renderer=$(WEB_RENDERER),)

# Flavor is only meaningful for device builds; web ignores flavors in your workflow.
FLAVOR_FLAG  := $(if $(filter 1 yes true,$(USE_FLAVOR)),$(if $(TENANT),--flavor $(TENANT),),)
TENANT_DEF   := $(if $(TENANT),--dart-define=TENANT=$(TENANT),)

# HQ must be explicit (your Dart boot now requires TENANT in HQ mode)
HQ_TENANT     ?= hq
TENANT_DEF_HQ := --dart-define=TENANT=$(HQ_TENANT)
APP_DEF_HQ    := --dart-define=APP=hq
HQ_DEFINES    := $(APP_DEF_HQ) $(TENANT_DEF_HQ)

# ─────────────────────────────────────────────────────────────────────────────
# .env loader (optional; safe when absent)
#  - looks for .env.<tenant>.web, .env.<tenant>, .env
#  - if none exist → DART_DEFINES becomes empty (no-op)
#
# NOTE:
#  - HQ targets set LOAD_ENV=0 to avoid leaking tenant/dev defines into HQ.
# ─────────────────────────────────────────────────────────────────────────────
LOAD_ENV ?= 1

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

DART_DEFINES := $(shell \
  if [ -n "$(ENV_FILE)" ]; then \
    awk 'BEGIN{FS="="} \
      /^[[:space:]]*#/ {next} \
      /^[[:space:]]*$$/ {next} \
      {key=$$1; sub(/^[[:space:]]+|[[:space:]]+$$/, "", key); \
       val=substr($$0, index($$0,$$2)); \
       sub(/^[[:space:]]+|[[:space:]]+$$/, "", val); \
       printf "--dart-define=%s=%s ", key, val}' $(ENV_FILE); \
  fi)

.PHONY: env-check
env-check:
	@echo "ENV_FILE=$(ENV_FILE)"
	@echo "LOAD_ENV=$(LOAD_ENV)"
	@echo "DART_DEFINES=$(DART_DEFINES)"
	@echo "TENANT=$(TENANT)"
	@echo "TENANTS=$(TENANTS)"
	@echo "HQ_TENANT=$(HQ_TENANT)"
	@echo "HQ_DEFINES=$(HQ_DEFINES)"
	@echo "WEB_PORT=$(WEB_PORT)"
	@echo "WEB_ICON_FLAGS=$(WEB_ICON_FLAGS)"
	@echo "HAS_WEB_RENDERER_BUILD=$(HAS_WEB_RENDERER_BUILD)"
	@echo "WEB_RENDERER_BUILD_FLAG=$(WEB_RENDERER_BUILD_FLAG)"
	@echo "HAS_WEB_RENDERER_RUN=$(HAS_WEB_RENDERER_RUN)"
	@echo "WEB_RENDERER_RUN_FLAG=$(WEB_RENDERER_RUN_FLAG)"

# ─────────────────────────────────────────────────────────────────────────────
# Guards
# ─────────────────────────────────────────────────────────────────────────────
define assert_tenant
	@if [ -z "$(TENANT)" ]; then \
	  echo "❌ Missing tenant. Usage: make $@ <tenant>"; \
	  exit 2; \
	fi
endef

define assert_tenants
	@if [ -z "$(TENANTS)" ]; then \
	  echo "❌ TENANTS is empty. Example: TENANTS=\"afyakit danabtmc dawapap\" make $@"; \
	  exit 2; \
	fi
endef

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help devices doctor outdated pubget
help:
	@echo "Targets:"
	@echo "  run / run-android / run-web           — run ONE tenant"
	@echo "  run-web-all / run-android-all         — run MANY tenants"
	@echo "  web / deploy / release-web            — build & deploy ONE tenant"
	@echo "  web-all / deploy-all / release-web-all— build/deploy MANY tenants"
	@echo "  run-hq / run-web-hq / web-hq / deploy-hq"
	@echo ""
	@echo "Notes:"
	@echo "  - Tenant mode uses:  --dart-define=TENANT=<slug>"
	@echo "  - HQ mode uses:      --dart-define=APP=hq --dart-define=TENANT=$(HQ_TENANT)"
	@echo "  - Web release uses:  $(WEB_ICON_FLAGS)"
	@echo "  - Web renderer flag is conditional based on your Flutter SDK."
devices:;  flutter devices
doctor:;   flutter doctor -v
outdated:; flutter pub outdated || true
pubget:;   flutter pub get

# ─────────────────────────────────────────────────────────────────────────────
# Tenant app: run (ONE)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run run-android run-web

run:
	@$(call assert_tenant)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	echo "🤖 Running $(TENANT) on '$$ANDROID'…"; \
	flutter run -d $$ANDROID $(FLAVOR_FLAG) -t $(ENTRY) $(TENANT_DEF) $(EXTRA) $(DART_DEFINES)

run-web:
	@$(call assert_tenant)
	@echo "🌐 Running (web) $(TENANT) on Chrome :$(WEB_PORT) …"
	flutter run -d chrome --web-port=$(WEB_PORT) $(WEB_RENDERER_RUN_FLAG) -t $(ENTRY) $(TENANT_DEF) $(EXTRA) $(DART_DEFINES)

run-android:
	@$(call assert_tenant)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	echo "🤖 Running $(TENANT) on '$$ANDROID'…"; \
	flutter run -d $$ANDROID $(FLAVOR_FLAG) -t $(ENTRY) $(TENANT_DEF) $(EXTRA) $(DART_DEFINES)

# ─────────────────────────────────────────────────────────────────────────────
# Matrix runs
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run-web-all run-android-all

run-web-all:
	@$(call assert_tenants)
	@PORT=$(WEB_PORT_BASE); \
	for t in $(TENANTS); do \
	  echo "🌐 Launch $$t on Chrome :$${PORT} …"; \
	  (flutter run -d chrome -t $(ENTRY) --dart-define=TENANT=$$t $(WEB_RENDERER_RUN_FLAG) $(EXTRA) $(DART_DEFINES) --web-port=$${PORT} &) ; \
	  PORT=$$((PORT+1)); \
	done; \
	echo "ℹ️ Started $(words $(TENANTS)) Chrome debuggers on ports $(WEB_PORT_BASE)..$$((PORT-1))."

run-android-all:
	@$(call assert_tenants)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	for t in $(TENANTS); do \
	  echo "🤖 Launch $$t on '$$ANDROID'…"; \
	  flutter run -d $$ANDROID $(FLAVOR_FLAG) -t $(ENTRY) --dart-define=TENANT=$$t $(EXTRA) $(DART_DEFINES); \
	done

# ─────────────────────────────────────────────────────────────────────────────
# Web build / deploy (ONE tenant)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: web deploy release-web web-verify web-clean

web:
	@$(call assert_tenant)
	@echo "🌐 Release build: $(TENANT) → $(WEB_OUT)"
	flutter build web --release $(WEB_ICON_FLAGS) $(WEB_RENDERER_BUILD_FLAG) \
	  -t $(ENTRY) \
	  -o $(WEB_OUT) \
	  $(TENANT_DEF) \
	  $(EXTRA) \
	  $(DART_DEFINES)
	@$(MAKE) web-verify TENANT=$(TENANT)

web-verify:
	@echo "🔎 Verifying web output…"
	@test -d "$(WEB_OUT)" || (echo "❌ Missing $(WEB_OUT)"; exit 2)
	@ls -lh "$(WEB_OUT)/assets/fonts" 2>/dev/null || true
	@if [ -f "$(WEB_OUT)/assets/fonts/MaterialIcons-Regular.otf" ]; then \
	  echo "✅ MaterialIcons-Regular.otf present:"; \
	  ls -lh "$(WEB_OUT)/assets/fonts/MaterialIcons-Regular.otf"; \
	else \
	  echo "⚠️ MaterialIcons-Regular.otf not found (this can be OK on some Flutter versions)"; \
	fi

web-clean:
	@echo "🧹 Cleaning web output…"
	rm -rf "$(WEB_OUT)" "$(WEB_OUT_HQ)"
	flutter clean

deploy:
	@$(call assert_tenant)
	@test -d "$(WEB_OUT)" || (echo "❌ Missing $(WEB_OUT) — run 'make web <tenant>' first." && exit 2)
	@echo "🚀 Deploy hosting:$(TENANT) from $(WEB_OUT)…"
	@cfg="firebase.$(TENANT).json"; \
	if [ ! -f "$$cfg" ]; then cfg="firebase.json"; fi; \
	echo "   → using $$cfg"; \
	firebase deploy --config "$$cfg" --only hosting:$(TENANT)

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
	flutter run -d chrome --web-port=$(WEB_PORT) $(WEB_RENDERER_RUN_FLAG) -t $(ENTRY) $(HQ_DEFINES) $(EXTRA)

web-hq: LOAD_ENV=0
web-hq:
	@echo "🏢🌐 Release build HQ → $(WEB_OUT_HQ)…"
	flutter build web --release $(WEB_ICON_FLAGS) $(WEB_RENDERER_BUILD_FLAG) \
	  -t $(ENTRY) \
	  -o $(WEB_OUT_HQ) \
	  $(HQ_DEFINES) \
	  $(EXTRA)

deploy-hq:
	@test -d "$(WEB_OUT_HQ)" || (echo "❌ Missing $(WEB_OUT_HQ) — run 'make web-hq' first." && exit 2)
	@echo "🚀 Deploy HQ hosting:$(HQ_SITE) from $(WEB_OUT_HQ)…"
	@cfg="firebase.hq.json"; \
	if [ ! -f "$$cfg" ]; then \
	  echo "❌ Missing $$cfg (expected in repo root)."; \
	  exit 2; \
	fi; \
	echo "   → using $$cfg"; \
	firebase deploy --config "$$cfg" --only hosting:$(HQ_SITE)

release-web-hq: LOAD_ENV=0
release-web-hq:
	@$(MAKE) web-hq EXTRA="$(EXTRA)"
	@$(MAKE) deploy-hq
