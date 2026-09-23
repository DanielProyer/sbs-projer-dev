/// Die Regeln des Mahnwesens (v0.134.0) — rein, ohne I/O.
///
/// WARUM rein: Hier entscheidet sich, ob ein Kunde gemahnt wird. Der Fehler,
/// den es um jeden Preis zu vermeiden gilt, ist eine Mahnung für Bezahltes
/// (Daniel 23.09.2026). Das muss ohne Datenbank und Widget prüfbar sein.
/// Spec: docs/superpowers/specs/2026-09-23-mahnwesen-design.md
library;

import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

/// Rechnungen davor sind Altlast (jahrgangsweise Abschreibung, Entscheid
/// 19.09.2026) und kommen nie ins Mahnsystem.
final kMahnStart = DateTime.utc(2026, 1, 1);

/// Zahlungserinnerung frühestens so viele Tage nach Fälligkeit.
const kErinnerungNachTagen = 10;

/// Nächste Stufe frühestens so viele Tage nach Ablauf der gesetzten Frist.
const kNaechsteStufeNachFrist = 5;

/// Frist im Mahnschreiben.
const kMahnFristTage = 10;

/// Der Mahnlauf ist gesperrt, wenn der letzte Bankauszug älter ist.
const kAuszugHoechstensAltTage = 2;

/// Eine Stufe ist erst fällig, wenn ihre Bedingung so viele Tage VOR dem
/// Auszug-Stichtag erfüllt war — eine Zahlung vom letzten Fristtag steht
/// sicher im Auszug.
const kPufferVorStichtagTage = 3;

enum MahnStufe { erinnerung, mahnung1, letzte }

extension MahnStufeX on MahnStufe {
  int get wert => index;

  /// Wert von `rechnungen.zahlungsstatus` nach dieser Stufe.
  String get status => switch (this) {
        MahnStufe.erinnerung => 'erinnert',
        MahnStufe.mahnung1 => 'mahnung_1',
        MahnStufe.letzte => 'mahnung_2',
      };

  String get titel => switch (this) {
        MahnStufe.erinnerung => 'Zahlungserinnerung',
        MahnStufe.mahnung1 => '1. Mahnung',
        MahnStufe.letzte => 'Letzte Mahnung',
      };
}

DateTime _tag(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime _plus(DateTime d, int tage) => _tag(d).add(Duration(days: tage));

bool imMahnbereich(Rechnung r) =>
    (r.rechnungstyp == 'kundenrechnung' || r.rechnungstyp == 'jahresrechnung') &&
    !_tag(r.rechnungsdatum).isBefore(kMahnStart) &&
    r.zahlungsstatus != 'bezahlt' &&
    r.zahlungsstatus != 'abgeschrieben';

/// Nachweislich beim Kunden: per Mail, am Tresen übergeben (mit Datum) oder
/// Versandart Tresen — das Übergabedatum wird erst seit v0.71.0 gespeichert,
/// davor gilt das Rechnungsdatum (Entscheid Daniel 23.09.2026).
bool istZugestellt(Rechnung r) =>
    r.versendetAm != null ||
    r.uebergebenAm != null ||
    r.versandart == 'rechnung_tresen';

DateTime zustelldatum(Rechnung r) =>
    _tag(r.versendetAm ?? r.uebergebenAm ?? r.rechnungsdatum);

/// Ist die Rechnung erst nach ihrem Fälligkeitsdatum zugestellt worden
/// (z. B. «erneut senden»), laufen die 30 Tage ab der Zustellung — sonst
/// würde eine eben zugestellte Rechnung sofort gemahnt.
DateTime massgebendeFaelligkeit(Rechnung r) {
  final z = zustelldatum(r);
  final f = _tag(r.faelligkeitsdatum);
  return z.isAfter(f) ? _plus(z, 30) : f;
}

/// Stufe, die jetzt fällig ist — oder null. [stichtag] ist das Ende des
/// letzten eingelesenen Bankauszugs, NICHT heute.
MahnStufe? faelligeStufe(Rechnung r, {required DateTime stichtag}) {
  if (!imMahnbereich(r) || !istZugestellt(r)) return null;
  final grenze = _plus(stichtag, -kPufferVorStichtagTage);
  bool erreicht(DateTime ab) => !ab.isAfter(grenze);

  switch (r.zahlungsstatus) {
    case 'erinnert':
      final frist = r.mahnFristBis ??
          (r.erinnerungAm != null ? _plus(r.erinnerungAm!, kMahnFristTage) : null);
      if (frist == null) return null;
      return erreicht(_plus(frist, kNaechsteStufeNachFrist)) ? MahnStufe.mahnung1 : null;
    case 'mahnung_1':
      final frist = r.mahnFristBis ??
          (r.mahnung1Am != null ? _plus(r.mahnung1Am!, kMahnFristTage) : null);
      if (frist == null) return null;
      return erreicht(_plus(frist, kNaechsteStufeNachFrist)) ? MahnStufe.letzte : null;
    case 'mahnung_2':
      return null; // weiter mit Heineken (Teil 2)
    default:
      return erreicht(_plus(massgebendeFaelligkeit(r), kErinnerungNachTagen))
          ? MahnStufe.erinnerung
          : null;
  }
}

bool bankSperre(DateTime? letzterAuszug, {required DateTime heute}) {
  if (letzterAuszug == null) return true;
  return _tag(heute).difference(_tag(letzterAuszug)).inDays > kAuszugHoechstensAltTage;
}

typedef OffeneGutschrift = ({String? partei, double betrag});

bool _gleich(double a, double b) => (a - b).abs() < 0.005;

/// Gibt es eine noch nicht zugeordnete Bankgutschrift, die zu diesem
/// Betrieb gehören könnte? Dann wird er nicht gemahnt.
///
/// Bewusst grosszügig: Ein Betrag, der zu irgendeiner offenen Rechnung
/// passt, sperrt — auch bei gängigen Preisen wie 94.05. Lieber ein Betrieb
/// zu viel zurückgehalten als eine Mahnung für Bezahltes.
bool gutschriftSperre({
  required String betriebName,
  required List<String> aliase,
  required List<double> offeneBetraege,
  required List<OffeneGutschrift> gutschriften,
}) {
  final namen = {
    zahlernameNorm(betriebName),
    for (final a in aliase) zahlernameNorm(a),
  }..remove('');
  final summe = offeneBetraege.fold<double>(0, (s, b) => s + b);
  for (final g in gutschriften) {
    final p = zahlernameNorm(g.partei ?? '');
    if (p.isNotEmpty && namen.contains(p)) return true;
    if (offeneBetraege.any((b) => _gleich(b, g.betrag))) return true;
    if (offeneBetraege.length > 1 && _gleich(summe, g.betrag)) return true;
  }
  return false;
}

MahnStufe hoechsteStufe(Iterable<MahnStufe> stufen) =>
    stufen.reduce((a, b) => a.index >= b.index ? a : b);

DateTime mahnFrist(DateTime versand) => _plus(versand, kMahnFristTage);
