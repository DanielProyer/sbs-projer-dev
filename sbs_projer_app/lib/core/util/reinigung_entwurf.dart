/// Zwischenstand einer NEUEN Reinigung, die noch nicht gespeichert ist (V2,
/// Analyse-Runde 5 «Tagesbetrieb»).
///
/// **Warum:** Eine neue Reinigung lebte nur im Browser-Tab. Die Kamera-App
/// schiebt Chrome in den Hintergrund, Android verwirft den Tab — und alles
/// Eingetippte war weg: 111 Formular-Öffnungen bei 73 Reinigungen in 17
/// Tagen. Der Entwurf überbrückt genau diese Lücke; er ist Übergangsmaterial
/// und verfällt nach [gueltigkeit].
///
/// Reine Klasse ohne Flutter-Abhängigkeit. [ReinigungEntwurf.fromJson] wirft
/// nie: Ein kaputter Speicherstand darf das Formular nicht abstürzen lassen,
/// er wird zu Standardwerten.
class ReinigungEntwurf {
  /// Älter als das → nicht mehr anbieten (eine Reinigung dauert Stunden,
  /// nicht Tage; ein Entwurf von vorgestern ist ein vergessener).
  static const gueltigkeit = Duration(days: 2);

  final String betriebId;
  final List<String> anlageIds;
  final DateTime datum;
  final String? uhrzeitStart;
  final String serviceArt;
  final String? serviceTyp;
  final int anzahlHaehneEigen;
  final int anzahlHaehneOrion;
  final int anzahlHaehneFremd;
  final int anzahlHaehneWein;
  final int anzahlHaehneAndererStandort;
  final bool istKulanz;
  final bool istBergkunde;
  final String? notizen;

  /// Pfad des bereits hochgeladenen Protokollfotos (Web: Sofort-Upload).
  final String? protokollFotoPfad;

  /// Vorab erzeugte Reinigungs-ID = Foto-Ordner. Muss beim Fortsetzen
  /// übernommen werden, sonst läge das Foto in einem fremden Ordner.
  final String? fotoReinigungId;

  /// Zahlungsart der Formular-Zeile (V6). Beim Fortsetzen gilt sie nur als
  /// eigene Wahl, wenn sie von der Betriebs-Vorgabe abweicht.
  final String? zahlungsart;
  final DateTime gespeichertAm;

  const ReinigungEntwurf({
    required this.betriebId,
    this.anlageIds = const [],
    required this.datum,
    this.uhrzeitStart,
    this.serviceArt = 'standardservice',
    this.serviceTyp,
    this.anzahlHaehneEigen = 0,
    this.anzahlHaehneOrion = 0,
    this.anzahlHaehneFremd = 0,
    this.anzahlHaehneWein = 0,
    this.anzahlHaehneAndererStandort = 0,
    this.istKulanz = false,
    this.istBergkunde = false,
    this.notizen,
    this.protokollFotoPfad,
    this.fotoReinigungId,
    this.zahlungsart,
    required this.gespeichertAm,
  });

  Map<String, dynamic> toJson() => {
    'betrieb_id': betriebId,
    'anlage_ids': anlageIds,
    'datum': datum.toIso8601String(),
    'uhrzeit_start': uhrzeitStart,
    'service_art': serviceArt,
    'service_typ': serviceTyp,
    'anzahl_haehne_eigen': anzahlHaehneEigen,
    'anzahl_haehne_orion': anzahlHaehneOrion,
    'anzahl_haehne_fremd': anzahlHaehneFremd,
    'anzahl_haehne_wein': anzahlHaehneWein,
    'anzahl_haehne_anderer_standort': anzahlHaehneAndererStandort,
    'ist_kulanz': istKulanz,
    'ist_bergkunde': istBergkunde,
    'notizen': notizen,
    'protokoll_foto_pfad': protokollFotoPfad,
    'foto_reinigung_id': fotoReinigungId,
    'zahlungsart': zahlungsart,
    'gespeichert_am': gespeichertAm.toIso8601String(),
  };

  factory ReinigungEntwurf.fromJson(Map<String, dynamic> json) {
    String? text(String k) {
      final v = json[k];
      return v is String && v.isNotEmpty ? v : null;
    }

    int zahl(String k) {
      final v = json[k];
      return v is int && v >= 0 ? v : 0;
    }

    bool schalter(String k) => json[k] == true;

    DateTime? zeit(String k) {
      final v = json[k];
      return v is String ? DateTime.tryParse(v) : null;
    }

    final anlagen = json['anlage_ids'];
    return ReinigungEntwurf(
      betriebId: text('betrieb_id') ?? '',
      anlageIds: anlagen is List
          ? anlagen.whereType<String>().toList()
          : const [],
      datum: zeit('datum') ?? DateTime.now(),
      uhrzeitStart: text('uhrzeit_start'),
      serviceArt: text('service_art') ?? 'standardservice',
      serviceTyp: text('service_typ'),
      anzahlHaehneEigen: zahl('anzahl_haehne_eigen'),
      anzahlHaehneOrion: zahl('anzahl_haehne_orion'),
      anzahlHaehneFremd: zahl('anzahl_haehne_fremd'),
      anzahlHaehneWein: zahl('anzahl_haehne_wein'),
      anzahlHaehneAndererStandort: zahl('anzahl_haehne_anderer_standort'),
      istKulanz: schalter('ist_kulanz'),
      istBergkunde: schalter('ist_bergkunde'),
      notizen: text('notizen'),
      protokollFotoPfad: text('protokoll_foto_pfad'),
      fotoReinigungId: text('foto_reinigung_id'),
      zahlungsart: text('zahlungsart'),
      // Ohne lesbaren Zeitstempel gilt der Entwurf als uralt: lieber
      // verwerfen, als einen Stand unbekannten Alters vorzuschlagen.
      gespeichertAm:
          zeit('gespeichert_am') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool istAbgelaufen(DateTime jetzt) =>
      jetzt.difference(gespeichertAm) > gueltigkeit;

  /// Uhrzeit der letzten Sicherung, z. B. «09:12» — für das Band
  /// «Angefangene Reinigung von 09:12».
  String kurzText() {
    String zwei(int n) => n.toString().padLeft(2, '0');
    return '${zwei(gespeichertAm.hour)}:${zwei(gespeichertAm.minute)}';
  }
}
