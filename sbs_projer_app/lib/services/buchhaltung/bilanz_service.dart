/// Leichtgewichtige Buchungs-Eingabe für die reine Saldo-Berechnung.
class BuchungSaldo {
  final int sollKonto;
  final int habenKonto;
  final double betrag; // betragBrutto
  final DateTime datum;
  final bool storniert;
  const BuchungSaldo({
    required this.sollKonto,
    required this.habenKonto,
    required this.betrag,
    required this.datum,
    required this.storniert,
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
      saldi[b.sollKonto] = (saldi[b.sollKonto] ?? 0) + b.betrag;
      saldi[b.habenKonto] = (saldi[b.habenKonto] ?? 0) - b.betrag;
    }
    return saldi;
  }

  /// Gruppiert die Saldi nach Bilanz-Abschnitten. Aktiven nehmen den Saldo
  /// (Soll−Haben) direkt; Passiven invertieren ihn (Haben−Soll). Posten mit
  /// Saldo 0 entfallen.
  static BilanzDaten gruppiere(
      Map<int, double> saldi, List<KontoInfo> konten) {
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
      if (posten.isNotEmpty) passiven.add(BilanzGruppe(titel, posten));
    });

    return BilanzDaten(aktiven, passiven);
  }
}
