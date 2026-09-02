import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/bank_waechter.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');
String chf(double v) => _chf.format(v);
String _datum(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

/// Eine einzelne Abschluss-Prüfregel. Reine Logik — alle Daten kommen aus
/// [AbschlussKontext], damit die Regeln ohne Repository testbar bleiben.
abstract class AbschlussRegel {
  String get id;
  String get gruppe;
  String get titel;
  Pruefbefund pruefe(AbschlussKontext k);
  Pruefbefund befund(
    PruefStatus s, {
    String ist = '',
    String soll = '',
    String hinweis = '',
    String? route,
  }) => Pruefbefund(
    regelId: id,
    gruppe: gruppe,
    status: s,
    titel: titel,
    ist: ist,
    soll: soll,
    hinweis: hinweis,
    aktionRoute: route,
  );
}

class BankCamtRegel extends AbschlussRegel {
  @override
  String get id => 'bank_camt';
  @override
  String get gruppe => 'Bank & Kasse';
  @override
  String get titel => 'Bank 1020 = Bank-Schlusssaldo';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final letzte = k.letzteCamtDateiBis(k.stichtag);
    if (letzte == null) {
      return befund(
        PruefStatus.gelb,
        hinweis: 'Keine camt-Datei bis zum Stichtag — Bankauszug importieren.',
        route: '/buchhaltung/camt-import',
      );
    }
    final journal = k.saldo(1020);
    final diff = journal - letzte.schlusssaldo;
    return befund(
      diff.abs() <= 0.05 ? PruefStatus.gruen : PruefStatus.rot,
      ist: chf(journal),
      soll: chf(letzte.schlusssaldo),
      hinweis: diff.abs() <= 0.05
          ? 'per ${_datum(letzte.bis)}'
          : 'Differenz ${chf(diff)} — Buchungen fehlen oder sind doppelt.',
      route: '/buchhaltung/camt-import',
    );
  }
}

class CamtKetteRegel extends AbschlussRegel {
  @override
  String get id => 'camt_kette';
  @override
  String get gruppe => 'Bank & Kasse';
  @override
  String get titel => 'camt-Exporte lückenlos';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final l = k.camtDateien.where((c) => !c.von.isAfter(k.stichtag)).toList()
      ..sort((a, c) => a.von.compareTo(c.von));
    final probleme = <String>[];
    var status = PruefStatus.gruen;
    for (var i = 1; i < l.length; i++) {
      final luecke = BankWaechter.luecke(
        letztesBis: l[i - 1].bis,
        neuesVon: l[i].von,
      );
      if (luecke != null) {
        probleme.add(luecke);
        if (status == PruefStatus.gruen) status = PruefStatus.gelb;
      }
      if ((l[i].anfangssaldo - l[i - 1].schlusssaldo).abs() > 0.05) {
        probleme.add(
          'Saldosprung ${chf(l[i - 1].schlusssaldo)} → '
          '${chf(l[i].anfangssaldo)} am ${_datum(l[i].von)}',
        );
        status = PruefStatus.rot;
      }
    }
    return befund(
      status,
      ist: '${l.length} Dateien',
      hinweis: probleme.isEmpty
          ? 'Anschluss aller Exporte stimmt.'
          : probleme.join(' · '),
    );
  }
}

class KasseRegel extends AbschlussRegel {
  @override
  String get id => 'kasse';
  @override
  String get gruppe => 'Bank & Kasse';
  @override
  String get titel => 'Kasse 1000 plausibel';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final s = k.saldo(1000);
    if (s < -0.05) {
      return befund(
        PruefStatus.rot,
        ist: chf(s),
        hinweis: 'Negative Kasse — Buchung in falscher Periode.',
      );
    }
    if (s > 10000) {
      return befund(
        PruefStatus.gelb,
        ist: chf(s),
        hinweis: 'Hoher Kassenbestand — Kassensturz/Privatbezug buchen.',
      );
    }
    return befund(PruefStatus.gruen, ist: chf(s));
  }
}

class MwstSaldiertRegel extends AbschlussRegel {
  @override
  String get id => 'mwst_saldiert';
  @override
  String get gruppe => 'MWST';
  @override
  String get titel => '2200/1170/1171 saldiert';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final q = k.letztesQuartalsende();
    final saldi = k.saldiPer(q);
    final reste = [2200, 1170, 1171]
        .where((kt) => (saldi[kt] ?? 0).abs() > 0.05)
        .map((kt) => '$kt ${chf(saldi[kt]!)}')
        .toList();
    return befund(
      reste.isEmpty ? PruefStatus.gruen : PruefStatus.rot,
      ist: reste.isEmpty ? '0.00' : reste.join(' · '),
      soll: '0.00 per ${_datum(q)}',
      hinweis: reste.isEmpty ? '' : 'Quartals-Saldierung auf 2202 fehlt.',
      route: '/buchhaltung/mwst',
    );
  }
}

