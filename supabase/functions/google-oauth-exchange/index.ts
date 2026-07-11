// Supabase Edge Function: google-oauth-exchange
// Tauscht OAuth-Code (PKCE) gegen Tokens und speichert den Refresh-Token server-seitig.
// Deploy: supabase functions deploy google-oauth-exchange
// Secrets: GOOGLE_OAUTH_CLIENT_ID, GOOGLE_OAUTH_CLIENT_SECRET
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const json = (b: unknown, s = 200) =>
    new Response(JSON.stringify(b), {
      status: s,
      headers: { ...CORS, "Content-Type": "application/json" },
    });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const clientId = Deno.env.get("GOOGLE_OAUTH_CLIENT_ID");
    const clientSecret = Deno.env.get("GOOGLE_OAUTH_CLIENT_SECRET");
    if (!clientId || !clientSecret) {
      return json({ error: "OAuth not configured" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const { code, code_verifier, redirect_uri } = await req.json();
    if (!code || !code_verifier || !redirect_uri) {
      return json({ error: "missing params" }, 400);
    }

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri,
        grant_type: "authorization_code",
        code_verifier,
      }),
    });
    const token = await tokenRes.json();
    if (!tokenRes.ok || !token.refresh_token) {
      console.error("token exchange failed", token);
      return json(
        { error: token.error_description || token.error || "no refresh_token" },
        502,
      );
    }

    let email: string | null = null;
    try {
      const infoRes = await fetch(
        "https://www.googleapis.com/oauth2/v2/userinfo",
        { headers: { Authorization: `Bearer ${token.access_token}` } },
      );
      if (infoRes.ok) email = (await infoRes.json()).email ?? null;
    } catch (_) { /* egal */ }

    const now = new Date().toISOString();
    const expiry = new Date(Date.now() + (token.expires_in ?? 3600) * 1000)
      .toISOString();
    const admin = createClient(supabaseUrl, serviceKey);
    await admin.from("google_calendar_tokens").upsert({
      user_id: user.id,
      refresh_token: token.refresh_token,
      access_token: token.access_token,
      access_token_expiry: expiry,
      google_email: email,
      scope: token.scope,
      updated_at: now,
    });
    await admin.from("google_calendar_status").upsert({
      user_id: user.id,
      connected: true,
      google_email: email,
      connected_at: now,
      updated_at: now,
    });
    return json({ connected: true, email });
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message }, 500);
  }
});
