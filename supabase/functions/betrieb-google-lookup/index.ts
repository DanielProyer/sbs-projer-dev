// Supabase Edge Function: betrieb-google-lookup
// Sucht einen Betrieb via Google Places API (New) Text Search und gibt das
// beste rohe Place-Objekt zurueck. Der API-Key bleibt server-seitig.
// Deploy: supabase functions deploy betrieb-google-lookup --no-verify-jwt
// Secret: supabase secrets set GOOGLE_PLACES_KEY=...

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const FIELD_MASK = [
  "places.displayName",
  "places.formattedAddress",
  "places.addressComponents",
  "places.internationalPhoneNumber",
  "places.nationalPhoneNumber",
  "places.websiteUri",
  "places.location",
  "places.regularOpeningHours",
  "places.googleMapsUri",
].join(",");

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });

  try {
    const apiKey = Deno.env.get("GOOGLE_PLACES_KEY");
    if (!apiKey) {
      return json({ error: "GOOGLE_PLACES_KEY not configured" }, 500);
    }

    const { query } = await req.json();
    if (!query || typeof query !== "string" || query.trim().length === 0) {
      return json({ error: "query is required" }, 400);
    }

    const response = await fetch(
      "https://places.googleapis.com/v1/places:searchText",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask": FIELD_MASK,
        },
        body: JSON.stringify({
          textQuery: query,
          languageCode: "de",
          regionCode: "CH",
        }),
      },
    );

    if (!response.ok) {
      const details = await response.text();
      console.error(`Places API error ${response.status}: ${details}`);
      return json(
        { error: `Places API error: ${response.status}`, details },
        502,
      );
    }

    const data = await response.json();
    const place = Array.isArray(data.places) ? data.places[0] : null;
    if (!place) {
      return json({ error: "no_result" }, 200);
    }
    return json({ place });
  } catch (error) {
    const msg = (error as Error).message;
    console.error("Function error:", msg);
    return json({ error: `Fehler: ${msg}` }, 500);
  }
});
