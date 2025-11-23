# Send Push Notification - Supabase Edge Function

## Overview

This Edge Function sends push notifications to device tokens stored in the `device_tokens` table using FCM HTTP v1 API with Firebase Admin SDK authentication. This is the modern, secure approach recommended by Google.

## Environment variables (set as Supabase secrets)

- `SUPABASE_URL` - your Supabase project URL (auto-set)
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key for supabase client
- `FIREBASE_SERVICE_ACCOUNT` - Firebase service account JSON (as single-line string)

## Setup

### 1. Download Firebase Service Account Key

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Download the JSON file (keep it secure!)

### 2. Deploy

```powershell
# From repository root
supabase functions deploy send-push-notification --no-verify-jwt
```

### 3. Set Secrets

```powershell
# Convert service account JSON to single-line string and set as secret
$serviceAccount = Get-Content path\to\service-account.json -Raw | ConvertFrom-Json | ConvertTo-Json -Compress
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$serviceAccount"

# Set Supabase service role key (get from Supabase Dashboard > Settings > API)
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
```

Test (example using curl)

1. Get a device token from your running app (use `FirebaseMessaging.instance.getToken()` and copy it from logs)
2. Insert the token into `device_tokens` table for your user (or let client upsert it)
3. Call the function with a user id in the body:

```powershell
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"userId":"<user-uuid>", "title":"Test", "body":"Hello from Edge Function", "payload":{"type":"test","ticket_id":"abc"}}' \
  https://<project>.supabase.co/functions/v1/send-push-notification
```

Notes

- This implementation uses the FCM legacy `/fcm/send` endpoint for simplicity. For better security and control use FCM HTTP v1 (requires OAuth and different flow).
- APNs direct calls require JWT signing with your APNs key; many teams use FCM as a gateway for iOS, or use third-party providers.
- Keep `FCM_SERVER_KEY` and `SUPABASE_SERVICE_ROLE_KEY` secret.
- Consider adding throttling logic in the function if you want server-side spam control.
