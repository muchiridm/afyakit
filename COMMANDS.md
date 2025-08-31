# Set once per shell

export TENANTS="afyakit danabtmc dawapap"

# Dev (Chrome)

make run-web afyakit
make run-web danabtmc
make run-web dawapap

make run-web-all

# Dev (Android)

make run afyakit
make run danabtmc
make run dawapap

make run-android-all

# Web build + deploy (tenants)

make web
make deploy afyakit
make deploy danabtmc
make deploy dawapap

make deploy-all
make release-web-all

# HQ

# CHROME

make run-hq-web

# DEVICE

make run-hq

# WEB

make web-hq && make deploy-hq
