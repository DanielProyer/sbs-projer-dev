// Reine Prüffunktionen für parse-oeffnungszeiten (ohne Deno.serve, damit
// `deno test` sie importieren kann).
//
// Hintergrund (Analyse 25.09.2026, R11): Die Function lädt die `url` aus dem
// Body serverseitig. Ohne Prüfung liesse sich damit jeder vom Supabase-Server
// erreichbare Host abfragen (SSRF) — Loopback, internes Netz, Cloud-Metadaten.

export const MAX_URL_LAENGE = 2000;

/** Setzt `https://` vor eine nackte Domain (so steht die Website oft im Betrieb). */
export function normalisiereUrl(u: string): string {
  const s = u.trim();
  if (/^https?:\/\//i.test(s)) return s;
  return "https://" + s;
}

function istPrivateIpv4(host: string): boolean {
  const m = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (!m) return false;
  const [a, b] = [Number(m[1]), Number(m[2])];
  if (a === 0) return true; // 0.0.0.0/8
  if (a === 10) return true; // 10/8
  if (a === 127) return true; // Loopback
  if (a === 169 && b === 254) return true; // Link-local, Cloud-Metadaten
  if (a === 172 && b >= 16 && b <= 31) return true; // 172.16/12
  if (a === 192 && b === 168) return true; // 192.168/16
  if (a === 100 && b >= 64 && b <= 127) return true; // Carrier-NAT 100.64/10
  if (a >= 224) return true; // Multicast/reserviert
  return false;
}

function istPrivateIpv6(host: string): boolean {
  // URL.hostname liefert IPv6 in eckigen Klammern: "[::1]".
  if (!host.startsWith("[")) return false;
  const h = host.slice(1, -1).toLowerCase();
  if (h === "::1" || h === "::") return true;
  if (h.startsWith("fc") || h.startsWith("fd")) return true; // ULA fc00::/7
  if (/^fe[89ab]/.test(h)) return true; // Link-local fe80::/10
  // IPv4-gemappt (::ffff:127.0.0.1 → vom Parser zu ::ffff:7f00:1)
  if (h.startsWith("::ffff:")) return true;
  return false;
}

/**
 * Prüft eine vom Aufrufer gelieferte URL und gibt die normalisierte Fassung
 * zurück — oder `null`, wenn sie nicht geladen werden darf.
 * Erlaubt: nur http/https, Länge ≤ 2000, Host weder localhost noch eine
 * private/Loopback/Link-local-Adresse. Der WHATWG-Parser normalisiert
 * Schreibweisen wie `http://2130706433/` oder `0x7f.1` zu `127.0.0.1`, die
 * Prüfung läuft auf dem normalisierten Host.
 */
export function pruefeUrl(eingabe: unknown): string | null {
  if (typeof eingabe !== "string") return null;
  const roh = eingabe.trim();
  if (roh.length === 0 || roh.length > MAX_URL_LAENGE) return null;
  // Fremdes Schema (ftp://, file://, javascript:) nicht stillschweigend
  // mit https:// überdecken.
  if (/^[a-z][a-z0-9+.-]*:/i.test(roh) && !/^https?:\/\//i.test(roh)) return null;

  let url: URL;
  try {
    url = new URL(normalisiereUrl(roh));
  } catch (_) {
    return null;
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") return null;
  if (url.username || url.password) return null;

  const host = url.hostname.toLowerCase().replace(/\.$/, "");
  if (host.length === 0) return null;
  if (host === "localhost" || host.endsWith(".localhost")) return null;
  if (host.endsWith(".local") || host.endsWith(".internal")) return null;
  if (istPrivateIpv4(host) || istPrivateIpv6(host)) return null;

  const ergebnis = url.toString();
  return ergebnis.length > MAX_URL_LAENGE ? null : ergebnis;
}

export function urlErlaubt(eingabe: unknown): boolean {
  return pruefeUrl(eingabe) !== null;
}
