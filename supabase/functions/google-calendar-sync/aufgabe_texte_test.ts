import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { aufgabeTexte } from "./aufgabe_texte.ts";

Deno.test("ohne Betrieb: Titel wie vor Migration 212, kein Ort", () => {
  const t = aufgabeTexte({ titel: "Hahn mitnehmen" });
  assertEquals(t.summary, "SBS · Aufgabe: Hahn mitnehmen");
  assertEquals(t.location, undefined);
});

Deno.test("ohne Betrieb: Ereignis serialisiert byte-gleich wie bisher (kein neuer Hash)", () => {
  // Bestehende Kalendereintraege duerfen durch die Umstellung nicht alle
  // neu geschrieben werden: content_hash = sha256(JSON.stringify(ev)).
  const vorher = { summary: "SBS · Aufgabe: X", start: { date: "2026-10-01" } };
  const { summary, location } = aufgabeTexte({ titel: "X" });
  const nachher = { summary, location, start: { date: "2026-10-01" } };
  assertEquals(JSON.stringify(nachher), JSON.stringify(vorher));
});

Deno.test("mit Betrieb und voller Adresse", () => {
  const t = aufgabeTexte({
    titel: "Hahn mitnehmen",
    betrieb_name: "Rössli",
    betrieb_strasse: "Dorfstrasse",
    betrieb_nr: "5",
    betrieb_plz: "7000",
    betrieb_ort: "Chur",
  });
  assertEquals(t.summary, "SBS · Aufgabe: Hahn mitnehmen · Rössli");
  assertEquals(t.location, "Rössli, Dorfstrasse 5, 7000 Chur");
});

Deno.test("mit Betrieb, Adresse lueckenhaft: nur vorhandene Teile", () => {
  const t = aufgabeTexte({
    titel: "Offerte",
    betrieb_name: "Bären",
    betrieb_strasse: "Hauptstrasse",
    betrieb_nr: null,
    betrieb_plz: null,
    betrieb_ort: "Davos",
  });
  assertEquals(t.location, "Bären, Hauptstrasse, Davos");
});

Deno.test("mit Betrieb ohne Adresse: Ort ist nur der Name", () => {
  const t = aufgabeTexte({ titel: "Anrufen", betrieb_name: "Krone" });
  assertEquals(t.summary, "SBS · Aufgabe: Anrufen · Krone");
  assertEquals(t.location, "Krone");
});

Deno.test("leerer Betriebsname haengt nichts an den Titel", () => {
  const t = aufgabeTexte({ titel: "X", betrieb_name: "  ", betrieb_ort: "Chur" });
  assertEquals(t.summary, "SBS · Aufgabe: X");
  assertEquals(t.location, "Chur");
});
