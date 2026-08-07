/// Sammelzahler zahlen für MEHRERE Betriebe (Zentrale/Konzern). Für sie darf
/// weder ein gelernter Alias noch ein exakter Name automatisch verbuchen —
/// die einzelne Zahlung kann jedem ihrer Objekte gehören. Zuordnung läuft
/// über den Vermerk (Betriebs-/Rechnungsnummer) oder manuell.
///
/// Bestätigt Daniel 07.08.2026:
/// - Weisse Arena Hospitality AG → IKIGAI, Il Pub, Indy Bar, Signina,
///   Legna, Nagens
/// - Goodfast Hotels AG → Grischa, Golden Dragon, Jodys, Bräma (alle Davos)
/// - Davos Klosters Bergbahnen AG → diverse Bergbetriebe (Vermerk trägt die
///   Heineken-Betriebsnummer, z. B. 0151 = Armando Klosters)
const kSammelzahler = ['davos klosters', 'weisse arena', 'goodfast'];

bool istSammelzahler(String? name) {
  if (name == null) return false;
  final n = name.toLowerCase();
  return kSammelzahler.any(n.contains);
}
