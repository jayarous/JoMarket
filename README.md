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

## Table of contents

- [Getting Started](#getting-started)
- [Supabase setup](#supabase-setup)
	- [Password recovery redirect configuration](#password-recovery-redirect-configuration)
	- [Google Sign-In (Android)](#google-sign-in-android)
- [Migrations — developer guide](#migrations---developer-guide)
- [Environment variables and `envied` guidance](#environment-variables-and-envied-guidance)
- [iOS Launch Screen Assets](#ios-launch-screen-assets)

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
Copy-Item env/.env.example .env
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
5. In the same project, create an OAuth client ID of type **Android** using package `com.jomarket.app` and the SHA-1 from step 3. Save the Android Client ID.
6. In Supabase Dashboard -> Authentication -> Providers -> Google, enable the provider. In **Client IDs** paste both IDs separated by a comma (for example `web-client-id,android-client-id`). In **Client Secret** paste the Web client secret from step 4, then save.
7. Supabase Dashboard -> Authentication -> URL Configuration: ensure both `com.jomarket.app://password-reset` and `com.jomarket.app://auth-callback` are listed.
8. Run the app on an Android emulator or device (`flutter run`) and tap **Continue with Google** to verify the OAuth flow.

## Migrations — developer guide

This project contains `migrations/sql_migration.sql` which creates the full JoMarket schema (tables, enums, functions, triggers, RLS policies).

Follow these steps to safely run migrations in a staging/dev environment before touching production.

1) Create a staging database/project
- Create a new Supabase project (recommended) or a local Postgres instance.
- For Supabase: use the Project -> Settings -> Database -> Connection info to get a connection string.

2) Run the extension statements (if necessary)
- Some extensions require admin privileges. Use the Supabase SQL editor (Project -> SQL) or an admin connection to run:

	create extension if not exists "pgcrypto";
	create extension if not exists "uuid-ossp";

- If `uuid-ossp` fails due to privileges, `pgcrypto`'s `gen_random_uuid()` is already used in this migration; it's safe to omit `uuid-ossp` if unavailable.

3) Run the full migration
- From PowerShell (Windows), run the helper script in this repo (it uses `psql`):

```powershell
# Example (replace with your connection string):
$conn = 'postgresql://postgres:password@db.host:5432/postgres'
.\scripts\run_migrations.ps1 -ConnectionString $conn
```

- Alternatively paste the SQL file contents into the Supabase SQL editor and run.

4) Seed test data
- Use `migrations/seed_dev.sql` to insert example categories, vendor, and product rows.
- Note: many tables reference `auth.users`. Create test users via Supabase Auth UI (or sign up through the app) and then update seed rows to use actual user UUIDs for full RLS coverage.

5) Test RLS & workflows
- Create the following test users (via Supabase Auth UI):
	- shopper@example.test
	- vendor_owner@example.test
	- delivery_staff@example.test
- Create `vendor_staff` and `delivery_staff` rows linking the user IDs to the vendor/delivery provider.
- Exercise flows in the app (using anon/public and authenticated keys):
	- Shopper: create cart, add items, place order, view own orders and shipments.
	- Vendor staff: read product list, update product, read order items for their vendor.
	- Delivery staff: browse marketplace shipments, accept a shipment.

6) Checklist before production
- [ ] Backup production DB.
- [ ] Verify required extensions exist (pgcrypto/uuid-ossp) or adapt migration to use `gen_random_uuid()` only.
- [ ] Ensure any background jobs or server-side processes use the Supabase service_role key where necessary (service_role bypasses RLS).
- [ ] Confirm Auth redirect URLs in Supabase Dashboard match the values in `lib/main.dart` and platform manifests (Android/iOS).
- [ ] Run a limited smoke test with a copy of production data where possible.

7) Rollback plan
- This migration is additive (creates tables, functions, triggers). If you need to rollback, have a DB backup/snapshot to restore.
- For production, prefer applying migration in a controlled window and take a snapshot beforehand.

---

## Environment variables and `envied` guidance

This repository contains `env/.env.example`. Use it as the canonical example for local development variables.

1) Create your local `.env`

- Copy `env/.env.example` to the repository root as `.env` and fill the values.
- Ensure `.env` is listed in `.gitignore`. Do NOT commit your `.env` file.

2) Add `envied` to your project (optional but recommended for typed env access)

- In `pubspec.yaml` add:

	dependencies:
		envied: ^2.0.0

	dev_dependencies:
		envied_generator: ^2.0.0
		build_runner: ^2.0.0

 (Adjust versions as appropriate.)

3) Create a typed env class

- Example (create `lib/src/env.dart`):

```dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied()
abstract class Env {
	@EnviedField(varName: 'SUPABASE_URL')
	static const supabaseUrl = '';

	@EnviedField(varName: 'SUPABASE_ANON_KEY')
	static const supabaseAnonKey = '';
}
```

4) Generate code

- Run the build runner to generate the typed classes:

	flutter pub run build_runner build --delete-conflicting-outputs

5) Use in code

- Import your generated env values instead of reading plain strings from `.env` directly. This gives compile-time guarantees and reduces typos.

6) CI and secrets

- Do NOT store production secrets in the repository. Use your CI provider's secret store (GitHub Actions secrets, Azure Key Vault, etc.) and inject them into workflows at build time.
- For GitHub Actions, add required secrets as repository secrets or use OIDC to retrieve them from your vault.

Notes
- If your `.env` already contains real keys (like Supabase keys), verify that it is NOT committed. If it is committed, rotate the secrets immediately and remove them from the repo history.

---

## iOS Launch Screen Assets

You can customize the launch screen with your own desired assets by replacing the image files in `ios/Runner/Assets.xcassets/LaunchImage.imageset`.

Open your Flutter project's Xcode workspace with `open ios/Runner.xcworkspace`, select `Runner/Assets.xcassets` in the Project Navigator and drop in the desired images.