class Mwst2202Regel extends AbschlussRegel {
  @override
  String get id => 'mwst_2202';
  @override
  String get gruppe => 'MWST';
  @override
  String get titel => '2202 nicht im Soll';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final s = k.saldo(2202); // roh Soll−Haben: Haben-Saldo negativ = Schuld
    return befund(
      s > 0.05 ? PruefStatus.gelb : PruefStatus.gruen,
      ist: chf(-s),
      hinweis: s > 0.05
          ? 'Mehr an die ESTV bezahlt als saldiert — Saldierung oder '
                'Rückzahlung prüfen.'
          : 'Geschuldete MWST',
    );
  }
}

class DebitorenVerjaehrtRegel extends AbschlussRegel {
  @override
  String get id => 'debitoren_verjaehrt';
  @override
  String get gruppe => 'Debitoren';
  @override
  String get titel => 'Offene Rechnungen älter als 5 Jahre';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final grenze = DateTime(
      k.stichtag.year - 5,
      k.stichtag.month,
      k.stichtag.day,
    );
    final alt = k.offeneRechnungen
        .where((r) => r.datum.isBefore(grenze))
        .toList();
    final summe = alt.fold(0.0, (s, r) => s + r.brutto);
    return befund(
      alt.isEmpty ? PruefStatus.gruen : PruefStatus.rot,
      ist: '${alt.length} Rechnungen · ${chf(summe)}',
      soll: '0',
      hinweis: alt.isEmpty ? '' : 'Verjährt (Art. 128 OR) — abschreiben.',
      route: '/rechnungen',
    );
  }
}

class DelkredereRegel extends AbschlussRegel {
  @override
  String get id => 'delkredere';
  @override
  String get gruppe => 'Debitoren';
  @override
  String get titel => 'Delkredere = 5 % Debitoren';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final deb = k.saldo(1100);
    final wb = -k.saldo(1109);
    final soll = rundeAufRappen(deb * 0.05);
    if (deb <= 0.05) {
      return befund(PruefStatus.gruen, ist: chf(wb), soll: '0.00');
    }
    if (wb <= 0.05) {
      return befund(
        PruefStatus.rot,
        ist: '0.00',
        soll: chf(soll),
        hinweis: 'Kein Delkredere gebildet (3805 an 1109).',
      );
    }
    final passt = (wb - soll).abs() <= 50;
    return befund(
      passt ? PruefStatus.gruen : PruefStatus.gelb,
      ist: chf(wb),
      soll: chf(soll),
      hinweis: passt ? '' : 'Auf 5 % nachführen.',
    );
  }
}

class DebitorenStatusRegel extends AbschlussRegel {
  @override
  String get id => 'debitoren_status';
  @override
  String get gruppe => 'Debitoren';
  @override
  String get titel => 'Rechnungen «offen» mit gebuchter Zahlung';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final n = k.offeneRechnungenMitZahlung.length;
    return befund(
      n == 0 ? PruefStatus.gruen : PruefStatus.gelb,
      ist: '$n',
      soll: '0',
      hinweis: n == 0 ? '' : 'Status auf «bezahlt» nachziehen.',
      route: '/rechnungen',
    );
  }
}

class RueckstellungRegel extends AbschlussRegel {
  @override
  String get id => 'rueckstellung';
  @override
  String get gruppe => 'Abschluss';
  @override
  String get titel => 'Steuerrückstellung 2208';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final s = -k.saldo(2208);
    if (s > 0.05) return befund(PruefStatus.gruen, ist: chf(s));
    return befund(
      k.jahrAbgeschlossen ? PruefStatus.rot : PruefStatus.gelb,
      ist: '0.00',
      hinweis: 'Rückstellung für Gewinn-/Kapitalsteuern buchen (8900 an 2208).',
      route: '/buchhaltung/steuern',
    );
  }
}

