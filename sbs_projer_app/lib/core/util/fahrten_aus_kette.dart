/// Fahrten aus der Kette (Fahrtenerkennung Stufe 1, 27.09.2026).
///
/// Aus den Ereignissen eines Arbeitstags — Arbeitsbeginn, Einsätze,
/// Feierabend — entsteht eine Kette von Halten; je zwei aufeinanderfolgende
/// Halte an verschiedenen Orten sind eine Fahrt. Die Kilometer kommen aus
/// gerouteten Distanzen (Nachschlag des Aufrufers), sonst aus der Luftlinie
/// mal dem kalibrierten [umwegFaktor]. Die Tagessumme wird gegen den
/// Zählerstand geprüft.
///
/// Bewusst ohne Flutter-/Supabase-Abhängigkeiten (auch nichts aus
/// `presentation/`): Startort-Koordinaten und Distanzen kommen als Parameter.
/// Nichts davon wird gespeichert — alles ist aus den Ereignissen ableitbar
/// (Stufe 2 würde `fahrten` persistieren). Kein Steuerbeleg, kein GPS-Tracking
/// (Entscheid Daniel 27.09.2026).
library;

import 'dart:math' as math;

import 'package:sbs_projer_app/core/util/arbeitstag_auswertung.dart'
    show tagesKm;
import 'package:sbs_projer_app/core/util/fahrzeit.dart'
    show haversineKm, umwegFaktor;
import 'package:sbs_projer_app/core/util/touren_anzeige.dart'
    show minutenAusHhmm;

enum HaltTyp { startort, betrieb }

/// Anzeigenamen der Startort-Schlüssel (`kStartorte` in tour_providers.dart).
/// Unbekannte Schlüssel erscheinen unverändert.
const kStartortNamen = <String, String>{
  'domat_ems': 'Domat/Ems',
  'chur': 'Chur',
};

/// Zwei Halte am selben Betrieb mit höchstens so viel Lücke gelten als EIN
/// Besuch (Reinigung, dann Störung am selben Ort: keine Fahrt dazwischen).
const kVerschmelzenBisMin = 15;

/// Toleranz der Zähler-Kontrolle: Befund erst, wenn |Differenz| grösser ist
/// als der grössere der beiden Werte — 5 km absolut oder 5 % des Zählers.
/// Geroutete Strecken treffen den gefahrenen Weg nie auf den Kilometer.
const kDifferenzToleranzKm = 5.0;
const kDifferenzToleranzAnteil = 0.05;

/// Herkunft der km einer [Fahrt].
const kKmQuelleAnfahrt = 'anfahrt'; // anfahrtszeiten.distanz_km
const kKmQuelleRoute = 'route'; // fahrzeiten.distanz_km
const kKmQuelleLuftlinie = 'luftlinie'; // geschätzt, kein Messwert

/// Ein Ort in der Tageskette: Startort (morgens/abends) oder Betrieb.
class Halt {
  const Halt({
    required this.typ,
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.ankunftMin,
    this.abfahrtMin,
    required this.quelle,
  });

  final HaltTyp typ;

  /// Startort-Schlüssel (`'domat_ems'`/`'chur'`) oder betriebId. Einsätze
  /// ohne Betrieb bekommen `'einsatz:<einsatzId>'`.
  final String id;
  final String name;
  final double? lat, lng;

  /// Minuten seit Mitternacht. `null` nur beim Startort morgens.
  final int? ankunftMin;

  /// Minuten seit Mitternacht. `null` nur beim Startort abends.
  final int? abfahrtMin;

  /// 'arbeitsbeginn', 'reinigung', 'stoerung', 'montage', 'wegpunkt' oder
  /// 'feierabend'. Bei verschmolzenen Halten die des frühesten Einsatzes.
  final String quelle;

  @override
  String toString() => 'Halt($id $ankunftMin–$abfahrtMin $quelle)';
}

/// Eingabe je Einsatz, vor der Zeit-Auflösung.
class EinsatzHalt {
  const EinsatzHalt({
    required this.einsatzId,
    required this.typ,
    this.betriebId,
    this.betriebName,
    this.lat,
    this.lng,
    this.von,
    this.bis,
    this.stempel,
  });

  final String einsatzId;

  /// 'reinigung' | 'stoerung' | 'montage'.
  final String typ;
  final String? betriebId, betriebName;
  final double? lat, lng;

