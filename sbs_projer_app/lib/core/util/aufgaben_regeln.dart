/// Aufgaben-Erinnerungen: Modell + die 4 automatischen Detektoren +
/// Sicht-/Sortier-Logik. Reine Funktionen, `heute` injizierbar (Spec
/// 2026-07-22). Detektoren erzeugen KEINE Persistenz — sie rechnen frisch.
library;

const _monate = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli',
  'August', 'September', 'Oktober', 'November', 'Dezember',
];

class Aufgabe {
  final String key;          // deterministisch: 'heineken:2026-07', 'mwst:2026-Q2', 'mahnlauf', 'saisondaten', 'eigene:<uuid>'
  final String titel;
  final bool dringend;       // rot statt orange
  final String? route;       // «Dorthin»-Ziel
  final bool manuellErledigbar; // Haken zeigen (mwst + eigene)
  const Aufgabe({
    required this.key,
    required this.titel,
    this.dringend = false,
    this.route,
    this.manuellErledigbar = false,
  });
}

/// Heineken-Monatsrechnung für den Vormonat. null = erledigt/nicht fällig.
Aufgabe? heinekenAufgabe({
  required DateTime heute,
  required bool rechnungExistiert,
  required bool rechnungOffen,
}) {
  final vormonat = DateTime(heute.year, heute.month - 1, 1);
  if (rechnungExistiert && !rechnungOffen) return null;
  final name = '${_monate[vormonat.month - 1]} ${vormonat.year}';
  final key =
      'heineken:${vormonat.year}-${vormonat.month.toString().padLeft(2, '0')}';
  return Aufgabe(
    key: key,
    titel: rechnungExistiert
        ? 'Heineken-Monatsrechnung $name versenden'
        : 'Heineken-Monatsrechnung $name erstellen',
    dringend: heute.day > 10,
    route: '/heineken',
  );
}

/// MWST für die letzten `maxQuartale` abgelaufenen Quartale (jüngstes
/// zuerst), die noch NICHT per Marker erledigt sind. Erledigung NUR per
/// Marker — unmarkierte ältere Quartale gehen dadurch nicht verloren, auch
/// wenn bereits weitere Quartale abgelaufen sind.
List<Aufgabe> mwstAufgaben({
  required DateTime heute,
  required Set<String> markerKeys,
  int maxQuartale = 4,
}) {
  // Zuletzt abgelaufenes Quartal.
  var jahr = heute.year;
  var quartal = ((heute.month - 1) ~/ 3); // 0 = Q4 Vorjahr
  if (quartal == 0) {
    jahr -= 1;
    quartal = 4;
  }
  final ergebnis = <Aufgabe>[];
  for (var i = 0; i < maxQuartale; i++) {
    final key = 'mwst:$jahr-Q$quartal';
    if (!markerKeys.contains(key)) {
      // Abgabefristen wie mwst_abrechnung_screen: Q1 31.05., Q2 31.08.,
      // Q3 30.11., Q4 28.02. Folgejahr.
      final frist = switch (quartal) {
        1 => DateTime(jahr, 5, 31),
        2 => DateTime(jahr, 8, 31),
        3 => DateTime(jahr, 11, 30),
        _ => DateTime(jahr + 1, 2, 28),
      };
      final tageBisFrist =
          frist.difference(DateTime(heute.year, heute.month, heute.day)).inDays;
      ergebnis.add(Aufgabe(
        key: key,
        titel: 'MWST Q$quartal $jahr abrechnen (Frist '
            '${frist.day.toString().padLeft(2, '0')}.${frist.month.toString().padLeft(2, '0')}.${frist.year})',
        dringend: tageBisFrist <= 14,
        route: '/buchhaltung/mwst',
        manuellErledigbar: true,
      ));
    }
    quartal -= 1;
    if (quartal == 0) {
      quartal = 4;
      jahr -= 1;
    }
  }
  return ergebnis;
}

Aufgabe? mahnlaufAufgabe(int anzahl) => anzahl <= 0
    ? null
    : Aufgabe(
        key: 'mahnlauf',
        titel: 'Mahnlauf: $anzahl Rechnungen fällig',
        route: '/buchhaltung/mahnwesen',
      );

Aufgabe? saisondatenAufgabe(int anzahl) => anzahl <= 0
    ? null
    : Aufgabe(
        key: 'saisondaten',
        titel: 'Saisondaten fehlen bei $anzahl Betrieben',
        route: '/touren',
      );

/// Snooze gilt bis EINSCHLIESSLICH snooze_bis.
bool snoozeAktiv(DateTime? snoozeBis, DateTime heute) {
  if (snoozeBis == null) return false;
  final h = DateTime(heute.year, heute.month, heute.day);
  return !DateTime(snoozeBis.year, snoozeBis.month, snoozeBis.day).isBefore(h);
}

/// Eigene Aufgabe sichtbar: ohne Datum sofort, sonst ab Fälligkeit − 7 Tage.
bool eigeneSichtbar(DateTime? faelligAm, DateTime heute) {
  if (faelligAm == null) return true;
  final h = DateTime(heute.year, heute.month, heute.day);
  final f = DateTime(faelligAm.year, faelligAm.month, faelligAm.day);
  return f.difference(h).inDays <= 7;
}

/// Dringende zuerst, sonst stabile Reihenfolge.
List<Aufgabe> sortiereAufgaben(List<Aufgabe> aufgaben) {
  final dringend = aufgaben.where((a) => a.dringend).toList();
  final rest = aufgaben.where((a) => !a.dringend).toList();
  return [...dringend, ...rest];
}
