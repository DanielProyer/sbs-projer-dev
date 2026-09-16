import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/core/util/einsatz_lage.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_pruef_service.dart';

/// Die Regeln des Monatsabschlusses (B4).
///
/// WARUM monatlich: Der Monat ist der Takt des Geschäfts —
/// Heineken-Monatsrechnung, Lohnlauf, Bankauszug. Und der Fehlertyp «Kette
/// bricht ab» (03./04.09.2026: zwei Ertragsbuchungen fehlten, weil das Handy
/// mitten im Abschluss wegging) wird hier sichtbar, bevor er teuer wird.
///
/// Gleicher Schnitt wie die Jahresprüfung, eigene Dateien: Die 17
/// Jahresregeln funktionieren und werden nicht angefasst.

// ---------------------------------------------------------------- Einsätze

class ReinigungenOffenRegel extends MonatsRegel {
  @override
  String get id => 'reinigungen_offen';
  @override
  String get gruppe => 'Einsätze';
  @override
  String get titel => 'Alle Reinigungen abgeschlossen';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    // «in Arbeit» heisst bei einer Reinigung: angelegt, nicht abgeschlossen.
    final offen = k
        .vomTyp(EinsatzTyp.reinigung)
        .where((e) => e.status == EinsatzStatus.inArbeit)
        .length;
    if (offen == 0) {
      return befund(PruefStatus.gruen, ist: 'keine offen');
    }
    return befund(
      PruefStatus.rot,
      ist: '$offen offen',
      soll: 'keine offen',
      hinweis: offen == 1
          ? 'Eine Reinigung steht noch auf «offen».'
          : '$offen Reinigungen stehen noch auf «offen».',
      route: '/einsaetze?typ=reinigung',
    );
  }
}

class EinsaetzeOffenRegel extends MonatsRegel {
  @override
  String get id => 'einsaetze_offen';
  @override
  String get gruppe => 'Einsätze';
  @override
  String get titel => 'Störungen und Montagen erledigt';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    const nichtFertig = {
      EinsatzStatus.offen,
      EinsatzStatus.geplant,
      EinsatzStatus.inArbeit,
    };
    final offen = k.einsaetze
        .where(
          (e) =>
              (e.typ == EinsatzTyp.stoerung || e.typ == EinsatzTyp.montage) &&
              nichtFertig.contains(e.status),
        )
        .length;
    if (offen == 0) {
      return befund(PruefStatus.gruen, ist: 'alle erledigt');
    }
    return befund(
      PruefStatus.rot,
      ist: '$offen offen',
      soll: 'alle erledigt',
      hinweis: 'Ein Einsatz aus diesem Monat ist noch nicht abgeschlossen.',
      route: '/einsaetze?typ=stoerung',
    );
  }
}

class ErtragsbuchungenRegel extends MonatsRegel {
  @override
  String get id => 'ertragsbuchungen';
  @override
  String get gruppe => 'Einsätze';
  @override
  String get titel => 'Jede Reinigung hat ihre Ertragsbuchung';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    // «erledigt» heisst: abgeschlossen, aber weder `abgerechnet` noch
    // Ertragsbuchung (B2, einsatz_lage.dart). Kulanz trägt keinen Betrag
    // und gehört nicht dazu.
    final ohne = k
        .vomTyp(EinsatzTyp.reinigung)
        .where(
          (e) => e.status == EinsatzStatus.erledigt && (e.betragCHF ?? 0) > 0,
        )
        .length;
    if (ohne == 0) {
      return befund(PruefStatus.gruen, ist: 'alle gebucht');
    }
    return befund(
      PruefStatus.rot,
      ist: '$ohne ohne Buchung',
      soll: 'alle gebucht',
      hinweis:
          'Die Ertragsbuchung ist der letzte Schritt der Abschlusskette '
          'und damit das erste Opfer, wenn die Verbindung abbricht. Über '
          'Forderungen nachbuchen.',
      route: '/rechnungen',
    );
  }
}

class VersandvermerkRegel extends MonatsRegel {
  @override
  String get id => 'versandvermerk';
  @override
  String get gruppe => 'Einsätze';
  @override
  String get titel => 'Mail-Rechnungen mit Versandvermerk';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (k.mailRechnungenOffen == 0) {
      return befund(PruefStatus.gruen, ist: 'alle vermerkt');
    }
    return befund(
      PruefStatus.rot,
      ist: '${k.mailRechnungenOffen} ohne Vermerk',
      soll: 'alle vermerkt',
      hinweis:
          'Entweder ist die Rechnung nie angekommen, oder sie geht '
          'doppelt raus — Postausgang prüfen.',
      route: '/rechnungen',
    );
  }
}

/// Die Regeln des Monatsabschlusses, in Anzeigereihenfolge (B4).
List<MonatsRegel> alleMonatsRegeln() => [
  ReinigungenOffenRegel(),
  EinsaetzeOffenRegel(),
  ErtragsbuchungenRegel(),
  VersandvermerkRegel(),
];
