# ─────────────────────────────────────────────────────────────────────────────
# Tenants & Auto-Tenant (last word of the command)
# Usage pattern: `make <action> <tenant>` e.g. `make run afyakit`
# ─────────────────────────────────────────────────────────────────────────────
TENANTS := afyakit danabtmc dawapap
TENANT  ?= $(lastword $(MAKECMDGOALS))

# Swallow the trailing tenant target so make doesn't error
$(TENANTS): ; @:

# ─────────────────────────────────────────────────────────────────────────────
# Device selection (auto-pick first Android device; fallback to chrome)
# Override per call: DEVICE=sdk_gphone64_x86_64
# ─────────────────────────────────────────────────────────────────────────────
DEVICE ?= $(shell flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}')
ifeq ($(strip $(DEVICE)),)
  DEVICE := chrome
endif

# Extra args passthrough if you need them: EXTRA="-t lib/main_alt.dart"
EXTRA ?=

# Build output base for web
WEB_OUT := build

# ─────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────────────────────────────────────
define assert_tenant
	@if ! printf "%s\n" $(TENANTS) | grep -qx "$(TENANT)"; then \
		echo "❌ Unknown or missing tenant '$(TENANT)'. Use one of: $(TENANTS)"; \
		exit 2; \
	fi
endef

# ─────────────────────────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help devices
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
	@echo "Examples:"
	@echo "  make run afyakit"
	@echo "  make run-web danabtmc"
	@echo "  make web dawapap"
	@echo "  make release-web afyakit"
	@echo "  make apk danabtmc"
	@echo "  make aab afyakit"
	@echo ""
	@echo "Vars: DEVICE=<id> (from 'make devices'), EXTRA='extra flutter args'"
devices:
	flutter devices

# ─────────────────────────────────────────────────────────────────────────────
# Run (Android if present, else chrome)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run run-web
run: $(TENANT)
	@$(call assert_tenant)
	@echo "▶️  Running $(TENANT) on '$(DEVICE)'..."
	flutter run -d $(DEVICE) --flavor $(TENANT) --dart-define=TENANT=$(TENANT) $(EXTRA)

run-web: $(TENANT)
	@$(call assert_tenant)
	@echo "🌐 Running (web) $(TENANT) on chrome..."
	flutter run -d chrome --dart-define=TENANT=$(TENANT) $(EXTRA)

# ─────────────────────────────────────────────────────────────────────────────
# Web build / deploy
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: web deploy release-web all-web
web: $(TENANT)
	@$(call assert_tenant)
	@echo "🌐 Building web for $(TENANT)…"
	flutter build web --release --dart-define=TENANT=$(TENANT) --output $(WEB_OUT)/$(TENANT)_web $(EXTRA)

deploy: $(TENANT)
	@$(call assert_tenant)
	@test -d "$(WEB_OUT)/$(TENANT)_web" || (echo "❌ Missing $(WEB_OUT)/$(TENANT)_web — run 'make web $(TENANT)' first." && exit 2)
	@echo "🚀 Deploying hosting:$(TENANT)…"
	firebase deploy --only hosting:$(TENANT)

release-web: $(TENANT)
	@$(MAKE) web $(TENENT) >/dev/null 2>&1 || true
	@$(call assert_tenant)
	@$(MAKE) web $(TENANT)
	@$(MAKE) deploy $(TENANT)

all-web:
	@for t in $(TENANTS); do \
	  echo "🌐 Building web for $$t…"; \
	  flutter build web --release --dart-define=TENANT=$$t --output $(WEB_OUT)/$${t}_web $(EXTRA) || exit $$?; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# Android builds
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: apk aab all-apk all-aab
apk: $(TENANT)
	@$(call assert_tenant)
	@echo "🤖 Building APK for $(TENANT)…"
	flutter build apk --release --flavor $(TENANT) --dart-define=TENANT=$(TENANT) $(EXTRA)

aab: $(TENANT)
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