  /// 'HH:mm' (auch 'HH:mm:ss') oder null — Reinigung `uhrzeit_start/ende`,
  /// Störung/Montage `arbeit_von/bis`.
  final String? von, bis;

  /// Wegpunkt-Zeitpunkt, wenn [von]/[bis] fehlen. MUSS lokale Zeit sein
  /// (Aufrufer: `DateTime.parse(zeitpunkt).toLocal()`): Die Regel rechnet
  /// stur `hour * 60 + minute` — ein UTC-Wert verschöbe den Halt um ein bis
  /// zwei Stunden. Stempel eines anderen Kalendertags als `datum` zählen
  /// nicht.
  final DateTime? stempel;

  @override
  String toString() => 'EinsatzHalt($typ $einsatzId @ $betriebId)';
}

/// Eine Fahrt zwischen zwei aufeinanderfolgenden, verschiedenen Halten.
class Fahrt {
  const Fahrt({
    required this.von,
    required this.nach,
    this.abfahrtMin,
    this.ankunftMin,
    this.km,
    this.kmQuelle,
  });

  final Halt von, nach;

  /// Abfahrt des ersten, Ankunft des zweiten Halts (Minuten seit Mitternacht).
  final int? abfahrtMin, ankunftMin;

  /// `null`, wenn eine Zeit fehlt oder die Halte sich überlappen (Ankunft vor
  /// Abfahrt — Erfassungsfehler, keine negative Fahrzeit anzeigen).
  int? get dauerMin {
    final ab = abfahrtMin, an = ankunftMin;
    if (ab == null || an == null) return null;
    final d = an - ab;
    return d < 0 ? null : d;
  }

  /// `null` nur, wenn weder ein Nachschlag noch Koordinaten vorliegen.
  final double? km;

  /// [kKmQuelleAnfahrt], [kKmQuelleRoute], [kKmQuelleLuftlinie] oder `null`.
  final String? kmQuelle;
}

/// Ergebnis eines Tages.
class TagesFahrten {
  const TagesFahrten({
    required this.fahrten,
    required this.ohneZeit,
    required this.kmFahrten,
    required this.fahrtenNurLuftlinie,
    required this.kmZaehler,
    required this.befunde,
  });

  final List<Fahrt> fahrten;
  final List<EinsatzHalt> ohneZeit;

  /// Summe aller Fahrten mit km, auf eine Nachkommastelle gerundet.
  final double kmFahrten;

  /// Anzahl Fahrten mit `kmQuelle == 'luftlinie'`.
  final int fahrtenNurLuftlinie;

  /// `tagesKm(kmStart, kmEnde)` — `null` ohne (gültige) Zählerstände.
  final int? kmZaehler;

  /// Zähler − Fahrten; positiv = mehr gefahren als erklärt.
  double? get differenz {
    final z = kmZaehler;
    return z == null ? null : z - kmFahrten;
  }

  /// Liegt die [differenz] ausserhalb der Toleranz? (Für die Farbe im UI.)
  bool get differenzAuffaellig {
    final z = kmZaehler;
    return z != null &&
        differenzIstAuffaellig(kmZaehler: z, differenz: z - kmFahrten);
  }

  /// Deutsche Hinweise mit Zahlen, wichtigster zuerst (Zähler-Kontrolle).
  final List<String> befunde;
}

/// Liefert die geroutete Strecke zwischen zwei Halten oder `null` (dann
/// rechnet [fahrtenAusHalten] mit der Luftlinie).
typedef KmNachschlag =
    ({double km, String quelle})? Function(Halt von, Halt nach);

