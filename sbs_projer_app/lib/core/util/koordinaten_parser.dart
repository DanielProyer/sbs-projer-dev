/// Koordinaten aus einer Texteingabe lesen — reine Funktionen, ohne IO.
///
/// Zweck (Daniel 11.08.2026): Standpositionen lassen sich am PC direkt
/// eintippen oder aus Google Maps einfügen, statt sie nur auf der Karte zu
/// setzen. Google Maps liefert beim «Koordinaten kopieren» das Format
/// `46.849994916702336, 9.532274794958706`; kopiert man stattdessen die
/// Adresszeile, steckt dasselbe in einer URL (`/@46.85,9.53,19z` oder
/// `?q=46.85,9.53`). Beide Wege sollen funktionieren.
library;

typedef Koordinaten = ({double lat, double lng});

/// Erste zwei Dezimalzahlen aus [text] als Breite/Länge.
/// `null`, wenn nichts Brauchbares drinsteht oder die Werte ausserhalb des
/// gültigen Bereichs liegen (Breite ±90, Länge ±180).
Koordinaten? koordinatenAus(String text) {
  final treffer = RegExp(r'-?\d+[.,]\d+').allMatches(text).toList();
  if (treffer.length < 2) return null;

  double? zahl(int i) =>
      double.tryParse(treffer[i].group(0)!.replaceAll(',', '.'));

  final lat = zahl(0);
  final lng = zahl(1);
  if (lat == null || lng == null) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return (lat: lat, lng: lng);
}

/// Grober Rahmen um die Schweiz (inkl. Liechtenstein und etwas Rand).
///
/// Nur für eine Warnung gedacht, nicht als Sperre: Der häufigste Tippfehler
/// ist die vertauschte Reihenfolge — `9.53, 46.85` landet in Nigeria statt in
/// Chur, und das fällt auf einer weit herausgezoomten Karte kaum auf.
bool istInDerSchweiz(double lat, double lng) =>
    lat >= 45.7 && lat <= 47.9 && lng >= 5.8 && lng <= 10.6;

/// Anzeigeform mit sechs Nachkommastellen (~10 cm) — mehr ist bei einer
/// Standposition Scheingenauigkeit.
String koordinatenText(double lat, double lng) =>
    '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
