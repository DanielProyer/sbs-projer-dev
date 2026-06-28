import 'bilanz_service.dart' show BuchungSaldo;
import 'saldo_expansion.dart';

/// Kurzbeschreibung der Haupt-Kontenklassen 3–8 (Schweizer KMU-Kontenrahmen),
/// für die kompakte Bildschirm-Darstellung.
const kontenklasseBeschreibung = <int, String>{
  3: 'Betriebsertrag',
  4: 'Materialaufwand',
  5: 'Personalaufwand',
  6: 'Übriger Aufwand, Abschreibungen & Finanzergebnis',
  7: 'Betrieblicher Nebenerfolg',
  8: 'Betriebsfremder & a.o. Erfolg, Steuern',
};

/// Ausführliche Beschreibung der Haupt-Kontenklassen 3–8 (offizielle
/// Bezeichnungen des Schweizer KMU-Kontenrahmens), für PDF/Berichte.
const kontenklasseBeschreibungDetail = <int, String>{
  3: 'Betrieblicher Ertrag aus Lieferungen und Leistungen',
  4: 'Aufwand für Material, Handelswaren, Dienstleistungen und Energie',
  5: 'Personalaufwand',
  6: 'Übriger betrieblicher Aufwand, Abschreibungen und Finanzergebnis',
  7: 'Betrieblicher Nebenerfolg',
  8: 'Betriebsfremder, ausserordentlicher und periodenfremder Aufwand und Ertrag sowie direkte Steuern',
};

/// Ergebnis der KMU-Stufengliederung.
class ErfolgsrechnungDaten {
  final double nettoerloes;
  final double materialaufwand;
  final double personalaufwand;
  final double uebrigerAufwand; // 6000–6799
  final double abschreibungen; // 6800–6899
  final double finanzerfolg; // 6900–6999, negativ wenn Aufwand überwiegt
  final double nebenerfolg; // Klasse 7 (Ertrag) − 8000–8899 (Aufwand)
  final double steuern; // 8900–8999
  const ErfolgsrechnungDaten({
    required this.nettoerloes,
    required this.materialaufwand,
    required this.personalaufwand,
    required this.uebrigerAufwand,
    required this.abschreibungen,
    required this.finanzerfolg,
    required this.nebenerfolg,
    required this.steuern,
  });

  double get bruttoergebnis1 => nettoerloes - materialaufwand;
  double get bruttoergebnis2 => bruttoergebnis1 - personalaufwand;
  double get ebitda => bruttoergebnis2 - uebrigerAufwand;
  double get ebit => ebitda - abschreibungen;
  double get ebt => ebit + finanzerfolg;
  double get jahresergebnis => ebt + nebenerfolg - steuern;
}

class ErfolgsrechnungService {
  /// Aufwand-Saldo (Soll−Haben) über einen Kontonummer-Bereich [von,bis].
  static double _aufwand(Map<int, double> sollMinusHaben, int von, int bis) {
    double s = 0;
    sollMinusHaben.forEach((nr, v) {
      if (nr >= von && nr <= bis) s += v;
    });
    return s;
  }

  static ErfolgsrechnungDaten berechne(
    List<BuchungSaldo> buchungen, {
    required DateTime von,
    required DateTime bis,
  }) {
    final shm = <int, double>{};
    for (final b in buchungen) {
      if (b.storniert || b.istGegenbuchung) continue;
      if (b.datum.isBefore(von) || b.datum.isAfter(bis)) continue;
      SaldoExpansion.apply(
        shm,
        sollKonto: b.sollKonto,
        habenKonto: b.habenKonto,
        mwstKonto: b.mwstKonto,
        betragNetto: b.betragNetto ?? b.betrag,
        mwstBetrag: b.mwstBetrag,
        betragBrutto: b.betrag,
      );
    }

    final nettoerloes = -_aufwand(shm, 3000, 3999);
    final material = _aufwand(shm, 4000, 4999);
    final personal = _aufwand(shm, 5000, 5999);
    final uebrig = _aufwand(shm, 6000, 6799);
    final abschreib = _aufwand(shm, 6800, 6899);
    final finanzAufwand = _aufwand(shm, 6900, 6999);
    final nebenErtrag = -_aufwand(shm, 7000, 7999);
    final nebenAufwand = _aufwand(shm, 8000, 8899);
    final steuern = _aufwand(shm, 8900, 8999);

    return ErfolgsrechnungDaten(
      nettoerloes: nettoerloes,
      materialaufwand: material,
      personalaufwand: personal,
      uebrigerAufwand: uebrig,
      abschreibungen: abschreib,
      finanzerfolg: -finanzAufwand,
      nebenerfolg: nebenErtrag - nebenAufwand,
      steuern: steuern,
    );
  }

  /// Konten-Aufstellung je Klasse 3–8 über [von,bis]. Vorzeichen: Ertragsklassen
  /// (3,7) positiv = Ertrag (−Saldo), Aufwandsklassen (4,5,6,8) positiv = Aufwand.
  static ErKontenAufstellung kontenAufstellung(
    List<BuchungSaldo> buchungen, {
    required DateTime von,
    required DateTime bis,
  }) {
    final shm = <int, double>{};
    for (final b in buchungen) {
      if (b.storniert || b.istGegenbuchung) continue;
      if (b.datum.isBefore(von) || b.datum.isAfter(bis)) continue;
      SaldoExpansion.apply(
        shm,
        sollKonto: b.sollKonto,
        habenKonto: b.habenKonto,
        mwstKonto: b.mwstKonto,
        betragNetto: b.betragNetto ?? b.betrag,
        mwstBetrag: b.mwstBetrag,
        betragBrutto: b.betrag,
      );
    }

    final byKlasse = <int, List<ErKonto>>{};
    shm.forEach((nr, net) {
      final kl = nr ~/ 1000;
      if (kl < 3 || kl > 8) return;
      final ertragsklasse = kl == 3 || kl == 7;
      final summe = ertragsklasse ? -net : net;
      if (summe == 0) return;
      (byKlasse[kl] ??= []).add(ErKonto(nr, summe));
    });

    final klassen = <ErKlasse>[];
    for (final kl in [3, 4, 5, 6, 7, 8]) {
      final konten = byKlasse[kl];
      if (konten == null || konten.isEmpty) continue;
      konten.sort((a, b) => a.nr.compareTo(b.nr));
      klassen.add(ErKlasse(kl, konten));
    }
    return ErKontenAufstellung(klassen);
  }
}

class ErKonto {
  final int nr;
  final String? bezeichnung; // im Service null, Provider füllt
  final double summe;
  const ErKonto(this.nr, this.summe, {this.bezeichnung});
  ErKonto withBezeichnung(String b) => ErKonto(nr, summe, bezeichnung: b);
}

class ErKlasse {
  final int klasse;
  final List<ErKonto> konten;
  const ErKlasse(this.klasse, this.konten);
  double get summe => konten.fold(0.0, (s, k) => s + k.summe);
}

class ErKontenAufstellung {
  final List<ErKlasse> klassen;
  const ErKontenAufstellung(this.klassen);
  double get nettoerloes {
    for (final k in klassen) {
      if (k.klasse == 3) return k.summe;
    }
    return 0;
  }
}
