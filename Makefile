# ─────────────────────────────────────────────────────────────────────────────
# KISS Makefile
# - Dynamic tenant app (AfyaKit / DanabTMC / DawaPap …)
# - Dedicated HQ app (AfyaKit HQ)
#
# Quick examples:
#   make run afyakit                 # run one tenant (Android or Chrome fallback)
#   EXTRA="--debug" make run-web danabtmc
#   make web                         # build ONE shared tenant web bundle
#   make deploy afyakit              # deploy one tenant
#   make release-web dawapap         # build shared + deploy that tenant
#
# Matrix / all-tenants:
#   TENANTS="afyakit danabtmc dawapap" make deploy-all
#   TENANTS="afyakit danabtmc dawapap" make release-web-all
#   TENANTS="afyakit danabtmc dawapap" WEB_PORT_BASE=5200 make run-web-all
#   TENANTS="afyakit danabtmc dawapap" make apk-all
#
# HQ:
#   make run-hq | make run-hq-web | make web-hq | make deploy-hq | make release-web-hq
#
# Overrides:
#   DEVICE=<id>         e.g. DEVICE=sdk_gphone64_x86_64
#   EXTRA="..."         extra flutter args (e.g. --debug)
#   ENTRY_TENANT=...    default: lib/main_dynamic.dart
#   ENTRY_HQ=...        default: lib/main_hq.dart
#   HQ_SITE=...         default: afyakit-hq (Firebase Hosting target)
#   USE_FLAVOR=1|0      pass --flavor <tenant> (default 1). Set 0 if flavors aren’t configured.
#   TENANTS="..."       space-separated tenant slugs for *-all targets
#   WEB_PORT_BASE=5000  starting port for run-web-all
# ─────────────────────────────────────────────────────────────────────────────

# Tenant from arg 2: "make <target> <tenant>"
TENANT ?= $(word 2,$(MAKECMDGOALS))

# Swallow the trailing "<tenant>"
ifneq ($(TENANT),)
  .PHONY: $(TENANT)
  $(TENANT): ; @:
endif

# Auto-pick first Android device; fallback to chrome
DEVICE ?= $(shell flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}')
ifeq ($(strip $(DEVICE)),)
  DEVICE := chrome
endif

ENTRY_TENANT ?= lib/main_dynamic.dart
ENTRY_HQ     ?= lib/main_hq.dart

WEB_OUT      ?= build/web
WEB_OUT_HQ   ?= build/web-hq

HQ_SITE      ?= afyakit-hq
EXTRA        ?=
USE_FLAVOR   ?= 1
WEB_PORT_BASE?= 5000

# Matrix list (override in command): TENANTS="afyakit danabtmc dawapap"
TENANTS ?=

# Derived flags for single-tenant commands
FLAVOR_FLAG  := $(if $(filter 1 yes true,$(USE_FLAVOR)),$(if $(TENANT),--flavor $(TENANT),),)
TENANT_DEF   := $(if $(TENANT),--dart-define=TENANT=$(TENANT),)

define assert_tenant
	@if [ -z "$(TENANT)" ]; then \
	  echo "❌ Missing tenant. Usage: make $(firstword $(MAKECMDGOALS)) <tenant>"; \
	  exit 2; \
	fi
endef

define assert_tenants
	@if [ -z "$(TENANTS)" ]; then \
	  echo "❌ TENANTS is empty. Example: TENANTS=\"afyakit danabtmc dawapap\" make $(firstword $(MAKECMDGOALS))"; \
	  exit 2; \
	fi
endef

# ─────────────────────────────────────────────────────────────────────────────
# Help & utilities
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help devices doctor outdated pubget
help:
	@echo "Targets: run/run-web/run-android, web/deploy/release-web, apk/apk-release/aab,"
	@echo "         run-web-all, run-android-all, web-all, deploy-all, release-web-all,"
	@echo "         apk-all, apk-debug-all, aab-all, and HQ equivalents."
devices:;  flutter devices
doctor:;   flutter doctor -v
outdated:; flutter pub outdated || true
pubget:;   flutter pub get

