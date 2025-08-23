# ─────────────────────────────────────────────────────────────────────────────
# Dynamic Tenants
#   - Tenants are read from a local ".tenants" file (one per line).
#   - If the file doesn't exist, we fall back to a small default list.
#   - You can manage the list via: add-tenant / remove-tenant / print-tenants
# ─────────────────────────────────────────────────────────────────────────────

TENANTS_FILE := .tenants

# Fallback list if no .tenants file exists yet
DEFAULT_TENANTS := afyakit danabtmc dawapap

# Load tenants from file (trim empty lines). Otherwise use defaults.
ifneq ("$(wildcard $(TENANTS_FILE))","")
  TENANTS := $(shell awk 'NF' $(TENANTS_FILE))
else
  TENANTS := $(DEFAULT_TENANTS)
endif

# Allow passing TENANT explicitly or infer it from "make <target> <tenant>"
TENANT_REQ_TARGETS := run run-web web deploy release-web apk aab
ifneq (,$(filter $(firstword $(MAKECMDGOALS)),$(TENANT_REQ_TARGETS)))
  TENANT ?= $(word 2,$(MAKECMDGOALS))
endif

# If not provided in the two-word form, fall back to the last goal
TENANT ?= $(lastword $(MAKECMDGOALS))

# Swallow the trailing "<tenant>" token so make doesn't try to build a target
# named after the tenant. For known tenants:
.PHONY: $(TENANTS)
$(TENANTS): ; @:

# For ad-hoc tenants when ALLOW_ANY_TENANT=1, swallow that token too
ifeq ($(ALLOW_ANY_TENANT),1)
  ifneq ($(TENANT),)
    .PHONY: $(TENANT)
    $(TENANT): ; @:
  endif
endif

# ─────────────────────────────────────────────────────────────────────────────
# Device selection (auto-pick first Android; fallback to chrome)
# Override: DEVICE=sdk_gphone64_x86_64
# ─────────────────────────────────────────────────────────────────────────────
DEVICE ?= $(shell flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}')
ifeq ($(strip $(DEVICE)),)
  DEVICE := chrome
endif

# Extra args passthrough to flutter commands
EXTRA ?=

# Web build output base
WEB_OUT := build

# ─────────────────────────────────────────────────────────────────────────────
# Internal: assertion helpers
# ─────────────────────────────────────────────────────────────────────────────
define assert_tenant
	@if [ -z "$(TENANT)" ]; then \
		echo "❌ Missing tenant. Usage: make $(firstword $(MAKECMDGOALS)) <tenant>"; \
		exit 2; \
	fi; \
	if [ "$(ALLOW_ANY_TENANT)" = "1" ]; then \
		exit 0; \
	fi; \
	if ! printf "%s\n" $(TENANTS) | grep -qx "$(TENANT)"; then \
		echo "❌ Unknown tenant '$(TENANT)'. Add it with 'make add-tenant NAME=$(TENANT)'"; \
		echo "   Known: $(TENANTS)"; \
		echo "   Or bypass the check: ALLOW_ANY_TENANT=1 make $(firstword $(MAKECMDGOALS)) $(TENANT)"; \
		exit 2; \
	fi
endef

# ─────────────────────────────────────────────────────────────────────────────
# Help & devices
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help devices print-tenants add-tenant remove-tenant
help:
	@echo "Usage:"
	@echo "  make run <tenant>           # Run (auto Android device or chrome fallback)"
	@echo "  make run-web <tenant>       # Run on chrome"
	@echo "  make web <tenant>           # Build web into build/<tenant>_web"
	@echo "  make deploy <tenant>        # Deploy hosting:<tenant> from build/<tenant>_web"
	@echo "  make release-web <tenant>   # Build web + deploy"
	@echo "  make apk <tenant>           # Build Android APK for flavor"
	@echo "  make aab <tenant>           # Build Android AAB for flavor"
	@echo "  make all-web                # Build web for ALL tenants"
	@echo "  make all-apk                # Build APK for ALL tenants"
	@echo "  make all-aab                # Build AAB for ALL tenants"
	@echo ""
	@echo "Tenant list management:"
	@echo "  make print-tenants"
	@echo "  make add-tenant NAME=<tenant>"
	@echo "  make remove-tenant NAME=<tenant>"
	@echo ""
	@echo "Examples:"
	@echo "  make run afyakit"
	@echo "  make run-web test           # after add-tenant NAME=test or with ALLOW_ANY_TENANT=1"
	@echo "  make web dawapap"
	@echo "  make release-web afyakit"
	@echo "  make apk danabtmc"
	@echo "  make aab afyakit"
	@echo ""
	@echo "Vars: DEVICE=<id> (see 'make devices'), EXTRA='extra flutter args', ALLOW_ANY_TENANT=1"
