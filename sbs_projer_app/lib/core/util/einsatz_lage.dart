/// Ein Status für alle Einsatztypen (B2).
///
/// WARUM: Sechs Typen, vier Vokabulare — «fertig» heisst je nach Tabelle
/// `abgeschlossen` oder `behoben`, «verrechnet» ist nirgends ein Status,
/// sondern ein Flag daneben, und `anlage_detail_screen.dart:878` verglich
/// eine Störung mit `'abgeschlossen'`, einem Wert, den Störungen nie tragen.
/// Hier steht die Regel einmal. Die Tabellen bleiben, wie sie sind: Sie
/// kennen ohnehin nur «fertig» (Ist-Aufnahme 15.09.2026: je Tabelle genau
/// ein Wert), und die Datenbank ist mit der v2 geteilt.
///
/// Nicht zu verwechseln mit `einsatz_status.dart` — dort lebt
/// `einsatzStatusNachSpeichern` (Fall Sartons, v0.76.0), das die Formulare
/// beim Speichern setzen; hier wird die Anzeige-Stufe aus den gespeicherten
/// Feldern abgeleitet.
///
/// Alle Eingaben sind Primitive — kein Modell —, damit die Tests ohne Isar
/// laufen und die Regel als Vorlage für das Einsatz-Modell der v2 taugt.
library;

/// Die fünf Stufen, in dieser Reihenfolge. Die Reihenfolge ist der Vorrang:
/// Trifft mehr als eine zu, gilt die höhere.
enum EinsatzStatus { offen, geplant, inArbeit, erledigt, verrechnet }

/// Steht neben der Stufe, ändert sie nicht — bleibt sichtbar, statt in
/// «erledigt» zu verschwinden.
enum EinsatzKennzeichen { keines, abgebrochen, nichtBehebbar }

typedef EinsatzLage = ({EinsatzStatus status, EinsatzKennzeichen kennzeichen});

EinsatzLage _lage(
  EinsatzStatus status, [
  EinsatzKennzeichen kennzeichen = EinsatzKennzeichen.keines,
]) => (status: status, kennzeichen: kennzeichen);

/// Abgebrochene Einsätze sind abgeschlossen, ohne dass etwas geleistet
/// wurde: Stufe «erledigt», Kennzeichen «abgebrochen», und nie «verrechnet» —
/// selbst wenn ein Flag anderes behauptet.
EinsatzLage _abgebrochen() =>
    _lage(EinsatzStatus.erledigt, EinsatzKennzeichen.abgebrochen);

/// Reinigung. «Verrechnet» ist `abgerechnet` ODER Ertragsbuchung vorhanden:
/// Heineken-Reinigungen bekommen keine eigene Buchung (die entsteht erst mit
/// der Monatsrechnung) und tragen `abgerechnet`; Bar, Tresen, Mail, Post und
/// Jahresrechnung bekommen beim Abschluss eine Buchung und tragen nie
/// `abgerechnet`. Das Oder deckt beide und die 8'439 Altdaten ohne
/// Zahlungsart.
EinsatzLage reinigungLage({
  required String status,
  required bool abgerechnet,
  required bool hatBuchung,
}) {
  if (status == 'storniert') return _abgebrochen();
  if (abgerechnet || hatBuchung || status == 'abgerechnet') {
    return _lage(EinsatzStatus.verrechnet);
  }
  return switch (status) {
    'abgeschlossen' => _lage(EinsatzStatus.erledigt),
    'offen' => _lage(EinsatzStatus.inArbeit),
    // Unbekannt wirft nicht — so fällt ein neuer Wert in der Liste auf,
    // statt die Liste zu stürzen.
    _ => _lage(EinsatzStatus.offen),
  };
}

