import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  baueSoll,
  personAusBetriebMitPersonen,
  sortierePersonen,
  vergleichsKey,
} from "./mapping.ts";

// Echte Daten aus der Produktion (29.07.2026).
const alpNova = {
  id: "b-alpnova",
  name: "Alp Nova",
  ort: "Lenzerheide/Lai",
  telefon: "+41 81 385 51 20",
  status: "aktiv",
};
const jon = {
  id: "k-jon",
  vorname: "Jon",
  nachname: "Bertogg",
  funktion: "Geschäftsführer",
  rolle: "geschaeftsfuehrer",
  telefon: "+41 76 553 13 67",
  email: null,
  betrieb_id: "b-alpnova",
};

Deno.test("Betrieb und Person landen in EINER Karte", () => {
  const soll = baueSoll([jon], [alpNova]);
  assertEquals(soll.size, 1);
  assertEquals([...soll.keys()], ["betrieb:b-alpnova"]);
});

Deno.test("Kartenname trägt Betrieb und Hauptperson", () => {
  const p = personAusBetriebMitPersonen(alpNova, [jon]);
  assertEquals(
    p.names[0].unstructuredName,
    "Alp Nova Lenzerheide/Lai — Jon Bertogg",
  );
});

Deno.test("beide Nummern in der Karte, Festnetz als Geschäft", () => {
  const p = personAusBetriebMitPersonen(alpNova, [jon]);
  assertEquals(p.phoneNumbers, [
    { value: "+41 81 385 51 20", type: "work" },
    { value: "+41 76 553 13 67", type: "mobile" },
  ]);
});

Deno.test("Funktion der Hauptperson steht in der Organisation", () => {
  const p = personAusBetriebMitPersonen(alpNova, [jon]);
  assertEquals(p.organizations[0].name, "Alp Nova");
  assertEquals(p.organizations[0].title, "Geschäftsführer");
});

Deno.test("Betrieb ohne Person behält seinen schlichten Namen", () => {
  const p = personAusBetriebMitPersonen(alpNova, []);
  assertEquals(p.names[0].unstructuredName, "Alp Nova Lenzerheide/Lai");
  assertEquals(p.phoneNumbers, [{ value: "+41 81 385 51 20", type: "work" }]);
});

Deno.test("mehrere Personen: Namen werden zu Rufnummern-Labels", () => {
  const zweite = {
    id: "k-zzz",
    vorname: "Anna",
    nachname: "Meier",
    telefon: "+41 79 111 22 33",
    betrieb_id: "b-alpnova",
  };
  // Ohne gesetzten Hauptkontakt entscheidet der Name, nicht die id:
  // Anna Meier steht vor Jon Bertogg, obwohl ihre id später kommt.
  const p = personAusBetriebMitPersonen(alpNova, [jon, zweite]);
  assertEquals(p.phoneNumbers, [
    { value: "+41 81 385 51 20", type: "work" },
    { value: "+41 79 111 22 33", type: "Anna Meier" },
    { value: "+41 76 553 13 67", type: "Jon Bertogg" },
  ]);
  // Im Namen steht nur die erste Person, sonst wird die Karte unlesbar.
  assertEquals(
    p.names[0].unstructuredName,
    "Alp Nova Lenzerheide/Lai — Anna Meier",
  );
});

Deno.test("Hauptkontakt bestimmt den Namen, nicht die Reihenfolge", () => {
  const anna = {
    id: "k-anna",
    vorname: "Anna",
    nachname: "Meier",
    telefon: "+41 79 111 22 33",
    ist_hauptkontakt: true,
    betrieb_id: "b-alpnova",
  };
  const p = personAusBetriebMitPersonen(alpNova, [jon, anna]);
  assertEquals(
    p.names[0].unstructuredName,
    "Alp Nova Lenzerheide/Lai — Anna Meier",
  );
});

