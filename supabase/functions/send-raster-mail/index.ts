// supabase/functions/send-raster-mail/index.ts
// Sendet den Heineken-Serviceraster (PDF aus dem Bucket raster-pdfs) per Gmail.
// Deploy: supabase functions deploy send-raster-mail   (verify_jwt = true, siehe config.toml)
// Secrets: GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN
//
// Herkunft: Diese Function lag bis 25.09.2026 NUR auf dem Server (v14, seit
// 10.05.2026, nie im Repo) — ohne Auth-Prüfung, und pdfBucket/pdfPath kamen
// ungeprüft aus dem Body: ein offenes Mail-Relay, mit dem sich jede Datei aus
// jedem Bucket per Mail hätte abziehen lassen. v15: Quelle ins Repo,
// JWT-Pflicht (ermittleUserId, Muster send-rechnung-mail v24), nur Bucket
// raster-pdfs, Pfad muss im eigenen Ordner <userId>/… liegen, kein CR/LF in
// Header-Feldern, Dateiname bereinigt.

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

import { bereinigeDateiname, headerSicher, rasterPfadErlaubt } from "./pfad_pruefung.ts";

const GMAIL_SENDER = "sbs.projer@gmail.com";
const ERLAUBTER_BUCKET = "raster-pdfs";

/** Liest den angemeldeten Benutzer aus dem Bearer-JWT über /auth/v1/user. */
async function ermittleUserId(req: Request): Promise<string | null> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) return null;
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) throw new Error("SUPABASE_URL/SUPABASE_ANON_KEY not configured");
  const res = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { "apikey": anonKey, "Authorization": auth },
  });
  if (!res.ok) return null;
  const user = await res.json();
  return typeof user?.id === "string" && user.id.length > 0 ? user.id : null;
}

function bytesToBinary(bytes: Uint8Array): string {
  const chunks: string[] = [];
  const chunkSize = 8192;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    chunks.push(String.fromCharCode(...bytes.subarray(i, Math.min(i + chunkSize, bytes.length))));
  }
  return chunks.join("");
}

function base64url(input: string): string {
  return btoa(bytesToBinary(new TextEncoder().encode(input)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function uint8ToBase64(bytes: Uint8Array): string {
  return btoa(bytesToBinary(bytes));
}

async function getGmailAccessToken(): Promise<string> {
  const clientId = Deno.env.get("GMAIL_CLIENT_ID");
  const clientSecret = Deno.env.get("GMAIL_CLIENT_SECRET");
  const refreshToken = Deno.env.get("GMAIL_REFRESH_TOKEN");
  if (!clientId || !clientSecret || !refreshToken) throw new Error("Gmail OAuth2 credentials not configured");
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: clientId, client_secret: clientSecret, refresh_token: refreshToken, grant_type: "refresh_token" }),
  });
  if (!response.ok) throw new Error(`OAuth2 refresh failed: ${await response.text()}`);
  return (await response.json()).access_token;
}

async function downloadFromStorage(bucket: string, path: string): Promise<Uint8Array | null> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) throw new Error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured");
  const kodiert = path.split("/").map((s) => encodeURIComponent(s)).join("/");
  const url = `${supabaseUrl}/storage/v1/object/${bucket}/${kodiert}`;
  const response = await fetch(url, { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } });
  if (!response.ok) {
    console.error(`Storage download failed: ${bucket}/${path} -> ${response.status}`);
    return null;
  }
  return new Uint8Array(await response.arrayBuffer());
}

function buildMimeMessage(to: string, subject: string, bodyText: string, attachments: Array<{ filename: string; contentType: string; data: Uint8Array }>): string {
  const boundary = `boundary_${crypto.randomUUID().replace(/-/g, "")}`;
  const subjectEncoded = `=?UTF-8?B?${btoa(bytesToBinary(new TextEncoder().encode(subject)))}?=`;
  let mime = `From: ${GMAIL_SENDER}\r\nTo: ${to}\r\nSubject: ${subjectEncoded}\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary="${boundary}"\r\n\r\n`;
  mime += `--${boundary}\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n${uint8ToBase64(new TextEncoder().encode(bodyText))}\r\n`;
  for (const att of attachments) {
    mime += `--${boundary}\r\nContent-Type: ${att.contentType}; name="${att.filename}"\r\nContent-Disposition: attachment; filename="${att.filename}"\r\nContent-Transfer-Encoding: base64\r\n\r\n`;
    const b64 = uint8ToBase64(att.data);
    for (let i = 0; i < b64.length; i += 76) mime += b64.slice(i, i + 76) + "\r\n";
  }
  mime += `--${boundary}--\r\n`;
  return mime;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
  try {
    const userId = await ermittleUserId(req);
    if (!userId) return json({ error: "unauthorized" }, 401);

    const { to, subject, bodyText, pdfBucket, pdfPath, pdfFilename } = await req.json();
    if (!headerSicher(to) || !headerSicher(subject)) return json({ error: "to, subject required (ohne Zeilenumbruch)" }, 400);
    if (pdfBucket !== ERLAUBTER_BUCKET) return json({ error: `nur Bucket ${ERLAUBTER_BUCKET}` }, 400);
    if (!rasterPfadErlaubt(pdfPath, userId)) return json({ error: "pdfPath ungueltig (muss im eigenen Ordner liegen)" }, 400);

    const pdfData = await downloadFromStorage(ERLAUBTER_BUCKET, pdfPath);
    if (!pdfData) return json({ error: "PDF not found in storage" }, 404);

    const attachments = [{ filename: bereinigeDateiname(pdfFilename), contentType: "application/pdf", data: pdfData }];
    const mimeMessage = buildMimeMessage(to, subject, typeof bodyText === "string" ? bodyText : "Siehe Anhang.", attachments);
    const accessToken = await getGmailAccessToken();
    const gmailResponse = await fetch("https://gmail.googleapis.com/gmail/v1/users/me/messages/send", {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({ raw: base64url(mimeMessage) }),
    });
    if (!gmailResponse.ok) {
      return json({ error: `Gmail API error: ${gmailResponse.status}`, details: await gmailResponse.text() }, 502);
    }
    const result = await gmailResponse.json();
    return json({ success: true, messageId: result.id });
  } catch (error) {
    return json({ error: (error as Error).message }, 500);
  }
});
