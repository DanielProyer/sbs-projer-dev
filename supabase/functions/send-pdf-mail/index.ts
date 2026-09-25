// supabase/functions/send-pdf-mail/index.ts
// Sendet eine E-Mail mit einem inline übergebenen PDF (base64) via Gmail API.
// Deploy: supabase functions deploy send-pdf-mail   (verify_jwt = true, siehe config.toml)
// Secrets: GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN
//
// Sicherheit (v2, 25.09.2026): Bis dahin lief die Function ohne jede
// Auth-Prüfung — ein offenes Mail-Relay über Daniels Gmail mit beliebigem
// Anhang. Jetzt: User-JWT wird selbst geprüft (`ermittleUserId`, gleiches
// Muster wie send-rechnung-mail v24), `to`/`subject`/`filename` dürfen
// keine Zeilenumbrüche enthalten (Header-Injection), der Dateiname wird
// bereinigt. Die App schickt das JWT automatisch über `functions.invoke`.

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

/** Kein CR/LF in Header-Feldern — sonst liessen sich Bcc:/weitere Header einschleusen. */
function headerSicher(wert: unknown): wert is string {
  return typeof wert === "string" && wert.length > 0 && wert.length <= 500 && !/[\r\n]/.test(wert);
}

/** Dateiname für Content-Disposition: nur [A-Za-z0-9._ -], Endung .pdf erzwungen, max. 80 Zeichen. */
function bereinigeDateiname(name: unknown): string {
  let s = (typeof name === "string" ? name : "Bericht.pdf")
    .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue")
    .replace(/Ä/g, "Ae").replace(/Ö/g, "Oe").replace(/Ü/g, "Ue").replace(/ß/g, "ss")
    .replace(/[^A-Za-z0-9._ -]/g, "_").trim();
  if (s.length === 0) s = "Bericht";
  if (!s.toLowerCase().endsWith(".pdf")) s = `${s.replace(/\.[A-Za-z0-9]{1,5}$/, "")}.pdf`;
  if (s.length > 80) s = `${s.slice(0, 76)}.pdf`;
  return s;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const GMAIL_SENDER = "sbs.projer@gmail.com";

function bytesToBinary(bytes: Uint8Array): string {
  const chunks: string[] = [];
  for (let i = 0; i < bytes.length; i += 8192) {
    chunks.push(String.fromCharCode(...bytes.subarray(i, Math.min(i + 8192, bytes.length))));
  }
  return chunks.join("");
}
function base64url(input: string): string {
  return btoa(bytesToBinary(new TextEncoder().encode(input)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
async function getGmailAccessToken(): Promise<string> {
  const clientId = Deno.env.get("GMAIL_CLIENT_ID");
  const clientSecret = Deno.env.get("GMAIL_CLIENT_SECRET");
  const refreshToken = Deno.env.get("GMAIL_REFRESH_TOKEN");
  if (!clientId || !clientSecret || !refreshToken) throw new Error("Gmail OAuth2 credentials not configured");
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: clientId, client_secret: clientSecret, refresh_token: refreshToken, grant_type: "refresh_token" }),
  });
  if (!r.ok) throw new Error(`OAuth2 token refresh failed (${r.status}): ${await r.text()}`);
  return (await r.json()).access_token;
}
function buildMime(to: string, subject: string, bodyText: string, filename: string, pdf: Uint8Array): string {
  const boundary = `b_${crypto.randomUUID().replace(/-/g, "")}`;
  const subjEnc = `=?UTF-8?B?${btoa(bytesToBinary(new TextEncoder().encode(subject)))}?=`;
  let mime = `From: ${GMAIL_SENDER}\r\nTo: ${to}\r\nSubject: ${subjEnc}\r\nMIME-Version: 1.0\r\n`;
  mime += `Content-Type: multipart/mixed; boundary="${boundary}"\r\n\r\n`;
  mime += `--${boundary}\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n`;
  mime += btoa(bytesToBinary(new TextEncoder().encode(bodyText))) + `\r\n`;
  mime += `--${boundary}\r\nContent-Type: application/pdf; name="${filename}"\r\n`;
  mime += `Content-Disposition: attachment; filename="${filename}"\r\nContent-Transfer-Encoding: base64\r\n\r\n`;
  const b64 = btoa(bytesToBinary(pdf));
  for (let i = 0; i < b64.length; i += 76) mime += b64.slice(i, i + 76) + "\r\n";
  mime += `--${boundary}--\r\n`;
  return mime;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  try {
    const userId = await ermittleUserId(req);
    if (!userId) {
      return new Response(JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }
    const { to, subject, bodyText, filename, pdfBase64 } = await req.json();
    if (!headerSicher(to) || !headerSicher(subject) || typeof pdfBase64 !== "string" || pdfBase64.length === 0) {
      return new Response(JSON.stringify({ error: "to, subject (ohne Zeilenumbruch), pdfBase64 required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }
    if (pdfBase64.length > 20_000_000) {
      return new Response(JSON.stringify({ error: "PDF zu gross" }),
        { status: 413, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }
    const mime = buildMime(to, subject, typeof bodyText === "string" ? bodyText : "Bericht im Anhang.", bereinigeDateiname(filename), b64ToBytes(pdfBase64));
    const token = await getGmailAccessToken();
    const resp = await fetch("https://gmail.googleapis.com/gmail/v1/users/me/messages/send", {
      method: "POST",
      headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ raw: base64url(mime) }),
    });
    if (!resp.ok) {
      return new Response(JSON.stringify({ error: `Gmail API error: ${resp.status}`, details: await resp.text() }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ success: true, messageId: (await resp.json()).id }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: `Fehler: ${(e as Error).message}` }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
  }
});
