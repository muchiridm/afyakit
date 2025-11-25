# ─────────────────────────────────────────────────────────────────────────────
# AfyaKit / DawaPap multi-tenant Makefile
# ─────────────────────────────────────────────────────────────────────────────
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

TENANT ?= $(word 2,$(MAKECMDGOALS))
ifneq ($(TENANT),)
  .PHONY: $(TENANT)
  $(TENANT): ; @:
endif

# we still keep this, but we won't use it for web runs anymore
DEVICE ?= $(shell flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}')
ifeq ($(strip $(DEVICE)),)
  DEVICE := chrome
endif

ENTRY_TENANT ?= lib/main.dart
ENTRY_HQ     ?= lib/main_hq.dart

WEB_OUT      ?= build/web
WEB_OUT_HQ   ?= build/web-hq

HQ_SITE      ?= afyakit-hq
EXTRA        ?=
USE_FLAVOR   ?= 1
WEB_PORT_BASE?= 5000
TENANTS ?=

FLAVOR_FLAG  := $(if $(filter 1 yes true,$(USE_FLAVOR)),$(if $(TENANT),--flavor $(TENANT),),)
TENANT_DEF   := $(if $(TENANT),--dart-define=TENANT=$(TENANT),)

# ─────────────────────────────────────────────────────────────────────────────
# .env loader (unchanged)
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

# ─────────────────────────────────────────────────────────────────────────────
# Guards (unchanged)
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
# Help (unchanged)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help devices doctor outdated pubget
help:
	@echo "Targets:"
	@echo "  run / run-web / run-android     — run a single tenant"
	@echo "  web / deploy / release-web      — build & deploy ONE tenant"
	@echo "  web-all / deploy-all            — build once, deploy many"
	@echo "  run-hq / run-hq-web / web-hq / deploy-hq"
	@echo ""
	@echo "Local web runs are now FIXED to: chrome --web-port=5000"
devices:;  flutter devices
doctor:;   flutter doctor -v
outdated:; flutter pub outdated || true
pubget:;   flutter pub get

# ─────────────────────────────────────────────────────────────────────────────
# Tenant app: run (one)  ← FORCE CHROME:5000
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run run-android run-web
# run → Android/emulator
run:
	@$(call assert_tenant)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	echo "🤖 Running $(TENANT) on '$$ANDROID'…"; \
	flutter run -d $$ANDROID $(FLAVOR_FLAG) -t $(ENTRY_TENANT) $(TENANT_DEF) $(EXTRA) $(DART_DEFINES)

run-web:
	@$(call assert_tenant)
	@echo "🌐 Running (web) $(TENANT) on Chrome :5000 …"
	flutter run -d chrome --web-port=5000 -t $(ENTRY_TENANT) $(TENANT_DEF) $(EXTRA) $(DART_DEFINES)

# keep Android one real Android
run-android:
	@$(call assert_tenant)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	echo "🤖 Running $(TENANT) on '$$ANDROID'…"; \
	flutter run -d $$ANDROID $(FLAVOR_FLAG) -t $(ENTRY_TENANT) $(TENANT_DEF) $(EXTRA) $(DART_DEFINES)

# ─────────────────────────────────────────────────────────────────────────────
# Web build / deploy (unchanged from your last version)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: web deploy release-web
web:
	@$(call assert_tenant)
	@echo "🌐 Building web bundle for tenant '$(TENANT)' → $(WEB_OUT)…"
	flutter build web --release \
	  -t $(ENTRY_TENANT) \
	  -o $(WEB_OUT) \
	  $(TENANT_DEF) \
	  $(EXTRA) \
	  $(DART_DEFINES)

deploy:
	@$(call assert_tenant)
	@test -d "$(WEB_OUT)" || (echo "❌ Missing $(WEB_OUT) — run 'make web' first." && exit 2)
	@echo "🚀 Deploy hosting:$(TENANT) from $(WEB_OUT)…"
	@cfg="firebase.$(TENANT).json"; \
	if [ ! -f "$$cfg" ]; then \
	  if [ "$(TENANT)" = "afyakit-hq" ] && [ -f "firebase.hq.json" ]; then \
	    cfg="firebase.hq.json"; \
	  else \
	    cfg="firebase.json"; \
	  fi; \
	fi; \
	echo "   → using $$cfg"; \
	firebase deploy --config "$$cfg" --only hosting:$(TENANT)

release-web:
	@$(call assert_tenant)
	@$(MAKE) web TENANT=$(TENANT) ENTRY_TENANT=$(ENTRY_TENANT) EXTRA="$(EXTRA)" DART_DEFINES="$(DART_DEFINES)"
	@$(MAKE) deploy TENANT=$(TENANT)

# ─────────────────────────────────────────────────────────────────────────────
# Matrix runs
# ─────────────────────────────────────────────────────────────────────────────
run-web-all:
	@$(call assert_tenants)
	@PORT=$(WEB_PORT_BASE); \
	for t in $(TENANTS); do \
	  echo "🌐 Launch $$t on Chrome :$${PORT} …"; \
	  (flutter run -d chrome -t $(ENTRY_TENANT) --dart-define=TENANT=$$t $(EXTRA) $(DART_DEFINES) --web-port=$${PORT} &) ; \
	  PORT=$$((PORT+1)); \
	done; \
	echo "ℹ️ Started $(words $(TENANTS)) Chrome debuggers on ports $(WEB_PORT_BASE)..$$((PORT-1))."

# ─────────────────────────────────────────────────────────────────────────────
# HQ app  ← force 5000 too
# ─────────────────────────────────────────────────────────────────────────────
run-hq:
	@echo "🏢 Running HQ on '$(DEVICE)'…"
	flutter run -d $(DEVICE) -t $(ENTRY_HQ) $(EXTRA) $(DART_DEFINES)

run-hq-web:
	@echo "🏢🌐 Running HQ on Chrome :5000 …"
	flutter run -d chrome --web-port=5000 -t $(ENTRY_HQ) $(EXTRA) $(DART_DEFINES)