/// Störung. «Offen» ist ein eigener Zustand vor «geplant»: gemeldet, aber
/// noch ohne Termin — das ist, was Daniel morgens sucht.
EinsatzLage stoerungLage({
  required String status,
  DateTime? geplantAm,
  String? arbeitVon,
  String? arbeitBis,
  required bool abgerechnet,
}) {
  if (abgerechnet) return _lage(EinsatzStatus.verrechnet);
  final arbeitLaeuft = arbeitVon != null && arbeitBis == null;
  return switch (status) {
    'behoben' => _lage(EinsatzStatus.erledigt),
    'nicht_behebbar' => _lage(
      EinsatzStatus.erledigt,
      EinsatzKennzeichen.nichtBehebbar,
    ),
    'in_bearbeitung' => _lage(EinsatzStatus.inArbeit),
    'offen' when arbeitLaeuft => _lage(EinsatzStatus.inArbeit),
    'offen' when geplantAm != null => _lage(EinsatzStatus.geplant),
    _ => _lage(EinsatzStatus.offen),
  };
}

/// Montage.
EinsatzLage montageLage({
  required String status,
  String? arbeitVon,
  String? arbeitBis,
  required bool abgerechnet,
}) {
  if (status == 'abgebrochen') return _abgebrochen();
  if (abgerechnet) return _lage(EinsatzStatus.verrechnet);
  final arbeitLaeuft = arbeitVon != null && arbeitBis == null;
  return switch (status) {
    'abgeschlossen' => _lage(EinsatzStatus.erledigt),
    'in_bearbeitung' => _lage(EinsatzStatus.inArbeit),
    'geplant' when arbeitLaeuft => _lage(EinsatzStatus.inArbeit),
    'geplant' => _lage(EinsatzStatus.geplant),
    _ => _lage(EinsatzStatus.offen),
  };
}

/// Eigenauftrag. Kein «geplant» — das Modell hat kein Plandatum.
EinsatzLage eigenauftragLage({
  required String status,
  required bool abgerechnet,
}) {
  if (abgerechnet) return _lage(EinsatzStatus.verrechnet);
  return switch (status) {
    'behoben' => _lage(EinsatzStatus.erledigt),
    'nicht_behebbar' => _lage(
      EinsatzStatus.erledigt,
      EinsatzKennzeichen.nichtBehebbar,
    ),
    'nachbearbeitung_noetig' => _lage(EinsatzStatus.inArbeit),
    _ => _lage(EinsatzStatus.offen),
  };
}

/// Saison-Beleg (`eroeffnungsreinigungen`, `art` eroeffnung oder
/// endreinigung). Ein Beleg ist per Definition erledigt; das Geplante dazu
/// steht in `termine`.
EinsatzLage saisonreinigungLage({required bool abgerechnet}) =>
    _lage(abgerechnet ? EinsatzStatus.verrechnet : EinsatzStatus.erledigt);

/// Termin (`termine`): vorgeschlagen · geplant · erledigt · abgesagt.
EinsatzLage terminLage({required String status}) => switch (status) {
  'abgesagt' => _abgebrochen(),
  'erledigt' => _lage(EinsatzStatus.erledigt),
  'geplant' => _lage(EinsatzStatus.geplant),
  _ => _lage(EinsatzStatus.offen),
};

/// Pikett: aktiv heisst gerade im Dienst.
EinsatzLage pikettLage({required bool istAktiv, required bool abgerechnet}) {
  if (abgerechnet) return _lage(EinsatzStatus.verrechnet);
  return _lage(istAktiv ? EinsatzStatus.inArbeit : EinsatzStatus.erledigt);
}

/// Anzeigename je Stufe — an einer Stelle, damit Badge und Filter dasselbe
/// Wort verwenden.
String einsatzStatusLabel(EinsatzStatus s) => switch (s) {
  EinsatzStatus.offen => 'offen',
  EinsatzStatus.geplant => 'geplant',
  EinsatzStatus.inArbeit => 'in Arbeit',
  EinsatzStatus.erledigt => 'erledigt',
  EinsatzStatus.verrechnet => 'verrechnet',
};

String einsatzKennzeichenLabel(EinsatzKennzeichen k) => switch (k) {
  EinsatzKennzeichen.keines => '',
  EinsatzKennzeichen.abgebrochen => 'abgebrochen',
  EinsatzKennzeichen.nichtBehebbar => 'nicht behebbar',
};
