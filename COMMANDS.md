# COMMANDS.md

# ─────────────────────────────────────────────

# 0) One time per shell

# ─────────────────────────────────────────────

export TENANTS="afyakit danabtmc dawapap"

# Now `make deploy-all`, `make web-all`, `make run-web-all`, etc. know what to loop.

# ─────────────────────────────────────────────

# 1) Dev – Web (per tenant, Chrome)

# ─────────────────────────────────────────────

make run-web afyakit
make run-web danabtmc
make run-web dawapap
make run-web rpmoc

# Or launch all (each on its own port, from WEB_PORT_BASE=5000)

make run-web-all

# Uses $TENANTS

# ─────────────────────────────────────────────

# 2) Dev – Device / Android

# ─────────────────────────────────────────────

make run afyakit
make run danabtmc
make run dawapap
make run rpmoc

# Or run all tenants sequentially on the same device/emulator

make run-android-all

# Uses $TENANTS

# ─────────────────────────────────────────────

# 3) Build web bundle (per tenant)

# ─────────────────────────────────────────────

make web afyakit
make web danabtmc
make web dawapap

# Build all tenants (loops $TENANTS)

make web-all

# ─────────────────────────────────────────────

# 4) Deploy web per tenant (site-specific firebase.<site>.json)

# ─────────────────────────────────────────────

make deploy afyakit # uses firebase.afyakit.json if present, else firebase.json
make deploy danabtmc # uses firebase.danabtmc.json if present, else firebase.json
make deploy dawapap # uses firebase.dawapap.json if present, else firebase.json

# Deploy all tenants (loops $TENANTS)

make deploy-all

# Build + deploy single tenant

make release-web dawapap
make release-web afyakit
make release-web danabtmc

# Build + deploy all tenants

make release-web-all

# ─────────────────────────────────────────────

# 5) HQ app

# ─────────────────────────────────────────────

# HQ uses the SAME entrypoint, switched by APP=hq

# Run HQ on Chrome (fixed port :5000)

make run-hq-web

# Run HQ on device

make run-hq

# Build + deploy HQ

make web-hq
make deploy-hq

# One-liner

make release-web-hq
