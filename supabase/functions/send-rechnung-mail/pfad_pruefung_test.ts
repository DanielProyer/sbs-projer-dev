import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  bereinigeDateiname,
  kodierePfad,
  zusatzPdfPfadErlaubt,
} from "./pfad_pruefung.ts";

const USER = "11111111-1111-1111-1111-111111111111";
const RECHNUNG = "22222222-2222-2222-2222-222222222222";

Deno.test("zusatzPdfPfadErlaubt: gewöhnlicher eigener Pfad ist erlaubt", () => {
  assertEquals(
    zusatzPdfPfadErlaubt(`${USER}/${RECHNUNG}/mahnschreiben.pdf`, USER),
    true,
  );
});

Deno.test("zusatzPdfPfadErlaubt: fremder erster Ordner wird abgelehnt", () => {
  assertEquals(
    zusatzPdfPfadErlaubt(`anderer-user/${RECHNUNG}/mahnschreiben.pdf`, USER),
    false,
  );
});

Deno.test("zusatzPdfPfadErlaubt: .. bricht aus dem Ordner aus — abgelehnt", () => {
  assertEquals(
    zusatzPdfPfadErlaubt(`${USER}/../anderer-user/mahnschreiben.pdf`, USER),
    false,
  );
  assertEquals(zusatzPdfPfadErlaubt(`${USER}/..`, USER), false);
});

Deno.test("zusatzPdfPfadErlaubt: führender Slash wird abgelehnt", () => {
  assertEquals(
    zusatzPdfPfadErlaubt(`/${USER}/${RECHNUNG}/mahnschreiben.pdf`, USER),
    false,
  );
});

Deno.test("zusatzPdfPfadErlaubt: Backslash wird abgelehnt", () => {
  assertEquals(
    zusatzPdfPfadErlaubt(`${USER}\\${RECHNUNG}\\mahnschreiben.pdf`, USER),
    false,
  );
});

Deno.test("zusatzPdfPfadErlaubt: Prozent-Kodierung wird abgelehnt (Doppel-Encoding-Trick)", () => {
  assertEquals(
    zusatzPdfPfadErlaubt(`${USER}/${RECHNUNG}/%2e%2e/mahnschreiben.pdf`, USER),
    false,
  );
});

Deno.test("zusatzPdfPfadErlaubt: leere Segmente (Doppel-Slash) werden abgelehnt", () => {
  assertEquals(
    zusatzPdfPfadErlaubt(`${USER}//mahnschreiben.pdf`, USER),
    false,
  );
});

Deno.test("zusatzPdfPfadErlaubt: nur Benutzer-Ordner ohne Datei wird abgelehnt", () => {
  assertEquals(zusatzPdfPfadErlaubt(USER, USER), false);
});

Deno.test("zusatzPdfPfadErlaubt: unerlaubte Zeichen im Dateinamen werden abgelehnt", () => {
  assertEquals(
    zusatzPdfPfadErlaubt(`${USER}/${RECHNUNG}/mahn schreiben.pdf`, USER),
    false,
  );
  assertEquals(
    zusatzPdfPfadErlaubt(`${USER}/${RECHNUNG}/mähnschreiben.pdf`, USER),
    false,
  );
});

Deno.test("zusatzPdfPfadErlaubt: kein String -> abgelehnt", () => {
  assertEquals(zusatzPdfPfadErlaubt(null, USER), false);
  assertEquals(zusatzPdfPfadErlaubt(undefined, USER), false);
  assertEquals(zusatzPdfPfadErlaubt(42, USER), false);
});

Deno.test("kodierePfad: gewöhnlicher Pfad bleibt unverändert", () => {
  assertEquals(
    kodierePfad(`${USER}/${RECHNUNG}/rechnung.pdf`),
    `${USER}/${RECHNUNG}/rechnung.pdf`,
  );
});

Deno.test("kodierePfad: Leerzeichen und Umlaute werden je Segment kodiert, Slashes bleiben Trenner", () => {
  const codiert = kodierePfad(`${USER}/Protokoll Müller.jpg`);
  assertEquals(codiert, `${USER}/${encodeURIComponent("Protokoll Müller.jpg")}`);
  // Der Trenner selbst darf nicht mitkodiert werden (sonst zwei falsche Segmente).
  assertEquals(codiert.split("/").length, 2);
});

Deno.test("bereinigeDateiname: Umlaute werden transkribiert", () => {
  assertEquals(bereinigeDateiname("Mahnschreiben Müller.pdf"), "Mahnschreiben Mueller.pdf");
});

Deno.test("bereinigeDateiname: erzwingt .pdf, ersetzt andere Endung", () => {
  assertEquals(bereinigeDateiname("Anhang.exe"), "Anhang.pdf");
  assertEquals(bereinigeDateiname("Anhang ohne Endung"), "Anhang ohne Endung.pdf");
});

Deno.test("bereinigeDateiname: Schrägstriche werden ersetzt (Punkte bleiben erlaubt)", () => {
  assertEquals(bereinigeDateiname("Rechnung/../geheim.pdf"), "Rechnung_.._geheim.pdf");
});

Deno.test("bereinigeDateiname: wird auf 80 Zeichen inkl. .pdf gekappt", () => {
  const lang = "A".repeat(200);
  const ergebnis = bereinigeDateiname(`${lang}.pdf`);
  assertEquals(ergebnis.length, 80);
  assertEquals(ergebnis.endsWith(".pdf"), true);
});

Deno.test("bereinigeDateiname: leerer Name ergibt trotzdem ein gültiges .pdf", () => {
  assertEquals(bereinigeDateiname(""), "Dokument.pdf");
});
