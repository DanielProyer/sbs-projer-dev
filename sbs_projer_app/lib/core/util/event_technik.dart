// Event-Technik: Anstiche & Leitungen (reine Funktionen, testbar).
// Spec: docs/superpowers/specs/2026-08-14-event-anstiche-leitungen-design.md
//
// Die Leitungsnummer ist die physisch angeschriebene Beschriftung — sie steht
// am Anstich UND am Zapfhahn (Auskunft Daniel 14.08.2026). Nummern sind
// eindeutig je Anstich, nicht eventweit.

/// Natürlicher Vergleich von Leitungsnummern: führender Zahlenteil numerisch,
/// Rest lexikographisch. Lexikographisch stünde «10» vor «2» — auf dem
/// Kühlzelt-Zettel steht aber 1, 2, …, 10.
int vergleicheLeitungsNummern(String a, String b) {
  final za = _fuehrendeZahl(a);
  final zb = _fuehrendeZahl(b);
  if (za != null && zb != null) {
    final cmp = za.$1.compareTo(zb.$1);
    if (cmp != 0) return cmp;
    return za.$2.compareTo(zb.$2); // Suffix («a» in «7a»)
  }
  if (za != null) return -1; // Zahlen vor reinem Text
  if (zb != null) return 1;
  return a.compareTo(b);
}

/// Führende Zahl + Rest, z. B. «7a» → (7, 'a'); null wenn kein Zahl-Anfang.
(int, String)? _fuehrendeZahl(String s) {
  final m = RegExp(r'^(\d+)(.*)$').firstMatch(s.trim());
  if (m == null) return null;
  return (int.parse(m.group(1)!), m.group(2)!);
}

/// Nummernliste für die Massenanlage «Leitungen erzeugen»: [von]–[bis]
/// einschliesslich, vertauschte Grenzen werden getauscht, bereits
/// [bestehend]e Nummern übersprungen (macht die Aktion wiederholbar, ohne
/// den Unique-Index (quelle_id, nummer) zu verletzen).
List<String> leitungsNummernBereich(
  int von,
  int bis, {
  Set<String> bestehend = const {},
}) {
  final lo = von <= bis ? von : bis;
  final hi = von <= bis ? bis : von;
  return [
    for (var n = lo; n <= hi; n++)
      if (!bestehend.contains('$n')) '$n',
  ];
}

/// Gegenrichtung für die Stand-Karte: «7, 9 ← Anstich A», eine Zeile je
/// Quelle, Nummern natürlich sortiert. Quellen in der Reihenfolge ihres
/// ersten Auftretens; unbekannte Quelle wird «?» (fällt nicht um).
List<String> leitungsHinweiseFuerStand({
  required String standId,
  required List<({String nummer, String quelleId, String? standId})> leitungen,
  required Map<String, String> quelleNamen,
}) {
  final jeQuelle = <String, List<String>>{};
  for (final l in leitungen) {
    if (l.standId != standId) continue;
    jeQuelle.putIfAbsent(l.quelleId, () => []).add(l.nummer);
  }
  return [
    for (final e in jeQuelle.entries)
      '${(e.value..sort(vergleicheLeitungsNummern)).join(', ')}'
          ' ← ${quelleNamen[e.key] ?? '?'}',
  ];
}

/// Nummernsuche: trim + case-insensitiv, exakter Treffer (kein Substring —
/// «7» darf nicht «17» finden).
bool leitungNummerPasst(String eingabe, String nummer) {
  final e = eingabe.trim().toLowerCase();
  if (e.isEmpty) return false;
  return e == nummer.trim().toLowerCase();
}
