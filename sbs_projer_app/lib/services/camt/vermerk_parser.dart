/// Aus dem camt-Verwendungszweck (`remittanceInfo`) extrahierte Hinweise zur
/// Zuordnung einer Zahlung: optionale **Betriebnummer** (Betreiber-
/// Sammelzahlung, z.B. Davos Klosters Bergbahnen `0151_2026_04_04`) und/oder
/// ein **Datum** (z.B. HAPIMAG mit Reinigungsdatum im Betreff).
///
/// Reine Funktion — dient nur der **Vorauswahl** im manuellen Zuordnungs-
/// Dialog, löst NIE eine automatische Buchung aus.
class VermerkHinweis {
  final String? betriebNummer;
  final DateTime? datum;
  const VermerkHinweis({this.betriebNummer, this.datum});

  bool get istLeer => betriebNummer == null && datum == null;
}

/// Baut ein gültiges Datum oder null (fängt Monat 13, 31.02. etc.).
/// 2-stellige Jahre werden als 20xx interpretiert.
DateTime? _gueltigesDatum(int jahr, int monat, int tag) {
  if (jahr < 100) jahr += 2000;
  if (monat < 1 || monat > 12 || tag < 1 || tag > 31) return null;
  final d = DateTime(jahr, monat, tag);
  if (d.year != jahr || d.month != monat || d.day != tag) return null;
  return d;
}

/// Parst den Verwendungszweck. Reihenfolge: strukturiert `Nummer_yyyy_MM_dd`
/// → ISO-Datum `yyyy-MM-dd` → Schweizer Datum `dd.MM.yyyy`.
VermerkHinweis parseVermerk(String? remittanceInfo) {
  final s = remittanceInfo?.trim() ?? '';
  if (s.isEmpty) return const VermerkHinweis();

  // 1. Strukturiert: <Nummer>_<yyyy>_<MM>_<dd> (Betreiber-Sammelzahlung).
  final strukt =
      RegExp(r'(\d{2,6})[_\s./-](\d{4})[_\s./-](\d{1,2})[_\s./-](\d{1,2})')
          .firstMatch(s);
  if (strukt != null) {
    final datum = _gueltigesDatum(int.parse(strukt.group(2)!),
        int.parse(strukt.group(3)!), int.parse(strukt.group(4)!));
    if (datum != null) {
      return VermerkHinweis(betriebNummer: strukt.group(1), datum: datum);
    }
  }

  // 2. ISO-Datum yyyy-MM-dd irgendwo im Text.
  final iso = RegExp(r'(\d{4})[_./-](\d{1,2})[_./-](\d{1,2})').firstMatch(s);
  if (iso != null) {
    final datum = _gueltigesDatum(int.parse(iso.group(1)!),
        int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    if (datum != null) return VermerkHinweis(datum: datum);
  }

  // 3. Schweizer Datum dd.MM.yyyy / dd.MM.yy.
  final swiss = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})').firstMatch(s);
  if (swiss != null) {
    final datum = _gueltigesDatum(int.parse(swiss.group(3)!),
        int.parse(swiss.group(2)!), int.parse(swiss.group(1)!));
    if (datum != null) return VermerkHinweis(datum: datum);
  }

  return const VermerkHinweis();
}
