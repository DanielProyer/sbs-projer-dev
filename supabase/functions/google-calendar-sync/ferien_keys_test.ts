import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { veralteteFerienZuordnungen } from "./ferien_keys.ts";

const B = "11111111-1111-1111-1111-111111111111";
const X = "22222222-2222-2222-2222-222222222222";

Deno.test("geloeschte Periode und Alt-Index-Schluessel muessen weg", () => {
  const weg = veralteteFerienZuordnungen(
    B,
    [
      `${B}:ferien_2026-10-11_endreinigung`,
      `${B}:ferien_2026-10-11_eroeffnung`,
      `${B}:ferien_2026-07-01_eroeffnung`,
      `${B}:ferien1_endreinigung`,
    ],
    ["ferien_2026-10-11_endreinigung", "ferien_2026-10-11_eroeffnung"],
  );
  assertEquals(weg, [
    `${B}:ferien_2026-07-01_eroeffnung`,
    `${B}:ferien1_endreinigung`,
  ]);
});

Deno.test("Saison-Schluessel und fremde Betriebe bleiben", () => {
  const weg = veralteteFerienZuordnungen(
    B,
    [`${B}:sommer_eroeffnung`, `${X}:ferien_2026-10-11_endreinigung`],
    [],
  );
  assertEquals(weg, []);
});

Deno.test("leere Schluesselmenge (keine Betriebsferien) raeumt alle Ferien weg", () => {
  const weg = veralteteFerienZuordnungen(
    B,
    [`${B}:ferien_2026-10-11_endreinigung`, `${B}:winter_endreinigung`],
    [],
  );
  assertEquals(weg, [`${B}:ferien_2026-10-11_endreinigung`]);
});