/// Baut die Halte eines Tages: Startort morgens (nur mit [arbeitsbeginn]),
/// Einsätze nach Zeit, Startort abends (nur mit [arbeitsende]).
///
/// Der Morgen-Startort steht immer vorn und der Abend-Startort immer hinten,
/// auch wenn ein Einsatz zeitlich davor/danach erfasst ist — sonst entstünde
/// aus einem Tippfehler eine Fahrt «Betrieb → zuhause → Betrieb».
///
/// Einsätze ohne auflösbare Zeit fehlen hier (siehe [einsaetzeOhneZeit]).
/// Aufeinanderfolgende Halte am selben Betrieb mit Lücke ≤
/// [verschmelzenBisMin] werden zu einem verschmolzen.
List<Halt> halteAusKette({
  required String? arbeitsbeginn,
  required String? arbeitsende,
  required String startortMorgen,
  required String startortAbend,
  required List<EinsatzHalt> einsaetze,
  required DateTime datum,
  required Map<String, ({double lat, double lng})> startorte,
  int verschmelzenBisMin = kVerschmelzenBisMin,
}) {
  final betriebsHalte = <Halt>[];
  for (final e in einsaetze) {
    final z = _zeitfenster(e, datum);
    if (z == null) continue;
    betriebsHalte.add(
      Halt(
        typ: HaltTyp.betrieb,
        id: e.betriebId ?? 'einsatz:${e.einsatzId}',
        name: e.betriebName ?? _typName(e.typ),
        lat: e.lat,
        lng: e.lng,
        ankunftMin: z.ankunft,
        abfahrtMin: z.abfahrt,
        quelle: z.quelle,
      ),
    );
  }
  betriebsHalte.sort(_nachZeit);

  final kette = <Halt>[];
  final beginn = minutenAusHhmm(arbeitsbeginn);
  if (beginn != null) {
    kette.add(
      _startortHalt(
        startortMorgen,
        startorte,
        abfahrtMin: beginn,
        quelle: 'arbeitsbeginn',
      ),
    );
  }

  Halt? vorher;
  for (final h in betriebsHalte) {
    final v = vorher;
    // Beide Zeiten sind bei Betriebs-Halten immer gesetzt (_zeitfenster).
    if (v != null &&
        v.id == h.id &&
        h.ankunftMin! - v.abfahrtMin! <= verschmelzenBisMin) {
      final neu = Halt(
        typ: v.typ,
        id: v.id,
        name: v.name,
        lat: v.lat ?? h.lat,
        lng: v.lng ?? h.lng,
        ankunftMin: math.min(v.ankunftMin!, h.ankunftMin!),
        abfahrtMin: math.max(v.abfahrtMin!, h.abfahrtMin!),
        quelle: v.quelle,
      );
      kette[kette.length - 1] = neu;
      vorher = neu;
    } else {
      kette.add(h);
      vorher = h;
    }
  }

  final ende = minutenAusHhmm(arbeitsende);
  if (ende != null) {
    kette.add(
      _startortHalt(
        startortAbend,
        startorte,
        ankunftMin: ende,
        quelle: 'feierabend',
      ),
    );
  }
  return kette;
}

/// Einsätze, für die weder Zeiten noch ein Stempel von [datum] vorliegen —
/// sie fehlen in [halteAusKette] und werden als Befund gemeldet.
List<EinsatzHalt> einsaetzeOhneZeit(
  List<EinsatzHalt> einsaetze, {
  required DateTime datum,
}) => [
  for (final e in einsaetze)
    if (_zeitfenster(e, datum) == null) e,
];

/// Je zwei aufeinanderfolgende Halte mit verschiedener Id ergeben eine Fahrt.
/// km aus [km]; ohne Treffer Luftlinie × Umwegfaktor (Quelle 'luftlinie'),
/// ohne Koordinaten `null`.
List<Fahrt> fahrtenAusHalten(List<Halt> halte, KmNachschlag km) {
  final fahrten = <Fahrt>[];
  for (var i = 1; i < halte.length; i++) {
    final von = halte[i - 1];
    final nach = halte[i];
    if (von.id == nach.id) continue;

    final treffer = km(von, nach);
    var strecke = treffer?.km;
    var quelle = treffer?.quelle;
    final vLat = von.lat, vLng = von.lng, nLat = nach.lat, nLng = nach.lng;
    if (strecke == null &&
        vLat != null &&
        vLng != null &&
        nLat != null &&
        nLng != null) {
      strecke = _eineStelle(
        luftlinieStreckeKm(haversineKm(vLat, vLng, nLat, nLng)),
      );
      quelle = kKmQuelleLuftlinie;
    }
    fahrten.add(
      Fahrt(
        von: von,
        nach: nach,
        abfahrtMin: von.abfahrtMin,
        ankunftMin: nach.ankunftMin,
        km: strecke,
        kmQuelle: strecke == null ? null : quelle,
      ),
    );
  }
  return fahrten;
}

