// Schweizer Feiertage — Kanton Luzern
// 13 gesetzliche Feiertage: 8 fixe + 5 Ostern-abhängige
// Basiert auf dem Ruhetags- und Ladenschlussgesetz (RLG, SRL Nr. 855)
// Gauss-Algorithmus für Osterberechnung (Gregorianischer Kalender)

class Feiertag {
  final DateTime datum;
  final String name;
  final bool istBeweglich; // Ostern-abhängig

  const Feiertag({
    required this.datum,
    required this.name,
    this.istBeweglich = false,
  });
}

class SchweizerFeiertage {
  /// Berechnet Ostersonntag nach Gauss-Algorithmus (Gregorianisch)
  static DateTime ostersonntag(int jahr) {
    final a = jahr % 19;
    final b = jahr % 4;
    final c = jahr % 7;
    final k = jahr ~/ 100;
    final p = (13 + 8 * k) ~/ 25;
    final q = k ~/ 4;
    final m = (15 - p + k - q) % 30;
    final n = (4 + k - q) % 7;
    final d = (19 * a + m) % 30;
    final e = (2 * b + 4 * c + 6 * d + n) % 7;

    int tag = 22 + d + e; // März-basiert
    int monat = 3;

    if (tag > 31) {
      tag -= 31;
      monat = 4;
    }

    // Sonderregeln
    if (monat == 4 && tag == 26) tag = 19;
    if (monat == 4 && tag == 25 && d == 28 && e == 6 && a > 10) tag = 18;

    return DateTime(jahr, monat, tag);
  }

  /// Alle 13 gesetzlichen Feiertage im Kanton Luzern für ein Jahr
  static List<Feiertag> feiertage(int jahr) {
    final ostern = ostersonntag(jahr);

    return [
      // ─── Fixe Feiertage (8) ───
      Feiertag(datum: DateTime(jahr, 1, 1), name: 'Neujahr'),
      Feiertag(datum: DateTime(jahr, 1, 2), name: 'Berchtoldstag'),
      Feiertag(datum: DateTime(jahr, 8, 1), name: 'Bundesfeiertag'),
      Feiertag(datum: DateTime(jahr, 8, 15), name: 'Mariä Himmelfahrt'),
      Feiertag(datum: DateTime(jahr, 11, 1), name: 'Allerheiligen'),
      Feiertag(datum: DateTime(jahr, 12, 8), name: 'Mariä Empfängnis'),
      Feiertag(datum: DateTime(jahr, 12, 25), name: 'Weihnachtstag'),
      Feiertag(datum: DateTime(jahr, 12, 26), name: 'Stephanstag'),

      // ─── Bewegliche Feiertage (5, Ostern-abhängig) ───
      Feiertag(
        datum: ostern.subtract(const Duration(days: 2)),
        name: 'Karfreitag',
        istBeweglich: true,
      ),
      Feiertag(
        datum: ostern.add(const Duration(days: 1)),
        name: 'Ostermontag',
        istBeweglich: true,
      ),
      Feiertag(
        datum: ostern.add(const Duration(days: 39)),
        name: 'Auffahrt',
        istBeweglich: true,
      ),
      Feiertag(
        datum: ostern.add(const Duration(days: 50)),
        name: 'Pfingstmontag',
        istBeweglich: true,
      ),
      Feiertag(
        datum: ostern.add(const Duration(days: 60)),
        name: 'Fronleichnam',
        istBeweglich: true,
      ),
    ];
  }

  /// Prüft ob ein Datum ein Feiertag ist. Gibt den Feiertag zurück oder null.
  static Feiertag? istFeiertag(DateTime datum) {
    final liste = feiertage(datum.year);
    final normDatum = DateTime(datum.year, datum.month, datum.day);
    for (final f in liste) {
      if (DateTime(f.datum.year, f.datum.month, f.datum.day) == normDatum) {
        return f;
      }
    }
    return null;
  }

  /// Zählt Feiertage in einem Datumsbereich (inklusive Start und Ende)
  static List<Feiertag> feiertageImZeitraum(DateTime von, DateTime bis) {
    final result = <Feiertag>[];
    final normVon = DateTime(von.year, von.month, von.day);
    final normBis = DateTime(bis.year, bis.month, bis.day);

    // Feiertage für alle betroffenen Jahre
    final jahre = <int>{von.year, bis.year};
    for (final jahr in jahre) {
      for (final f in feiertage(jahr)) {
        final normF = DateTime(f.datum.year, f.datum.month, f.datum.day);
        if (!normF.isBefore(normVon) && !normF.isAfter(normBis)) {
          result.add(f);
        }
      }
    }
    return result;
  }

  /// Feiertage für einen ganzen Monat (für Kalender-Darstellung)
  static Map<DateTime, Feiertag> feiertageImMonat(int jahr, int monat) {
    final map = <DateTime, Feiertag>{};
    for (final f in feiertage(jahr)) {
      if (f.datum.month == monat && f.datum.year == jahr) {
        map[DateTime(f.datum.year, f.datum.month, f.datum.day)] = f;
      }
    }
    // Falls Jahresgrenze (z.B. Dezember-Anzeige zeigt Januar)
    if (monat == 12) {
      for (final f in feiertage(jahr + 1)) {
        if (f.datum.month == 1) {
          map[DateTime(f.datum.year, f.datum.month, f.datum.day)] = f;
        }
      }
    }
    if (monat == 1) {
      for (final f in feiertage(jahr - 1)) {
        if (f.datum.month == 12) {
          map[DateTime(f.datum.year, f.datum.month, f.datum.day)] = f;
        }
      }
    }
    return map;
  }
}
