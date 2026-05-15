// Supabase Edge Function: send_push
// Sends FCM push notifications to device tokens stored in `public.thix_push_tokens`.
//
// This uses the FCM Legacy HTTP API for maximum compatibility.
// In production, you may migrate to HTTP v1 with service accounts.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type SendPushBody = {
  // Optional: send to one user
  userId?: string;
  // Optional: send to all users (admin only in your own logic)
  broadcast?: boolean;
  // Notification
  title: string;
  body: string;
  // Extra payload
  data?: Record<string, string>;
  // Optional: only target a platform
  platform?: "android" | "ios" | "web";
};

function json(data: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(data), {
    headers: { "content-type": "application/json; charset=utf-8", ...CORS_HEADERS, ...(init.headers ?? {}) },
    status: init.status ?? 200,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, { status: 405 });

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";

  if (!supabaseUrl || !serviceRoleKey) return json({ error: "Missing Supabase env" }, { status: 500 });
  if (!fcmServerKey) return json({ error: "Missing secret FCM_SERVER_KEY" }, { status: 500 });

  let body: SendPushBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, { status: 400 });
  }

  if (!body?.title || !body?.body) return json({ error: "title and body are required" }, { status: 400 });
  if (!body.userId && !body.broadcast) return json({ error: "Provide userId or broadcast=true" }, { status: 400 });

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // 1) fetch tokens
  let q = supabase.from("thix_push_tokens").select("token, platform").eq("active", true);
  if (body.platform) q = q.eq("platform", body.platform);
  if (body.userId) q = q.eq("user_id", body.userId);

  const { data: rows, error } = await q;
  if (error) return json({ error: `Token query failed: ${error.message}` }, { status: 500 });
  const tokens = (rows ?? []).map((r) => r.token).filter(Boolean);
  if (tokens.length === 0) return json({ ok: true, sent: 0, reason: "No tokens" });

  // 2) send batches (FCM legacy: up to 1000 registration_ids)
  const batchSize = 900;
  let sent = 0;
  const failures: Array<{ token?: string; error: string }> = [];

  for (let i = 0; i < tokens.length; i += batchSize) {
    const batch = tokens.slice(i, i + batchSize);

    const payload = {
      registration_ids: batch,
      notification: {
        title: body.title,
        body: body.body,
      },
      data: body.data ?? {},
    };

    const res = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `key=${fcmServerKey}`,
      },
      body: JSON.stringify(payload),
    });

    const txt = await res.text();
    if (!res.ok) return json({ error: `FCM error ${res.status}: ${txt}` }, { status: 502 });

    // Best-effort parsing
    try {
      const parsed = JSON.parse(txt);
      sent += parsed?.success ?? batch.length;
      const results = parsed?.results ?? [];
      for (let j = 0; j < results.length; j++) {
        const r = results[j];
        if (r?.error) failures.push({ token: batch[j], error: r.error });
      }
    } catch {
      sent += batch.length;
    }
  }

  // Optional: mark invalid tokens inactive
  const invalid = failures
    .filter((f) => (f.error ?? "").includes("NotRegistered") || (f.error ?? "").includes("InvalidRegistration"))
    .map((f) => f.token)
    .filter(Boolean) as string[];

  if (invalid.length > 0) {
    await supabase.from("thix_push_tokens").update({ active: false, updated_at: new Date().toISOString() }).in("token", invalid);
  }

  return json({ ok: true, sent, tokens: tokens.length, failuresCount: failures.length, invalidTokensDisabled: invalid.length });
});
