# Google Sign-In Setup Guide

This guide will help you complete the Google Sign-In integration for JoMarket.

## Prerequisites

- A Google Cloud Console project
- Firebase project (if using Firebase)
- Access to Supabase dashboard

## Step 1: Google Cloud Console Setup

### 1.1 Create OAuth 2.0 Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Navigate to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **OAuth client ID**

### 1.2 Configure OAuth Consent Screen (if not already done)

1. Click **Configure Consent Screen**
2. Select **External** user type
3. Fill in the required fields:
   - App name: `JoMarket`
   - User support email: Your email
   - Developer contact email: Your email
4. Add scopes: `email`, `profile`, `openid`
5. Save and continue

### 1.3 Create Web Client ID

1. Go back to **Credentials** > **Create Credentials** > **OAuth client ID**
2. Select **Web application**
3. Add **Authorized redirect URIs**:
   - `https://qjwnudofsiznvfcgzwuv.supabase.co/auth/v1/callback`
   - `http://localhost:3000/auth-callback` (for local testing)
4. Click **Create**
5. **Save the Client ID** - you'll need this for the next steps

### 1.4 Create Android Client ID

1. Create another **OAuth client ID**
2. Select **Android**
3. Package name: `com.jomarket.app`
4. Get your SHA-1 certificate fingerprint:

**For Debug builds:**
```powershell
cd android
./gradlew signingReport
```
Look for the SHA-1 under the `debug` variant.

**Quick method (for debug keystore):**
```powershell
keytool -list -v -alias androiddebugkey -keystore C:\Users\YOUR_USERNAME\.android\debug.keystore -storepass android
```

5. Paste the SHA-1 fingerprint
6. Click **Create**

### 1.5 Create iOS Client ID

1. Create another **OAuth client ID**
2. Select **iOS**
3. Bundle ID: `com.jomarket.app`
4. Click **Create**

## Step 2: Supabase Configuration

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Navigate to **Authentication** > **Providers**
3. Find **Google** and enable it
4. Paste your **Web Client ID** from Step 1.3
5. Paste your **Client Secret** from the Web OAuth client
6. Add authorized redirect URL: `com.jomarket.app://auth-callback`
7. Click **Save**

## Step 3: Update Environment Variables

1. Copy the `.env.example` file to `.env` (if you haven't already):
```powershell
Copy-Item env\.env.example .env
```

2. Edit the `.env` file and add your credentials:
```env
SUPABASE_URL=https://qjwnudofsiznvfcgzwuv.supabase.co
SUPABASE_KEY=your_actual_anon_key_from_supabase

# Use the Web Client ID here (NOT the Android or iOS client ID)
GOOGLE_SERVER_CLIENT_ID=123456789-abcdefg.apps.googleusercontent.com
```

## Step 4: iOS Configuration (if targeting iOS)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Add the reversed client ID to `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Existing schemes -->
            <string>com.jomarket.app</string>
            <!-- Add your reversed client ID -->
            <string>com.googleusercontent.apps.123456789-abcdefg</string>
        </array>
    </dict>
</array>
```

## Step 5: Testing

### Clean and Rebuild

```powershell
flutter clean
flutter pub get
flutter run
```

### Test the Sign-In Flow

1. Launch the app
2. Click **Continue with Google**
3. Select a Google account
4. Grant permissions
5. You should be redirected back to the app and signed in

## Troubleshooting

### Error: "Sign in failed" or "No client ID found"

- **Solution**: Make sure you've added the `GOOGLE_SERVER_CLIENT_ID` to your `.env` file
- Verify the client ID is the **Web client ID**, not the Android or iOS client ID

### Error: "API not enabled"

- **Solution**: Enable the Google+ API in Google Cloud Console:
  1. Go to **APIs & Services** > **Library**
  2. Search for "Google+ API"
  3. Click **Enable**

### Error: "Invalid SHA-1"

- **Solution**: Make sure you've added the correct SHA-1 fingerprint for your debug keystore
- For release builds, you'll need to add the SHA-1 from your release keystore

### Error: "Redirect URI mismatch"

- **Solution**: Verify the redirect URIs in Google Cloud Console match:
  - Supabase: `https://qjwnudofsiznvfcgzwuv.supabase.co/auth/v1/callback`
  - Android/iOS: `com.jomarket.app://auth-callback`

### Android: "Sign in cancelled immediately"

- **Solution**: This usually means the SHA-1 fingerprint is missing or incorrect
- Re-run the `signingReport` command and verify the SHA-1 in Google Cloud Console

### Emulator: `PlatformException(network_error, ApiException: 7)`

- **Why**: Older emulators or images without Google Play Services can't complete the native GoogleSignIn flow.
- **Fix**: Use a `Google Play` system image, sign into the emulator's Play Store, and ensure Google Play Services is updated.
- **Fallback**: If you just need to unblock testing, set `FORCE_GOOGLE_WEB_OAUTH=true` in `.env` (or run `flutter run --dart-define=FORCE_GOOGLE_WEB_OAUTH=true`) to force Supabase's browser OAuth flow on Android.

### iOS: "Sign in doesn't open Google"

- **Solution**: Make sure you've added the reversed client ID to `Info.plist`
- The reversed client ID should be: `com.googleusercontent.apps.YOUR_CLIENT_ID`

## Additional Notes

### Web Support

For web support, the Google Sign-In will work automatically using the OAuth redirect flow. No additional configuration needed beyond the Web client ID in Supabase.

### Production Release

When releasing to production:

1. Generate a production keystore for Android
2. Get the SHA-1 from the production keystore
3. Add the production SHA-1 to Google Cloud Console
4. Update your Supabase redirect URIs if needed

### Security

- Never commit your `.env` file to version control
- Keep your client secrets secure
- Use different OAuth clients for development and production

## Summary

You've successfully configured Google Sign-In! The key requirements are:

1. ✅ Google Cloud Console OAuth credentials (Web, Android, iOS)
2. ✅ Supabase Google provider enabled
3. ✅ `.env` file with `GOOGLE_SERVER_CLIENT_ID`
4. ✅ Correct SHA-1 fingerprints for Android
5. ✅ `google_sign_in` package added to `pubspec.yaml`
6. ✅ Updated `auth_form.dart` with native sign-in flow

If you're still having issues, check the Flutter logs:
```powershell
flutter run --verbose
```
