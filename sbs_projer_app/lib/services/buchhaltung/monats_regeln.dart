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

// ---------------------------------------------------------------- Heineken

/// Die Stufen der Heineken-Monatsrechnung (CLAUDE.md):
/// `offen → gesendet → freigegeben → bezahlt`. «Mindestens Stufe X» heisst:
/// Der aktuelle Status liegt an oder hinter dieser Stelle.
const _heinekenStufen = ['offen', 'gesendet', 'freigegeben', 'bezahlt'];

bool _mindestens(String? status, String stufe) {
  if (status == null) return false;
  final ist = _heinekenStufen.indexOf(status);
  final soll = _heinekenStufen.indexOf(stufe);
  return ist >= 0 && soll >= 0 && ist >= soll;
}

class HeinekenRechnungRegel extends MonatsRegel {
  @override
  String get id => 'heineken_rechnung';
  @override
  String get gruppe => 'Heineken';
  @override
  String get titel => 'Monatsrechnung erstellt';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (k.heinekenStatus != null) {
      return befund(PruefStatus.gruen, ist: 'erstellt');
    }
    return laeuftNoch(k, route: '/heineken') ??
        befund(
          PruefStatus.rot,
          ist: 'fehlt',
          soll: 'erstellt',
          hinweis: 'Ohne Rechnung kein Ertrag für ${k.monatName}.',
          route: '/heineken',
        );
  }
}

class HeinekenGesendetRegel extends MonatsRegel {
  @override
  String get id => 'heineken_gesendet';
  @override
  String get gruppe => 'Heineken';
  @override
  String get titel => 'Monatsrechnung versendet';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (_mindestens(k.heinekenStatus, 'gesendet')) {
      return befund(PruefStatus.gruen, ist: 'versendet');
    }
    if (k.heinekenStatus == null) {
      // Kein zweiter roter Alarm — die Regel darüber sagt es schon.
      return befund(
        PruefStatus.gelb,
        ist: 'keine Rechnung',
        hinweis: 'Rechnung zuerst erstellen.',
        route: '/heineken',
      );
    }
    return befund(
      PruefStatus.gelb,
      ist: k.heinekenStatus!,
      soll: 'gesendet',
      hinweis: 'Rechnung liegt bereit, ist aber noch nicht raus.',
      route: '/heineken',
    );
  }
}

class HeinekenFreigegebenRegel extends MonatsRegel {
  @override
  String get id => 'heineken_freigegeben';
  @override
  String get gruppe => 'Heineken';
  @override
  String get titel => 'Monatsrechnung freigegeben';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (_mindestens(k.heinekenStatus, 'freigegeben')) {
      return befund(PruefStatus.gruen, ist: 'freigegeben');
    }
    if (k.heinekenStatus == null) {
      return befund(
        PruefStatus.gelb,
        ist: 'keine Rechnung',
        hinweis: 'Rechnung zuerst erstellen.',
        route: '/heineken',
      );
    }
    return befund(
      PruefStatus.gelb,
      ist: k.heinekenStatus!,
      soll: 'freigegeben',
      hinweis: 'Erst die Freigabe bucht Debitoren und Ertrag.',
      route: '/heineken',
    );
  }
}

class BergkundenpauschalenRegel extends MonatsRegel {
  @override
  String get id => 'bergkundenpauschalen';
  @override
  String get gruppe => 'Heineken';
  @override
  String get titel => 'Bergkundenpauschalen erfasst';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    // Pro Betrieb und Tag eine Pauschale (180 CHF je Besuch), nicht je
    // Anlage — deshalb Tagesschlüssel statt Reinigungen.
    final fehlen = k.bergTage.difference(k.pauschalenTage);
    if (fehlen.isEmpty) {
      return befund(
        PruefStatus.gruen,
        ist: k.bergTage.isEmpty ? 'keine Bergkunden' : 'alle erfasst',
      );
    }
    return laeuftNoch(k, route: '/bergkundenpauschalen') ??
        befund(
          PruefStatus.gelb,
          ist: '${fehlen.length} fehlen',
          soll: '${k.bergTage.length} Besuche',
          hinweis: 'Ein Besuch bei einem Bergkunden ohne Pauschale.',
          route: '/bergkundenpauschalen',
        );
  }
}

// ------------------------------------------------------------- Bank & Lohn

class BankAbgedecktRegel extends MonatsRegel {
  @override
  String get id => 'bank_abgedeckt';
  @override
  String get gruppe => 'Bank';
  @override
  String get titel => 'Bankauszug importiert und geprüft';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    // Deckung Tag für Tag: Mehrere Auszüge dürfen den Monat gemeinsam
    // abdecken — Daniel zieht sie nicht immer monatsweise.
    var tag = k.von;
    final luecken = <DateTime>[];
    while (!tag.isAfter(k.bis)) {
      final gedeckt = k.camtDeckung.any(
        (d) => !tag.isBefore(d.von) && !tag.isAfter(d.bis),
      );
      if (!gedeckt) luecken.add(tag);
      tag = tag.add(const Duration(days: 1));
    }

    if (luecken.isNotEmpty) {
      return laeuftNoch(k, route: '/buchhaltung/camt-import') ??
          befund(
            PruefStatus.gelb,
            ist: '${luecken.length} Tage ohne Auszug',
            soll: 'ganzer Monat',
            hinweis: 'Bankauszug für ${k.monatName} importieren.',
            route: '/buchhaltung/camt-import',
          );
    }

    if (k.offenePrueflisteImMonat > 0) {
      return befund(
        PruefStatus.gelb,
        ist: '${k.offenePrueflisteImMonat} offen',
        soll: 'Prüfliste leer',
        hinweis: 'Buchungen aus diesem Monat warten auf die Zuordnung.',
        route: '/buchhaltung/camt-pruefliste',
      );
    }

    return befund(PruefStatus.gruen, ist: 'importiert, Prüfliste leer');
  }
}

class LohnlaufRegel extends MonatsRegel {
  @override
  String get id => 'lohnlauf';
  @override
  String get gruppe => 'Lohn';
  @override
  String get titel => 'Lohnlauf gemacht';

  @override
  Pruefbefund pruefe(MonatsKontext k) {
    if (k.lohnMonate.contains(k.monat)) {
      return befund(PruefStatus.gruen, ist: 'abgerechnet');
    }
    return laeuftNoch(k, route: '/buchhaltung/lohn') ??
        befund(
          PruefStatus.gelb,
          ist: 'fehlt',
          soll: 'abgerechnet',
          hinweis: 'Keine Lohnabrechnung für ${k.monatName}.',
          route: '/buchhaltung/lohn',
        );
  }
}

/// Die Regeln des Monatsabschlusses, in Anzeigereihenfolge (B4).
List<MonatsRegel> alleMonatsRegeln() => [
  ReinigungenOffenRegel(),
  EinsaetzeOffenRegel(),
  ErtragsbuchungenRegel(),
  VersandvermerkRegel(),
  HeinekenRechnungRegel(),
  HeinekenGesendetRegel(),
  HeinekenFreigegebenRegel(),
  BergkundenpauschalenRegel(),
  BankAbgedecktRegel(),
  LohnlaufRegel(),
];
