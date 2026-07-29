/// Dauer-Schaetzung fuer Besuchs-Bloecke im Tourenplan (Spec 2026-07-29).
///
/// Kaskade: Median der Besuche dieses Betriebs mit gleicher Anlagenzahl ->
/// Betriebs-Median ueber die globale Kurve skaliert -> 60 min. Der Median ist
/// bewusst gewaehlt: einzelne Langlaeufer (Reparatur nebenbei) verzerren ihn
/// nicht — genau Daniels «Durchschnitt ohne Ausreisser», ohne erfundene Grenze.
library;

typedef BesuchHistorie = ({int anlagenZahl, int dauerMinuten});

/// Globale Median-Kurve je Anlagenzahl (aus 8'472 Reinigungen, 29.07.2026).
/// Ueber 4 Anlagen linear fortgeschrieben (+32 min je weitere Anlage).
const _kurve = <int, int>{1: 28, 2: 33, 3: 54, 4: 86};

int _kurvenWert(int anlagen) {
  if (anlagen <= 0) return _kurve[1]!;
  final k = _kurve[anlagen];
  if (k != null) return k;
  return _kurve[4]! + (anlagen - 4) * (_kurve[4]! - _kurve[3]!);
}

int? _median(List<int> werte) {
  if (werte.isEmpty) return null;
  final s = [...werte]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : ((s[m - 1] + s[m]) / 2).round();
}

const int kDauerDefaultMinuten = 60;

/// Voraussichtliche Dauer eines Besuchs mit [anlagenZahl] Anlagen.
int geschaetzteDauer({
  required List<BesuchHistorie> historie,
  required int anlagenZahl,
}) {
  final gueltig = historie.where((b) =>
      b.dauerMinuten >= 5 && b.dauerMinuten <= 300).toList();
  final gleiche = _median([
    for (final b in gueltig) if (b.anlagenZahl == anlagenZahl) b.dauerMinuten,
  ]);
  if (gleiche != null) return gleiche;

  // Betriebs-Median (haeufigste Anlagenzahl als Referenz) ueber Kurve skalieren.
  if (gueltig.isNotEmpty) {
    final zaehlung = <int, int>{};
    for (final b in gueltig) {
      zaehlung[b.anlagenZahl] = (zaehlung[b.anlagenZahl] ?? 0) + 1;
    }
    final refZahl = (zaehlung.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first.key;
    final refMedian = _median([
      for (final b in gueltig) if (b.anlagenZahl == refZahl) b.dauerMinuten,
    ])!;
    return (refMedian * _kurvenWert(anlagenZahl) / _kurvenWert(refZahl)).round();
  }
  return kDauerDefaultMinuten;
}

/// Dauer einer historischen Reinigung: dauer_minuten hat Vorrang, sonst
/// Ende - Start (HH:mm); unbrauchbar -> null.
int? dauerAusReinigung({int? dauerMinuten, String? start, String? ende}) {
  if (dauerMinuten != null && dauerMinuten > 0) return dauerMinuten;
  if (start == null || ende == null) return null;
  int? min(String s) {
    final t = s.split(':');
    if (t.length < 2) return null;
    final h = int.tryParse(t[0]), m = int.tryParse(t[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
  final a = min(start), b = min(ende);
  if (a == null || b == null || b <= a) return null;
  return b - a;
}
