/// Aus dem camt-Verwendungszweck (`remittanceInfo`) extrahierte Hinweise zur
/// Zuordnung einer Zahlung:
/// - [rechnungsnummer]: direkt genannte Rechnungsnummer `YYYY-MM-NNNN` (z.B.
///   Davos Klosters Bergbahnen „01.05.2026 2026-04-0505") — stärkstes Signal,
///   matcht die Forderung exakt.
/// - [betriebNummer]: Betriebnummer aus einem strukturierten `Nummer_yyyy_MM_dd`.
/// - [datum]: Datum aus dem Betreff (z.B. HAPIMAG-Reinigungsdatum).
///
/// Reine Funktion — dient nur der **Vorauswahl** im manuellen Zuordnungs-
/// Dialog bzw. dem Routing zum Betrieb, löst NIE eine automatische Buchung aus.
class VermerkHinweis {
  final String? rechnungsnummer;
  final String? betriebNummer;
  final DateTime? datum;
  const VermerkHinweis({this.rechnungsnummer, this.betriebNummer, this.datum});

  bool get istLeer =>
      rechnungsnummer == null && betriebNummer == null && datum == null;
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

/// Parst den Verwendungszweck. Reihenfolge: Rechnungsnummer (extrahiert +
/// entfernt) → strukturiert `Nummer_yyyy_MM_dd` → ISO-Datum → Schweizer Datum.
VermerkHinweis parseVermerk(String? remittanceInfo) {
  final raw = remittanceInfo?.trim() ?? '';
  if (raw.isEmpty) return const VermerkHinweis();

  // 1. Rechnungsnummer YYYY-MM-NNNN zuerst extrahieren und aus dem Rest
  //    entfernen, damit ihre Ziffern nicht als Datum fehlinterpretiert werden.
  String? rechnungsnummer;
  var s = raw;
  final rn = RegExp(r'\b(\d{4}-\d{2}-\d{3,5})\b').firstMatch(s);
  if (rn != null) {
    rechnungsnummer = rn.group(1);
    s = s.replaceRange(rn.start, rn.end, ' ');
  }

  // 2. Strukturiert: <Nummer>_<yyyy>_<MM>_<dd> (Betreiber-Sammelzahlung).
  String? betriebNummer;
  DateTime? datum;
  final strukt =
      RegExp(r'(\d{2,6})[_\s./-](\d{4})[_\s./-](\d{1,2})[_\s./-](\d{1,2})')
          .firstMatch(s);
  if (strukt != null) {
    final d = _gueltigesDatum(int.parse(strukt.group(2)!),
        int.parse(strukt.group(3)!), int.parse(strukt.group(4)!));
    if (d != null) {
      betriebNummer = strukt.group(1);
      datum = d;
    }
  }

  // 3. ISO-Datum yyyy-MM-dd.
  if (datum == null) {
    final iso = RegExp(r'(\d{4})[_./-](\d{1,2})[_./-](\d{1,2})').firstMatch(s);
    if (iso != null) {
      datum = _gueltigesDatum(int.parse(iso.group(1)!),
          int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    }
  }

  // 4. Schweizer Datum dd.MM.yyyy / dd.MM.yy.
  if (datum == null) {
    final sw = RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})').firstMatch(s);
    if (sw != null) {
      datum = _gueltigesDatum(int.parse(sw.group(3)!),
          int.parse(sw.group(2)!), int.parse(sw.group(1)!));
    }
  }

  return VermerkHinweis(
      rechnungsnummer: rechnungsnummer,
      betriebNummer: betriebNummer,
      datum: datum);
}
