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
///
/// [anfangssaldo]/[schlusssaldo] sind bewusst nullable: OPBD/CLBD fehlen in
/// älteren Importen (produktiv bei 2 von 3 Zeilen NULL). Regeln, die Saldi
/// vergleichen, überspringen solche Dateien, statt 0 anzunehmen.
class CamtDateiInfo {
  final DateTime von, bis;
  final double? anfangssaldo, schlusssaldo;
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
/// Eine abgeschlossene Reinigung, zu der keine Ertragsbuchung existiert.
/// Am 03./04.09.2026 entstanden zwei solche Fälle, weil die Abschluss-Kette im
/// Browser abbrach — der Ertrag fehlte damit in der Erfolgsrechnung.
class UnverbuchteReinigung {
  final DateTime datum;
  final String betrieb;
  final double brutto;
  const UnverbuchteReinigung({
    required this.datum,
    required this.betrieb,
    required this.brutto,
  });
}

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
  final List<UnverbuchteReinigung> unverbuchteReinigungen;

  AbschlussKontext({
    required this.jahr,
    required this.heute,
    required this.buchungen,
    required this.konten,
    required this.camtDateien,
    required this.offeneRechnungen,
    required this.steuerbuchungenOhneJahr,
    required this.dokumentTypen,
    this.steuerjahrStatus = 'offen',
    required this.offeneRechnungenMitZahlung,
    this.unverbuchteReinigungen = const [],
  });

  bool get jahrAbgeschlossen => jahr < heute.year;

  /// «heute» ohne Uhrzeit — sonst hängen Stichtag und Quartalsgrenze davon ab,
  /// zu welcher Tageszeit die Prüfung läuft.
  DateTime get heuteDatum => DateTime(heute.year, heute.month, heute.day);

  /// Abgeschlossenes Jahr: 31.12.; laufendes Jahr: heute.
  DateTime get stichtag =>
      jahrAbgeschlossen ? DateTime(jahr, 12, 31) : heuteDatum;

  late final Map<int, double> saldi = saldiPer(stichtag);

  double saldo(int konto) => saldi[konto] ?? 0;

  final Map<DateTime, Map<int, double>> _saldiCache = {};

  /// Saldi per beliebigem Datum (mehrere Regeln fragen dieselben Stichtage ab).
  Map<int, double> saldiPer(DateTime d) => _saldiCache.putIfAbsent(
    d,
    () => BilanzService.saldiPerStichtag(buchungen, d),
  );

  /// Letzte camt-Datei, die vollständig bis [d] reicht (`bis <= d`).
  CamtDateiInfo? letzteCamtDateiBis(DateTime d) {
    CamtDateiInfo? l;
    for (final c in camtDateien) {
      if (!c.bis.isAfter(d) && (l == null || c.bis.isAfter(l.bis))) l = c;
    }
    return l;
  }

  /// camt-Datei, deren Zeitraum den Stichtag überspannt (`von <= d < bis`).
  /// Produktiv der Normalfall: ein einziger Export 09.08.2024–07.08.2026.
  CamtDateiInfo? camtDateiUeber(DateTime d) {
    for (final c in camtDateien) {
      if (!c.von.isAfter(d) && c.bis.isAfter(d)) return c;
    }
    return null;
  }

  /// Letztes Quartalsende ≤ Stichtag, das schon vollständig vor «heute» liegt.
  /// `DateTime(jahr, monat, 0)` ist der letzte Tag des Vormonats.
  DateTime letztesQuartalsende() {
    DateTime qEnde(DateTime x) =>
        DateTime(x.year, ((x.month - 1) ~/ 3) * 3 + 4, 0);
    var q = qEnde(stichtag);
    if (q.isAfter(stichtag) || !q.isBefore(heuteDatum)) {
      q = qEnde(DateTime(q.year, q.month - 3, 1));
    }
    return q;
  }
}

/// Regelbasierte Abschlussprüfung: führt alle Regeln aus und sortiert die
/// Befunde nach Dringlichkeit (rot → gelb → grün). Bei gleicher Ampel bleibt
/// die Reihenfolge aus [alleAbschlussRegeln] erhalten — `List.sort` ist nicht
/// stabil, deshalb der Tiebreak über den Regel-Index.
class AbschlussPruefService {
  static List<Pruefbefund> pruefe(AbschlussKontext k) {
    final regeln = alleAbschlussRegeln();
    final rang = {for (var i = 0; i < regeln.length; i++) regeln[i].id: i};
    final l = regeln.map((r) => r.pruefe(k)).toList();
    l.sort((a, b) {
      final s = a.status.index.compareTo(b.status.index);
      return s != 0 ? s : rang[a.regelId]!.compareTo(rang[b.regelId]!);
    });
    return l;
  }
}