/// Fahrten, Summe und Befunde eines Tages.
///
/// [feierabendErfasst]/[arbeitsbeginnErfasst]: ob der Tagesplan die Zeit
/// kennt (sonst fehlen Heimweg bzw. Anfahrt in der Kette — das erklärt eine
/// positive Differenz und wird deshalb eigens gemeldet).
TagesFahrten tagesFahrten({
  required List<Halt> halte,
  required List<EinsatzHalt> ohneZeit,
  required KmNachschlag km,
  int? kmStart,
  int? kmEnde,
  required bool feierabendErfasst,
  bool arbeitsbeginnErfasst = true,
}) {
  final fahrten = fahrtenAusHalten(halte, km);
  final summe = _eineStelle(fahrten.fold<double>(0, (s, f) => s + (f.km ?? 0)));
  final nurLuftlinie = fahrten
      .where((f) => f.kmQuelle == kKmQuelleLuftlinie)
      .length;
  final ohneKm = fahrten.where((f) => f.km == null).length;
  final zaehler = tagesKm(kmStart: kmStart, kmEnde: kmEnde);

  final befunde = <String>[];
  if (zaehler != null) {
    final differenz = zaehler - summe;
    if (differenzIstAuffaellig(kmZaehler: zaehler, differenz: differenz)) {
      // Mit der gerundeten Summe rechnen, damit die Zahlen im Text aufgehen.
      final fahrtenKm = summe.round();
      befunde.add(
        differenz > 0
            ? 'Zähler $zaehler km, Fahrten $fahrtenKm km — '
                  '${zaehler - fahrtenKm} km unerklärt (privat oder Umweg?)'
            : 'Fahrten $fahrtenKm km liegen über dem Zähler $zaehler km — '
                  'Zählerstand prüfen',
      );
    }
  } else if (kmStart != null && kmEnde != null) {
    // tagesKm verweigert Abend < Morgen — das ist ein Tippfehler, kein
    // fehlender Stand.
    befunde.add(
      'Zählerstand Feierabend $kmEnde km liegt unter dem Morgenstand '
      '$kmStart km — Tippfehler?',
    );
  } else {
    befunde.add('Zählerstand fehlt — keine Kontrolle möglich');
  }
  if (!arbeitsbeginnErfasst) {
    befunde.add('Kein Arbeitsbeginn erfasst — Anfahrt fehlt');
  }
  if (!feierabendErfasst) {
    befunde.add('Kein Feierabend erfasst — Heimweg fehlt');
  }
  if (ohneZeit.isNotEmpty) {
    final n = ohneZeit.length;
    befunde.add(
      '$n ${n == 1 ? 'Einsatz' : 'Einsätze'} ohne Zeit — '
      'nicht in den Fahrten',
    );
  }
  if (ohneKm > 0) {
    befunde.add(
      '$ohneKm ${ohneKm == 1 ? 'Fahrt' : 'Fahrten'} ohne Distanz '
      '(Koordinaten fehlen)',
    );
  }
  if (nurLuftlinie > 0) {
    final n = fahrten.length;
    befunde.add(
      '$nurLuftlinie von $n ${n == 1 ? 'Fahrt' : 'Fahrten'} nur als '
      'Luftlinie geschätzt',
    );
  }

  return TagesFahrten(
    fahrten: fahrten,
    ohneZeit: ohneZeit,
    kmFahrten: summe,
    fahrtenNurLuftlinie: nurLuftlinie,
    kmZaehler: zaehler,
    befunde: befunde,
  );
}

/// |[differenz]| > max(5 km, 5 % von [kmZaehler]) — in beide Richtungen.
bool differenzIstAuffaellig({
  required int kmZaehler,
  required double differenz,
}) =>
    differenz.abs() >
    math.max(kDifferenzToleranzKm, kmZaehler * kDifferenzToleranzAnteil);

/// Geschätzte Strassenstrecke aus der Luftlinie (gleiche Kalibrierung wie
/// die Fahrzeit-Heuristik).
double luftlinieStreckeKm(double luftlinieKm) =>
    luftlinieKm * umwegFaktor(luftlinieKm);

/// «12.3 km» — eine Nachkommastelle, Punkt (wie `distanzText`).
String kmText(double km) => '${km.toStringAsFixed(1)} km';