class NegativeSaldenRegel extends AbschlussRegel {
  @override
  String get id => 'negative_salden';
  @override
  String get gruppe => 'Abschluss';
  @override
  String get titel => 'Keine vorzeichenwidrigen Bilanzsalden';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final probleme = <String>[];
    k.saldi.forEach((kt, v) {
      if (kt >= 1000 && kt < 2000 && kt != 1109 && v < -0.05) {
        probleme.add('$kt ${chf(v)}');
      }
      if (kt >= 2000 && kt < 3000 && kt != 2970 && kt != 2980 && v > 0.05) {
        probleme.add('$kt ${chf(v)} im Soll');
      }
    });
    return befund(
      probleme.isEmpty ? PruefStatus.gruen : PruefStatus.rot,
      ist: probleme.isEmpty ? 'keine' : probleme.join(' · '),
      hinweis: probleme.isEmpty ? '' : 'Aufbau- oder Abgrenzungsbuchung fehlt.',
    );
  }
}

class LohnkontenRegel extends AbschlussRegel {
  @override
  String get id => 'lohnkonten';
  @override
  String get gruppe => 'Abschluss';
  @override
  String get titel => 'Lohnkonten 2270–2273';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final soll = [2270, 2271, 2272, 2273]
        .where((kt) => k.saldo(kt) > 0.05)
        .map((kt) => '$kt ${chf(k.saldo(kt))}')
        .toList();
    return befund(
      soll.isEmpty ? PruefStatus.gruen : PruefStatus.gelb,
      ist: soll.isEmpty ? 'alle im Haben/0' : soll.join(' · '),
      hinweis: soll.isEmpty
          ? ''
          : 'Vorauszahlung oder fehlender Lohnlauf — als Forderung (1180) '
                'ausweisen oder Lohnlauf nachholen.',
      route: '/buchhaltung/lohn',
    );
  }
}

class FehlerKontenRegel extends AbschlussRegel {
  @override
  String get id => 'fehler_konten';
  @override
  String get gruppe => 'Abschluss';
  @override
  String get titel => 'FEHLER-Konten leer';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    final t = k.konten
        .where(
          (ko) =>
              ko.bezeichnung.toUpperCase().contains('FEHLER') &&
              k.saldo(ko.kontonummer).abs() > 0.05,
        )
        .map((ko) => '${ko.kontonummer} ${chf(k.saldo(ko.kontonummer))}')
        .toList();
    return befund(
      t.isEmpty ? PruefStatus.gruen : PruefStatus.rot,
      ist: t.isEmpty ? 'leer' : t.join(' · '),
      hinweis: t.isEmpty ? '' : 'Umbuchen auf das richtige Konto.',
    );
  }
}

class SteuerZuordnungRegel extends AbschlussRegel {
  @override
  String get id => 'steuer_zuordnung';
  @override
  String get gruppe => 'Steuern';
  @override
  String get titel => 'Steuerzahlungen einem Jahr zugeordnet';
  @override
  Pruefbefund pruefe(AbschlussKontext k) => befund(
    k.steuerbuchungenOhneJahr == 0 ? PruefStatus.gruen : PruefStatus.gelb,
    ist: '${k.steuerbuchungenOhneJahr} ohne Jahr',
    soll: '0',
    hinweis: k.steuerbuchungenOhneJahr == 0
        ? ''
        : 'Im Steuern-Screen zuordnen.',
    route: '/buchhaltung/steuern',
  );
}

class SteuererklaerungRegel extends AbschlussRegel {
  @override
  String get id => 'steuererklaerung';
  @override
  String get gruppe => 'Steuern';
  @override
  String get titel => 'Steuererklärung eingereicht';
  @override
  Pruefbefund pruefe(AbschlussKontext k) {
    if (!k.jahrAbgeschlossen) {
      return befund(PruefStatus.gruen, hinweis: 'Jahr läuft noch.');
    }
    final ok =
        k.dokumentTypen.contains('steuererklaerung') ||
        k.steuerjahrStatus != 'offen';
    return befund(
      ok ? PruefStatus.gruen : PruefStatus.gelb,
      ist: k.steuerjahrStatus,
      hinweis: ok
          ? ''
          : 'Einreichung bis 30.09. des Folgejahres; Dokument unter Steuern '
                'ablegen.',
      route: '/buchhaltung/steuern/${k.jahr}',
    );
  }
}

List<AbschlussRegel> alleAbschlussRegeln() => [
  BankCamtRegel(),
  CamtKetteRegel(),
  KasseRegel(),
  MwstSaldiertRegel(),
  Mwst2202Regel(),
  DebitorenVerjaehrtRegel(),
  DelkredereRegel(),
  DebitorenStatusRegel(),
  RueckstellungRegel(),
  NegativeSaldenRegel(),
  LohnkontenRegel(),
  FehlerKontenRegel(),
  SteuerZuordnungRegel(),
  SteuererklaerungRegel(),
];
