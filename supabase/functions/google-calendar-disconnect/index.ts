// Supabase Edge Function: google-calendar-disconnect
// Widerruft den Google-Refresh-Token und loescht die Verbindung.
// Deploy: supabase functions deploy google-calendar-disconnect
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
    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "unauthorized" }, 401);

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: row } = await admin
      .from("google_calendar_tokens")
      .select("refresh_token")
      .eq("user_id", user.id)
      .maybeSingle();
    if (row?.refresh_token) {
      try {
        await fetch(
          "https://oauth2.googleapis.com/revoke?token=" +
            encodeURIComponent(row.refresh_token),
          {
            method: "POST",
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
          },
        );
      } catch (_) { /* egal */ }
    }
    await admin.from("google_calendar_tokens").delete().eq("user_id", user.id);
    await admin.from("google_calendar_status").upsert({
      user_id: user.id,
      connected: false,
      google_email: null,
      connected_at: null,
      updated_at: new Date().toISOString(),
    });
    return json({ connected: false });
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message }, 500);
  }
});
