import 'package:sbs_projer_app/core/util/rundung.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/buchhaltung/bilanz_service.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

enum SteuerAmpel { ausgeglichen, schuld, guthaben }

/// Frühestes Jahr, für das die App Steuerjahre führt.
const int kSteuerJahrAb = 2019;

/// Saldo-Buchungen nach Kalenderjahr bündeln, damit die Erfolgsrechnung je
/// Jahr nur ihre eigenen Zeilen sieht — sonst läuft die Übersicht die
/// Gesamtliste einmal pro Jahr durch (O(n·Jahre) statt O(n)).
Map<int, List<BuchungSaldo>> gruppiereNachJahr(List<BuchungSaldo> saldi) {
  final jeJahr = <int, List<BuchungSaldo>>{};
  for (final b in saldi) {
    (jeJahr[b.datum.year] ??= []).add(b);
  }
  return jeJahr;
}

/// Eine Steuerart im Soll/Ist-Vergleich eines Jahres.
class SollIstZeile {
  final String steuerart;
  final double? provisorisch;
  final double? definitiv;

  /// Netto aus `view_steuerjahr_zahlungen` (Zahlungen positiv, Rückzahlungen negativ).
  final double bezahlt;
  const SollIstZeile({
    required this.steuerart,
    this.provisorisch,
    this.definitiv,
    required this.bezahlt,
  });
  bool get istProvisorisch => definitiv == null;

  /// Ob für diese Zeile überhaupt ein Soll bekannt ist (Veranlagung/Rechnung
  /// erfasst) — false bedeutet «offen» ist nicht aussagekräftig, weil das
  /// Soll schlicht fehlt statt bei 0 zu liegen.
  bool get sollErfasst => definitiv != null || provisorisch != null;
  double get soll => definitiv ?? provisorisch ?? 0;

  /// > 0 = noch geschuldet, < 0 = Guthaben.
  double get offen => rundeAufRappen(soll - bezahlt);
}

class SollIst {
  final List<SollIstZeile> zeilen;
  const SollIst(this.zeilen);
  SollIstZeile zeile(String art) => zeilen.firstWhere(
    (z) => z.steuerart == art,
    orElse: () => SollIstZeile(steuerart: art, bezahlt: 0),
  );

  Iterable<SollIstZeile> get _bundKanton =>
      zeilen.where((z) => z.steuerart == 'bund' || z.steuerart == 'kanton');

  /// Nur «Steuern definitiv (Bund + Kanton)» — Busse/MWST/Sonstiges haben
  /// kein separates Veranlagungs-Soll und würden die Summe sonst verwässern.
  double get totalDefinitiv =>
      rundeAufRappen(_bundKanton.fold(0.0, (s, z) => s + (z.definitiv ?? 0)));

  /// Wie [totalDefinitiv], aber null, solange weder für Bund noch Kanton eine
  /// Veranlagung erfasst ist — sonst zeigten Screens eine 0.00, die wie
  /// «keine Steuern geschuldet» aussieht statt wie «noch nicht veranlagt».
  /// Ein erfasstes `definitiv: 0` bleibt eine echte 0.
  double? get totalDefinitivOderNull =>
      _bundKanton.any((z) => z.definitiv != null) ? totalDefinitiv : null;
  double get totalBezahlt =>
      rundeAufRappen(zeilen.fold(0.0, (s, z) => s + z.bezahlt));
  double get totalOffen =>
      rundeAufRappen(zeilen.fold(0.0, (s, z) => s + z.offen));
  SteuerAmpel get ampel {
    if (totalOffen.abs() <= 0.05) return SteuerAmpel.ausgeglichen;
    return totalOffen > 0 ? SteuerAmpel.schuld : SteuerAmpel.guthaben;
  }

  /// True, wenn Geld für Bund oder Kanton geflossen ist, aber noch keine
  /// Veranlagung/Rechnung erfasst wurde — Screens zeigen dann «Veranlagung
  /// fehlt» statt eines (irreführenden) blauen Guthaben-Punkts.
  bool get sollUnvollstaendig =>
      _bundKanton.any((z) => z.bezahlt != 0 && !z.sollErfasst);
}

class Dossier {
  final int total;
  final int vorhanden;
  final List<String> fehlend;
  const Dossier({
    required this.total,
    required this.vorhanden,
    required this.fehlend,
  });
}

class SteuerjahrRechner {
  /// [bezahlt] je Steuerart (`bund`, `kanton`, `busse`, `mwst`, ggf. `unbekannt`).
  /// Bund/Kanton: Soll aus der Veranlagung. Busse/MWST/unbekannt: kein
  /// eigenes Soll — definitiv = bezahlt, damit nie «offen» entsteht, der
  /// Betrag aber sichtbar bleibt und in `totalBezahlt` zählt.
  static SollIst sollIst({
    required Steuerjahr jahr,
    required Map<String, double> bezahlt,
  }) {
    final zeilen = [
      SollIstZeile(
        steuerart: 'bund',
        provisorisch: jahr.bundProvisorisch,
        definitiv: jahr.bundDefinitiv,
        bezahlt: bezahlt['bund'] ?? 0,
      ),
      SollIstZeile(
        steuerart: 'kanton',
        provisorisch: jahr.kantonProvisorisch,
        definitiv: jahr.kantonDefinitiv,
        bezahlt: bezahlt['kanton'] ?? 0,
      ),
      SollIstZeile(
        steuerart: 'busse',
        definitiv: bezahlt['busse'] ?? 0,
        bezahlt: bezahlt['busse'] ?? 0,
      ),
      SollIstZeile(
        steuerart: 'mwst',
        definitiv: bezahlt['mwst'] ?? 0,
        bezahlt: bezahlt['mwst'] ?? 0,
      ),
    ];
    final zusatzSchluessel =
        bezahlt.keys.where((k) => !steuerarten.containsKey(k)).toList()..sort();
    for (final k in zusatzSchluessel) {
      zeilen.add(
        SollIstZeile(steuerart: k, definitiv: bezahlt[k], bezahlt: bezahlt[k]!),
      );
    }
    return SollIst(zeilen);
  }

  /// [vorhanden]: (typ, kategorie) der Dokumente des Jahres.
  static Dossier dossier({
    required int jahr,
    required DateTime heute,
    required List<(String, String?)> vorhanden,
  }) {
    final pflicht = pflichtTypen(jahr: jahr, heute: heute);
    final fehlend = <String>[];
    for (final p in pflicht) {
      final teile = p.split(':');
      final ok = vorhanden.any(
        (v) => v.$1 == teile[0] && (teile.length == 1 || v.$2 == teile[1]),
      );
      if (!ok) fehlend.add(p);
    }
    return Dossier(
      total: pflicht.length,
      vorhanden: pflicht.length - fehlend.length,
      fehlend: fehlend,
    );
  }
}
