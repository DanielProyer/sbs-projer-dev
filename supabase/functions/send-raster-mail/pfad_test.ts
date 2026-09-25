import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { bereinigeDateiname, headerSicher, rasterPfadErlaubt } from "./pfad_pruefung.ts";

const U = "11111111-1111-1111-1111-111111111111";

Deno.test("rasterPfadErlaubt: eigener Raster-Pfad ja, alles andere nein", () => {
  assertEquals(rasterPfadErlaubt(`${U}/Raster_2026.pdf`, U), true);
  assertEquals(rasterPfadErlaubt(`anderer/Raster_2026.pdf`, U), false);
  assertEquals(rasterPfadErlaubt(`${U}/../x/Raster.pdf`, U), false);
  assertEquals(rasterPfadErlaubt(`${U}/geheim.txt`, U), false);
  assertEquals(rasterPfadErlaubt(`${U}/%2e%2e/r.pdf`, U), false);
  assertEquals(rasterPfadErlaubt(null, U), false);
});

Deno.test("headerSicher: kein CR/LF", () => {
  assertEquals(headerSicher("a@b.ch"), true);
  assertEquals(headerSicher("a@b.ch\r\nBcc: x@y.z"), false);
  assertEquals(headerSicher(""), false);
});

Deno.test("bereinigeDateiname", () => {
  assertEquals(bereinigeDateiname("Raster_2026.pdf"), "Raster_2026.pdf");
  assertEquals(bereinigeDateiname("Raester/../x.exe"), "Raester_.._x.pdf");
  assertEquals(bereinigeDateiname(undefined), "Raster.pdf");
});
