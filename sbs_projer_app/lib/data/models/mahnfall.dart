/// Ein Mahnfall (Migration 204, v0.135.0): Eskalation nach der letzten
/// Mahnung — Heineken einschalten, Ergebnis, ggf. Betreibung. Ein Fall je
/// Betrieb und Eskalation; die Rechnungen des Falls stehen in [rechnungIds].
class Mahnfall {
  final String id;
  final String userId;
  final String betriebId;
  final List<String> rechnungIds;
  final DateTime eroeffnetAm;

  /// 'heineken' | 'heineken_frist' | 'betreibung' | 'erledigt'
  final String status;
  final bool test;

  final DateTime? heinekenKontaktAm;
  final String? heinekenEmpfaenger;

  /// 'vermittelt' | 'uebernommen' | 'konkurs' | 'betreibung'
  final String? heinekenErgebnis;
  final DateTime? heinekenErgebnisAm;
  final DateTime? heinekenFristBis;

  final String? schuldnerName;
  final String? schuldnerAdresse;

  /// 'einzelfirma' | 'gmbh' | 'ag' | 'andere'
  final String? rechtsform;
  final String? betreibungsamt;
  final DateTime? eingereichtAm;
  final DateTime? zahlungsbefehlAm;
  final bool? rechtsvorschlag;
  final DateTime? fortsetzungAm;
  final double? kostenVorschuss;

  final DateTime? erledigtAm;

  /// 'bezahlt' | 'abgeschrieben' | 'zurueckgezogen' | 'uebernommen'
  final String? erledigung;
  final String? notiz;
  final DateTime erstelltAm;
  final DateTime aktualisiertAm;

  const Mahnfall({
    required this.id,
    required this.userId,
    required this.betriebId,
    required this.rechnungIds,
    required this.eroeffnetAm,
    required this.status,
    required this.test,
    this.heinekenKontaktAm,
    this.heinekenEmpfaenger,
    this.heinekenErgebnis,
    this.heinekenErgebnisAm,
    this.heinekenFristBis,
    this.schuldnerName,
    this.schuldnerAdresse,
    this.rechtsform,
    this.betreibungsamt,
    this.eingereichtAm,
    this.zahlungsbefehlAm,
    this.rechtsvorschlag,
    this.fortsetzungAm,
    this.kostenVorschuss,
    this.erledigtAm,
    this.erledigung,
    this.notiz,
    required this.erstelltAm,
    required this.aktualisiertAm,
  });

  bool get offen => status != 'erledigt';

  static DateTime? _tag(dynamic v) {
    if (v == null) return null;
    final d = DateTime.parse(v as String);
    return DateTime.utc(d.year, d.month, d.day);
  }

  factory Mahnfall.fromJson(Map<String, dynamic> j) => Mahnfall(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        betriebId: j['betrieb_id'] as String,
        rechnungIds: List<String>.from(j['rechnung_ids'] as List? ?? const []),
        eroeffnetAm: _tag(j['eroeffnet_am'])!,
        status: j['status'] as String,
        test: j['test'] as bool? ?? true,
        heinekenKontaktAm: _tag(j['heineken_kontakt_am']),
        heinekenEmpfaenger: j['heineken_empfaenger'] as String?,
        heinekenErgebnis: j['heineken_ergebnis'] as String?,
        heinekenErgebnisAm: _tag(j['heineken_ergebnis_am']),
        heinekenFristBis: _tag(j['heineken_frist_bis']),
        schuldnerName: j['schuldner_name'] as String?,
        schuldnerAdresse: j['schuldner_adresse'] as String?,
        rechtsform: j['rechtsform'] as String?,
        betreibungsamt: j['betreibungsamt'] as String?,
        eingereichtAm: _tag(j['eingereicht_am']),
        zahlungsbefehlAm: _tag(j['zahlungsbefehl_am']),
        rechtsvorschlag: j['rechtsvorschlag'] as bool?,
        fortsetzungAm: _tag(j['fortsetzung_am']),
        kostenVorschuss: j['kosten_vorschuss'] == null
            ? null
            : double.parse(j['kosten_vorschuss'].toString()),
        erledigtAm: _tag(j['erledigt_am']),
        erledigung: j['erledigung'] as String?,
        notiz: j['notiz'] as String?,
        erstelltAm: DateTime.parse(j['erstellt_am'] as String),
        aktualisiertAm: DateTime.parse(j['aktualisiert_am'] as String),
      );
}
