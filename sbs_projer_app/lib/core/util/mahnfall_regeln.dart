import 'package:sbs_projer_app/core/util/aufgaben_regeln.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';

/// Reine Regeln der Eskalation (Mahnwesen Teil 2, Spec §5). Keine DB, keine
/// Widgets — alles hier ist mit Tests abgesichert.

/// Tage ohne Heineken-Ergebnis, nach denen die Glocke nachfragt.
const kHeinekenNachfrageTage = 20;

/// Standardfrist, wenn Heineken vermittelt hat und der Kunde zahlen will.
const kVermittlungsFristTage = 20;

/// SchKG 88 Abs. 1: Fortsetzung frühestens 20 Tage nach Zustellung des
/// Zahlungsbefehls; Abs. 2: das Recht erlischt nach einem Jahr.
const kFortsetzungAbTage = 20;

DateTime _tag(DateTime d) => DateTime.utc(d.year, d.month, d.day);
DateTime _plus(DateTime d, int tage) => _tag(d).add(Duration(days: tage));

/// Kostenvorschuss für den Zahlungsbefehl nach GebV SchKG Art. 16 Abs. 1.
double betreibungsKostenvorschuss(double forderung) {
  if (forderung <= 100) return 7;
  if (forderung <= 500) return 20;
  if (forderung <= 1000) return 40;
  if (forderung <= 10000) return 60;
  if (forderung <= 100000) return 90;
  if (forderung <= 1000000) return 190;
  return 400;
}

/// Zeitfenster für das Fortsetzungsbegehren ab Zustellung des Zahlungsbefehls.
({DateTime ab, DateTime bis}) fortsetzungsFenster(DateTime zahlungsbefehlAm) {
  final z = _tag(zahlungsbefehlAm);
  return (
    ab: _plus(z, kFortsetzungAbTage),
    bis: DateTime.utc(z.year + 1, z.month, z.day),
  );
}

/// Alle Rechnungen eines Falls beglichen (bezahlt/abgeschrieben)?
bool alleBezahlt(List<String> zahlungsstatus) =>
    zahlungsstatus.isNotEmpty &&
    zahlungsstatus.every((s) => s == 'bezahlt' || s == 'abgeschrieben');

/// Glocken-Aufgaben eines Mahnfalls. Schlüssel `mahnfall:<id>:<art>`.
List<Aufgabe> mahnfallAufgaben({
  required String fallId,
  required String betrieb,
  required String status,
  DateTime? heinekenKontaktAm,
  DateTime? heinekenFristBis,
  DateTime? zahlungsbefehlAm,
  bool? rechtsvorschlag,
  DateTime? fortsetzungAm,
  String? erledigung,
  bool uebernahmeVerbucht = true,
  required DateTime heute,
}) {
  final h = _tag(heute);
  final route = '/rechnungen/mahnfall/$fallId';
  final a = <Aufgabe>[];
  switch (status) {
    case 'heineken':
      if (heinekenKontaktAm != null &&
          !_plus(heinekenKontaktAm, kHeinekenNachfrageTage).isAfter(h)) {
        a.add(Aufgabe(
            key: 'mahnfall:$fallId:heineken',
            titel: 'Mahnfall $betrieb: Heineken seit $kHeinekenNachfrageTage Tagen ohne Ergebnis',
            route: route));
      }
    case 'heineken_frist':
      if (heinekenFristBis != null && heinekenFristBis.isBefore(h)) {
        a.add(Aufgabe(
            key: 'mahnfall:$fallId:frist',
            titel: 'Mahnfall $betrieb: Zahlungsfrist nach Vermittlung abgelaufen',
            dringend: true,
            route: route));
      }
    case 'betreibung':
      if (zahlungsbefehlAm != null && fortsetzungAm == null) {
        final f = fortsetzungsFenster(zahlungsbefehlAm);
        final warnAb = DateTime.utc(f.bis.year, f.bis.month - 1, f.bis.day);
        if (!warnAb.isAfter(h)) {
          a.add(Aufgabe(
              key: 'mahnfall:$fallId:verwirkung',
              titel: 'Mahnfall $betrieb: Betreibung verfällt am '
                  '${f.bis.day}.${f.bis.month}.${f.bis.year}',
              dringend: true,
              route: route));
        } else if (rechtsvorschlag == false && !f.ab.isAfter(h)) {
          a.add(Aufgabe(
              key: 'mahnfall:$fallId:fortsetzung',
              titel: 'Mahnfall $betrieb: Fortsetzungsbegehren möglich',
              route: route));
        }
      }
    case 'erledigt':
      if (erledigung == 'uebernommen' && !uebernahmeVerbucht) {
        a.add(Aufgabe(
            key: 'mahnfall:$fallId:uebernahme',
            titel: 'Mahnfall $betrieb: Heineken-Übernahme verbuchen — mit Daniel prüfen',
            dringend: true,
            route: route));
      }
  }
  return a;
}

String _datumText(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Status eines Mahnfalls als Text — zentral, damit Mahnlauf, Mahnverlauf
/// und Fall-Arbeitsblatt dasselbe sagen.
String mahnfallStatusText(Mahnfall f) => switch (f.status) {
      'heineken' => 'Bei Heineken',
      'heineken_frist' => f.heinekenFristBis != null
          ? 'Kunde zahlt bis ${_datumText(f.heinekenFristBis!)}'
          : 'Kunde zahlt bis …',
      'betreibung' => 'Betreibung',
      'erledigt' => switch (f.erledigung) {
          'bezahlt' => 'Erledigt: bezahlt',
          'abgeschrieben' => 'Erledigt: abgeschrieben',
          'zurueckgezogen' => 'Erledigt: Betreibung zurückgezogen',
          'uebernommen' => 'Erledigt: Heineken übernimmt',
          _ => 'Erledigt',
        },
      _ => f.status,
    };

/// Beginn des Verzugszinses im Betreibungsbegehren: Datum der
/// Zahlungserinnerung der ältesten Rechnung (nach Rechnungsdatum). Hat die
/// älteste keine vermerkte Erinnerung, gilt die früheste vermerkte
/// Erinnerung des Falls; `null`, wenn es gar keine gibt.
DateTime? zinsSeit(List<Rechnung> rechnungen) {
  if (rechnungen.isEmpty) return null;
  final sortiert = [...rechnungen]
    ..sort((a, b) => a.rechnungsdatum.compareTo(b.rechnungsdatum));
  final aelteste = sortiert.first.erinnerungAm;
  if (aelteste != null) return _tag(aelteste);
  final alle = rechnungen.map((r) => r.erinnerungAm).whereType<DateTime>().toList()
    ..sort();
  return alle.isEmpty ? null : _tag(alle.first);
}