// ── Zusammenbau je Monat ────────────────────────────────────────────────
//
// Die Monatsabfragen (Tagesplan, Einsätze, Wegpunkte) und die beiden
// Distanz-Nachschlagewerke kommen roh herein; hier entstehen daraus die
// Tages-Fahrten. Rein und ohne Supabase, damit der Zusammenbau testbar ist
// (`test/fahrten_providers_test.dart`) — die Provider in
// `fahrten_providers.dart` beschaffen nur die Daten.

/// Rückfall-Startort, wenn die GPS-Position fehlt oder zu keinem der
/// Startorte passt (`startortSchluessel` liefert dann `null`).
const kStartortRueckfall = 'domat_ems';

/// Ein Einsatz aus den Monatsabfragen, vor dem Betriebs-Nachschlag.
typedef EinsatzRoh = ({
  String id,

  /// 'reinigung' | 'stoerung' | 'montage'.
  String typ,
  String? betriebId,
  DateTime datum,

  /// 'HH:mm(:ss)' — Reinigung `uhrzeit_start/ende`, Störung/Montage
  /// `arbeit_von/bis` (NICHT `uhrzeit_start`: bei der Störung ist das der
  /// Störungseingang, nicht die Arbeit vor Ort).
  String? von,
  String? bis,
});

/// Ein Wegpunkt-Stempel (`wegpunkte`). [zeitpunkt] MUSS lokal sein
/// (`toLocal()`), siehe [EinsatzHalt.stempel].
typedef StempelRoh = ({
  DateTime zeitpunkt,
  String quelle,
  String? betriebId,
  String? referenzId,
});

/// Name und Koordinaten eines Betriebs (aus den Stammdaten).
typedef BetriebOrt = ({String name, double? lat, double? lng});

/// Arbeitstag-Rahmen eines Tages (`tagesplaene`). Positionen = GPS beim
/// Arbeitsbeginn bzw. Feierabend (`start_lat/lng`, `end_lat/lng`).
typedef TagesplanRoh = ({
  String? beginn,
  String? ende,
  int? kmStart,
  int? kmEnde,
  ({double lat, double lng})? startPosition,
  ({double lat, double lng})? endPosition,
});

/// Montage-Typen ohne Besuch vor Ort — reine Abrechnungsposten.
const _montageTypenOhneBesuch = {'spesen', 'aufwandsentschaedigung'};

/// War bei dieser Störung jemand vor Ort? Eine noch offene Störung ist nur
/// gemeldet — sie in die Kette zu nehmen hiesse, eine Fahrt zu erfinden
/// (oder sie als «Einsatz ohne Zeit» anzumahnen).
bool stoerungWarVorOrt(String status) => status != 'offen';

/// Wie [stoerungWarVorOrt] für Montagen: geplante zählen nicht, ebenso
/// Spesen und Aufwandsentschädigungen (kein Ort, nur ein Betrag).
bool montageWarVorOrt(String status, String? montageTyp) =>
    status != 'geplant' && !_montageTypenOhneBesuch.contains(montageTyp);

/// km-Nachschlag aus den gespeicherten Distanzen.
///
/// - Startort ↔ Betrieb: [anfahrten] (`anfahrtszeiten.distanz_km`, Schlüssel
///   Startort → betriebId), Richtung egal — Heimweg = Anfahrt rückwärts.
/// - Betrieb ↔ Betrieb: [routen] (`fahrzeiten.distanz_km`, Schlüssel
///   `'von>nach'`), beide Richtungen wie `FahrzeitRepository.ausMap`.
/// - Sonst `null` → [fahrtenAusHalten] rechnet mit der Luftlinie.
KmNachschlag kmNachschlagAus({
  required Map<String, Map<String, double>> anfahrten,
  required Map<String, double> routen,
}) => (Halt von, Halt nach) {
  ({double km, String quelle})? anfahrt(Halt startort, Halt betrieb) {
    final km = anfahrten[startort.id]?[betrieb.id];
    return km == null ? null : (km: km, quelle: kKmQuelleAnfahrt);
  }

  if (von.typ == HaltTyp.startort && nach.typ == HaltTyp.betrieb) {
    return anfahrt(von, nach);
  }
  if (von.typ == HaltTyp.betrieb && nach.typ == HaltTyp.startort) {
    return anfahrt(nach, von);
  }
  if (von.typ == HaltTyp.betrieb && nach.typ == HaltTyp.betrieb) {
    final km = routen['${von.id}>${nach.id}'] ?? routen['${nach.id}>${von.id}'];
    return km == null ? null : (km: km, quelle: kKmQuelleRoute);
  }
  return null;
};