# ─────────────────────────────────────────────────────────────────────────────
# Tenant app: run (one)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run run-android run-web
run:
	@$(call assert_tenant)
	@echo "▶️  Running $(TENANT) on '$(DEVICE)'… (USE_FLAVOR=$(USE_FLAVOR))"
	flutter run -d $(DEVICE) $(FLAVOR_FLAG) -t $(ENTRY_TENANT) $(TENANT_DEF) $(EXTRA)

run-android:
	@$(call assert_tenant)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	echo "🤖 Running $(TENANT) on '$$ANDROID'… (USE_FLAVOR=$(USE_FLAVOR))"; \
	flutter run -d $$ANDROID $(FLAVOR_FLAG) -t $(ENTRY_TENANT) $(TENANT_DEF) $(EXTRA)

run-web:
	@$(call assert_tenant)
	@echo "🌐 Running (web) $(TENANT) on Chrome…"
	flutter run -d chrome -t $(ENTRY_TENANT) $(TENANT_DEF) $(EXTRA)

# ─────────────────────────────────────────────────────────────────────────────
# Tenant app: web build/deploy (shared bundle)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: web deploy release-web
web:
	@echo "🌐 Building ONE shared tenant web bundle → $(WEB_OUT)…"
	flutter build web --release -t $(ENTRY_TENANT) -o $(WEB_OUT) $(EXTRA)

deploy:
	@$(call assert_tenant)
	@test -d "$(WEB_OUT)" || (echo "❌ Missing $(WEB_OUT) — run 'make web' first." && exit 2)
	@echo "🚀 Deploy hosting:$(TENANT) from $(WEB_OUT)…"
	firebase deploy --only hosting:$(TENANT)

release-web:
	@$(call assert_tenant)
	@$(MAKE) web ENTRY_TENANT=$(ENTRY_TENANT) EXTRA=$(EXTRA)
	@$(MAKE) deploy TENANT=$(TENANT)

# ─────────────────────────────────────────────────────────────────────────────
# Tenant app: Android artifacts (one)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: apk apk-release aab
apk:
	@$(call assert_tenant)
	@echo "📦 DEBUG APK for $(TENANT)…"
	flutter build apk --debug $(FLAVOR_FLAG) -t $(ENTRY_TENANT) $(TENANT_DEF) $(EXTRA)
	@echo "👉 build/app/outputs/flutter-apk/"

apk-release:
	@$(call assert_tenant)
	@echo "📦 RELEASE APK for $(TENANT)…"
	flutter build apk --release $(FLAVOR_FLAG) -t $(ENTRY_TENANT) $(TENANT_DEF) $(EXTRA)
	@echo "👉 build/app/outputs/flutter-apk/"

aab:
	@$(call assert_tenant)
	@echo "🟣 RELEASE AAB for $(TENANT)…"
	flutter build appbundle --release $(FLAVOR_FLAG) -t $(ENTRY_TENANT) $(TENANT_DEF) $(EXTRA)
	@echo "👉 build/app/outputs/bundle/release/"

# ─────────────────────────────────────────────────────────────────────────────
# Matrix: tenants (ALL)
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: web-all deploy-all release-web-all
web-all:  ## builds tenant bundle + HQ bundle
	@$(MAKE) web
	@$(MAKE) web-hq

deploy-all:
	@$(call assert_tenants)
	@test -d "$(WEB_OUT)" || (echo "❌ Missing $(WEB_OUT) — run 'make web' first." && exit 2)
	@for t in $(TENANTS); do \
	  echo "🚀 Deploy hosting:$$t …"; \
	  firebase deploy --only hosting:$$t || exit $$?; \
	done

release-web-all:
	@$(MAKE) web
	@$(MAKE) deploy-all TENANTS="$(TENANTS)"

.PHONY: apk-all apk-debug-all aab-all
apk-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do \
	  echo "📦 RELEASE APK for $$t …"; \
	  flutter build apk --release $(if $(filter 1 yes true,$(USE_FLAVOR)),--flavor $$t,) \
	    -t $(ENTRY_TENANT) --dart-define=TENANT=$$t $(EXTRA) || exit $$?; \
	done
	@echo "👉 build/app/outputs/flutter-apk/"

