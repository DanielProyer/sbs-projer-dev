import 'package:sbs_projer_app/core/util/betrieb_suche.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/local/eroeffnungsreinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/montage_local_export.dart';
import 'package:sbs_projer_app/core/util/kalenderwoche.dart';
import 'package:sbs_projer_app/data/local/pikett_dienst_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/models/termin.dart';

/// Die Einsatzarten des gemeinsamen Screens (B2).
enum EinsatzTyp {
  reinigung,
  stoerung,
  montage,
  eigenauftrag,
  saisonreinigung,
  termin,
  pikett,
}

String einsatzTypLabel(EinsatzTyp t) => switch (t) {
  EinsatzTyp.reinigung => 'Reinigung',
  EinsatzTyp.stoerung => 'Störung',
  EinsatzTyp.montage => 'Montage',
  EinsatzTyp.eigenauftrag => 'Eigenauftrag',
  EinsatzTyp.saisonreinigung => 'Saisonreinigung',
  EinsatzTyp.termin => 'Termin',
  EinsatzTyp.pikett => 'Pikett',
};

/// Eine Sicht auf einen Einsatz — kein Modell, keine Tabelle. Wird aus den
/// geladenen Daten berechnet, wie `TourEintrag` für den Tourenplan.
class Einsatz {
  final EinsatzTyp typ;

  /// Feiner als der Typ: «Eröffnungsreinigung», «Endreinigung»,
  /// «Termin Endreinigung».
  final String typLabel;
  final String routeId;
  final String? betriebId;
  final String betriebName;
  final String? betriebOrt;
  final String? betriebNr;
  final String? regionId;
  final DateTime datum;

  /// Geplanter Tag (Störung/Montage). Für die Aufgaben-Fälligkeit (B6):
  /// `geplantAm ?? datum` — ein geplanter Einsatz ist am Plantag fällig,
  /// nicht am Meldetag.
  final DateTime? geplantAm;

  /// Nur bei Geplantem: Störung/Montage `geplantZeit`, Termin `uhrzeitVon`.
  final String? zeit;
  final String? beschreibung;
  final EinsatzStatus status;
  final EinsatzKennzeichen kennzeichen;

  /// `null` bei Geplantem und bei Terminen — dort gibt es noch nichts zu
  /// verrechnen.
  final double? betragCHF;

  // Die drei Störungs-Zusatzfilter aus Paket 06 — nur bei Störungen belegt.
  final String? anlageTyp;
  final bool istKilometerabrechnung;
  final List<int> stoerungBereiche;

  const Einsatz({
    required this.typ,
    required this.typLabel,
    required this.routeId,
    required this.betriebId,
    required this.betriebName,
    required this.betriebOrt,
    required this.betriebNr,
    required this.regionId,
    required this.datum,
    this.geplantAm,
    required this.status,
    required this.kennzeichen,
    this.zeit,
    this.beschreibung,
    this.betragCHF,
    this.anlageTyp,
    this.istKilometerabrechnung = false,
    this.stoerungBereiche = const [],
  });

  /// Die bestehende Detailseite des Typs. Termine haben keine — sie öffnen
  /// den Betrieb.
  String get detailRoute => switch (typ) {
    EinsatzTyp.reinigung => '/reinigungen/$routeId',
    EinsatzTyp.stoerung => '/stoerungen/$routeId',
    EinsatzTyp.montage => '/montagen/$routeId',
    EinsatzTyp.eigenauftrag => '/eigenauftraege/$routeId',
    EinsatzTyp.saisonreinigung => '/eroeffnungsreinigungen/$routeId',
    EinsatzTyp.termin => '/betriebe/$betriebId',
    EinsatzTyp.pikett => '/pikett/$routeId',
  };

  bool get istGeplantOderOffen =>
      status == EinsatzStatus.offen || status == EinsatzStatus.geplant;
}

const _unbekannt = 'Unbekannter Betrieb';

/// Betrag nur, wenn der Einsatz stattgefunden hat — bei Geplantem wäre er
/// eine Schätzung, die wie eine Tatsache aussieht.
double? _betragWennErledigt(EinsatzLage l, double? betrag) =>
    (l.status == EinsatzStatus.offen || l.status == EinsatzStatus.geplant)
    ? null
    : betrag;

