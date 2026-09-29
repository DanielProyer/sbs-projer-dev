// Schluessel der Routen-Enden (Migration 213) -- `deno test`.
//
// Dieselben drei Beispiele stehen in `test/routen_punkt_key_test.dart`:
// App und Function muessen fuer denselben Punkt denselben Schluessel
// rechnen, sonst findet die App die gecachte Strecke nie.

import { assertEquals } from "jsr:@std/assert@1";
import { betriebKey, punktKey } from "./keys.ts";

Deno.test("punktKey: Domat/Ems auf vier Nachkommastellen", () => {
  assertEquals(punktKey(46.8328452, 9.4529918), "p:46.8328,9.4530");
});

Deno.test("punktKey: Aufrunden an der vierten Stelle", () => {
  assertEquals(punktKey(46.86396925, 9.5278708), "p:46.8640,9.5279");
});

// toFixed behaelt das Minus bei kleinen negativen Werten ("-0.0000"); die
// Dart-Fassung liefert dasselbe (siehe Kopfkommentar keys.ts).
Deno.test("punktKey: kleine Werte um null", () => {
  assertEquals(punktKey(-0.00004, 0.00005), "p:-0.0000,0.0001");
});

Deno.test("betriebKey: Praefix b:", () => {
  assertEquals(
    betriebKey("0b7c1e2a-1111-2222-3333-444455556666"),
    "b:0b7c1e2a-1111-2222-3333-444455556666",
  );
});
