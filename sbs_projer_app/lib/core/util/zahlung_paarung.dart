// Paarung von Zahlungseingängen mit Forderungen bei Mehrfachauswahl.

/// Ordnet Zahlungen und Forderungen paarweise zu: **neueste Zahlung zur
/// neuesten Forderung**, dann die zweitneueste zur zweitneuesten und so fort
/// (Regel Daniel 28.07.2026).
///
/// Vorher trugen alle Rechnungen einer Sammelzahlung die Werte der zuerst
/// markierten Zahlung — Datum und camt-Schlüssel inbegriffen. Bei Zahlungen
/// von verschiedenen Tagen stand damit an einer Rechnung ein Datum, an dem sie
/// gar nicht bezahlt wurde.
///
/// Gibt je Forderung (Schlüssel = Forderungs-Id) die zugeordnete Zahlung
/// zurück. Sind es mehr Forderungen als Zahlungen, erhalten die übrigen — die
/// ältesten — die älteste Zahlung: Sie wurden mit demselben Geldeingang
/// beglichen.
Map<String, T> paareNachDatum<T>({
  required List<T> zahlungen,
  required DateTime Function(T) datumVon,
  required List<({String id, DateTime rechnungsdatum})> forderungen,
}) {
  if (zahlungen.isEmpty || forderungen.isEmpty) return {};

  final sortierteZahlungen = [...zahlungen]
    ..sort((a, b) => datumVon(b).compareTo(datumVon(a)));
  final sortierteForderungen = [...forderungen]
    ..sort((a, b) => b.rechnungsdatum.compareTo(a.rechnungsdatum));

  final ergebnis = <String, T>{};
  for (var i = 0; i < sortierteForderungen.length; i++) {
    ergebnis[sortierteForderungen[i].id] = i < sortierteZahlungen.length
        ? sortierteZahlungen[i]
        : sortierteZahlungen.last;
  }
  return ergebnis;
}

/// Wie [paareNachDatum], aber mit **Betrags-Vorrang**: Zuerst werden Paare
/// gebildet, deren Beträge exakt übereinstimmen (neueste Forderung zuerst),
/// nur der Rest läuft über die Datums-Regel.
///
/// Grund (Sammelzahler wie Weisse Arena / Davos Klosters Bergbahnen,
/// 07.08.2026): Mehrere Zahlungen desselben Tages begleichen mehrere
/// Rechnungen desselben Tages — die reine Datums-Paarung ist dann Zufall und
/// hängt z.B. die 74.60-Zahlung an die 132.95-Rechnung. Der Betrag ist in
/// diesem Fall das eindeutige Signal.
Map<String, T> paareMitBetrag<T>({
  required List<T> zahlungen,
  required DateTime Function(T) datumVon,
  required double Function(T) betragVon,
  required List<({String id, DateTime rechnungsdatum, double betrag})>
      forderungen,
}) {
  if (zahlungen.isEmpty || forderungen.isEmpty) return {};

  final ergebnis = <String, T>{};
  final freieZahlungen = [...zahlungen]
    ..sort((a, b) => datumVon(b).compareTo(datumVon(a)));
  final freieForderungen = [...forderungen]
    ..sort((a, b) => b.rechnungsdatum.compareTo(a.rechnungsdatum));

  // 1. Betrag-exakte Paare (auf den Rappen), neueste Forderung zuerst.
  for (final f in [...freieForderungen]) {
    T? passend;
    for (final z in freieZahlungen) {
      if ((betragVon(z) - f.betrag).abs() < 0.005) {
        passend = z;
        break;
      }
    }
    if (passend != null) {
      ergebnis[f.id] = passend;
      freieZahlungen.remove(passend);
      freieForderungen.remove(f);
    }
  }

  // 2. Rest über die Datums-Regel. Sind alle Zahlungen betragsgepaart,
  //    erhalten übrige Forderungen die älteste Zahlung (wie [paareNachDatum]).
  if (freieForderungen.isNotEmpty) {
    final restZahlungen = freieZahlungen.isNotEmpty
        ? freieZahlungen
        : <T>[([...zahlungen]..sort((a, b) => datumVon(b).compareTo(datumVon(a)))).last];
    ergebnis.addAll(paareNachDatum<T>(
      zahlungen: restZahlungen,
      datumVon: datumVon,
      forderungen: [
        for (final f in freieForderungen)
          (id: f.id, rechnungsdatum: f.rechnungsdatum)
      ],
    ));
  }
  return ergebnis;
}
