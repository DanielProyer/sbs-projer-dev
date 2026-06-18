// supabase/functions/send-pdf-mail/index.ts
// Sendet eine E-Mail mit einem inline übergebenen PDF (base64) via Gmail API.
// Deploy: supabase functions deploy send-pdf-mail --no-verify-jwt
// Secrets: GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN

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
    const { to, subject, bodyText, filename, pdfBase64 } = await req.json();
    if (!to || !subject || !pdfBase64) {
      return new Response(JSON.stringify({ error: "to, subject, pdfBase64 required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } });
    }
    const mime = buildMime(to, subject, bodyText ?? "Bericht im Anhang.", filename ?? "Bericht.pdf", b64ToBytes(pdfBase64));
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
