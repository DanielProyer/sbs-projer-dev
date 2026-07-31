/// Ergebnis der Edge-Function `parse-einsatz` — Daniel diktiert unterwegs
/// (Gboard-Mikrofon) einen kurzen Satz, die KI macht daraus einen
/// strukturierten Einsatz-Vorschlag, der in der App bestätigt wird (siehe
/// `presentation/widgets/diktat_sheet.dart`). Nichts hieraus wird je still
/// gespeichert — der Vorschlag ist immer nur Vorschlag.
class EinsatzDiktatErgebnis {
  /// 'stoerung' | 'montage' | 'eroeffnungsreinigung' | 'endreinigung' |
  /// 'aufgabe' | 'neuer_betrieb'.
  final String art;
  final String? betriebId;
  final String? betriebNameErkannt;
  final List<EinsatzBetriebKandidat> betriebKandidaten;
  final DateTime? geplantAm;
  final String? geplantZeit;
  final int? geplantDauerMin;
  final String? beschreibung;
  final double konfidenz;
  final String? rueckfrage;

  // Nur bei art == 'neuer_betrieb' gesetzt.
  final String? betriebNeuName;
  final String? betriebNeuOrt;
  final String? anlagenTyp; // 'heigenie' | 'david' | 'konventionell' | 'orion'
  final bool? istMeinKunde;

  const EinsatzDiktatErgebnis({
    required this.art,
    this.betriebId,
    this.betriebNameErkannt,
    this.betriebKandidaten = const [],
    this.geplantAm,
    this.geplantZeit,
    this.geplantDauerMin,
    this.beschreibung,
    this.konfidenz = 0,
    this.rueckfrage,
    this.betriebNeuName,
    this.betriebNeuOrt,
    this.anlagenTyp,
    this.istMeinKunde,
  });

  factory EinsatzDiktatErgebnis.fromJson(Map<String, dynamic> json) {
    return EinsatzDiktatErgebnis(
      art: json['art'] as String? ?? 'aufgabe',
      betriebId: _emptyToNull(json['betrieb_id']),
      betriebNameErkannt: _emptyToNull(json['betrieb_name_erkannt']),
      betriebKandidaten:
          (json['betrieb_kandidaten'] as List?)
              ?.whereType<Map>()
              .map(EinsatzBetriebKandidat.fromJson)
              .where((k) => k.id.isNotEmpty)
              .toList() ??
          const [],
      geplantAm: _datum(json['geplant_am']),
      geplantZeit: _emptyToNull(json['geplant_zeit']),
      geplantDauerMin: (json['geplant_dauer_min'] as num?)?.toInt(),
      beschreibung: _emptyToNull(json['beschreibung']),
      konfidenz: (json['konfidenz'] as num?)?.toDouble() ?? 0,
      rueckfrage: _emptyToNull(json['rueckfrage']),
      betriebNeuName: _emptyToNull(json['betrieb_neu_name']),
      betriebNeuOrt: _emptyToNull(json['betrieb_neu_ort']),
      anlagenTyp: _emptyToNull(json['anlagen_typ']),
      istMeinKunde: json['ist_mein_kunde'] as bool?,
    );
  }

  static String? _emptyToNull(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _datum(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class EinsatzBetriebKandidat {
  final String id;
  final String name;

  const EinsatzBetriebKandidat({required this.id, required this.name});

  factory EinsatzBetriebKandidat.fromJson(Map json) => EinsatzBetriebKandidat(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
  );
}
