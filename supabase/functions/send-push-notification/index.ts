import { serve } from "https://deno.land/std@0.201.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!;

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Parse Firebase service account JSON
let serviceAccount: any;
let projectId: string;
try {
  serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);
  projectId = serviceAccount.project_id;
} catch (e) {
  console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT:', e);
  throw new Error('Invalid FIREBASE_SERVICE_ACCOUNT JSON');
}

// Get OAuth2 access token for FCM HTTP v1 API
async function getAccessToken(): Promise<string> {
  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  // Create JWT (simplified - in production use a proper JWT library)
  const encodedHeader = btoa(JSON.stringify(header));
  const encodedPayload = btoa(JSON.stringify(payload));
  const signatureInput = `${encodedHeader}.${encodedPayload}`;

  // Sign with private key
  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    str2ab(atob(serviceAccount.private_key.replace(/-----BEGIN PRIVATE KEY-----/g, '').replace(/-----END PRIVATE KEY-----/g, '').replace(/\n/g, ''))),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(signatureInput)
  );

  const jwt = `${signatureInput}.${btoa(String.fromCharCode(...new Uint8Array(signature)))}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

// Helper function to convert string to ArrayBuffer
function str2ab(str: string): ArrayBuffer {
  const buf = new ArrayBuffer(str.length);
  const bufView = new Uint8Array(buf);
  for (let i = 0; i < str.length; i++) {
    bufView[i] = str.charCodeAt(i);
  }
  return buf;
}

serve(async (req) => {
  try {
    const body = await req.json();
    const userId: string | undefined = body.userId;
    const title: string = body.title ?? '';
    const message: string = body.body ?? '';
    const payload: Record<string, unknown> = body.payload ?? {};

    if (!userId) {
      return new Response(JSON.stringify({ error: 'userId required' }), { status: 400 });
    }

    // Fetch device tokens for user
    const { data: tokens, error: tokenError } = await supabase
      .from('device_tokens')
      .select('provider, token, platform')
      .eq('user_id', userId);

    if (tokenError) throw tokenError;

    if (!tokens || tokens.length === 0) {
      // Still insert notification record for audit
      await supabase.from('notifications').insert([{ user_id: userId, title, body: message, channel: 'push', payload }]);
      return new Response(JSON.stringify({ ok: true, sent: 0 }), { status: 200 });
    }

    // Collect FCM tokens
    const fcmTokens = tokens.filter((t: any) => t.provider === 'fcm').map((t: any) => ({ token: t.token as string, platform: t.platform }));

    if (fcmTokens.length === 0) {
      await supabase.from('notifications').insert([{ user_id: userId, title, body: message, channel: 'push', payload }]);
      return new Response(JSON.stringify({ ok: true, sent: 0 }), { status: 200 });
    }

    // Get OAuth2 access token
    const accessToken = await getAccessToken();

    // Send to FCM HTTP v1 API
    const sendToFcm = async (deviceToken: { token: string; platform: string }) => {
      const fcmMessage = {
        message: {
          token: deviceToken.token,
          notification: {
            title,
            body: message,
          },
          data: Object.fromEntries(
            Object.entries(payload).map(([k, v]) => [k, String(v)])
          ),
          // Platform-specific configuration
          android: {
            priority: "high",
            notification: {
              sound: "default",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        },
      };

      return fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmMessage),
      });
    };

    const promises: Promise<Response>[] = [];
    for (const t of fcmTokens) {
      promises.push(sendToFcm(t));
    }

    // Wait for all sends and check for errors (best-effort)
    const results = await Promise.allSettled(promises);
    const sentCount = results.filter(r => r.status === 'fulfilled').length;

    // Log any failures
    results.forEach((result, idx) => {
      if (result.status === 'rejected') {
        console.error(`Failed to send to token ${idx}:`, result.reason);
      }
    });

    // Insert notification record (audit)
    await supabase.from('notifications').insert([{ user_id: userId, title, body: message, channel: 'push', payload, delivered: sentCount > 0 }]);

    return new Response(JSON.stringify({ ok: true, sent: sentCount, total: fcmTokens.length }), { status: 200 });
  } catch (err: any) {
    console.error('send-push error', err?.message ?? err);
    return new Response(JSON.stringify({ error: err?.message ?? String(err) }), { status: 500 });
  }
});
