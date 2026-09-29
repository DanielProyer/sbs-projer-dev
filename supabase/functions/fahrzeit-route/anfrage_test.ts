// Body-Pruefung von fahrzeit-route (Migration 213) -- `deno test`.

import { assertEquals } from "jsr:@std/assert@1";
import { anfrageLesen, endeLesen } from "./anfrage.ts";

Deno.test("altes Format {vonBetriebId, nachBetriebId} bleibt gueltig", () => {
  assertEquals(anfrageLesen({ vonBetriebId: "a", nachBetriebId: "b" }), {
    von: { art: "betrieb", betriebId: "a" },
    nach: { art: "betrieb", betriebId: "b" },
  });
});

Deno.test("neues Format: Punkt -> Betrieb", () => {
  assertEquals(
    anfrageLesen({ von: { lat: 47.37, lng: 8.54 }, nach: { betriebId: "b" } }),
    {
      von: { art: "punkt", lat: 47.37, lng: 8.54 },
      nach: { art: "betrieb", betriebId: "b" },
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

Deno.test("zweimal derselbe Betrieb -> abgelehnt (wie vor 213)", () => {
  assertEquals(anfrageLesen({ vonBetriebId: "a", nachBetriebId: "a" }), null);
  assertEquals(
    anfrageLesen({ von: { betriebId: "a" }, nach: { betriebId: "a" } }),
    null,
  );
});

Deno.test("fehlende oder leere Enden -> abgelehnt", () => {
  assertEquals(anfrageLesen({}), null);
  assertEquals(anfrageLesen(null), null);
  assertEquals(anfrageLesen({ vonBetriebId: "a" }), null);
  assertEquals(anfrageLesen({ vonBetriebId: "", nachBetriebId: "b" }), null);
  assertEquals(
    anfrageLesen({ von: { betriebId: "" }, nach: { betriebId: "b" } }),
    null,
  );
});

Deno.test("Ende: Betrieb UND Punkt zugleich -> abgelehnt", () => {
  assertEquals(endeLesen({ betriebId: "a", lat: 46.8, lng: 9.5 }), null);
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
