/// Reine Hilfsfunktionen des Dokumente-Moduls (kein DB-Zugriff, testbar).
library;

const dokumentBereiche = <String, String>{
  'steuern': 'Steuern',
  'versicherungen': 'Versicherungen',
  'vertraege': 'Verträge',
  'behoerden': 'Behörden',
  'bank': 'Bank',
  'sonstiges': 'Sonstiges',
};

const _typLabels = <String, String>{
  'steuererklaerung': 'Steuererklärung',
  'jahresrechnung': 'Jahresrechnung',
  'veranlagung': 'Veranlagungsverfügung',
  'rechnung_provisorisch': 'Rechnung provisorisch',
  'rechnung_definitiv': 'Rechnung definitiv',
  'mahnung': 'Mahnung',
  'einspracheentscheid': 'Einspracheentscheid',
  'bussverfuegung': 'Bussverfügung',
  'bewertung_stammanteile': 'Bewertung Stammanteile',
  'zinsausweis': 'Zins-/Kapitalausweis',
  'lohnausweis': 'Lohnausweis',
  'police': 'Police',
  'vertrag': 'Vertrag',
  'brief': 'Brief',
  'sonstiges': 'Sonstiges',
};

const _typenJeBereich = <String, List<String>>{
  'steuern': [
    'steuererklaerung',
    'jahresrechnung',
    'veranlagung',
    'rechnung_provisorisch',
    'rechnung_definitiv',
    'mahnung',
    'einspracheentscheid',
    'bussverfuegung',
    'bewertung_stammanteile',
    'zinsausweis',
    'lohnausweis',
    'brief',
    'sonstiges',
  ],
  'versicherungen': ['police', 'rechnung_definitiv', 'brief', 'sonstiges'],
  'vertraege': ['vertrag', 'brief', 'sonstiges'],
  'behoerden': ['brief', 'veranlagung', 'sonstiges'],
  'bank': ['zinsausweis', 'vertrag', 'brief', 'sonstiges'],
  'sonstiges': ['brief', 'sonstiges'],
};

const steuerarten = <String, String>{
  'bund': 'Bund',
  'kanton': 'Kanton/Gemeinde',
  'mwst': 'MWST',
  'busse': 'Busse',
};

List<String> dokumentTypen(String bereich) =>
    _typenJeBereich[bereich] ?? const ['sonstiges'];

String dokumentTypLabel(String typ) => _typLabels[typ] ?? typ;

/// `$userId/$bereich/$jahr/$id_$dateiname`; Leerzeichen im Dateinamen → `_`.
String dokumentStoragePfad({
  required String userId,
  required String bereich,
  required int? jahr,
  required String dokumentId,
  required String dateiname,
}) {
  final safe = dateiname.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return '$userId/$bereich/${jahr ?? 'ohne-jahr'}/${dokumentId}_$safe';
}

/// Pflicht-Dokumenttypen eines Steuerjahres für die Dossier-Vollständigkeit.
/// Laufendes/künftiges Jahr: nur die Unterlagen, die vor der Einreichung
/// entstehen. Abgeschlossen: zusätzlich Erklärung und beide Verfügungen
/// (Kategorie bund/kanton werden im Rechner geprüft).
List<String> pflichtTypen({required int jahr, required DateTime heute}) {
  if (jahr >= heute.year) {
    return const ['jahresrechnung', 'lohnausweis', 'zinsausweis'];
  }
  return const [
    'jahresrechnung',
    'lohnausweis',
    'zinsausweis',
    'steuererklaerung',
    'veranlagung:bund',
    'veranlagung:kanton',
  ];
}
