// supabase/functions/agora-token/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";
import { RtcTokenBuilder, RtcRole } from "npm:agora-access-token@2";

const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

type Body = {
  channel: string;
  uid: number;
  role?: "publisher" | "subscriber";
  expireSeconds?: number;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Use POST" }), { status: 405, headers: { ...CORS_HEADERS, "content-type": "application/json" } });

  try {
    const appId = Deno.env.get("AGORA_APP_ID") ?? "";
    const appCert = Deno.env.get("AGORA_APP_CERTIFICATE") ?? "";
    if (!appId || !appCert) {
      return new Response(JSON.stringify({ error: "Missing Agora env vars" }), { status: 500, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
    }

    const body = (await req.json()) as Body;
    const channel = (body.channel ?? "").toString().trim();
    const uid = Number(body.uid);
    const role = (body.role ?? "publisher").toString();
    const expireSeconds = Math.max(60, Math.min(Number(body.expireSeconds ?? 600), 24 * 60 * 60));

    if (!channel || !Number.isFinite(uid) || uid <= 0) {
      return new Response(JSON.stringify({ error: "Invalid channel/uid" }), { status: 400, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
    }

    // Auth check: require a valid Supabase JWT.
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authHeader = req.headers.get("Authorization") ?? "";

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
    }

    const now = Math.floor(Date.now() / 1000);
    const privilegeExpire = now + expireSeconds;
    const rtcRole = role === "subscriber" ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;

    // Build token for numeric uid.
    const token = RtcTokenBuilder.buildTokenWithUid(appId, appCert, channel, uid, rtcRole, privilegeExpire);

    return new Response(
      JSON.stringify({ appId, token, channel, uid, expireAt: privilegeExpire }),
      { headers: { ...CORS_HEADERS, "content-type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...CORS_HEADERS, "content-type": "application/json" } });
  }
});