/// Baut die Tages-Fahrten eines Monats (Schlüssel: Datum ohne Uhrzeit).
///
/// Ein Tag erscheint, sobald sein Tagesplan etwas erfasst hat (Zeit oder
/// km-Stand) oder ein Einsatz auf ihn fällt. Tagesplan-Zeilen ohne jede
/// Erfassung sind bloss geplant und fallen weg.
///
/// Startort morgens/abends aus der GPS-Position via [startortFuer]
/// (`startortSchluessel`), ohne Treffer [kStartortRueckfall].
///
/// Einsatz-Zeit: von/bis, sonst der früheste Stempel desselben Tages —
/// zuerst über `referenz_id` = Einsatz-Id, sonst gleiche Einsatzart am
/// selben Betrieb (Störungs-Stempel tragen in der Praxis keine Referenz:
/// 0 von 33 seit August, Stand 27.09.2026).
Map<DateTime, TagesFahrten> monatsFahrtenBauen({
  required Map<DateTime, TagesplanRoh> tagesplaene,
  required List<EinsatzRoh> einsaetze,
  required List<StempelRoh> stempel,
  required Map<String, BetriebOrt> betriebe,
  required Map<String, Map<String, double>> anfahrten,
  required Map<String, double> routen,
  required Map<String, ({double lat, double lng})> startorte,
  required String? Function(({double lat, double lng})? position)
  startortFuer,
}) {
  final plaene = {
    for (final e in tagesplaene.entries) _tag(e.key): e.value,
  };
  final einsaetzeJeTag = <DateTime, List<EinsatzRoh>>{};
  for (final e in einsaetze) {
    (einsaetzeJeTag[_tag(e.datum)] ??= []).add(e);
  }
  final stempelJeTag = <DateTime, List<StempelRoh>>{};
  for (final s in stempel) {
    (stempelJeTag[_tag(s.zeitpunkt)] ??= []).add(s);
  }

  final tage = <DateTime>{
    for (final e in plaene.entries)
      if (_hatRahmen(e.value)) e.key,
    ...einsaetzeJeTag.keys,
  };
  final km = kmNachschlagAus(anfahrten: anfahrten, routen: routen);

  final ergebnis = <DateTime, TagesFahrten>{};
  for (final tag in tage) {
    final plan = plaene[tag];
    final stempelDesTages = stempelJeTag[tag] ?? const <StempelRoh>[];
    final einsatzHalte = [
      for (final e in einsaetzeJeTag[tag] ?? const <EinsatzRoh>[])
        _einsatzHalt(e, betriebe, stempelDesTages),
    ];
    final halte = halteAusKette(
      arbeitsbeginn: plan?.beginn,
      arbeitsende: plan?.ende,
      startortMorgen: startortFuer(plan?.startPosition) ?? kStartortRueckfall,
      startortAbend: startortFuer(plan?.endPosition) ?? kStartortRueckfall,
      einsaetze: einsatzHalte,
      datum: tag,
      startorte: startorte,
    );
    ergebnis[tag] = tagesFahrten(
      halte: halte,
      ohneZeit: einsaetzeOhneZeit(einsatzHalte, datum: tag),
      km: km,
      kmStart: plan?.kmStart,
      kmEnde: plan?.kmEnde,
      arbeitsbeginnErfasst: plan?.beginn != null,
      feierabendErfasst: plan?.ende != null,
    );
  }
  return ergebnis;
}

/// Betrieb→Betrieb-Fahrten, die nur als Luftlinie geschätzt sind, obwohl
/// beide Betriebe Koordinaten haben — Kandidaten fürs Nachrouten über die
/// Edge Function `fahrzeit-route`. Je Paar nur eine Richtung (der Nachschlag
/// prüft beide), in der Reihenfolge der übergebenen Tage.
List<({String von, String nach})> fehlendeRoutenPaare(
  Iterable<TagesFahrten> tage,
) {
  final gesehen = <String>{};
  final paare = <({String von, String nach})>[];
  for (final t in tage) {
    for (final f in t.fahrten) {
      if (f.kmQuelle != kKmQuelleLuftlinie) continue;
      if (f.von.typ != HaltTyp.betrieb || f.nach.typ != HaltTyp.betrieb) {
        continue;
      }
      if (f.von.lat == null ||
          f.von.lng == null ||
          f.nach.lat == null ||
          f.nach.lng == null) {
        continue;
      }
      if (gesehen.add(routenPaarSchluessel(f.von.id, f.nach.id))) {
        paare.add((von: f.von.id, nach: f.nach.id));
      }
    }
  }
  return paare;
}

