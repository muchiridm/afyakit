# 📜 AfyaKit / DanabTMC / DawaPap Dev Commands

Common commands for building, running, and deploying **AfyaKit**, **DanabTMC**, and **DawaPap**.  
Run these from the project root.

---

## 🏃 Run the App

| Tenant       | Run Command       | Run on Web / CHROME   |
| ------------ | ----------------- | --------------------- |
| **AfyaKit**  | make run afyakit  | make run-web afyakit  |
| **DanabTMC** | make run danabtmc | make run-web danabtmc |
| **DawaPap**  | make run dawapap  | make run-web dawapap  |

> List devices:
>
> ```bash
> flutter devices
> ```

---

## 📦 Build (Web)

| Tenant       | Build Command       |
| ------------ | ------------------- |
| **AfyaKit**  | `make web afyakit`  |
| **DanabTMC** | `make web danabtmc` |
| **DawaPap**  | `make web dawapap`  |

---

## 🚀 Deploy to Firebase Hosting

| Tenant       | Deploy Command         |
| ------------ | ---------------------- |
| **AfyaKit**  | `make deploy afyakit`  |
| **DanabTMC** | `make deploy danabtmc` |
| **DawaPap**  | `make deploy dawapap`  |

> **Note:** Multi-site hosting in Firebase means you **don’t** use `--public`.  
> The correct `public` path is set in `firebase.json` per tenant.

---

## 🔍 Device & Emulator Commands

```bash
flutter devices                  # Show connected devices
flutter emulators                # List available emulators
flutter emulators --launch <id>  # Start a specific emulator
```
