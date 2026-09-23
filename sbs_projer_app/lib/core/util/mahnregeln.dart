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
    r.zahlungsstatus != 'abgeschrieben' &&
    // I-3 (Review 23.09.2026): Ein bereits vermerkter Zahlungseingang darf
    // nie ins Mahnsystem, auch wenn der Status noch nicht auf «bezahlt»
    // nachgezogen wurde — sonst mahnt der Lauf schneller, als der Mensch
    // den Status pflegt.
    r.zahlungEingegangenAm == null &&
    (r.zahlungBetrag ?? 0) == 0;

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
    case 'offen':
    case 'gesendet':
      return erreicht(_plus(massgebendeFaelligkeit(r), kErinnerungNachTagen))
          ? MahnStufe.erinnerung
          : null;
    default:
      // I-4 (Review 23.09.2026): Nur bekannte Status lösen die erste Stufe
      // aus. Ein unbekannter oder abweichender Status (z. B. «storniert»,
      // «freigegeben») ist immer ein Zeichen, dass hier NICHT stur nach
      // Fälligkeit gemahnt werden darf.
      return null;
  }
}

bool bankSperre(
  DateTime? letzterAuszug, {
  required DateTime heute,
  // M-4 (Review 23.09.2026): Eine erkannte Lücke in der Auszugskette
  // (Bank-Wächter) heisst, dass Zahlungen fehlen könnten, die den Mahnlauf
  // stoppen würden — auch wenn der letzte Auszug scheinbar aktuell ist.
  bool auszugLuecke = false,
}) {
  if (letzterAuszug == null || auszugLuecke) return true;
  return _tag(heute).difference(_tag(letzterAuszug)).inDays > kAuszugHoechstensAltTage;
}

typedef OffeneGutschrift = ({String? partei, double betrag});

/// Toleranz beim Betragsvergleich: Kunden zahlen oft auf 5 Rappen gerundet
/// oder mit kleinen Bankspesen-Abweichungen (Review 23.09.2026, I-2).
/// Lieber zu vorsichtig sperren als eine bezahlte Rechnung mahnen.
const kBetragsToleranz = 0.10;

bool _gleich(double a, double b) => (a - b).abs() < kBetragsToleranz;

/// Höchstzahl offener Beträge, bis zu der die Teilsummen-Prüfung per
/// Bitmaske noch vertretbar ist (2^12 = 4096 Kombinationen).
const kMaxBetraegeFuerTeilsumme = 12;

/// Trifft der normalisierte Zahlername einen der bekannten Namen, exakt
/// oder als Teilstring (in beide Richtungen)? Der kürzere Teil muss
/// mindestens 4 Zeichen haben (Review 23.09.2026, M-2) — sonst würde z. B.
/// «Bar» jeden Zahler mit «bar» irgendwo im Namen treffen.
bool _nameTrifft(Set<String> namen, String zahler) {
  if (zahler.isEmpty) return false;
  for (final n in namen) {
    if (n == zahler) return true;
    final kurz = n.length <= zahler.length ? n : zahler;
    final lang = n.length <= zahler.length ? zahler : n;
    if (kurz.length >= 4 && lang.contains(kurz)) return true;
  }
  return false;
}

/// Prüft, ob eine (beliebige, nicht-leere) Teilmenge der offenen Beträge in
/// der Summe dem Gutschriftsbetrag entspricht — z. B. wenn eine Sammel-
/// zahlung 2 von 3 offenen Rechnungen deckt (Review 23.09.2026, I-1).
///
/// WARUM Bitmaske bis [kMaxBetraegeFuerTeilsumme]: Ein Betrieb hat praktisch
/// nie mehr offene Rechnungen; 2^12 Kombinationen sind trivial zu prüfen.
/// Bei mehr offenen Beträgen wird — weil sich keine vollständige Prüfung
/// mehr lohnt — aus Vorsicht IMMER gesperrt (sicherer Rückfall): lieber ein
/// Betrieb zu viel zurückgehalten als eine Mahnung für Bezahltes.
bool _teilsummeTrifft(List<double> betraege, double ziel) {
  if (betraege.isEmpty) return false;
  if (betraege.length > kMaxBetraegeFuerTeilsumme) return true;
  final n = betraege.length;
  for (var maske = 1; maske < (1 << n); maske++) {
    var summe = 0.0;
    for (var i = 0; i < n; i++) {
      if (maske & (1 << i) != 0) summe += betraege[i];
    }
    if (_gleich(summe, ziel)) return true;
  }
  return false;
}

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
  for (final g in gutschriften) {
    final p = zahlernameNorm(g.partei ?? '');
    if (_nameTrifft(namen, p)) return true;
    if (_teilsummeTrifft(offeneBetraege, g.betrag)) return true;
  }
  return false;
}

MahnStufe hoechsteStufe(Iterable<MahnStufe> stufen) {
  if (stufen.isEmpty) {
    // M-5 (Review 23.09.2026): Ein leerer Aufruf ist ein Programmierfehler
    // beim Aufrufer (kein Schreiben ohne Stufe) — lieber laut scheitern als
    // still eine falsche Stufe erraten.
    throw ArgumentError('hoechsteStufe: Liste darf nicht leer sein');
  }
  return stufen.reduce((a, b) => a.index >= b.index ? a : b);
}

DateTime mahnFrist(DateTime versand) => _plus(versand, kMahnFristTage);
