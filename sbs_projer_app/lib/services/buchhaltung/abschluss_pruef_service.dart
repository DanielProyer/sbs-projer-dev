import 'package:sbs_projer_app/services/buchhaltung/abschluss_regeln.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';

/// Ampel einer Abschlussprüfung. Reihenfolge = Sortier-Reihenfolge im Screen.
enum PruefStatus { rot, gelb, gruen }

/// Ergebnis einer einzelnen Regel.
class Pruefbefund {
  final String regelId, gruppe, titel, ist, soll, hinweis;
  final PruefStatus status;
  final String? aktionRoute;
  const Pruefbefund({
    required this.regelId,
    required this.gruppe,
    required this.status,
    required this.titel,
    this.ist = '',
    this.soll = '',
    this.hinweis = '',
    this.aktionRoute,
  });
}

/// Zeitraum + Saldi einer importierten camt-Datei.
class CamtDateiInfo {
  final DateTime von, bis;
  final double anfangssaldo, schlusssaldo;
  const CamtDateiInfo({
    required this.von,
    required this.bis,
    required this.anfangssaldo,
    required this.schlusssaldo,
  });
}

/// Eine noch offene Kundenrechnung (für Verjährung/Delkredere).
class OffeneRechnungInfo {
  final String id;
  final DateTime datum;
  final double brutto;
  const OffeneRechnungInfo({
    required this.id,
    required this.datum,
    required this.brutto,
  });
}

/// Alles, was die Regeln brauchen — vorab geladen, damit die Regeln rein bleiben.
class AbschlussKontext {
  final int jahr;
  final DateTime heute;
  final List<BuchungSaldo> buchungen;
  final List<KontoInfo> konten;
  final List<CamtDateiInfo> camtDateien;
  final List<OffeneRechnungInfo> offeneRechnungen;
  final int steuerbuchungenOhneJahr;
  final Set<String> dokumentTypen;
  final String steuerjahrStatus;
  final Set<String> offeneRechnungenMitZahlung;
  late final Map<int, double> saldi = BilanzService.saldiPerStichtag(
    buchungen,
    stichtag,
  );

  AbschlussKontext({
    required this.jahr,
    required this.heute,
    required this.buchungen,
    required this.konten,
    required this.camtDateien,
    required this.offeneRechnungen,
    required this.steuerbuchungenOhneJahr,
    required this.dokumentTypen,
    required this.steuerjahrStatus,
    required this.offeneRechnungenMitZahlung,
  });

  bool get jahrAbgeschlossen => jahr < heute.year;

  /// Abgeschlossenes Jahr: 31.12.; laufendes Jahr: heute (Datum ohne Uhrzeit).
  DateTime get stichtag => jahrAbgeschlossen
      ? DateTime(jahr, 12, 31)
      : DateTime(heute.year, heute.month, heute.day);

  double saldo(int konto) => saldi[konto] ?? 0;

  Map<int, double> saldiPer(DateTime d) =>
      BilanzService.saldiPerStichtag(buchungen, d);

  CamtDateiInfo? letzteCamtDateiBis(DateTime d) {
    CamtDateiInfo? l;
    for (final c in camtDateien) {
      if (!c.bis.isAfter(d) && (l == null || c.bis.isAfter(l.bis))) l = c;
    }
    return l;
  }

  /// Letztes Quartalsende ≤ Stichtag, das schon vollständig vor «heute» liegt.
  /// `DateTime(jahr, monat, 0)` ist der letzte Tag des Vormonats.
  DateTime letztesQuartalsende() {
    DateTime qEnde(DateTime x) =>
        DateTime(x.year, ((x.month - 1) ~/ 3) * 3 + 4, 0);
    var q = qEnde(stichtag);
    if (q.isAfter(stichtag) || !q.isBefore(heute)) {
      q = qEnde(DateTime(q.year, q.month - 3, 1));
    }
    return q;
  }
}

/// Regelbasierte Abschlussprüfung: führt alle Regeln aus und sortiert die
/// Befunde nach Dringlichkeit (rot → gelb → grün).
class AbschlussPruefService {
  static List<Pruefbefund> pruefe(AbschlussKontext k) {
    final l = alleAbschlussRegeln().map((r) => r.pruefe(k)).toList();
    l.sort((a, b) => a.status.index.compareTo(b.status.index));
    return l;
  }
}