Einsatz einsatzAusReinigung(
  ReinigungLocal r, {
  required BetriebLocal? betrieb,
  required bool hatBuchung,
}) {
  final l = reinigungLage(
    status: r.status,
    abgerechnet: r.istAbgerechnet,
    hatBuchung: hatBuchung,
  );
  return Einsatz(
    typ: EinsatzTyp.reinigung,
    // Kulanz: geschenkt — kein Betrag, aber sichtbar als solche.
    typLabel: r.istKulanz ? 'Reinigung (Kulanz)' : 'Reinigung',
    routeId: r.routeId,
    betriebId: r.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: r.datum,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: r.istKulanz ? null : _betragWennErledigt(l, r.preisBrutto),
  );
}

Einsatz einsatzAusStoerung(StoerungLocal s, {required BetriebLocal? betrieb}) {
  final l = stoerungLage(
    status: s.status,
    geplantAm: s.geplantAm,
    arbeitVon: s.arbeitVon,
    arbeitBis: s.arbeitBis,
    abgerechnet: s.abgerechnet,
  );
  return Einsatz(
    typ: EinsatzTyp.stoerung,
    typLabel: 'Störung',
    routeId: s.routeId,
    betriebId: s.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: s.datum,
    geplantAm: s.geplantAm,
    zeit: l.status == EinsatzStatus.geplant ? s.geplantZeit : null,
    beschreibung: s.problemBeschreibung,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: _betragWennErledigt(l, s.preisNetto),
    anlageTyp: s.anlageTyp,
    istKilometerabrechnung: s.istKilometerabrechnung,
    stoerungBereiche: s.stoerungBereiche ?? const [],
  );
}

Einsatz einsatzAusMontage(MontageLocal m, {required BetriebLocal? betrieb}) {
  final l = montageLage(
    status: m.status,
    arbeitVon: m.arbeitVon,
    arbeitBis: m.arbeitBis,
    abgerechnet: m.abgerechnet,
  );
  return Einsatz(
    typ: EinsatzTyp.montage,
    typLabel: 'Montage',
    routeId: m.routeId,
    betriebId: m.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: m.datum,
    geplantAm: m.geplantAm,
    zeit: l.status == EinsatzStatus.geplant ? m.geplantZeit : null,
    beschreibung: m.beschreibung,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: _betragWennErledigt(l, m.kostenArbeit),
  );
}

Einsatz einsatzAusEigenauftrag(
  EigenauftragLocal e, {
  required BetriebLocal? betrieb,
}) {
  final l = eigenauftragLage(status: e.status, abgerechnet: e.abgerechnet);
  return Einsatz(
    typ: EinsatzTyp.eigenauftrag,
    typLabel: 'Eigenauftrag',
    routeId: e.routeId,
    betriebId: e.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: e.datum,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: _betragWennErledigt(l, e.pauschale),
  );
}

Einsatz einsatzAusSaisonreinigung(
  EroeffnungsreinigungLocal s, {
  required BetriebLocal? betrieb,
}) {
  final l = saisonreinigungLage(abgerechnet: s.abgerechnet);
  return Einsatz(
    typ: EinsatzTyp.saisonreinigung,
    typLabel: s.art == 'endreinigung' ? 'Endreinigung' : 'Eröffnungsreinigung',
    routeId: s.routeId,
    betriebId: s.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: s.datum,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: s.preis,
  );
}

Einsatz einsatzAusTermin(TerminDto t, {required BetriebLocal? betrieb}) {
  final l = terminLage(status: t.status);
  final art = switch (t.typ) {
    'eroeffnungsreinigung' => 'Eröffnungsreinigung',
    'endreinigung' => 'Endreinigung',
    _ => t.titel,
  };
  return Einsatz(
    typ: EinsatzTyp.termin,
    typLabel: 'Termin $art',
    routeId: t.id,
    betriebId: t.betriebId,
    betriebName: betrieb?.name ?? _unbekannt,
    betriebOrt: betrieb?.ort,
    betriebNr: betrieb?.betriebNr,
    regionId: betrieb?.regionId,
    datum: t.datum,
    zeit: t.uhrzeitVon,
    beschreibung: t.notizen,
    status: l.status,
    kennzeichen: l.kennzeichen,
  );
}

