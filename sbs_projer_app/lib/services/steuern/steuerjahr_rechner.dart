import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';

enum SteuerAmpel { ausgeglichen, schuld, guthaben }

/// Eine Steuerart im Soll/Ist-Vergleich eines Jahres.
class SollIstZeile {
  final String steuerart;
  final double? provisorisch;
  final double? definitiv;
  /// Netto aus `view_steuerjahr_zahlungen` (Zahlungen positiv, Rückzahlungen negativ).
  final double bezahlt;
  const SollIstZeile({required this.steuerart, this.provisorisch, this.definitiv, required this.bezahlt});
  bool get istProvisorisch => definitiv == null;
  double get soll => definitiv ?? provisorisch ?? 0;
  /// > 0 = noch geschuldet, < 0 = Guthaben.
  double get offen => _r(soll - bezahlt);
}

class SollIst {
  final List<SollIstZeile> zeilen;
  const SollIst(this.zeilen);
  SollIstZeile zeile(String art) => zeilen.firstWhere((z) => z.steuerart == art,
      orElse: () => SollIstZeile(steuerart: art, bezahlt: 0));
  double get totalDefinitiv => _r(zeilen.fold(0.0, (s, z) => s + (z.definitiv ?? 0)));
  double get totalBezahlt => _r(zeilen.fold(0.0, (s, z) => s + z.bezahlt));
  double get totalOffen => _r(zeilen.fold(0.0, (s, z) => s + z.offen));
  SteuerAmpel get ampel {
    if (totalOffen.abs() <= 0.05) return SteuerAmpel.ausgeglichen;
    return totalOffen > 0 ? SteuerAmpel.schuld : SteuerAmpel.guthaben;
  }
}

class Dossier {
  final int total;
  final int vorhanden;
  final List<String> fehlend;
  const Dossier({required this.total, required this.vorhanden, required this.fehlend});
}

double _r(double v) => (v * 100).roundToDouble() / 100;

class SteuerjahrRechner {
  /// [bezahlt] je Steuerart (`bund`, `kanton`, `busse`, `mwst`, ggf. `unbekannt`).
  /// Bund/Kanton: Soll aus der Veranlagung. Busse/MWST/unbekannt: kein
  /// eigenes Soll — definitiv = bezahlt, damit nie «offen» entsteht, der
  /// Betrag aber sichtbar bleibt und in `totalBezahlt` zählt.
  static SollIst sollIst({required Steuerjahr jahr, required Map<String, double> bezahlt}) {
    final zeilen = [
      SollIstZeile(steuerart: 'bund', provisorisch: jahr.bundProvisorisch, definitiv: jahr.bundDefinitiv, bezahlt: bezahlt['bund'] ?? 0),
      SollIstZeile(steuerart: 'kanton', provisorisch: jahr.kantonProvisorisch, definitiv: jahr.kantonDefinitiv, bezahlt: bezahlt['kanton'] ?? 0),
      SollIstZeile(steuerart: 'busse', definitiv: bezahlt['busse'] ?? 0, bezahlt: bezahlt['busse'] ?? 0),
      SollIstZeile(steuerart: 'mwst', definitiv: bezahlt['mwst'] ?? 0, bezahlt: bezahlt['mwst'] ?? 0),
    ];
    for (final e in bezahlt.entries) {
      if (!const {'bund', 'kanton', 'busse', 'mwst'}.contains(e.key)) {
        zeilen.add(SollIstZeile(steuerart: e.key, definitiv: e.value, bezahlt: e.value));
      }
    }
    return SollIst(zeilen);
  }

  /// [vorhanden]: (typ, kategorie) der Dokumente des Jahres.
  static Dossier dossier({required int jahr, required DateTime heute, required List<(String, String?)> vorhanden}) {
    final pflicht = pflichtTypen(jahr: jahr, heute: heute);
    final fehlend = <String>[];
    for (final p in pflicht) {
      final teile = p.split(':');
      final ok = vorhanden.any((v) => v.$1 == teile[0] && (teile.length == 1 || v.$2 == teile[1]));
      if (!ok) fehlend.add(p);
    }
    return Dossier(total: pflicht.length, vorhanden: pflicht.length - fehlend.length, fehlend: fehlend);
  }
}
