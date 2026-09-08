/// Reine Hilfsfunktionen des Dokumente-Moduls (kein DB-Zugriff, testbar).
library;

/// Oberste Ablage-Ebene. Ein Bereich = ein Absender mit eigenem Belegkreis.
///
/// Die Sozialversicherungen standen bis 08.09.2026 als Kategorien unter einem
/// gemeinsamen Bereich «Versicherungen». Das hiess: wer eine SUVA-Verfügung
/// suchte, sah zuerst 101 Dokumente von vier Absendern. Seit dem Entscheid
/// Daniels an diesem Tag hat jede Stelle ihre eigene Ebene — sie schicken
/// verschiedene Belege, haben verschiedene Ansprechpartner und verschiedene
/// Fristen. «Versicherungen (übrige)» bleibt als Auffangbereich für alles, was
/// später dazukommt (Sach, Rechtsschutz, Fahrzeug).
const dokumentBereiche = <String, String>{
  'steuern': 'Steuern',
  'ahv': 'AHV/SVA',
  'unfall': 'Unfall/SUVA',
  'krankentaggeld': 'Krankentaggeld',
  'pensionskasse': 'Pensionskasse',
  'haftpflicht': 'Haftpflicht',
  'versicherungen': 'Versicherungen (übrige)',
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
  'statuten': 'Statuten',
  'urkunde': 'Öffentliche Urkunde',
  'protokoll': 'Protokoll',
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
  // Die SVA stellt akonto und rechnet am Jahresende ab; Bussen und
  // Verzugszinsen kommen als eigene Verfügung.
  'ahv': [
    'rechnung_provisorisch',
    'rechnung_definitiv',
    'mahnung',
    'verfuegung',
    'bussverfuegung',
    'kontoauszug',
    'vertrag',
    'brief',
    'sonstiges',
  ],
  // Die SUVA schickt eine provisorische Prämienrechnung und im Folgejahr die
  // Prämienverfügung mit der Abrechnung.
  'unfall': [
    'police',
    'rechnung_provisorisch',
    'rechnung_definitiv',
    'verfuegung',
    'mahnung',
    'vertrag',
    'brief',
    'sonstiges',
  ],
  'krankentaggeld': [
    'police',
    'rechnung_definitiv',
    'mahnung',
    'vertrag',
    'brief',
    'sonstiges',
  ],
  'haftpflicht': [
    'police',
    'rechnung_definitiv',
    'mahnung',
    'vertrag',
    'brief',
    'sonstiges',
  ],
  'versicherungen': [
    'police',
    'rechnung_definitiv',
    'mahnung',
    'vertrag',
    'brief',
    'sonstiges',
  ],
  'pensionskasse': [
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
  'vertraege': ['vertrag', 'statuten', 'urkunde', 'protokoll', 'brief', 'sonstiges'],
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

/// Kategorien im Bereich «Verträge» — der Ordner 17_Firmengründung enthält
/// Gründungsakte, den Heineken-Franchisevertrag und den
/// Fahrzeugüberlassungsvertrag; ohne Trennung liegen sie unauffindbar
/// nebeneinander.
const vertragsarten = <String, String>{
  'gruendung': 'Gründung',
  'franchise': 'Franchise (Heineken)',
  'fahrzeug': 'Fahrzeug',
  'miete': 'Miete',
  'sonstiges': 'Sonstiges',
};

/// Feste Kategorien eines Bereichs, oder null wenn dort Freitext gilt.
/// Der Upload-Dialog zeigt danach ein Dropdown statt eines Textfelds.
Map<String, String>? dokumentKategorien(String bereich) => switch (bereich) {
  'steuern' => steuerarten,
  'vertraege' => vertragsarten,
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