/// Pikett hängt an keinem Betrieb — der Dienst gilt für das ganze Gebiet.
Einsatz einsatzAusPikett(PikettDienstLocal p) {
  final l = pikettLage(istAktiv: p.istAktiv, abgerechnet: p.abgerechnet);
  return Einsatz(
    typ: EinsatzTyp.pikett,
    typLabel: 'Pikett',
    routeId: p.routeId,
    betriebId: null,
    // Die KW ist beim Pikett die gebräuchliche Bezeichnung (Detailseite:
    // «Pikett KW 38») — in der Liste stand bis 23.09.2026 nur «Pikettdienst».
    betriebName: 'Pikettdienst KW ${kalenderwoche(p.datumStart)}',
    betriebOrt: null,
    betriebNr: null,
    regionId: null,
    datum: p.datumStart,
    status: l.status,
    kennzeichen: l.kennzeichen,
    betragCHF: p.pauschaleGesamt ?? p.pauschale,
  );
}

const Object _unveraendert = Object();

/// Der Filterzustand des Screens. Unveränderlich, damit er sich testen und
/// in der URL abbilden lässt.
class EinsatzFilter {
  final int jahr;
  final int monat; // 0 = alle
  final Set<EinsatzTyp> typen; // leer = alle
  final Set<EinsatzStatus> status; // leer = alle
  final Set<String> regionIds; // leer = alle
  final String suche;

  // Störungs-Zusatzfilter — wirken nur, wenn `typen` genau {stoerung} ist.
  final String? anlageTyp; // null = alle, 'ohne' = ohne Typ
  final String kmFilter; // 'alle' | 'mit' | 'ohne'
  final int? bereich; // 1..5

  const EinsatzFilter({
    required this.jahr,
    this.monat = 0,
    this.typen = const {},
    this.status = const {},
    this.regionIds = const {},
    this.suche = '',
    this.anlageTyp,
    this.kmFilter = 'alle',
    this.bereich,
  });

  bool get nurStoerung =>
      typen.length == 1 && typen.contains(EinsatzTyp.stoerung);

  EinsatzFilter copyWith({
    int? jahr,
    int? monat,
    Set<EinsatzTyp>? typen,
    Set<EinsatzStatus>? status,
    Set<String>? regionIds,
    String? suche,
    Object? anlageTyp = _unveraendert,
    String? kmFilter,
    Object? bereich = _unveraendert,
  }) => EinsatzFilter(
    jahr: jahr ?? this.jahr,
    monat: monat ?? this.monat,
    typen: typen ?? this.typen,
    status: status ?? this.status,
    regionIds: regionIds ?? this.regionIds,
    suche: suche ?? this.suche,
    anlageTyp: anlageTyp == _unveraendert
        ? this.anlageTyp
        : anlageTyp as String?,
    kmFilter: kmFilter ?? this.kmFilter,
    bereich: bereich == _unveraendert ? this.bereich : bereich as int?,
  );
}

/// Reine Filterfunktion — der Screen ruft sie mit seinem Zustand auf.
List<Einsatz> filtereEinsaetze(List<Einsatz> alle, EinsatzFilter f) {
  final gefiltert = alle.where((e) {
    if (e.datum.year != f.jahr) return false;
    if (f.monat != 0 && e.datum.month != f.monat) return false;
    if (f.typen.isNotEmpty && !f.typen.contains(e.typ)) return false;
    if (f.status.isNotEmpty && !f.status.contains(e.status)) return false;
    if (f.regionIds.isNotEmpty && !f.regionIds.contains(e.regionId)) {
      return false;
    }
    if (f.suche.trim().isNotEmpty &&
        !betriebPasst(
          name: e.betriebName,
          ort: e.betriebOrt,
          betriebNr: e.betriebNr,
          suche: f.suche,
        ) &&
        !(e.beschreibung?.toLowerCase().contains(
              f.suche.trim().toLowerCase(),
            ) ??
            false)) {
      return false;
    }
    if (f.nurStoerung) {
      if (f.anlageTyp == 'ohne' && e.anlageTyp != null) return false;
      if (f.anlageTyp != null &&
          f.anlageTyp != 'ohne' &&
          e.anlageTyp != f.anlageTyp) {
        return false;
      }
      if (f.kmFilter == 'mit' && !e.istKilometerabrechnung) return false;
      if (f.kmFilter == 'ohne' && e.istKilometerabrechnung) return false;
      if (f.bereich != null && !e.stoerungBereiche.contains(f.bereich)) {
        return false;
      }
    }
    return true;
  }).toList()..sort((a, b) => b.datum.compareTo(a.datum));
  return gefiltert;
}
