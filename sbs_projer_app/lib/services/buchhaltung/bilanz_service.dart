import 'saldo_expansion.dart';

/// Leichtgewichtige Buchungs-Eingabe für die reine Saldo-Berechnung.
class BuchungSaldo {
  final int sollKonto;
  final int habenKonto;
  final double betrag; // betragBrutto
  final DateTime datum;
  final bool storniert;
  final int? mwstKonto;
  final double? betragNetto; // null → = betrag (brutto)
  final double mwstBetrag;
  const BuchungSaldo({
    required this.sollKonto,
    required this.habenKonto,
    required this.betrag,
    required this.datum,
    required this.storniert,
    this.mwstKonto,
    this.betragNetto,
    this.mwstBetrag = 0,
  });
}

/// Konto-Stammdaten für die Gruppierung.
class KontoInfo {
  final int kontonummer;
  final String bezeichnung;
  final String kategorie;
  const KontoInfo({
    required this.kontonummer,
    required this.bezeichnung,
    required this.kategorie,
  });
}

/// Eine Zeile (Konto + Saldo) in einer Bilanz-Gruppe.
class BilanzPosten {
  final int kontonummer;
  final String bezeichnung;
  final double summe;
  const BilanzPosten(this.kontonummer, this.bezeichnung, this.summe);
}

/// Eine Gruppe (z. B. „Umlaufvermögen") mit ihren Posten + Gruppensumme.
class BilanzGruppe {
  final String titel;
  final List<BilanzPosten> posten;
  const BilanzGruppe(this.titel, this.posten);
  double get summe => posten.fold(0.0, (s, p) => s + p.summe);
}

/// Eine fertige Bilanz: Aktiven/Passiven als Gruppen + Summen + Differenz.
class BilanzDaten {
  final List<BilanzGruppe> aktiven;
  final List<BilanzGruppe> passiven;
  const BilanzDaten(this.aktiven, this.passiven);
  double get totalAktiven => aktiven.fold(0.0, (s, g) => s + g.summe);
  double get totalPassiven => passiven.fold(0.0, (s, g) => s + g.summe);
  double get differenz => totalAktiven - totalPassiven;
}

class BilanzService {
  // Reihenfolge der Aktiv-Gruppen (Konto-Kategorie = Gruppentitel).
  static const _aktivKategorien = ['Umlaufvermögen', 'Anlagevermögen'];

  // Reihenfolge der Passiv-Gruppen + welche Konto-Kategorien hineinfallen.
  static const _passivGruppen = <String, Set<String>>{
    'Kurzfristiges Fremdkapital': {
      'Kurzfristiges Fremdkapital',
      'Sozialversicherungen',
    },
    'Langfristiges Fremdkapital': {'Langfristiges Fremdkapital'},
    'Eigenkapital': {'Eigenkapital'},
  };

  /// Saldo je Konto per Stichtag: Σ Soll − Σ Haben (nur nicht-storniert,
  /// datum ≤ Stichtag). Vorzeichen wird erst in [gruppiere] seitenabhängig
  /// interpretiert.
  static Map<int, double> saldiPerStichtag(
      List<BuchungSaldo> buchungen, DateTime stichtag) {
    final saldi = <int, double>{};
    for (final b in buchungen) {
      if (b.storniert) continue;
      if (b.datum.isAfter(stichtag)) continue;
      SaldoExpansion.apply(
        saldi,
        sollKonto: b.sollKonto,
        habenKonto: b.habenKonto,
        mwstKonto: b.mwstKonto,
        betragNetto: b.betragNetto ?? b.betrag,
        mwstBetrag: b.mwstBetrag,
        betragBrutto: b.betrag,
      );
    }
    return saldi;
  }

  /// Kumuliertes Ergebnis = −Σ Roh-Saldo der Erfolgskonten (Klasse 3–8).
  /// Gewinn positiv. (Die ER-Konten laufen durch; das Ergebnis wird hieraus
  /// berechnet statt über Abschlussbuchungen.)
  static double kumuliertesErgebnis(Map<int, double> saldi) {
    double s = 0;
    saldi.forEach((konto, v) {
      final kl = konto ~/ 1000;
      if (kl >= 3 && kl <= 8) s += v;
    });
    return -s;
  }

  /// Komplette Bilanz per [stichtag]: Saldi bis Stichtag + EK-Split aus
  /// kumuliertem Ergebnis (Gewinnvortrag bis 31.12. Vorjahr, Jahresergebnis
  /// Jahresbeginn–Stichtag). Reine Funktion (testbar).
  static BilanzDaten erstelle(
    List<BuchungSaldo> buchungen,
    List<KontoInfo> konten,
    DateTime stichtag,
  ) {
    final saldiBis = saldiPerStichtag(buchungen, stichtag);
    final saldiVor = saldiPerStichtag(buchungen, DateTime(stichtag.year - 1, 12, 31));
    final resBis = kumuliertesErgebnis(saldiBis);
    final resVor = kumuliertesErgebnis(saldiVor);
    return gruppiere(
      saldiBis,
      konten,
      gewinnvortrag: resVor,
      jahresergebnis: resBis - resVor,
    );
  }

  /// Gruppiert die Saldi nach Bilanz-Abschnitten. Aktiven nehmen den Saldo
  /// (Soll−Haben) direkt; Passiven invertieren ihn (Haben−Soll). Posten mit
  /// Saldo 0 entfallen. [gewinnvortrag]/[jahresergebnis] werden als berechnete
  /// Eigenkapital-Posten angehängt (≠ 0).
  static BilanzDaten gruppiere(
    Map<int, double> saldi,
    List<KontoInfo> konten, {
    double gewinnvortrag = 0,
    double jahresergebnis = 0,
  }) {
    final byNr = {for (final k in konten) k.kontonummer: k};

    List<BilanzPosten> postenFuer(bool Function(String kat) match,
        {required bool invertieren}) {
      final result = <BilanzPosten>[];
      for (final entry in saldi.entries) {
        final k = byNr[entry.key];
        if (k == null || !match(k.kategorie)) continue;
        final summe = invertieren ? -entry.value : entry.value;
        if (summe == 0) continue;
        result.add(BilanzPosten(k.kontonummer, k.bezeichnung, summe));
      }
      result.sort((a, b) => a.kontonummer.compareTo(b.kontonummer));
      return result;
    }

    final aktiven = <BilanzGruppe>[];
    for (final kat in _aktivKategorien) {
      final posten = postenFuer((k) => k == kat, invertieren: false);
      if (posten.isNotEmpty) aktiven.add(BilanzGruppe(kat, posten));
    }

    final passiven = <BilanzGruppe>[];
    _passivGruppen.forEach((titel, kategorien) {
      final posten =
          postenFuer((k) => kategorien.contains(k), invertieren: true);
      if (titel == 'Eigenkapital') {
        if (gewinnvortrag != 0) {
          posten.add(BilanzPosten(2970, 'Gewinn-/Verlustvortrag', gewinnvortrag));
        }
        if (jahresergebnis != 0) {
          posten.add(BilanzPosten(2980, 'Jahresergebnis', jahresergebnis));
        }
      }
      if (posten.isNotEmpty) passiven.add(BilanzGruppe(titel, posten));
    });

    return BilanzDaten(aktiven, passiven);
  }
}
