// parse-dokument: Request-Handler mit eingespeisten Abhängigkeiten
// (Benutzerprüfung, API-Key, Messages API) — `deno test`. Kein Netz, kein
// Supabase: prüft Statuscodes und was an die Messages API ginge.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { type Deps, handle } from "./handler.ts";

const KATALOG = {
  bereiche: ["steuern", "bank", "sonstiges"],
  typen: {
    steuern: ["veranlagung", "zinsausweis", "sonstiges"],
    bank: ["zinsausweis", "sonstiges"],
    sonstiges: ["brief", "sonstiges"],
  },
  kategorien: { steuern: ["bund", "kanton"] },
};

const PDF = {
  datei_base64: "JVBERi0xLjQ=",
  media_type: "application/pdf",
  ...KATALOG,
};

function modellAntwort(text: string, status = 200): Response {
  return new Response(
    JSON.stringify({ content: [{ type: "text", text }] }),
    { status, headers: { "Content-Type": "application/json" } },
  );
}

const ZINSAUSWEIS = JSON.stringify({
  bereich: "steuern",
  typ: "zinsausweis",
  jahr: 2025,
  titel: "Zins- und Kapitalausweis GKB per 31.12.2025",
  dateiname: "2025_GKB_Zins-Kapitalausweis",
  zuversicht: 0.93,
  felder: { saldo_31_12: 10869.26 },
});

/** Abhängigkeiten, die alles erlauben; [gesendet] hält die API-Anfragen. */
function deps(over: Partial<Deps> = {}) {
  const gesendet: Record<string, unknown>[] = [];
  const autorisierung: string[] = [];
  const d: Deps = {
    benutzer: (authorization) => {
      autorisierung.push(authorization);
      return Promise.resolve({ id: "u1" });
    },
    apiKey: "sk-test",
    anthropic: (body) => {
      gesendet.push(body as Record<string, unknown>);
      return Promise.resolve(modellAntwort(ZINSAUSWEIS));
    },
    ...over,
  };
  return { d, gesendet, autorisierung };
}

function anfrage(body: unknown): Request {
  return new Request("http://localhost/parse-dokument", {
    method: "POST",
    headers: {
      "Authorization": "Bearer nutzer-jwt",
      "Content-Type": "application/json",
    },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function json(r: Response): Promise<Record<string, unknown>> {
  return await r.json();
}

Deno.test("OPTIONS (CORS-Preflight) → 200 ohne Prüfung", async () => {
  const { d, autorisierung } = deps();
  const r = await handle(
    new Request("http://localhost/parse-dokument", { method: "OPTIONS" }),
    d,
  );
  assertEquals(r.status, 200);
  assertEquals(await r.text(), "ok");
  assertEquals(autorisierung, []);
});

Deno.test("200: Ergebnis normalisiert, Anfrage an die Messages API stimmt", async () => {
  const { d, gesendet, autorisierung } = deps();
  const r = await handle(anfrage(PDF), d);
  assertEquals(r.status, 200);
  const b = await json(r);
  assertEquals(b.ok, true);
  const e = b.ergebnis as Record<string, unknown>;
  assertEquals(e.typ, "zinsausweis");
  assertEquals(e.jahr, 2025);
  assertEquals(e.dateiname, "2025_GKB_Zins-Kapitalausweis.pdf");
  assertEquals(autorisierung, ["Bearer nutzer-jwt"]);

  assertEquals(gesendet.length, 1);
  assertEquals(gesendet[0].model, "claude-sonnet-4-6");
  const inhalt = (gesendet[0].messages as { content: unknown[] }[])[0]
    .content as Record<string, unknown>[];
  assertEquals(inhalt[0].type, "document");
  assertEquals(
    (inhalt[0].source as Record<string, unknown>).media_type,
    "application/pdf",
  );
  assertEquals(inhalt[1].type, "text");
});

Deno.test("Bild geht als image-Block", async () => {
  const { d, gesendet } = deps();
  const r = await handle(
    anfrage({ ...PDF, media_type: "image/png" }),
    d,
  );
  assertEquals(r.status, 200);
  const inhalt = (gesendet[0].messages as { content: unknown[] }[])[0]
    .content as Record<string, unknown>[];
  assertEquals(inhalt[0].type, "image");
  assertEquals(
    ((await json(r)).ergebnis as Record<string, unknown>).dateiname,
    "2025_GKB_Zins-Kapitalausweis.png",
  );
});

Deno.test("401: ohne eingeloggten Benutzer, keine API-Anfrage", async () => {
  const { d, gesendet } = deps({ benutzer: () => Promise.resolve(null) });
  const r = await handle(anfrage(PDF), d);
  assertEquals(r.status, 401);
  assertEquals((await json(r)).ok, false);
  assertEquals(gesendet, []);
});

Deno.test("500: ANTHROPIC_API_KEY fehlt", async () => {
  const { d, gesendet } = deps({ apiKey: undefined });
  const r = await handle(anfrage(PDF), d);
  assertEquals(r.status, 500);
  assertEquals(gesendet, []);
});

Deno.test("400: kaputter Body, fehlende Datei, falscher Typ, kein Katalog", async () => {
  const faelle: unknown[] = [
    "{kein json",
    { ...PDF, datei_base64: "" },
    { ...PDF, media_type: "image/heic" },
    { datei_base64: "JVBE", media_type: "application/pdf" },
    { ...PDF, bereiche: ["Steuern und so"] },
  ];
  for (const body of faelle) {
    const { d, gesendet } = deps();
    const r = await handle(anfrage(body), d);
    assertEquals(r.status, 400, JSON.stringify(body).slice(0, 80));
    assertEquals((await json(r)).ok, false);
    assertEquals(gesendet, []);
  }
});

Deno.test("413: Bild über 5 MB base64", async () => {
  const { d, gesendet } = deps();
  const r = await handle(
    anfrage({
      ...PDF,
      media_type: "image/jpeg",
      datei_base64: "A".repeat(5 * 1024 * 1024 + 4),
    }),
    d,
  );
  assertEquals(r.status, 413);
  assertEquals(gesendet, []);
});

Deno.test("502: API-Fehler, keine Textantwort, kein JSON", async () => {
  const antworten = [
    () => modellAntwort("überlastet", 529),
    () =>
      new Response(JSON.stringify({ content: [] }), {
        headers: { "Content-Type": "application/json" },
      }),
    () => modellAntwort("Das Dokument ist eine Rechnung."),
  ];
  for (const a of antworten) {
    const { d } = deps({ anthropic: () => Promise.resolve(a()) });
    const r = await handle(anfrage(PDF), d);
    assertEquals(r.status, 502);
    assertEquals((await json(r)).ok, false);
  }
});

Deno.test("504: Abbruch nach dem Timeout", async () => {
  const { d } = deps({
    timeoutMs: 5,
    anthropic: (_body, signal) =>
      new Promise((_, reject) => {
        signal.addEventListener("abort", () =>
          reject(
            new DOMException("The signal has been aborted", "AbortError"),
          ));
      }),
  });
  const r = await handle(anfrage(PDF), d);
  assertEquals(r.status, 504);
  const b = await json(r);
  assertEquals(b.ok, false);
  assert(String(b.error).startsWith("Timeout"));
});
