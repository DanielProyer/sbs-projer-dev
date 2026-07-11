/// Datenmodell der Buchhaltungs-Auswertung (Umsatz/Arbeiten nach Jahr+Monat).
///
/// Alle Beträge werden pro Posten sowohl netto als auch brutto geführt, damit
/// der Screen ohne Neuberechnung zwischen netto/brutto umschalten kann.
library;

/// Kategorien wie im Excel-Blatt „Auswertung".
enum AuswertungKategorie {
  reinigung, // Kunden-Reinigung (Betrieb ≠ heineken)
  reinigungHk, // Reinigung bei Heineken-Betrieb (rechnungsstellung == 'heineken')
  stoerung,
  eigenauftrag,
  eroeffnung, // Eröffnung + Endreinigung
  montage,
  pikett,
  bkPauschale, // Bergkunden-Pauschale
}

/// Kategorien, die in die Heineken-Monatsrechnung („Rechnung HK") fliessen.
const Set<AuswertungKategorie> heinekenKategorien = {
  AuswertungKategorie.reinigungHk,
  AuswertungKategorie.stoerung,
  AuswertungKategorie.eigenauftrag,
  AuswertungKategorie.eroeffnung,
  AuswertungKategorie.montage,
  AuswertungKategorie.pikett,
  AuswertungKategorie.bkPauschale,
};

/// Ein normalisierter Arbeitsposten (netto UND brutto bereits aufbereitet).
class ArbeitsPosten {
  final AuswertungKategorie kategorie;
  final int jahr;
  final int monat; // 1..12
  final double netto;
  final double brutto;
  const ArbeitsPosten(
    this.kategorie,
    this.jahr,
    this.monat,
    this.netto,
    this.brutto,
  );
}

/// Aggregierter Wert einer Kategorie (Anzahl + Netto + Brutto).
class KategorieWert {
  final int anzahl;
  final double netto;
  final double brutto;
  const KategorieWert(this.anzahl, this.netto, this.brutto);

  KategorieWert plus(double n, double b) =>
      KategorieWert(anzahl + 1, netto + n, brutto + b);

  static const leer = KategorieWert(0, 0, 0);
}

/// Werte eines Monats (monat 0 = Jahres-Aggregat).
class MonatsWerte {
  final int jahr;
  final int monat;
  final Map<AuswertungKategorie, KategorieWert> kategorien;
  const MonatsWerte(this.jahr, this.monat, this.kategorien);

  KategorieWert kat(AuswertungKategorie k) =>
      kategorien[k] ?? KategorieWert.leer;

  int get anzahlGesamt =>
      kategorien.values.fold(0, (s, w) => s + w.anzahl);

  double _betrag(AuswertungKategorie k, bool brutto) =>
      brutto ? kat(k).brutto : kat(k).netto;

  /// Kunden-Reinigung (nur reguläre Reinigung).
  double reinigungKunde(bool brutto) =>
      _betrag(AuswertungKategorie.reinigung, brutto);

  /// Heineken-Monatsrechnung = Summe aller HK-Kategorien.
  double rechnungHk(bool brutto) =>
      heinekenKategorien.fold(0.0, (s, k) => s + _betrag(k, brutto));

  /// Total = Kunde + Heineken.
  double total(bool brutto) => reinigungKunde(brutto) + rechnungHk(brutto);
}
