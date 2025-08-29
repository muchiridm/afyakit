# ─────────────────────────────────────────────────────────────────────────────
# KISS Makefile: dynamic tenants, run on Android or Chrome, build+deploy web.
# Usage examples:
#   make run afyakit
#   make run-web danabtmc
#   make web
#   make deploy afyakit
#   make release-web afyakit
# Overrides:
#   DEVICE=<id>         e.g. DEVICE=sdk_gphone64_x86_64
#   ENTRY=<path.dart>   default: lib/main_dynamic.dart
#   EXTRA="..."         extra flutter args (e.g. --debug)
# ─────────────────────────────────────────────────────────────────────────────

# TENANT: support "make <target> <tenant>" or TENANT=<slug>
TENANT ?= $(word 2,$(MAKECMDGOALS))

# Swallow the trailing "<tenant>" so make doesn't try to build that target
ifneq ($(TENANT),)
  .PHONY: $(TENANT)
  $(TENANT): ; @:
endif

# Auto-pick first Android device; fallback to chrome
DEVICE ?= $(shell flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}')
ifeq ($(strip $(DEVICE)),)
  DEVICE := chrome
endif

ENTRY ?= lib/main_dynamic.dart
WEB_OUT := build/web
EXTRA ?=

define assert_tenant
	@if [ -z "$(TENANT)" ]; then \
	  echo "❌ Missing tenant. Usage: make $(firstword $(MAKECMDGOALS)) <tenant>"; \
	  exit 2; \
	fi
endef

# ─────────────────────────────────────────────────────────────────────────────
# Help & devices
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help devices
help:
	@echo "Usage:"
	@echo "  make run <tenant>         # Run on Android (auto) or chrome fallback"
	@echo "  make run-web <tenant>     # Run on Chrome"
	@echo "  make web                  # Build ONE shared web bundle into build/web"
	@echo "  make deploy <tenant>      # Deploy hosting:<tenant> from build/web"
	@echo "  make release-web <tenant> # Build web + deploy to tenant"
	@echo ""
	@echo "Vars: DEVICE=<id>, ENTRY=$(ENTRY), EXTRA='--debug …'"
devices:
	flutter devices

# ─────────────────────────────────────────────────────────────────────────────
# Run
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run run-web
run:
	@$(call assert_tenant)
	@echo "▶️  Running $(TENANT) on '$(DEVICE)'…"
	flutter run -d $(DEVICE) --flavor $(TENANT) -t $(ENTRY) --dart-define=TENANT=$(TENANT) $(EXTRA)

run-web:
	@$(call assert_tenant)
	@echo "🌐 Running (web) $(TENANT) on Chrome…"
	flutter run -d chrome -t $(ENTRY) --dart-define=TENANT=$(TENANT) $(EXTRA)

# ─────────────────────────────────────────────────────────────────────────────
# Web build / deploy (ONE shared build)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: web deploy release-web
web:
	@echo "🌐 Building ONE shared web bundle into $(WEB_OUT)…"
	flutter build web --release -t $(ENTRY) --output $(WEB_OUT) $(EXTRA)

deploy:
	@$(call assert_tenant)
	@test -d "$(WEB_OUT)" || (echo "❌ Missing $(WEB_OUT) — run 'make web' first." && exit 2)
	@echo "🚀 Deploying hosting:$(TENANT) from $(WEB_OUT)…"
	firebase deploy --only hosting:$(TENANT)

release-web:
	@$(call assert_tenant)
	@$(MAKE) web ENTRY=$(ENTRY) EXTRA=$(EXTRA)
	@$(MAKE) deploy TENANT=$(TENANT)

# ─────────────────────────────────────────────────────────────────────────────
# Clean
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	flutter clean
	rm -rf build/web
