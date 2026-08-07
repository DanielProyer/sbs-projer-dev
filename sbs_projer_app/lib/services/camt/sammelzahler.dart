/// Sammelzahler zahlen für MEHRERE Betriebe (Zentrale/Konzern). Für sie darf
/// weder ein gelernter Alias noch ein exakter Name automatisch verbuchen —
/// die einzelne Zahlung kann jedem ihrer Objekte gehören. Zuordnung läuft
/// über den Vermerk (Betriebs-/Rechnungsnummer) oder manuell.
const kSammelzahler = ['davos klosters', 'weisse arena'];

bool istSammelzahler(String? name) {
  if (name == null) return false;
  final n = name.toLowerCase();
  return kSammelzahler.any(n.contains);
}
