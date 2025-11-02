# jo_market

A multivendor shopping app.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase setup

This project uses Supabase for backend services. The app expects an anon
key (and optionally a URL) to be provided at runtime. There are three
recommended ways to provide the values:

1) Provide at build/run time (recommended for CI and production):

```powershell
flutter run --dart-define=SUPABASE_KEY="your_anon_key_here"
# Optionally override URL:
flutter run --dart-define=SUPABASE_URL="https://your.supabase.co" --dart-define=SUPABASE_KEY="your_anon_key_here"
```

2) Local developer convenience with a local `.env` file:

```powershell
Copy-Item .env.example .env
# Edit .env and put your SUPABASE_KEY (and optional SUPABASE_URL).
flutter run
```

3) Use an OS environment variable (works with VS Code launch config):

```powershell
$env:SUPABASE_KEY = "your_anon_key_here"; flutter run
```

Notes:
- Do NOT commit your `.env` file. This repo ignores `.env` by default.
- The app will throw and refuse to start if no `SUPABASE_KEY` is provided.
- For CI, store the anon key in your CI secrets and pass it with `--dart-define`.

### Password recovery redirect configuration

The reset-password email needs to deep-link back into the mobile app so the user can pick a new password. Add the following items to your Supabase project:

- In **Authentication -> URL Configuration**, add `com.jomarket.app://password-reset` to **Redirect URLs**.
- If you use a different bundle ID / app scheme in production, update the value in `lib/main.dart`, `android/app/src/main/AndroidManifest.xml`, and `ios/Runner/Info.plist` to match.

### Google Sign-In (Android)

1. Confirm your Android application ID in `android/app/build.gradle.kts` (now `com.jomarket.app`). If you ever change it, update the manifest, Kotlin package, and `_googleOAuthRedirectUri`.
2. Install Android Studio (or a standalone JDK 17) so Gradle has Java available. Set `JAVA_HOME` to the bundled JDK path (for Android Studio it is typically `C:\Program Files\Android\Android Studio\jbr`) and add `%JAVA_HOME%\bin` to your `PATH`, then restart your terminal.
3. Generate SHA-1 and SHA-256 fingerprints for the keystore you will ship with: run `cd android` followed by `./gradlew signingReport`. Copy the fingerprints shown under the `debug` variant (and repeat later for a release keystore).
4. In [Google Cloud Console](https://console.cloud.google.com/apis/credentials), create an OAuth client ID of type **Web application**. Add the redirect URI `https://qjwnudofsiznvfcgzwuv.supabase.co/auth/v1/callback`. Save the Web **Client ID** and **Client secret**.
5. In the same project, create an OAuth client ID of type **Android** using package `com.jomarket.app` and the SHA-1 from step 3. Save the Android Client ID.
6. In Supabase Dashboard -> Authentication -> Providers -> Google, enable the provider. In **Client IDs** paste both IDs separated by a comma (for example `web-client-id,android-client-id`). In **Client Secret** paste the Web client secret from step 4, then save.
7. Supabase Dashboard -> Authentication -> URL Configuration: ensure both `com.jomarket.app://password-reset` and `com.jomarket.app://auth-callback` are listed.
8. Run the app on an Android emulator or device (`flutter run`) and tap **Continue with Google** to verify the OAuth flow.

