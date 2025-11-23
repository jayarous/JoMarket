# Building a signed release APK (Windows - PowerShell)

Quick helper for generating a local keystore and building a signed release APK for this Flutter app.

Prerequisites
- Flutter SDK installed and on PATH
- JDK (keytool) installed and on PATH

Recommended (safe) approach
1. Do NOT commit your keystore file or real passwords into Git. The repo `.gitignore` already excludes `**/*.keystore`.
2. Use the helper script below to create a local keystore and build an APK.

Run (from the repository root in PowerShell):

```powershell
.\scripts\build_release_apk.ps1
```

What the script does
- Checks for `keytool` (JDK) and `flutter`.
- If no keystore exists at `android/app/jomarket-release.keystore`, it will prompt to create one and then update `android/key.properties` locally.
- Runs `flutter build apk --release`.
- Copies generated APK(s) to `release/apk/`.

Manual commands (if you prefer to do it step-by-step)
1. Create keystore (example):

```powershell
cd android\app
keytool -genkeypair -v -keystore jomarket-release.keystore -alias jomarket -keyalg RSA -keysize 2048 -validity 10000
```

2. Update `android/key.properties` with the password and alias (keep this file private and do not commit sensitive values).

3. Build release APK:

```powershell
cd <repo-root>
flutter clean
flutter pub get
flutter build apk --release
```

4. APK location after build:

 - `build/app/outputs/flutter-apk/app-release.apk` (single non-split release)
 - or for split-per-abi: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`

If you want help running this on your machine or you'd like me to create a temporary (local) keystore inside the project and perform the build here, tell me and I'll proceed. (I won't commit any secrets.)
