import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/services/buchhaltung/storno_logik.dart';

/// Was eine einzelne Abschreibung bucht (Mahnwesen-Weg, eine Rechnung).
///
/// Reine Rechnung, damit sie ohne Datenbank prüfbar ist — gebucht wird in
/// [AbschreibungService.abschreiben]: `3805 an 1100` netto und
/// `2200 an 1100` MWST.
typedef EinzelAbschreibung = ({
  DateTime datum,
  double brutto,
  double netto,
  double mwst,
  String beschreibung,
});

final DateFormat _ddMMyyyy = DateFormat('dd.MM.yyyy');

/// Bucht auf **[heute]**, nicht auf das Rechnungsdatum.
///
/// WARUM: Ein Debitorenverlust entsteht an dem Tag, an dem man ihn erkennt,
/// nicht rückwirkend (Art. 41 Abs. 2 MWSTG — Korrektur in der Periode, in der
/// der Verlust eintritt). Bis zum 20.09.2026 datierte das Mahnwesen auf
/// `rechnung.rechnungsdatum`. Stammt die Rechnung aus einem bereits
/// eingereichten Quartal, landete die MWST-Rückholung damit in einer
/// geschlossenen Periode — rückgängig nur noch über eine Korrekturabrechnung.
/// Aufgefallen bei Dischma 2026-05-0579: Rechnung vom 08.05. (Q2, längst
/// abgerechnet), Entscheid am 20.09. (Q3).
///
/// **Beträge unverändert aus der Rechnung.** Früher wurde das Brutto auf
/// 5 Rappen nachgerundet — solange die Rechnungssummen ohnehin auf 5 Rappen
/// stehen (Migration 143) ist das wirkungslos, bei einem krummen Betrag würde
/// die Buchung den Debitor aber um ein paar Rappen NICHT glattstellen. Das
/// Netto wird deshalb als `brutto − mwst` abgeleitet: So geht die Buchung
/// gegen 1100 immer exakt auf, auch wenn `betrag_netto` einer Altrechnung
/// nicht genau dazu passt.
EinzelAbschreibung einzelAbschreibung(Rechnung r, {required DateTime heute}) {
  final brutto = rundeAufRappen(r.betragBrutto);
  // Unsinnige Steuerbeträge (negativ, oder grösser als das Brutto) würden
  // ein negatives Netto buchen. Dann lieber alles als Aufwand.
  final roh = r.mwstBetrag;
  final mwst = (roh <= 0 || roh > brutto) ? 0.0 : rundeAufRappen(roh);
  return (
    datum: DateTime(heute.year, heute.month, heute.day),
    brutto: brutto,
    netto: rundeAufRappen(brutto - mwst),
    mwst: mwst,
    beschreibung:
        'Debitorenverlust ${r.rechnungsnummer ?? r.id.substring(0, 8)} '
        '(Rechnung vom ${_ddMMyyyy.format(r.rechnungsdatum)}, abgeschrieben)',
  );
}

/// Buchungen, die für eine Rechnung zählen (nicht storniert, kein Storno).
Iterable<Buchung> _zaehlend(Iterable<Buchung> buchungen) => buchungen.where(
    (b) => zaehltFuerSaldo(istStorniert: b.istStorniert, stornoVonId: b.stornoVonId));

/// Steht für die Rechnung schon eine Abschreibung im Journal
/// (`beleg_typ = 'abschreibung'`, nicht storniert)?
///
/// WARUM (Review Mahnwesen Teil 2, I-2): `MahnwesenService.abschreiben`
/// bucht zuerst und setzt danach den Status. Bricht es dazwischen ab, steht
/// die Buchung, der Status aber nicht — ein zweiter Versuch darf dann nur
/// noch den Status nachziehen, nie ein zweites Mal buchen.
bool abschreibungSchonGebucht(Iterable<Buchung> buchungenDerRechnung) =>
    _zaehlend(buchungenDerRechnung).any((b) => b.belegTyp == 'abschreibung');

/// Ist auf die Rechnung ein Zahlungseingang gebucht (Haben 1100, nicht
/// storniert)? Eine Abschreibung bucht ebenfalls Haben 1100 — sie ist keine
/// Zahlung und zählt hier nicht. Jede Zahlung, auch eine Teilzahlung,
/// sperrt das Abschreiben (Review Mahnwesen Teil 2, I-1).
bool zahlungGebucht(Iterable<Buchung> buchungenDerRechnung) => _zaehlend(buchungenDerRechnung)
    .any((b) => b.habenKonto == 1100 && b.belegTyp != 'abschreibung');
