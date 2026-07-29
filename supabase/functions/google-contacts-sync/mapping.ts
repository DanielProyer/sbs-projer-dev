// Reine Abbildungs-Logik des Kontakte-Syncs (ohne Netz-/Supabase-Abhängigkeit,
// damit sie eigenständig testbar bleibt — siehe mapping_test.ts).
//
// Seit 29.07.2026 (Wunsch Daniel) entsteht pro Betrieb EINE Google-Karte, die
// die Kontaktpersonen mitträgt: Vorher standen «Alp Nova Lenzerheide/Lai» und
// «Jon Bertogg» als zwei getrennte Einträge im Adressbuch.

// deno-lint-ignore no-explicit-any
export type Any = any;

export function istSyncWuerdigKontakt(k: Any): boolean {
  const tel = (k.telefon ?? "").trim();
  const mail = (k.email ?? "").trim();
  return tel !== "" || mail !== "";
}

export function istSyncWuerdigBetrieb(b: Any): boolean {
  const tel = (b.telefon ?? "").trim();
  return (b.status === "aktiv" || b.status === "saisonpause") && tel !== "";
}

/// Anzeigename einer Person: «Vorname Nachname», leer wenn beides fehlt.
export function personName(k: Any): string {
  return [k.vorname, k.nachname]
    .map((x: Any) => (x ?? "").trim())
    .filter((x: string) => x !== "")
    .join(" ");
}

/// Funktion/Rolle der Person, wie sie im Adressbuch stehen soll.
export function personFunktion(k: Any): string {
  return ((k.funktion ?? k.rolle) ?? "").trim();
}

/// Klartext zu den Rollen-Schlüsseln; gleiche Beschriftung wie in der App
/// (lib/data/models/kontakt.dart).
const ROLLEN_LABEL: Record<string, string> = {
  geschaeftsfuehrer: "Geschäftsführer",
  fb_manager: "F&B Manager",
  mitarbeiter: "Mitarbeiter",
  hauswart: "Hauswart",
  sonstige: "Sonstige",
  rsl: "RSL",
  buero: "Büro",
  monteur: "Monteur",
  event_heineken: "Event Heineken",
  pikett: "Pikett",
  vertreter: "Vertreter",
  stardrinks: "Stardrinks",
  ok: "OK",
  bau: "Bau",
  stand: "Stand",
};

export function rolleLabel(rolle: Any): string {
  const r = (rolle ?? "").trim();
  return ROLLEN_LABEL[r] ?? r;
}

/// Karte für einen Heineken-Kontakt: «Heineken - Vorname Nachname - Rolle».
export function personAusHeineken(k: Any): Any {
  const teile = ["Heineken", personName(k), rolleLabel(k.rolle)]
    .filter((x: string) => x !== "");
  const p: Any = {
    names: [{ unstructuredName: teile.join(" - ") }],
    organizations: [{ name: "Heineken", title: rolleLabel(k.rolle) }],
    clientData: [{ key: "sbs_id", value: `kontakt:${k.id}` }],
  };
  const tel = (k.telefon ?? "").trim();
  if (tel) p.phoneNumbers = [{ value: tel, type: "mobile" }];
  const mail = (k.email ?? "").trim();
  if (mail) p.emailAddresses = [{ value: mail }];
  return p;
}

/// Was ein Event-Kontakt über seinen Einsatz weiss.
export type EventInfo = {
  name: string;
  jahr: Any;
  rolle: Any;
  stand: string;
};

