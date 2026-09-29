// Body von fahrzeit-route lesen und pruefen (Migration 213, 29.09.2026).
//
// Neu:  { von: RoutenEnde, nach: RoutenEnde }
//       RoutenEnde = { betriebId: string } | { lat: number, lng: number }
// Alt:  { vonBetriebId: string, nachBetriebId: string } -- wird auf
//       von/nach mit betriebId abgebildet (App-Staende vor 213).
//
// Jedes Ende ist ENTWEDER ein Betrieb ODER ein Punkt; beides zugleich ist
// eine unklare Anfrage und wird abgelehnt. Zwei Mal derselbe Betrieb bleibt
// wie vor 213 ein bad_request.

export type Ende =
  | { art: "betrieb"; betriebId: string }
  | { art: "punkt"; lat: number; lng: number };

export interface Anfrage {
  von: Ende;
  nach: Ende;
}

function gesetzt(v: unknown): boolean {
  return v !== undefined && v !== null;
}

function koordinate(v: unknown, grenze: number): number | null {
  return typeof v === "number" && Number.isFinite(v) && Math.abs(v) <= grenze
    ? v
    : null;
}

/** Ein Ende pruefen; `null` = ungueltig. */
export function endeLesen(roh: unknown): Ende | null {
  if (roh == null || typeof roh !== "object" || Array.isArray(roh)) {
    return null;
  }
  const o = roh as Record<string, unknown>;
  if (gesetzt(o.betriebId)) {
    if (gesetzt(o.lat) || gesetzt(o.lng)) return null;
    const id = o.betriebId;
    return typeof id === "string" && id.length > 0
      ? { art: "betrieb", betriebId: id }
      : null;
  }
  const lat = koordinate(o.lat, 90);
  const lng = koordinate(o.lng, 180);
  return lat != null && lng != null ? { art: "punkt", lat, lng } : null;
}

/** Den ganzen Body pruefen; `null` = 400 bad_request. */
export function anfrageLesen(body: unknown): Anfrage | null {
  const b = (body != null && typeof body === "object" ? body : {}) as Record<
    string,
    unknown
  >;
  const vonRoh = gesetzt(b.von)
    ? b.von
    : gesetzt(b.vonBetriebId)
    ? { betriebId: b.vonBetriebId }
    : undefined;
  const nachRoh = gesetzt(b.nach)
    ? b.nach
    : gesetzt(b.nachBetriebId)
    ? { betriebId: b.nachBetriebId }
    : undefined;
  const von = endeLesen(vonRoh);
  const nach = endeLesen(nachRoh);
  if (von == null || nach == null) return null;
  if (
    von.art === "betrieb" && nach.art === "betrieb" &&
    von.betriebId === nach.betriebId
  ) {
    return null;
  }
  return { von, nach };
}
