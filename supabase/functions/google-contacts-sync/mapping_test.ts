import {
  assertEquals,
  assertNotEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  baueSoll,
  ortFuerAnzeige,
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
    "Lenzerheide/Lai - Alp Nova (Jon Bertogg)",
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
  assertEquals(p.names[0].unstructuredName, "Lenzerheide/Lai - Alp Nova");
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
    "Lenzerheide/Lai - Alp Nova (Anna Meier)",
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
    "Lenzerheide/Lai - Alp Nova (Anna Meier)",
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

Deno.test("Ortsteile werden zur Hauptortschaft zusammengefasst", () => {
  assertEquals(ortFuerAnzeige("Davos Platz"), "Davos");
  assertEquals(ortFuerAnzeige("Davos Dorf"), "Davos");
  assertEquals(ortFuerAnzeige("Klosters Dorf"), "Klosters");
  assertEquals(ortFuerAnzeige("Flims Waldhaus"), "Flims");
  assertEquals(ortFuerAnzeige("Flims Dorf"), "Flims");
  assertEquals(ortFuerAnzeige("Obersaxen Meierhof"), "Obersaxen");
  assertEquals(ortFuerAnzeige("Seewis Dorf"), "Seewis");
});

Deno.test("Regel greift auch für künftige Betriebe", () => {
  // Kein Eintrag in einer Liste — der Zusatz allein genügt.
  assertEquals(ortFuerAnzeige("Sedrun Dorf"), "Sedrun");
  assertEquals(ortFuerAnzeige("Irgendwo Platz"), "Irgendwo");
});

Deno.test("Doppelnamen mit Schrägstrich bleiben unangetastet", () => {
  assertEquals(ortFuerAnzeige("Lenzerheide/Lai"), "Lenzerheide/Lai");
  assertEquals(ortFuerAnzeige("Breil/Brigels"), "Breil/Brigels");
  assertEquals(ortFuerAnzeige("Lantsch/Lenz"), "Lantsch/Lenz");
  assertEquals(ortFuerAnzeige("Domat/Ems"), "Domat/Ems");
  assertEquals(ortFuerAnzeige("Tumegl/Tomils"), "Tumegl/Tomils");
});

Deno.test("Disentis/Mustér wird auf die vorhandene Kurzform gebracht", () => {
  assertEquals(ortFuerAnzeige("Disentis/Mustér"), "Disentis");
  assertEquals(ortFuerAnzeige("Disentis"), "Disentis");
});

Deno.test("gewöhnliche Orte bleiben, wie sie sind", () => {
  assertEquals(ortFuerAnzeige("Chur"), "Chur");
  assertEquals(ortFuerAnzeige("Bad Ragaz"), "Bad Ragaz");
  assertEquals(ortFuerAnzeige("Arosa"), "Arosa");
  assertEquals(ortFuerAnzeige(null), "");
  assertEquals(ortFuerAnzeige("  Chur  "), "Chur");
});

Deno.test("Kartenname nutzt den zusammengefassten Ort", () => {
  const bolgen = {
    id: "b-bolgen",
    name: "Bolgen Plaza",
    ort: "Davos Platz",
    telefon: "+41 81 000 00 00",
    status: "aktiv",
  };
  assertEquals(
    personAusBetriebMitPersonen(bolgen, []).names[0].unstructuredName,
    "Davos - Bolgen Plaza",
  );
});

// ── Heineken- und Event-Kontakte (echte Daten, 29.07.2026) ──

const beat = {
  id: "k-beat",
  vorname: "Beat",
  nachname: "Jörg",
  kategorie: "heineken",
  rolle: "rsl",
  telefon: "+41 79 458 71 49",
  email: "beat.joerg@heineken.com",
};
const andreas = {
  id: "k-andreas",
  vorname: "Andreas",
  nachname: "Muster",
  kategorie: "event",
  rolle: "stand",
  telefon: "+41 79 736 97 12",
};
const openair = {
  name: "Openair Val Lumnezia",
  jahr: 2026,
  rolle: "stand",
  stand: "24h Bar",
};

Deno.test("Heineken-Kontakt: Heineken - Name - Rolle", () => {
  const soll = baueSoll([beat], []);
  const p = soll.get("kontakt:k-beat");
  assertEquals(p.names[0].unstructuredName, "Heineken - Beat Jörg - RSL");
  assertEquals(p.organizations[0].name, "Heineken");
  assertEquals(p.organizations[0].title, "RSL");
  assertEquals(p.phoneNumbers, [
    { value: "+41 79 458 71 49", type: "mobile" },
  ]);
  assertEquals(p.emailAddresses, [{ value: "beat.joerg@heineken.com" }]);
});

Deno.test("Heineken: Rollen werden ausgeschrieben", () => {
  const buero = { ...beat, id: "k-mani", vorname: "Daniel", nachname: "Mani", rolle: "buero" };
  assertEquals(
    baueSoll([buero], []).get("kontakt:k-mani").names[0].unstructuredName,
    "Heineken - Daniel Mani - Büro",
  );
});

Deno.test("Event-Kontakt mit Stand: Rolle plus Standname", () => {
  const infos = new Map([["k-andreas", openair]]);
  const p = baueSoll([andreas], [], infos).get("kontakt:k-andreas");
  assertEquals(
    p.names[0].unstructuredName,
    "Event - Openair Val Lumnezia 2026 - Stand 24h Bar - Andreas Muster",
  );
  assertEquals(p.organizations[0].name, "Openair Val Lumnezia 2026");
});

Deno.test("Event-Kontakt ohne Stand: nur die Rolle", () => {
  const rene = {
    id: "k-rene",
    vorname: "Rene",
    nachname: "Bolz",
    kategorie: "event",
    rolle: "ok",
    telefon: "+41 76 387 73 80",
  };
  const infos = new Map([
    ["k-rene", { ...openair, rolle: "ok", stand: "" }],
  ]);
  assertEquals(
    baueSoll([rene], [], infos).get("kontakt:k-rene").names[0].unstructuredName,
    "Event - Openair Val Lumnezia 2026 - OK - Rene Bolz",
  );
});

Deno.test("Event-Kontakt ohne Event-Zuordnung: Eventteil entfaellt", () => {
  assertEquals(
    baueSoll([andreas], []).get("kontakt:k-andreas").names[0].unstructuredName,
    "Event - Stand - Andreas Muster",
  );
});

Deno.test("Heineken gewinnt gegen Event-Beteiligung", () => {
  // Beat Joerg ist Heineken-RSL UND am Openair beteiligt.
  const infos = new Map([["k-beat", { ...openair, rolle: "rsl", stand: "" }]]);
  assertEquals(
    baueSoll([beat], [], infos).get("kontakt:k-beat").names[0].unstructuredName,
    "Heineken - Beat Jörg - RSL",
  );
});

Deno.test("Heineken/Event landen nie in einer Betriebskarte", () => {
  // Selbst mit gesetztem Betrieb bleiben sie eigenstaendig.
  const mitBetrieb = { ...beat, betrieb_id: "b-alpnova" };
  const soll = baueSoll([mitBetrieb], [alpNova]);
  assertEquals(soll.size, 2);
  assertEquals(soll.has("kontakt:k-beat"), true);
  assertEquals(
    soll.get("betrieb:b-alpnova").names[0].unstructuredName,
    "Lenzerheide/Lai - Alp Nova",
  );
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
      givenName: "Lenzerheide/Lai",
      familyName: "- Alp Nova (Jon Bertogg)",
    }],
    organizations: [{ name: "Alp Nova", title: "Geschäftsführer" }],
    phoneNumbers: [
      { value: "+41 76 553 13 67", type: "mobile" },
      { value: "+41 81 385 51 20", type: "work" },
    ],
  };
  assertEquals(vergleichsKey(geschrieben), vergleichsKey(gelesen));
});