/// Richtungsloser Schlüssel eines Betriebspaars (`a|b` mit a < b).
String routenPaarSchluessel(String a, String b) =>
    a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

// ── intern ──────────────────────────────────────────────────────────────

DateTime _tag(DateTime d) => DateTime(d.year, d.month, d.day);

bool _hatRahmen(TagesplanRoh p) =>
    p.beginn != null || p.ende != null || p.kmStart != null || p.kmEnde != null;

EinsatzHalt _einsatzHalt(
  EinsatzRoh e,
  Map<String, BetriebOrt> betriebe,
  List<StempelRoh> stempelDesTages,
) {
  final bid = e.betriebId;
  final betrieb = bid == null ? null : betriebe[bid];
  return EinsatzHalt(
    einsatzId: e.id,
    typ: e.typ,
    betriebId: bid,
    betriebName: betrieb?.name,
    lat: betrieb?.lat,
    lng: betrieb?.lng,
    von: e.von,
    bis: e.bis,
    stempel: _stempelFuer(e, stempelDesTages),
  );
}

/// Frühester passender Stempel: über die Referenz, sonst gleiche
/// Einsatzart am selben Betrieb.
DateTime? _stempelFuer(EinsatzRoh e, List<StempelRoh> desTages) {
  DateTime? fruehester(Iterable<StempelRoh> kandidaten) {
    DateTime? best;
    for (final s in kandidaten) {
      if (best == null || s.zeitpunkt.isBefore(best)) best = s.zeitpunkt;
    }
    return best;
  }

  final perReferenz = fruehester(desTages.where((s) => s.referenzId == e.id));
  if (perReferenz != null) return perReferenz;
  final bid = e.betriebId;
  if (bid == null) return null;
  return fruehester(
    desTages.where((s) => s.quelle == e.typ && s.betriebId == bid),
  );
}

/// Zeit eines Einsatzes: von/bis; nur eine davon → Punkt-Halt dort; sonst
/// der Stempel von [datum] als Punkt-Halt; sonst `null` («ohne Zeit»).
/// Ein Ende vor dem Start (Erfassungsfehler) zählt nur den Start.
({int ankunft, int abfahrt, String quelle})? _zeitfenster(
  EinsatzHalt e,
  DateTime datum,
) {
  final von = minutenAusHhmm(e.von);
  final bis = minutenAusHhmm(e.bis);
  if (von != null) {
    final ende = (bis != null && bis >= von) ? bis : von;
    return (ankunft: von, abfahrt: ende, quelle: e.typ);
  }
  if (bis != null) return (ankunft: bis, abfahrt: bis, quelle: e.typ);

  final s = e.stempel;
  if (s != null &&
      s.year == datum.year &&
      s.month == datum.month &&
      s.day == datum.day) {
    final m = s.hour * 60 + s.minute;
    return (ankunft: m, abfahrt: m, quelle: 'wegpunkt');
  }
  return null;
}

int _nachZeit(Halt a, Halt b) {
  final an = a.ankunftMin!.compareTo(b.ankunftMin!);
  if (an != 0) return an;
  final ab = a.abfahrtMin!.compareTo(b.abfahrtMin!);
  if (ab != 0) return ab;
  return a.id.compareTo(b.id);
}

Halt _startortHalt(
  String schluessel,
  Map<String, ({double lat, double lng})> startorte, {
  int? ankunftMin,
  int? abfahrtMin,
  required String quelle,
}) {
  final pos = startorte[schluessel];
  return Halt(
    typ: HaltTyp.startort,
    id: schluessel,
    name: kStartortNamen[schluessel] ?? schluessel,
    lat: pos?.lat,
    lng: pos?.lng,
    ankunftMin: ankunftMin,
    abfahrtMin: abfahrtMin,
    quelle: quelle,
  );
}

String _typName(String typ) => switch (typ) {
  'reinigung' => 'Reinigung',
  'stoerung' => 'Störung',
  'montage' => 'Montage',
  _ => typ,
};

double _eineStelle(double km) => (km * 10).round() / 10;
