// Supabase Edge Function: send-rechnung-mail
// Sendet E-Mail mit PDF-Anhängen (Rechnung + Protokoll) via Gmail API.
// Deploy: supabase functions deploy send-rechnung-mail --no-verify-jwt
// Secrets: GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const GMAIL_SENDER = "sbs.projer@gmail.com";

/** Uint8Array → binary string (chunk-weise, um Stack Overflow zu vermeiden) */
function bytesToBinary(bytes: Uint8Array): string {
  const chunks: string[] = [];
  const chunkSize = 8192;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, Math.min(i + chunkSize, bytes.length));
    chunks.push(String.fromCharCode(...chunk));
  }
  return chunks.join("");
}

/** Base64url-Kodierung (Gmail API erwartet URL-safe base64 ohne Padding) */
function base64url(input: string): string {
  const bytes = new TextEncoder().encode(input);
  const base64 = btoa(bytesToBinary(bytes));
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Uint8Array → standard base64 (für MIME Content-Transfer-Encoding) */
function uint8ToBase64(bytes: Uint8Array): string {
  return btoa(bytesToBinary(bytes));
}

/** Holt einen frischen Access Token via Refresh Token */
async function getGmailAccessToken(): Promise<string> {
  const clientId = Deno.env.get("GMAIL_CLIENT_ID");
  const clientSecret = Deno.env.get("GMAIL_CLIENT_SECRET");
  const refreshToken = Deno.env.get("GMAIL_REFRESH_TOKEN");

  if (!clientId || !clientSecret || !refreshToken) {
    throw new Error("Gmail OAuth2 credentials not configured (GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN)");
  }

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OAuth2 token refresh failed (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  return data.access_token;
}

/** Lädt eine Datei aus Supabase Storage (via Service Role Key) */
async function downloadFromStorage(bucket: string, path: string): Promise<Uint8Array | null> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceKey) {
    throw new Error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured");
  }

  const url = `${supabaseUrl}/storage/v1/object/${bucket}/${path}`;
  const response = await fetch(url, {
    headers: {
      "apikey": serviceKey,
      "Authorization": `Bearer ${serviceKey}`,
    },
  });

  if (!response.ok) {
    console.error(`Storage download failed for ${bucket}/${path}: ${response.status}`);
    return null;
  }

  const arrayBuffer = await response.arrayBuffer();
  return new Uint8Array(arrayBuffer);
}

/** Baut eine RFC 2822 MIME multipart/mixed E-Mail */
function buildMimeMessage(
  to: string,
  subject: string,
  bodyText: string,
  attachments: Array<{ filename: string; contentType: string; data: Uint8Array }>,
): string {
  const boundary = `boundary_${crypto.randomUUID().replace(/-/g, "")}`;

  // Subject mit UTF-8 Base64-Kodierung (RFC 2047)
  const subjectEncoded = `=?UTF-8?B?${btoa(new TextEncoder().encode(subject).reduce((s, b) => s + String.fromCharCode(b), ""))}?=`;

  let mime = `From: ${GMAIL_SENDER}\r\n`;
  mime += `To: ${to}\r\n`;
  mime += `Subject: ${subjectEncoded}\r\n`;
  mime += `MIME-Version: 1.0\r\n`;
  mime += `Content-Type: multipart/mixed; boundary="${boundary}"\r\n`;
  mime += `\r\n`;

  // Text-Body
  mime += `--${boundary}\r\n`;
  mime += `Content-Type: text/plain; charset=UTF-8\r\n`;
  mime += `Content-Transfer-Encoding: base64\r\n`;
  mime += `\r\n`;
  mime += uint8ToBase64(new TextEncoder().encode(bodyText));
  mime += `\r\n`;

  // Attachments
  for (const att of attachments) {
    mime += `--${boundary}\r\n`;
    mime += `Content-Type: ${att.contentType}; name="${att.filename}"\r\n`;
    mime += `Content-Disposition: attachment; filename="${att.filename}"\r\n`;
    mime += `Content-Transfer-Encoding: base64\r\n`;
    mime += `\r\n`;
    // Base64 in 76-Zeichen-Zeilen aufteilen (RFC 2045)
    const b64 = uint8ToBase64(att.data);
    for (let i = 0; i < b64.length; i += 76) {
      mime += b64.slice(i, i + 76) + "\r\n";
    }
  }

  mime += `--${boundary}--\r\n`;
  return mime;
}