apk-debug-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do \
	  echo "📦 DEBUG APK for $$t …"; \
	  flutter build apk --debug $(if $(filter 1 yes true,$(USE_FLAVOR)),--flavor $$t,) \
	    -t $(ENTRY_TENANT) --dart-define=TENANT=$$t $(EXTRA) || exit $$?; \
	done
	@echo "👉 build/app/outputs/flutter-apk/"

aab-all:
	@$(call assert_tenants)
	@for t in $(TENANTS); do \
	  echo "🟣 RELEASE AAB for $$t …"; \
	  flutter build appbundle --release $(if $(filter 1 yes true,$(USE_FLAVOR)),--flavor $$t,) \
	    -t $(ENTRY_TENANT) --dart-define=TENANT=$$t $(EXTRA) || exit $$?; \
	done
	@echo "👉 build/app/outputs/bundle/release/"

.PHONY: run-web-all run-android-all
run-web-all:
	@$(call assert_tenants)
	@PORT=$(WEB_PORT_BASE); \
	for t in $(TENANTS); do \
	  echo "🌐 Launch $$t on Chrome :$${PORT} …"; \
	  (flutter run -d chrome -t $(ENTRY_TENANT) --dart-define=TENANT=$$t --web-port=$${PORT} $(EXTRA) &) ; \
	  PORT=$$((PORT+1)); \
	done; \
	echo "ℹ️ Started $(words $(TENANTS)) Chrome debuggers on ports $(WEB_PORT_BASE)..$$((PORT-1))."

# Note: this runs tenants sequentially on a single Android device. Use separate terminals/emulators if you want them side-by-side.
run-android-all:
	@$(call assert_tenants)
	@ANDROID=$$(flutter devices 2>/dev/null | awk '/android|emulator|gphone|Pixel/ {print $$1; exit}'); \
	if [ -z "$$ANDROID" ]; then echo "❌ No Android device/emulator found."; exit 2; fi; \
	for t in $(TENANTS); do \
	  echo "🤖 Run $$t on $$ANDROID (Ctrl+C to stop; next starts after exit)…"; \
	  flutter run -d $$ANDROID $(if $(filter 1 yes true,$(USE_FLAVOR)),--flavor $$t,) \
	    -t $(ENTRY_TENANT) --dart-define=TENANT=$$t $(EXTRA) || exit $$?; \
	done

# ─────────────────────────────────────────────────────────────────────────────
# HQ app
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: run-hq run-hq-web web-hq deploy-hq release-web-hq
run-hq:      ; @echo "🏢 Running HQ on '$(DEVICE)'…" && flutter run -d $(DEVICE) -t $(ENTRY_HQ) $(EXTRA)
run-hq-web:  ; @echo "🏢🌐 Running HQ on Chrome…"    && flutter run -d chrome -t $(ENTRY_HQ) $(EXTRA)
web-hq:      ; @echo "🏗️  Building HQ → $(WEB_OUT_HQ)…" && flutter build web --release -t $(ENTRY_HQ) -o $(WEB_OUT_HQ) $(EXTRA)
deploy-hq:
	@test -d "$(WEB_OUT_HQ)" || (echo "❌ Missing $(WEB_OUT_HQ) — run 'make web-hq' first." && exit 2)
	@echo "🚀 Deploy hosting:$(HQ_SITE) from $(WEB_OUT_HQ)…"
	firebase deploy --only hosting:$(HQ_SITE)
release-web-hq:
	@$(MAKE) web-hq ENTRY_HQ=$(ENTRY_HQ) EXTRA=$(EXTRA)
	@$(MAKE) deploy-hq HQ_SITE=$(HQ_SITE)

# ─────────────────────────────────────────────────────────────────────────────
# Clean
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: clean deep-clean
clean:
	flutter clean
	rm -rf build/web build/web-hq

deep-clean: clean
	rm -rf .dart_tool build ios/Pods ios/Podfile.lock android/.gradle android/build
