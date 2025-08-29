# 📜 AfyaKit / DanabTMC / DawaPap – Dev Commands (Dynamic)

Run these from the project root. The tenant slug is dynamic at **run/deploy** time.  
**Web is a single shared build** used by all tenant sites.

---

## 🏃 Run the App

| Tenant       | Android (auto device) | Web (Chrome)            |
| ------------ | --------------------- | ----------------------- |
| **AfyaKit**  | `make run afyakit`    | `make run-web afyakit`  |
| **DanabTMC** | `make run danabtmc`   | `make run-web danabtmc` |
| **DawaPap**  | `make run dawapap`    | `make run-web dawapap`  |

> List devices:
>
> ```bash
> make devices
> ```
>
> Force a specific device:
>
> ```bash
> DEVICE=sdk_gphone64_x86_64 make run afyakit
> ```
>
> Extra flutter args (e.g., debug):
>
> ```bash
> EXTRA="--debug" make run afyakit
> ```

---

## 📦 Build (Web) — **ONE shared bundle**

Build once for all tenants:

make deploy afyakit
make deploy danabtmc
make deploy dawapap

or

make release-web afyakit

```bash
make web
```