Deno.serve(async (req: Request) => {
  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { to, subject, bodyText, rechnungId, protokollFotoPfad, userId, testMode } = await req.json();

    if (!to || !subject) {
      return new Response(
        JSON.stringify({ error: "to, subject are required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    // Test-Modus: Nur Text-Mail senden (ohne PDF-Anhänge)
    if (testMode) {
      const mimeMessage = buildMimeMessage(to, subject, bodyText ?? "Test", []);
      const accessToken = await getGmailAccessToken();
      const rawMessage = base64url(mimeMessage);
      const gmailResponse = await fetch(
        "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ raw: rawMessage }),
        },
      );
      if (!gmailResponse.ok) {
        const errorText = await gmailResponse.text();
        return new Response(
          JSON.stringify({ error: `Gmail API error: ${gmailResponse.status}`, details: errorText }),
          { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
        );
      }
      const result = await gmailResponse.json();
      return new Response(
        JSON.stringify({ success: true, messageId: result.id, test: true }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    if (!userId) {
      return new Response(
        JSON.stringify({ error: "userId is required" }),
        { status: 400, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    console.log(`Sending mail to ${to}, rechnungId=${rechnungId ?? "none"}, protokoll=${protokollFotoPfad ?? "none"}`);

    const attachments: Array<{ filename: string; contentType: string; data: Uint8Array }> = [];

    // 1. Rechnung-PDF laden (optional — nicht bei HeiGenie-Protokollen)
    if (rechnungId) {
      const rechnungPdf = await downloadFromStorage(
        "rechnung-pdfs",
        `${userId}/${rechnungId}/rechnung.pdf`,
      );

      if (!rechnungPdf) {
        return new Response(
          JSON.stringify({ error: "Rechnung-PDF nicht in Storage gefunden" }),
          { status: 404, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
        );
      }

      attachments.push({ filename: "Rechnung.pdf", contentType: "application/pdf", data: rechnungPdf });
    }

    // 2. Protokoll-Foto laden (optional)
    if (protokollFotoPfad) {
      const protokollData = await downloadFromStorage("reinigung-fotos", protokollFotoPfad);
      if (protokollData) {
        // Dateiendung erkennen für Content-Type
        const ext = protokollFotoPfad.split(".").pop()?.toLowerCase();
        const isImage = ["jpg", "jpeg", "png", "webp"].includes(ext ?? "");
        attachments.push({
          filename: isImage ? `Reinigungsprotokoll.${ext}` : "Reinigungsprotokoll.pdf",
          contentType: isImage ? `image/${ext === "jpg" ? "jpeg" : ext}` : "application/pdf",
          data: protokollData,
        });
      } else {
        console.warn(`Protokoll-Foto nicht gefunden: ${protokollFotoPfad}`);
      }
    }

    console.log(`Attachments: ${attachments.map((a) => `${a.filename} (${Math.round(a.data.length / 1024)} KB)`).join(", ")}`);

    // 2. MIME-Email bauen
    const mimeMessage = buildMimeMessage(to, subject, bodyText ?? "Rechnung im Anhang.", attachments);

    // 3. Gmail Access Token holen
    const accessToken = await getGmailAccessToken();

    // 4. Via Gmail API senden (raw MIME base64url-encoded)
    const rawMessage = base64url(mimeMessage);

    const gmailResponse = await fetch(
      "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ raw: rawMessage }),
      },
    );

    if (!gmailResponse.ok) {
      const errorText = await gmailResponse.text();
      console.error(`Gmail API error ${gmailResponse.status}: ${errorText}`);
      return new Response(
        JSON.stringify({ error: `Gmail API error: ${gmailResponse.status}`, details: errorText }),
        { status: 502, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
      );
    }

    const result = await gmailResponse.json();
    console.log(`Email sent successfully, messageId: ${result.id}`);

    return new Response(
      JSON.stringify({ success: true, messageId: result.id }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  } catch (error) {
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    return new Response(
      JSON.stringify({ error: `Fehler: ${msg}` }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  }
});
