// Body von fahrzeit-route lesen und pruefen (Migration 213, 29.09.2026).
//
// Neu:  { von: RoutenEnde, nach: RoutenEnde }
//       RoutenEnde = { betriebId: string } | { lat: number, lng: number }
// Alt:  { vonBetriebId: string, nachBetriebId: string } -- wird auf
//       von/nach mit betriebId abgebildet (App-Staende vor 213).
// Beide: Die App ab 213 schickt Betrieb -> Betrieb in BEIDEN Formaten,
//       damit sie im Rollout-Fenster auch gegen die alte Function laeuft.
//       Gelesen wird von/nach; das alte Format muss dasselbe sagen, sonst
//       ist die Anfrage widerspruechlich (400).
//
// Jedes Ende ist ENTWEDER ein Betrieb ODER ein Punkt; beides zugleich ist
// eine unklare Anfrage und wird abgelehnt. Eine Betriebs-Id muss eine UUID
// sein (betriebe.id) -- sonst scheiterte erst die Abfrage, und die App
// bekaeme ein 500 db_error statt eines 400. Zwei Mal derselbe Betrieb
// bleibt wie vor 213 ein bad_request.

export type Ende =
  | { art: "betrieb"; betriebId: string }
  | { art: "punkt"; lat: number; lng: number };

export interface Anfrage {
  von: Ende;
  nach: Ende;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
    return typeof id === "string" && UUID.test(id)
      ? { art: "betrieb", betriebId: id }
      : null;
  }
  const lat = koordinate(o.lat, 90);
  const lng = koordinate(o.lng, 180);
  return lat != null && lng != null ? { art: "punkt", lat, lng } : null;
}

/**
 * Eine Seite (von oder nach) aus neuem und/oder altem Format. Das neue geht
 * vor; steht zusaetzlich das alte da, muss es denselben Betrieb nennen.
 */
function seiteLesen(neu: unknown, alt: unknown): Ende | null {
  const ausAlt = gesetzt(alt) ? endeLesen({ betriebId: alt }) : null;
  if (!gesetzt(neu)) return ausAlt;
  const ende = endeLesen(neu);
  if (ende == null || !gesetzt(alt)) return ende;
  return ausAlt?.art === "betrieb" && ende.art === "betrieb" &&
      ausAlt.betriebId === ende.betriebId
    ? ende
    : null;
}

/** Den ganzen Body pruefen; `null` = 400 bad_request. */
export function anfrageLesen(body: unknown): Anfrage | null {
  const b = (body != null && typeof body === "object" ? body : {}) as Record<
    string,
    unknown
  >;
  const von = seiteLesen(b.von, b.vonBetriebId);
  const nach = seiteLesen(b.nach, b.nachBetriebId);
  if (von == null || nach == null) return null;
  if (
    von.art === "betrieb" && nach.art === "betrieb" &&
    von.betriebId === nach.betriebId
  ) {
    return null;
  }
  return { von, nach };
}
