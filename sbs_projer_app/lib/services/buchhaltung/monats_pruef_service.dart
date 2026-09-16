import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/services/buchhaltung/abschluss_pruef_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/monats_regeln.dart';

/// Was eine Monatsregel zum Prüfen braucht — einmal geladen, nicht je Regel.
///
/// WARUM `Einsatz` statt der Isar-Modelle: Die abgeleitete Lage aus B2
/// (`einsatz_lage.dart`) beantwortet vier der zehn Regeln direkt — «offen»,
/// «erledigt», «verrechnet» stehen dort schon —, und ein `Einsatz` lässt
/// sich im Test mit einem Konstruktor bauen. Was sich daraus nicht ablesen
/// lässt (Zahlungsart, Heineken-Status, Bankdeckung), liegt als schlanker
/// Wert daneben.
class MonatsKontext {
  final int jahr, monat;
  final DateTime heute;

  /// Alle Einsätze des Monats — Reinigungen, Störungen, Montagen.
  final List<Einsatz> einsaetze;

  /// Reinigungen des Monats mit Zahlungsart «Rechnung per Mail», deren
  /// Rechnung noch auf «offen» steht (Versandvermerk fehlt).
  final int mailRechnungenOffen;

  /// `zahlungsstatus` der Heineken-Monatsrechnung; `null` = keine Rechnung.
  final String? heinekenStatus;

  /// Tage mit mindestens einer abgeschlossenen Reinigung bei einem
  /// Bergkunden, als `betriebId|yyyy-MM-dd` — die Pauschale gilt pro Betrieb
  /// und Tag, nicht pro Anlage (180 CHF je Besuch).
  final Set<String> bergTage;

  /// Dieselben Schlüssel, für die eine Pauschale erfasst ist.
  final Set<String> pauschalenTage;

  /// Von–bis jeder importierten camt-Datei.
  final List<({DateTime von, DateTime bis})> camtDeckung;

  /// Offene Prüflisten-Einträge mit Buchungsdatum im Monat.
  final int offenePrueflisteImMonat;

  /// Monate des Jahres, für die eine Lohnabrechnung existiert.
  final Set<int> lohnMonate;

  const MonatsKontext({
    required this.jahr,
    required this.monat,
    required this.heute,
    required this.einsaetze,
    required this.mailRechnungenOffen,
    required this.heinekenStatus,
    required this.bergTage,
    required this.pauschalenTage,
    required this.camtDeckung,
    required this.offenePrueflisteImMonat,
    required this.lohnMonate,
  });

  DateTime get von => DateTime(jahr, monat, 1);

  /// Tag 0 des Folgemonats ist der letzte Tag dieses Monats — deckt auch
  /// Februar und Schaltjahre ab.
  DateTime get bis => DateTime(jahr, monat + 1, 0);

  bool get istLaufenderMonat => heute.year == jahr && heute.month == monat;

  /// Einsätze eines Typs.
  List<Einsatz> vomTyp(EinsatzTyp t) =>
      einsaetze.where((e) => e.typ == t).toList();

  /// Der Monatsname für Titel und Hinweise.
  String get monatName => monatsName(monat);
}

/// Monatsname 1–12. Freistehend, damit auch der Detektor ihn nutzen kann,
/// ohne einen ganzen Kontext zu bauen.
String monatsName(int monat) => const [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
][monat - 1];

/// Eine Regel des Monatsabschlusses. Gleicher Schnitt wie `AbschlussRegel`
/// der Jahresprüfung — dieselbe `Pruefbefund`-Ausgabe, damit Screen und
/// Zählung wiederverwendbar bleiben.
abstract class MonatsRegel {
  String get id;
  String get gruppe;
  String get titel;
  Pruefbefund pruefe(MonatsKontext k);

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

  /// Was erst am Monatsende fällig ist, meldet im laufenden Monat gelb
  /// statt rot — sonst stünde der laufende Monat immer auf Alarm.
  Pruefbefund? laeuftNoch(MonatsKontext k, {String? route}) =>
      k.istLaufenderMonat
      ? befund(PruefStatus.gelb, hinweis: 'Monat läuft noch.', route: route)
      : null;
}

/// Prüft den Monat: erst nach Status (rot, gelb, grün), dann nach der
/// Reihenfolge in `alleMonatsRegeln()`.
List<Pruefbefund> pruefeMonat(MonatsKontext k) {
  final regeln = alleMonatsRegeln();
  final rang = {for (var i = 0; i < regeln.length; i++) regeln[i].id: i};
  final l = regeln.map((r) => r.pruefe(k)).toList();
  l.sort((a, b) {
    final s = a.status.index.compareTo(b.status.index);
    return s != 0 ? s : rang[a.regelId]!.compareTo(rang[b.regelId]!);
  });
  return l;
}