Deno.test("Reihenfolge ist stabil — sonst Endlos-Churn", () => {
  // Nach Name sortiert, unabhängig von der Eingabereihenfolge.
  const a = { id: "k-zzz", vorname: "Anton" };
  const b = { id: "k-aaa", vorname: "Berta" };
  assertEquals(sortierePersonen([b, a]).map((x) => x.id), ["k-zzz", "k-aaa"]);
  assertEquals(sortierePersonen([a, b]).map((x) => x.id), ["k-zzz", "k-aaa"]);
});

Deno.test("gleiche Namen: die id entscheidet, aber immer gleich", () => {
  const a = { id: "k-1", vorname: "Hans" };
  const b = { id: "k-2", vorname: "Hans" };
  assertEquals(sortierePersonen([b, a]).map((x) => x.id), ["k-1", "k-2"]);
});

Deno.test("Person ohne Betrieb bleibt eigener Eintrag", () => {
  const privat = {
    id: "k-privat",
    vorname: "Peter",
    nachname: "Muster",
    telefon: "+41 79 999 88 77",
    betrieb_id: null,
  };
  const soll = baueSoll([privat], [alpNova]);
  assertEquals(soll.size, 2);
  assertEquals(soll.has("kontakt:k-privat"), true);
});

Deno.test("Person eines nicht sync-würdigen Betriebs bleibt sichtbar", () => {
  // Betrieb ohne Telefon bekommt keine eigene Karte — die Person darf
  // deswegen nicht aus dem Adressbuch verschwinden.
  const ohneTel = { ...alpNova, telefon: "" };
  const soll = baueSoll([jon], [ohneTel]);
  assertEquals(soll.size, 1);
  assertEquals(soll.has("kontakt:k-jon"), true);
  assertEquals(
    soll.get("kontakt:k-jon").organizations[0].name,
    "Alp Nova, Lenzerheide/Lai",
  );
});

Deno.test("geschlossener Betrieb erzeugt keine Karte", () => {
  const zu = { ...alpNova, status: "geschlossen" };
  const soll = baueSoll([], [zu]);
  assertEquals(soll.size, 0);
});

Deno.test("Kontakt ohne Telefon und Mail wird nicht gesynct", () => {
  const leer = { id: "k-leer", vorname: "Ohne", telefon: "", email: "" };
  assertEquals(baueSoll([leer], []).size, 0);
});

Deno.test("vergleichsKey: Nummern-Reihenfolge egal", () => {
  const a = {
    names: [{ unstructuredName: "X" }],
    phoneNumbers: [{ value: "+41 79 1" }, { value: "+41 81 2" }],
  };
  const b = {
    names: [{ unstructuredName: "X" }],
    phoneNumbers: [{ value: "+41812" }, { value: "+41791" }],
  };
  assertEquals(vergleichsKey(a), vergleichsKey(b));
});

Deno.test("vergleichsKey: zweite Nummer wird bemerkt", () => {
  const vorher = personAusBetriebMitPersonen(alpNova, []);
  const nachher = personAusBetriebMitPersonen(alpNova, [jon]);
  assertNotEquals(vergleichsKey(vorher), vergleichsKey(nachher));
});

Deno.test("vergleichsKey: gelesene Google-Form ergibt denselben Schlüssel", () => {
  // Google zerlegt unstructuredName beim Speichern und liefert given/family.
  const geschrieben = personAusBetriebMitPersonen(alpNova, [jon]);
  const gelesen = {
    names: [{
      givenName: "Alp",
      familyName: "Nova Lenzerheide/Lai — Jon Bertogg",
    }],
    organizations: [{ name: "Alp Nova", title: "Geschäftsführer" }],
    phoneNumbers: [
      { value: "+41 76 553 13 67", type: "mobile" },
      { value: "+41 81 385 51 20", type: "work" },
    ],
  };
  assertEquals(vergleichsKey(geschrieben), vergleichsKey(gelesen));
});
