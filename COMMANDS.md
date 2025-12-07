# ─────────────────────────────────────────────

# 0) One time per shell

# ─────────────────────────────────────────────

export TENANTS="afyakit danabtmc dawapap"

# now `make deploy-all` + `make run-web-all` know what to loop

# ─────────────────────────────────────────────

# 1) Dev – Web (per tenant, Chrome)

# ─────────────────────────────────────────────

make run-web afyakit
make run-web danabtmc
make run-web dawapap
make run-web rpmoc

# or launch all (each on its own port, from WEB_PORT_BASE=5000)

make run-web-all

# uses $TENANTS

# ─────────────────────────────────────────────

# 2) Dev – Device / Android

# ─────────────────────────────────────────────

make run afyakit
make run danabtmc
make run dawapap
make run rpmoc

# or all (will iterate TENANTS and try to run on device/emulator)

make run-android-all

# ─────────────────────────────────────────────

# 3) Build web bundle (shared tenant entry)

# ─────────────────────────────────────────────

# build once → build/web

make web

# ─────────────────────────────────────────────

# 4) Deploy per tenant (now uses site-specific firebase.<site>.json)

# ─────────────────────────────────────────────

make deploy afyakit # → uses firebase.afyakit.json if present
make deploy danabtmc # → uses firebase.danabtmc.json if present
make deploy dawapap # → uses firebase.dawapap.json if present

# full matrix deploy (loops TENANTS, picks right json per tenant)

make deploy-all

# build + deploy all in one go

make release-web-all

# = make web + make deploy-all

# build + deploy single tenant

make release-web dawapap
make release-web afyakit
make release-web danabtmc
make release-web rpmoc

# ─────────────────────────────────────────────

# 5) HQ app

# ─────────────────────────────────────────────

# run HQ on Chrome

make run-hq-web

# run HQ on device

make run-hq

# build + deploy HQ (uses firebase.hq.json if it exists)

make web-hq && make deploy-hq
