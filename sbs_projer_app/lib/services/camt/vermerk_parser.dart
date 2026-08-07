/// Aus dem camt-Verwendungszweck (`remittanceInfo`) extrahierte Hinweise zur
/// Zuordnung einer Zahlung:
/// - [rechnungsnummern]: direkt genannte Rechnungsnummern `YYYY-MM-NNNN` (z.B.
///   Davos Klosters Bergbahnen „01.05.2026 2026-04-0505") — stärkstes Signal,
///   matcht die Forderung exakt. Sammelzahlungen nennen mehrere Nummern.
/// - [betriebNummer]: Betriebnummer aus einem strukturierten `Nummer_yyyy_MM_dd`.
/// - [datum]: Datum aus dem Betreff (z.B. HAPIMAG-Reinigungsdatum).
///
/// Reine Funktion — dient der **Vorauswahl** im manuellen Zuordnungs-Dialog
/// bzw. dem Routing zum Betrieb; nur wenn ALLE genannten Nummern offen sind
/// und ihre Summe exakt dem Zahlbetrag entspricht, entsteht ein Auto-Vorschlag.
class VermerkHinweis {
  final List<String> rechnungsnummern;
  final String? betriebNummer;
  final DateTime? datum;
  const VermerkHinweis(
      {this.rechnungsnummern = const [], this.betriebNummer, this.datum});

  /// Erste genannte Rechnungsnummer (Kompatibilität für Einzelnummer-Nutzer).
  String? get rechnungsnummer =>
      rechnungsnummern.isEmpty ? null : rechnungsnummern.first;

  bool get istLeer =>
      rechnungsnummern.isEmpty && betriebNummer == null && datum == null;
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

  // 1. Rechnungsnummern YYYY-MM-NNNN zuerst extrahieren und aus dem Rest
  //    entfernen, damit ihre Ziffern nicht als Datum fehlinterpretiert werden.
  //    Vorab Bank-Zeilenumbrüche MITTEN in einer Nummer reparieren (Fall LHG
  //    26.06.2026: «2026-04-047 5» = 2026-04-0475): Sequenz-Teile, die
  //    zusammen exakt 4 Stellen ergeben (Live-Format), werden verbunden —
  //    eine bereits vollständige Nummer bleibt unangetastet, weil ihre
  //    4-stellige Sequenz nicht auf \d{1,3} passt.
  var s = raw;
  s = s.replaceAllMapped(
      RegExp(r'(\d{4}-\d{2}-)(\d{1,3})\s+(\d{1,3})(?!\d)'), (m) {
    final seq = '${m.group(2)}${m.group(3)}';
    return seq.length == 4 ? '${m.group(1)}$seq' : m.group(0)!;
  });
  // Umbruch direkt nach dem zweiten Bindestrich («2026-04- 0475»).
  s = s.replaceAllMapped(RegExp(r'(\d{4}-\d{2}-)\s+(\d{3,5})\b'),
      (m) => '${m.group(1)}${m.group(2)}');
  final rechnungsnummern = <String>[];
  s = s.replaceAllMapped(RegExp(r'\b(\d{4}-\d{2}-\d{3,5})\b'), (m) {
    rechnungsnummern.add(m.group(1)!);
    return ' ';
  });

  // 2. Strukturiert: <Betriebnummer>_<yyyy>_<MM>_<dd> (Davos Klosters
  //    Bergbahnen, z.B. „0151_2026_04_04"). Die führende Zahl ist die
  //    (Heineken-)Betriebnummer — NICHT die Rechnungssequenz. Sie dient dem
  //    Routing zum Betrieb (matchByNummer), das Datum wählt die Forderung vor.
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
      rechnungsnummern: rechnungsnummern,
      betriebNummer: betriebNummer,
      datum: datum);
}