devices:
	flutter devices

print-tenants:
	@echo "📜 Tenants:"; \
	if [ -n "$(TENANTS)" ]; then printf "  - %s\n" $(TENANTS); else echo "  (none)"; fi

add-tenant:
	@if [ -z "$(NAME)" ]; then echo "Usage: make add-tenant NAME=<tenant>"; exit 2; fi
	@touch $(TENANTS_FILE)
	@if grep -qx "$(NAME)" $(TENANTS_FILE); then \
		echo "ℹ️  Tenant '$(NAME)' already present"; \
	else \
		echo "$(NAME)" >> $(TENANTS_FILE); \
		echo "✅ Added tenant '$(NAME)' to $(TENANTS_FILE)"; \
	fi

remove-tenant:
	@if [ -z "$(NAME)" ]; then echo "Usage: make remove-tenant NAME=<tenant>"; exit 2; fi
	@if [ ! -f "$(TENANTS_FILE)" ]; then echo "ℹ️  No $(TENANTS_FILE) file yet"; exit 0; fi
	@grep -vx "$(NAME)" $(TENANTS_FILE) > $(TENANTS_FILE).tmp || true
	@mv $(TENANTS_FILE).tmp $(TENANTS_FILE)
	@echo "🗑️  Removed tenant '$(NAME)' (if it existed)"

# ─────────────────────────────────────────────────────────────────────────────
# Run (Android if present, else chrome)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run run-web
run:
	@$(call assert_tenant)
	@echo "▶️  Running $(TENANT) on '$(DEVICE)'..."
	flutter run -d $(DEVICE) --flavor $(TENANT) --dart-define=TENANT=$(TENANT) $(EXTRA)

run-web:
	@$(call assert_tenant)
	@echo "🌐 Running (web) $(TENANT) on chrome..."
	flutter run -d chrome --dart-define=TENANT=$(TENANT) $(EXTRA)

# ─────────────────────────────────────────────────────────────────────────────
# Web build / deploy
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: web deploy release-web all-web
web:
	@$(call assert_tenant)
	@echo "🌐 Building web for $(TENANT)…"
	flutter build web --release --dart-define=TENANT=$(TENANT) --output $(WEB_OUT)/$(TENANT)_web $(EXTRA)

deploy:
	@$(call assert_tenant)
	@test -d "$(WEB_OUT)/$(TENANT)_web" || (echo "❌ Missing $(WEB_OUT)/$(TENANT)_web — run 'make web $(TENANT)' first." && exit 2)
	@echo "🚀 Deploying hosting:$(TENANT)…"
	firebase deploy --only hosting:$(TENANT)

release-web:
	@$(call assert_tenant)
	@$(MAKE) web TENANT=$(TENANT)
	@$(MAKE) deploy TENANT=$(TENANT)

all-web:
	@for t in $(TENANTS); do \
	  echo "🌐 Building web for $$t…"; \
	  flutter build web --release --dart-define=TENANT=$$t --output $(WEB_OUT)/$${t}_web $(EXTRA) || exit $$?; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# Android builds
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: apk aab all-apk all-aab
apk:
	@$(call assert_tenant)
	@echo "🤖 Building APK for $(TENANT)…"
	flutter build apk --release --flavor $(TENANT) --dart-define=TENANT=$(TENANT) $(EXTRA)

aab:
	@$(call assert_tenant)
	@echo "📦 Building AAB for $(TENANT)…"
	flutter build appbundle --release --flavor $(TENANT) --dart-define=TENANT=$(TENANT) $(EXTRA)

all-apk:
	@for t in $(TENANTS); do \
	  echo "🤖 Building APK for $$t…"; \
	  flutter build apk --release --flavor $$t --dart-define=TENANT=$$t $(EXTRA) || exit $$?; \
	done

all-aab:
	@for t in $(TENANTS); do \
	  echo "📦 Building AAB for $$t…"; \
	  flutter build appbundle --release --flavor $$t --dart-define=TENANT=$$t $(EXTRA) || exit $$?; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# Clean
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	flutter clean
	rm -rf $(WEB_OUT)/*_web