/// Karte für einen Event-Kontakt:
/// «Event - Openair Val Lumnezia 2026 - Stand 24h Bar - Andreas Muster».
///
/// Bei der Rolle «Stand» wird der Standname angehängt, sonst steht dort nur
/// die Rolle. Ohne Event-Zuordnung entfällt der Eventteil — sonst stünde dort
/// eine leere Lücke.
export function personAusEventKontakt(k: Any, info: EventInfo | null): Any {
  const eventTeil = info
    ? [info.name, (info.jahr ?? "").toString()]
      .map((x: Any) => (x ?? "").toString().trim())
      .filter((x: string) => x !== "")
      .join(" ")
    : "";
  const rolleRoh = info?.rolle ?? k.rolle;
  const rolleTeil = rolleRoh === "stand" && (info?.stand ?? "") !== ""
    ? `${rolleLabel(rolleRoh)} ${info!.stand}`
    : rolleLabel(rolleRoh);

  const teile = ["Event", eventTeil, rolleTeil, personName(k)]
    .filter((x: string) => x !== "");

  const p: Any = {
    names: [{ unstructuredName: teile.join(" - ") }],
    organizations: [{
      name: eventTeil !== "" ? eventTeil : "Event",
      title: rolleTeil,
    }],
    clientData: [{ key: "sbs_id", value: `kontakt:${k.id}` }],
  };
  const tel = (k.telefon ?? "").trim();
  if (tel) p.phoneNumbers = [{ value: tel, type: "mobile" }];
  const mail = (k.email ?? "").trim();
  if (mail) p.emailAddresses = [{ value: mail }];
  return p;
}

/// Ortsteil-Zusätze, die im Adressbuch zur Hauptortschaft zusammengefasst
/// werden. Als Regel formuliert und nicht als Liste einzelner Orte, damit sie
/// auch für künftig angelegte Betriebe greift (Rückfrage Daniel 29.07.2026).
const ORTSTEIL_ZUSAETZE = [" Dorf", " Platz", " Waldhaus", " Meierhof"];

/// Ortschaften, deren gebräuchliche Kurzform sich nicht aus einer Regel
/// ergibt. Amtliche Doppelnamen wie «Lenzerheide/Lai» oder «Breil/Brigels»
/// bleiben bewusst stehen: Mal ist der erste Teil der geläufige, mal der
/// zweite — eine pauschale Regel läge zwangsläufig oft daneben.
const ORT_SONDERFAELLE: Record<string, string> = {
  "Disentis/Mustér": "Disentis",
};

/// Ort, wie er im Namen der Google-Karte erscheint.
///
/// Fasst Ortsteile zur Hauptortschaft zusammen («Davos Platz» → «Davos»),
/// damit alle Betriebe einer Ortschaft im Adressbuch beieinanderstehen. Die
/// Stammdaten bleiben davon unberührt — «Davos Platz» ist die korrekte
/// Postanschrift.
export function ortFuerAnzeige(ort: Any): string {
  const o = (ort ?? "").trim();
  if (o === "") return "";
  const sonder = ORT_SONDERFAELLE[o];
  if (sonder) return sonder;
  for (const zusatz of ORTSTEIL_ZUSAETZE) {
    if (o.endsWith(zusatz) && o.length > zusatz.length) {
      return o.slice(0, -zusatz.length).trim();
    }
  }
  return o;
}

/// «Ort - Betrieb» — der Kartenname eines Betriebs ohne Kontaktperson.
///
/// Der Ort steht vorn (Format Daniel, 29.07.2026): So sortiert das Adressbuch
/// nach Ort, alle Betriebe einer Ortschaft stehen für die Tour beieinander —
/// und die Karten passen zu den von Hand angelegten Einträgen, sodass Google
/// die Dubletten als solche erkennt.
export function betriebAnzeige(b: Any): string {
  return [ortFuerAnzeige(b.ort), b.name]
    .map((x: Any) => (x ?? "").trim())
    .filter((x: string) => x !== "")
    .join(" - ");
}

