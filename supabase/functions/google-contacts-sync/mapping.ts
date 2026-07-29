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

/// «Betriebsname Ort» — der Kartenname eines Betriebs ohne Kontaktperson.
export function betriebAnzeige(b: Any): string {
  return [b.name, b.ort]
    .map((x: Any) => (x ?? "").trim())
    .filter((x: string) => x !== "")
    .join(" ");
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
/// Der Kartenname trägt den Betrieb und die Hauptperson («Alp Nova
/// Lenzerheide/Lai — Jon Bertogg»), damit die Suche beide findet. Die
/// Festnetznummer steht als Geschäftsnummer, jede Personennummer als
/// Mobilnummer; bei mehreren Personen wird der Name zum Rufnummern-Label,
/// sonst bleibt es beim schlichten «mobile».
export function personAusBetriebMitPersonen(b: Any, personen: Any[]): Any {
  const sortiert = sortierePersonen(personen);
  const haupt = sortiert[0];
  const basis = betriebAnzeige(b);
  const hauptName = haupt ? personName(haupt) : "";
  const anzeige = hauptName ? `${basis} — ${hauptName}` : basis;

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
export function baueSoll(kontakte: Any[], betriebe: Any[]): Map<string, Any> {
  const syncBetriebe = (betriebe ?? []).filter(istSyncWuerdigBetrieb);
  const hatEigeneKarte = new Set(syncBetriebe.map((b: Any) => b.id));

  const personenJeBetrieb = new Map<string, Any[]>();
  const einzeln: Any[] = [];
  for (const k of (kontakte ?? []).filter(istSyncWuerdigKontakt)) {
    const bid = k.betrieb_id;
    if (bid && hatEigeneKarte.has(bid)) {
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
    soll.set(
      `kontakt:${k.id}`,
      personAusKontakt(k, betriebTextJeId.get(k.betrieb_id) ?? ""),
    );
  }
  return soll;
}
