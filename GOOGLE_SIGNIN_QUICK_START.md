# Google Sign-In Quick Start

## What Was Fixed

The Google Sign-In issue has been resolved by:

1. ✅ Added `google_sign_in: ^6.2.2` package to `pubspec.yaml`
2. ✅ Updated `auth_form.dart` to use native Google Sign-In flow on mobile
3. ✅ Added `GOOGLE_SERVER_CLIENT_ID` to environment configuration
4. ✅ Kept web OAuth flow for browser-based sign-in

## Quick Setup (3 Steps)

### 1. Get Your Google Web Client ID

1. Go to [Google Cloud Console Credentials](https://console.cloud.google.com/apis/credentials)
2. Find your **Web application** OAuth 2.0 Client ID (or create one)
3. Copy the Client ID (format: `xxxxx.apps.googleusercontent.com`)

### 2. Update Your .env File

Create or update `.env` in the project root:

```env
SUPABASE_URL=https://qjwnudofsiznvfcgzwuv.supabase.co
SUPABASE_KEY=your_anon_key_here
GOOGLE_SERVER_CLIENT_ID=your_web_client_id_here.apps.googleusercontent.com
```

### 3. Configure Supabase

1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → Your Project
2. Navigate to **Authentication** > **Providers** > **Google**
3. Enable Google provider
4. Add your Web Client ID and Client Secret
5. Save

## Android SHA-1 Setup (Required for Android)

Get your debug SHA-1:

```powershell
# Navigate to android folder
cd android

# Run signing report
./gradlew signingReport
```

Add the SHA-1 to your Google Cloud Console:
1. **APIs & Services** > **Credentials**
2. Create or edit **Android** OAuth client
3. Package: `com.jomarket.app`
4. Add your SHA-1 fingerprint

## Test It

```powershell
flutter clean
flutter pub get
flutter run
```

Then tap **Continue with Google** in the app.

## Still Having Issues?

See the full setup guide: [GOOGLE_SIGNIN_SETUP.md](./GOOGLE_SIGNIN_SETUP.md)

## Important Notes

- Use the **Web Client ID** in your `.env` file (not Android or iOS client ID)
- The SHA-1 certificate is required for Android to work
- Web support works automatically without additional config
- Make sure `.env` is in your `.gitignore` (never commit secrets!)