/// Reihenfolge der Personen eines Betriebs: Hauptkontakt zuerst, sonst
/// alphabetisch nach Name; die id entscheidet nur bei Namensgleichheit.
///
/// Bewusst deterministisch und nachvollziehbar: Wer auf der Karte steht, darf
/// nicht von der zufälligen id abhängen — und die Reihenfolge darf zwischen
/// zwei Läufen nicht wechseln, sonst sähe Google endlose Änderungen.
export function sortierePersonen(personen: Any[]): Any[] {
  return [...personen].sort((a, b) => {
    const ha = a.ist_hauptkontakt === true ? 0 : 1;
    const hb = b.ist_hauptkontakt === true ? 0 : 1;
    if (ha !== hb) return ha - hb;
    const na = personName(a);
    const nb = personName(b);
    if (na !== nb) return na.localeCompare(nb, "de");
    return String(a.id).localeCompare(String(b.id));
  });
}

/// Person-Payload für einen App-Kontakt ohne (sync-würdigen) Betrieb.
/// betriebText = "Name, Ort" oder "".
export function personAusKontakt(k: Any, betriebText: string): Any {
  const p: Any = {
    names: [{
      givenName: (k.vorname ?? "").trim(),
      familyName: (k.nachname ?? "").trim(),
    }],
    clientData: [{ key: "sbs_id", value: `kontakt:${k.id}` }],
  };
  const funktion = personFunktion(k);
  if (betriebText || funktion) {
    p.organizations = [{ name: betriebText, title: funktion }];
  }
  const tel = (k.telefon ?? "").trim();
  if (tel) p.phoneNumbers = [{ value: tel, type: "mobile" }];
  const mail = (k.email ?? "").trim();
  if (mail) p.emailAddresses = [{ value: mail }];
  return p;
}

/// Eine Karte für den Betrieb — mit seinen Kontaktpersonen darin.
///
/// Der Kartenname trägt Ort, Betrieb und die Hauptperson («Lenzerheide/Lai -
/// Alp Nova (Jon Bertogg)»), damit die Suche beide findet. Die Festnetznummer
/// steht als Geschäftsnummer, jede Personennummer als Mobilnummer; bei
/// mehreren Personen wird der Name zum Rufnummern-Label, sonst bleibt es beim
/// schlichten «mobile».
export function personAusBetriebMitPersonen(b: Any, personen: Any[]): Any {
  const sortiert = sortierePersonen(personen);
  const haupt = sortiert[0];
  const basis = betriebAnzeige(b);
  const hauptName = haupt ? personName(haupt) : "";
  const anzeige = hauptName ? `${basis} (${hauptName})` : basis;

  const p: Any = {
    names: [{ unstructuredName: anzeige }],
    organizations: [{
      name: (b.name ?? "").trim(),
      title: haupt ? personFunktion(haupt) : "",
    }],
    clientData: [{ key: "sbs_id", value: `betrieb:${b.id}` }],
  };

  const nummern: Any[] = [];
  const betriebTel = (b.telefon ?? "").trim();
  if (betriebTel) nummern.push({ value: betriebTel, type: "work" });
  for (const k of sortiert) {
    const tel = (k.telefon ?? "").trim();
    if (!tel) continue;
    // Mehrere Personen: Name als Label, sonst ist nicht klar, wessen Nummer
    // das ist. Bei einer Person steht der Name bereits im Kartennamen.
    const typ = sortiert.length > 1 ? (personName(k) || "mobile") : "mobile";
    nummern.push({ value: tel, type: typ });
  }
  if (nummern.length) p.phoneNumbers = nummern;

  const mails: Any[] = [];
  for (const k of sortiert) {
    const mail = (k.email ?? "").trim();
    if (mail) mails.push({ value: mail });
  }
  if (mails.length) p.emailAddresses = mails;

  return p;
}

