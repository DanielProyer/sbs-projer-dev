// Edge-Wächter (Analyse 25.09.2026, R11/Q3) — `deno test --allow-read`
//
// 1. Jede Function unter supabase/functions/<name>/index.ts prüft den
//    Aufrufer selbst: `auth.getUser(`, `ermittleUserId(` oder `x-cron-secret`.
//    verify_jwt am Gateway allein reicht NICHT — der öffentliche Anon-Key ist
//    ein gültiges JWT. Bis 25.09.2026 waren sieben Functions so offen
//    (Mail-Relay, Claude-Proxy, SSRF, Google-Kosten).
// 2. Jeder `functions.invoke('<name>'` in sbs_projer_app/lib hat einen
//    Quellordner hier — sonst läuft in Produktion Code, den niemand prüfen
//    kann.
// 3. Jede Function hat in supabase/config.toml einen `[functions.<name>]`-
//    Eintrag (sonst bestimmt der Deploy-Befehl von Hand, ob JWT-Pflicht gilt).

import { assert, assertEquals } from "jsr:@std/assert@1";
import { fromFileUrl, join } from "jsr:@std/path@1";

const FUNCTIONS_DIR = fromFileUrl(new URL(".", import.meta.url));
const REPO_ROOT = join(FUNCTIONS_DIR, "..", "..");
const APP_LIB = join(REPO_ROOT, "sbs_projer_app", "lib");
const CONFIG_TOML = join(REPO_ROOT, "supabase", "config.toml");

const AUTH_MUSTER = ["auth.getUser(", "ermittleUserId(", "x-cron-secret"];

/**
 * Von der App aufgerufen, aber ohne Quellcode im Repo. Jeder Eintrag ist eine
 * bekannte Lücke, kein Freibrief: Sobald der Ordner existiert, schlägt der
 * Test fehl, bis der Eintrag hier entfernt ist.
 */
const BEKANNT_OHNE_QUELLE: Record<string, string> = {
  // leer seit 25.09.2026: send-raster-mail ist jetzt im Repo (v15)
};

function functionNamen(): string[] {
  const namen: string[] = [];
  for (const e of Deno.readDirSync(FUNCTIONS_DIR)) {
    if (!e.isDirectory || e.name.startsWith("_") || e.name.startsWith(".")) continue;
    try {
      Deno.statSync(join(FUNCTIONS_DIR, e.name, "index.ts"));
      namen.push(e.name);
    } catch (_) {
      // Ordner ohne index.ts ist keine Function
    }
  }
  return namen.sort();
}

function* dartDateien(dir: string): Generator<string> {
  for (const e of Deno.readDirSync(dir)) {
    const pfad = join(dir, e.name);
    if (e.isDirectory) yield* dartDateien(pfad);
    else if (e.name.endsWith(".dart")) yield pfad;
  }
}

Deno.test("es gibt Functions (Pfad-Sanity)", () => {
  assert(functionNamen().length >= 10, `zu wenige Functions in ${FUNCTIONS_DIR}`);
});

Deno.test("jede Function prüft den Aufrufer selbst", () => {
  const ohne: string[] = [];
  for (const name of functionNamen()) {
    const code = Deno.readTextFileSync(join(FUNCTIONS_DIR, name, "index.ts"));
    if (!AUTH_MUSTER.some((m) => code.includes(m))) ohne.push(name);
  }
  assertEquals(
    ohne,
    [],
    `Ohne eigene Benutzerprüfung (${AUTH_MUSTER.join(" / ")}): ${ohne.join(", ")}`,
  );
});

Deno.test("jeder functions.invoke der App hat einen Quellordner", () => {
  const vorhanden = new Set(functionNamen());
  const re = /functions\.invoke\(\s*['"]([a-z0-9_-]+)['"]/g;
  const aufgerufen = new Map<string, string>();
  for (const datei of dartDateien(APP_LIB)) {
    const code = Deno.readTextFileSync(datei);
    for (const m of code.matchAll(re)) {
      if (!aufgerufen.has(m[1])) aufgerufen.set(m[1], datei.slice(REPO_ROOT.length + 1));
    }
  }
  assert(aufgerufen.size >= 5, "keine functions.invoke-Aufrufe gefunden — Pfad falsch?");

  const fehlend: string[] = [];
  for (const [name, datei] of aufgerufen) {
    if (vorhanden.has(name) || name in BEKANNT_OHNE_QUELLE) continue;
    fehlend.push(`${name} (${datei})`);
  }
  assertEquals(fehlend, [], `App ruft Functions ohne Quellcode auf: ${fehlend.join(", ")}`);

  // Ausnahmeliste aktuell halten
  const veraltet = Object.keys(BEKANNT_OHNE_QUELLE).filter((n) => vorhanden.has(n) || !aufgerufen.has(n));
  assertEquals(veraltet, [], `BEKANNT_OHNE_QUELLE aufräumen: ${veraltet.join(", ")}`);
});

Deno.test("jede Function hat einen [functions.<name>]-Eintrag in config.toml", () => {
  const toml = Deno.readTextFileSync(CONFIG_TOML);
  const eintraege = new Set(
    [...toml.matchAll(/^\s*\[functions\.([a-z0-9_-]+)\]\s*$/gm)].map((m) => m[1]),
  );
  const fehlend = functionNamen().filter((n) => !eintraege.has(n));
  assertEquals(fehlend, [], `Ohne [functions.<name>] in config.toml: ${fehlend.join(", ")}`);

  // Eintrag ohne Ordner = Tippfehler oder gelöschte Function
  const verwaist = [...eintraege].filter((n) => !functionNamen().includes(n));
  assertEquals(verwaist, [], `config.toml nennt Functions ohne Ordner: ${verwaist.join(", ")}`);
});
