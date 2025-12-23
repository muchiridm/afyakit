# ─────────────────────────────────────────────────────────────────────────────
# AfyaKit multi-tenant Makefile (Tenant + HQ via APP mode)
#   - Tenant mode: lib/main.dart + --dart-define=TENANT=<slug>
#   - HQ mode:     lib/main.dart + --dart-define=APP=hq
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
EXTRA        ?=
USE_FLAVOR   ?= 1
WEB_PORT_BASE?= 5000
TENANTS      ?=

# Flavor is only meaningful for device builds; web ignores flavors in your workflow.
FLAVOR_FLAG  := $(if $(filter 1 yes true,$(USE_FLAVOR)),$(if $(TENANT),--flavor $(TENANT),),)
TENANT_DEF   := $(if $(TENANT),--dart-define=TENANT=$(TENANT),)
APP_DEF_HQ   := --dart-define=APP=hq

# ─────────────────────────────────────────────────────────────────────────────
# .env loader (optional; safe when absent)
#  - looks for .env.<tenant>.web, .env.<tenant>, .env
#  - if none exist → DART_DEFINES becomes empty (no-op)
# ─────────────────────────────────────────────────────────────────────────────
ENV_FILE :=
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
	@echo "DART_DEFINES=$(DART_DEFINES)"
	@echo "TENANT=$(TENANT)"
	@echo "TENANTS=$(TENANTS)"

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
	@echo "  run-hq / run-hq-web / web-hq / deploy-hq"
	@echo ""
	@echo "Notes:"
	@echo "  - Tenant mode uses:  --dart-define=TENANT=<slug>"
	@echo "  - HQ mode uses:      --dart-define=APP=hq"
	@echo "  - Single web runs pinned to Chrome :5000"
devices:;  flutter devices
doctor:;   flutter doctor -v
outdated:; flutter pub outdated || true
pubget:;   flutter pub get

# ─────────────────────────────────────────────────────────────────────────────
# Tenant app: run (ONE)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run run-android run-web

# run → Android/emulator
run:
	@$(call assert_tenant)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	echo "🤖 Running $(TENANT) on '$$ANDROID'…"; \
	flutter run -d $$ANDROID $(FLAVOR_FLAG) -t $(ENTRY) $(TENANT_DEF) $(EXTRA) $(DART_DEFINES)

# run-web → Chrome fixed to :5000
run-web:
	@$(call assert_tenant)
	@echo "🌐 Running (web) $(TENANT) on Chrome :5000 …"
	flutter run -d chrome --web-port=5000 -t $(ENTRY) $(TENANT_DEF) $(EXTRA) $(DART_DEFINES)

# run-android → explicit Android device selection
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
	  (flutter run -d chrome -t $(ENTRY) --dart-define=TENANT=$$t $(EXTRA) $(DART_DEFINES) --web-port=$${PORT} &) ; \
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
.PHONY: web deploy release-web

web:
	@$(call assert_tenant)
	@echo "🌐 Building web bundle for tenant '$(TENANT)' → $(WEB_OUT)…"
	flutter build web --release \
	  -t $(ENTRY) \
	  -o $(WEB_OUT) \
	  $(TENANT_DEF) \
	  $(EXTRA) \
	  $(DART_DEFINES)

deploy:
	@$(call assert_tenant)
	@test -d "$(WEB_OUT)" || (echo "❌ Missing $(WEB_OUT) — run 'make web <tenant>' first." && exit 2)
	@echo "🚀 Deploy hosting:$(TENANT) from $(WEB_OUT)…"
	@cfg="firebase.$(TENANT).json"; \
	if [ ! -f "$$cfg" ]; then \
	  if [ "$(TENANT)" = "$(HQ_SITE)" ] && [ -f "firebase.hq.json" ]; then \
	    cfg="firebase.hq.json"; \
	  else \
	    cfg="firebase.json"; \
	  fi; \
	fi; \
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
	  echo "🌐 Building $$t → $(WEB_OUT)…"; \
	  flutter build web --release \
	    -t $(ENTRY) \
	    -o $(WEB_OUT) \
	    --dart-define=TENANT=$$t \
	    $(EXTRA) \
	    $(DART_DEFINES); \
	done

deploy-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do \
	  echo "🚀 Deploy $$t from $(WEB_OUT)…"; \
	  cfg="firebase.$$t.json"; \
	  if [ ! -f "$$cfg" ]; then cfg="firebase.json"; fi; \
	  echo "   → using $$cfg"; \
	  firebase deploy --config "$$cfg" --only hosting:$$t; \
	done

release-web-all:
	@$(call assert_tenants)
	@$(MAKE) web-all TENANTS="$(TENANTS)" EXTRA="$(EXTRA)" DART_DEFINES="$(DART_DEFINES)"
	@$(MAKE) deploy-all TENANTS="$(TENANTS)"

# ─────────────────────────────────────────────────────────────────────────────
# HQ app (same entry, APP=hq)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run-hq run-hq-web web-hq deploy-hq release-web-hq

run-hq:
	@echo "🏢 Running HQ on '$(DEVICE)'…"
	flutter run -d $(DEVICE) -t $(ENTRY) $(APP_DEF_HQ) $(EXTRA) $(DART_DEFINES)

run-hq-web:
	@echo "🏢🌐 Running HQ on Chrome :5000 …"
	flutter run -d chrome --web-port=5000 -t $(ENTRY) $(APP_DEF_HQ) $(EXTRA) $(DART_DEFINES)

web-hq:
	@echo "🏢🌐 Building HQ web bundle → $(WEB_OUT_HQ)…"
	flutter build web --release \
	  -t $(ENTRY) \
	  -o $(WEB_OUT_HQ) \
	  $(APP_DEF_HQ) \
	  $(EXTRA) \
	  $(DART_DEFINES)

deploy-hq:
	@test -d "$(WEB_OUT_HQ)" || (echo "❌ Missing $(WEB_OUT_HQ) — run 'make web-hq' first." && exit 2)
	@echo "🚀 Deploy HQ hosting:$(HQ_SITE) from $(WEB_OUT_HQ)…"
	@cfg="firebase.$(HQ_SITE).json"; \
	if [ ! -f "$$cfg" ]; then \
	  if [ -f "firebase.hq.json" ]; then cfg="firebase.hq.json"; else cfg="firebase.json"; fi; \
	fi; \
	echo "   → using $$cfg"; \
	firebase deploy --config "$$cfg" --only hosting:$(HQ_SITE)

release-web-hq:
	@$(MAKE) web-hq EXTRA="$(EXTRA)" DART_DEFINES="$(DART_DEFINES)"
	@$(MAKE) deploy-hq