/// Vergleichs-Schlüssel: alles, was wir schreiben, normalisiert.
///
/// Der Name wird als EIN zusammengesetzter Schlüssel geführt: Google zerlegt
/// unstructuredName beim Speichern in given/family und liefert beim Lesen
/// beide Varianten — ein Einzelfeld-Vergleich sähe deshalb jeden Betrieb bei
/// jedem Lauf als geändert (Endlos-Churn). Rufnummern und Adressen werden
/// sortiert verglichen, weil Google die Reihenfolge nicht garantiert; die
/// Typ-Labels bleiben bewusst draussen, da Google sie umschreibt.
export function vergleichsKey(p: Any): string {
  const n = p.names?.[0] ?? {};
  const o = p.organizations?.[0] ?? {};
  const nameKey = [n.givenName ?? "", n.familyName ?? ""].join(" ").trim() ||
    (n.unstructuredName ?? "").trim();
  const tel = (p.phoneNumbers ?? [])
    .map((x: Any) => (x.value ?? "").replace(/\s+/g, ""))
    .filter((x: string) => x !== "")
    .sort();
  const mail = (p.emailAddresses ?? [])
    .map((x: Any) => (x.value ?? "").trim().toLowerCase())
    .filter((x: string) => x !== "")
    .sort();
  return JSON.stringify([nameKey, o.name ?? "", o.title ?? "", tel, mail]);
}

export function sbsIdVon(p: Any): string | null {
  for (const c of p.clientData ?? []) {
    if (c.key === "sbs_id" && c.value) return c.value as string;
  }
  return null;
}

/// Soll-Zustand: welche Google-Karte mit welcher sbs_id entstehen soll.
///
/// Ein sync-würdiger Betrieb bekommt eine Karte samt seiner Personen. Nur
/// Personen, deren Betrieb keine eigene Karte hat (kein Telefon, inaktiv,
/// oder gar kein Betrieb hinterlegt), bleiben eigenständige Einträge —
/// sonst würden sie im Adressbuch fehlen.
///
/// Heineken- und Event-Kontakte bekommen ihr eigenes Namensschema und wandern
/// nie in eine Betriebskarte: Sie sind eigene Ansprechpartner, keine
/// Kontaktpersonen des Lokals. Liegt ein Kontakt in beiden Welten — ein
/// Heineken-Mitarbeiter, der an einem Event mitwirkt —, gewinnt die
/// Kategorie: Heineken-Leute sind dauerhaft, das Event ist eine Episode.
export function baueSoll(
  kontakte: Any[],
  betriebe: Any[],
  eventInfos?: Map<string, EventInfo>,
): Map<string, Any> {
  const syncBetriebe = (betriebe ?? []).filter(istSyncWuerdigBetrieb);
  const hatEigeneKarte = new Set(syncBetriebe.map((b: Any) => b.id));

  const personenJeBetrieb = new Map<string, Any[]>();
  const einzeln: Any[] = [];
  for (const k of (kontakte ?? []).filter(istSyncWuerdigKontakt)) {
    const bid = k.betrieb_id;
    const eigenesSchema = k.kategorie === "heineken" || k.kategorie === "event";
    if (!eigenesSchema && bid && hatEigeneKarte.has(bid)) {
      const liste = personenJeBetrieb.get(bid) ?? [];
      liste.push(k);
      personenJeBetrieb.set(bid, liste);
    } else {
      einzeln.push(k);
    }
  }

  const betriebTextJeId = new Map<string, string>();
  for (const b of betriebe ?? []) {
    betriebTextJeId.set(
      b.id,
      [b.name, b.ort]
        .map((x: Any) => (x ?? "").trim())
        .filter((x: string) => x !== "")
        .join(", "),
    );
  }

  const soll = new Map<string, Any>();
  for (const b of syncBetriebe) {
    soll.set(
      `betrieb:${b.id}`,
      personAusBetriebMitPersonen(b, personenJeBetrieb.get(b.id) ?? []),
    );
  }
  for (const k of einzeln) {
    const person = k.kategorie === "heineken"
        ? personAusHeineken(k)
        : k.kategorie === "event"
        ? personAusEventKontakt(k, eventInfos?.get(k.id) ?? null)
        : personAusKontakt(k, betriebTextJeId.get(k.betrieb_id) ?? "");
    soll.set(`kontakt:${k.id}`, person);
  }
  return soll;
}
