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
  'kontoauszug': 'Kontoauszug',
  'freizuegigkeit': 'Freizügigkeitsleistung',
  'verfuegung': 'Verfügung',
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
  'versicherungen': [
    'police',
    'rechnung_definitiv',
    'mahnung',
    'kontoauszug',
    'verfuegung',
    'freizuegigkeit',
    'vertrag',
    'brief',
    'sonstiges',
  ],
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

/// Kategorien im Bereich «Versicherungen» — analog [steuerarten].
/// Die Pensionskasse ist der Grund dafür: Der Ordner 06_PK enthält 31
/// BVG-Dokumente, die sich sonst nicht von Haftpflicht oder Unfall trennen
/// liessen.
const versicherungsarten = <String, String>{
  'ahv': 'AHV/IV/EO/ALV/FAK (SVA)',
  'pensionskasse': 'Pensionskasse (BVG)',
  'unfall': 'Unfall (UVG/SUVA)',
  'krankentaggeld': 'Krankentaggeld (KTG)',
  'haftpflicht': 'Haftpflicht',
  'fahrzeug': 'Fahrzeug',
};

/// Feste Kategorien eines Bereichs, oder null wenn dort Freitext gilt.
/// Der Upload-Dialog zeigt danach ein Dropdown statt eines Textfelds.
Map<String, String>? dokumentKategorien(String bereich) => switch (bereich) {
  'steuern' => steuerarten,
  'versicherungen' => versicherungsarten,
  _ => null,
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

/// Lesbares Label für einen Pflicht-Dokumenttyp aus [pflichtTypen], z. B.
/// `'veranlagung:kanton'` → `'Veranlagungsverfügung Kanton/Gemeinde'`.
String pflichtTypLabel(String schluessel) {
  final teile = schluessel.split(':');
  final basis = dokumentTypLabel(teile[0]);
  if (teile.length < 2) return basis;
  final art = steuerarten[teile[1]] ?? teile[1];
  return '$basis $art';
}
