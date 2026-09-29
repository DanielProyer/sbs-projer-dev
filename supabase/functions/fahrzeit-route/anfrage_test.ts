// Body-Pruefung von fahrzeit-route (Migration 213) -- `deno test`.

import { assertEquals } from "jsr:@std/assert@1";
import { anfrageLesen, endeLesen } from "./anfrage.ts";

// Betriebs-Ids sind UUIDs (betriebe.id) -- alles andere ist ein 400.
const A = "0b7c1e2a-1111-4222-8333-444455556666";
const B = "9f3d2c1b-aaaa-4bbb-9ccc-ddddeeeeffff";

Deno.test("altes Format {vonBetriebId, nachBetriebId} bleibt gueltig", () => {
  assertEquals(anfrageLesen({ vonBetriebId: A, nachBetriebId: B }), {
    von: { art: "betrieb", betriebId: A },
    nach: { art: "betrieb", betriebId: B },
  });
});

Deno.test("neues Format: Punkt -> Betrieb", () => {
  assertEquals(
    anfrageLesen({ von: { lat: 47.37, lng: 8.54 }, nach: { betriebId: B } }),
    {
      von: { art: "punkt", lat: 47.37, lng: 8.54 },
      nach: { art: "betrieb", betriebId: B },
    },
  );
});

Deno.test("neues Format: Punkt -> Punkt", () => {
  assertEquals(
    anfrageLesen({
      von: { lat: 46.8328452, lng: 9.4529918 },
      nach: { lat: 46.8639692, lng: 9.5278708 },
    }),
    {
      von: { art: "punkt", lat: 46.8328452, lng: 9.4529918 },
      nach: { art: "punkt", lat: 46.8639692, lng: 9.5278708 },
    },
  );
});

// Die App ab 213 schickt Betrieb -> Betrieb in BEIDEN Formaten, damit sie im
// Rollout-Fenster auch gegen die alte Function laeuft. Die neue liest
// von/nach zuerst; das alte Format muss dasselbe sagen.
Deno.test("beide Formate, gleicher Inhalt -> Betriebspaar", () => {
  assertEquals(
    anfrageLesen({
      von: { betriebId: A },
      nach: { betriebId: B },
      vonBetriebId: A,
      nachBetriebId: B,
    }),
    {
      von: { art: "betrieb", betriebId: A },
      nach: { art: "betrieb", betriebId: B },
    },
  );
});

Deno.test("beide Formate, Widerspruch -> abgelehnt", () => {
  // Vertauscht.
  assertEquals(
    anfrageLesen({
      von: { betriebId: A },
      nach: { betriebId: B },
      vonBetriebId: B,
      nachBetriebId: A,
    }),
    null,
  );
  // Neu sagt Punkt, alt sagt Betrieb.
  assertEquals(
    anfrageLesen({
      von: { lat: 47.37, lng: 8.54 },
      nach: { betriebId: B },
      vonBetriebId: A,
      nachBetriebId: B,
    }),
    null,
  );
  // Altes Format selbst ungueltig.
  assertEquals(
    anfrageLesen({
      von: { betriebId: A },
      nach: { betriebId: B },
      vonBetriebId: "kaputt",
      nachBetriebId: B,
    }),
    null,
  );
});

Deno.test("zweimal derselbe Betrieb -> abgelehnt (wie vor 213)", () => {
  assertEquals(anfrageLesen({ vonBetriebId: A, nachBetriebId: A }), null);
  assertEquals(
    anfrageLesen({ von: { betriebId: A }, nach: { betriebId: A } }),
    null,
  );
});

Deno.test("fehlende oder leere Enden -> abgelehnt", () => {
  assertEquals(anfrageLesen({}), null);
  assertEquals(anfrageLesen(null), null);
  assertEquals(anfrageLesen({ vonBetriebId: A }), null);
  assertEquals(anfrageLesen({ vonBetriebId: "", nachBetriebId: B }), null);
  assertEquals(
    anfrageLesen({ von: { betriebId: "" }, nach: { betriebId: B } }),
    null,
  );
});

// Vorher lief eine Nicht-UUID bis in die Abfrage und kam als 500 db_error
// zurueck -- es ist aber eine falsche Anfrage, kein Datenbankfehler.
Deno.test("Betriebs-Id muss eine UUID sein -> sonst abgelehnt", () => {
  assertEquals(anfrageLesen({ vonBetriebId: "a", nachBetriebId: B }), null);
  assertEquals(
    anfrageLesen({ von: { lat: 47.37, lng: 8.54 }, nach: { betriebId: "b" } }),
    null,
  );
  assertEquals(endeLesen({ betriebId: `${A}x` }), null);
  assertEquals(endeLesen({ betriebId: A.replaceAll("-", "") }), null);
  assertEquals(endeLesen({ betriebId: `${A}' or '1'='1` }), null);
  // Grossbuchstaben sind eine gueltige UUID-Schreibweise.
  assertEquals(endeLesen({ betriebId: A.toUpperCase() }), {
    art: "betrieb",
    betriebId: A.toUpperCase(),
  });
});

Deno.test("Ende: Betrieb UND Punkt zugleich -> abgelehnt", () => {
  assertEquals(endeLesen({ betriebId: A, lat: 46.8, lng: 9.5 }), null);
});

Deno.test("Ende: Koordinaten muessen endliche Zahlen im Bereich sein", () => {
  assertEquals(endeLesen({ lat: 46.8 }), null);
  assertEquals(endeLesen({ lat: "46.8", lng: "9.5" }), null);
  assertEquals(endeLesen({ lat: NaN, lng: 9.5 }), null);
  assertEquals(endeLesen({ lat: 46.8, lng: Infinity }), null);
  assertEquals(endeLesen({ lat: 90.0001, lng: 9.5 }), null);
  assertEquals(endeLesen({ lat: 46.8, lng: -180.5 }), null);
  assertEquals(endeLesen({ lat: -90, lng: 180 }), {
    art: "punkt",
    lat: -90,
    lng: 180,
  });
});

Deno.test("Ende: kein Objekt -> abgelehnt", () => {
  assertEquals(endeLesen("a"), null);
  assertEquals(endeLesen([46.8, 9.5]), null);
  assertEquals(endeLesen(undefined), null);
  assertEquals(endeLesen({ betriebId: 42 }), null);
});
