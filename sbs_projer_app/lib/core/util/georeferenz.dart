/// Georeferenzierung eines Lageplan-Bilds über Passpunkte — reine Mathematik,
/// ohne IO (Wunsch Daniel 13.08.2026: «jpg mit 2–5 Punkten auf die Karte
/// referenzieren», Fall Openair Gampel).
///
/// Ein Passpunkt verbindet einen Bildpixel (px, py — y nach unten) mit dem
/// zugehörigen Ort auf der Karte (lat, lng). Aus 2 Punkten entsteht eine
/// Ähnlichkeitstransformation (verschieben, drehen, gleichmässig skalieren);
/// ab 3 Punkten eine affine Ausgleichung, die auch verzerrte «grobe» Pläne
/// abbildet (unterschiedliche Achsen-Massstäbe, Scherung). Bei mehr Punkten
/// als nötig wird nach kleinsten Quadraten ausgeglichen, und [residuenMeter]
/// zeigt pro Punkt, wie gut er passt — der grösste Wert entlarvt einen
/// falsch gesetzten Punkt.
///
/// Gerechnet wird in einem lokalen Meter-System um den Schwerpunkt der
/// Kartenpunkte; auf Festgelände-Grösse (< 1 km) ist die Erdkrümmung darin
/// bedeutungslos. Bild-y wird intern gespiegelt (Pixel wachsen nach unten,
/// Nord nach oben), damit die 2-Punkt-Lösung ohne Spiegelung auskommt.
library;

import 'dart:math';

typedef Passpunkt = ({double px, double py, double lat, double lng});

typedef Kartenpunkt = ({double lat, double lng});

/// Meter je Grad Breite (WGS84-Äquatorradius · π/180).
const double _mProGradLat = 111319.49079327358;

class Georeferenz {
  // Affine Abbildung (u, v) → (Ost, Nord) in Metern, mit u = px, v = -py.
  final double _a11, _a12, _a21, _a22, _tE, _tN;
  final double _lat0, _lng0, _mLng;

  /// Abweichung jedes Passpunkts in Metern (Reihenfolge der Eingabe).
  final List<double> residuenMeter;

  /// Quadratisches Mittel der Abweichungen — die eine Qualitätszahl.
  final double rmsMeter;

  const Georeferenz._(this._a11, this._a12, this._a21, this._a22, this._tE,
      this._tN, this._lat0, this._lng0, this._mLng,
      {required this.residuenMeter, required this.rmsMeter});

  /// `null`, wenn die Punkte keine Transformation tragen: weniger als zwei,
  /// deckungsgleich oder (ab drei) alle auf einer Linie.
  static Georeferenz? berechne(List<Passpunkt> punkte) {
    if (punkte.length < 2) return null;

    // Lokales Meter-System um den Schwerpunkt der Kartenpunkte.
    final lat0 =
        punkte.map((p) => p.lat).reduce((a, b) => a + b) / punkte.length;
    final lng0 =
        punkte.map((p) => p.lng).reduce((a, b) => a + b) / punkte.length;
    final mLng = _mProGradLat * cos(lat0 * pi / 180);

    final u = [for (final p in punkte) p.px];
    final v = [for (final p in punkte) -p.py]; // y-Flip
    final e = [for (final p in punkte) (p.lng - lng0) * mLng];
    final nord = [for (final p in punkte) (p.lat - lat0) * _mProGradLat];

    final n = punkte.length;
    final um = u.reduce((a, b) => a + b) / n;
    final vm = v.reduce((a, b) => a + b) / n;
    final em = e.reduce((a, b) => a + b) / n;
    final nm = nord.reduce((a, b) => a + b) / n;

    double a11, a12, a21, a22, tE, tN;

    if (n == 2) {
      // Ähnlichkeit (Helmert): E = a·u − b·v + tE, N = b·u + a·v + tN.
      double d = 0, sa = 0, sb = 0;
      for (var i = 0; i < n; i++) {
        final du = u[i] - um, dv = v[i] - vm;
        final de = e[i] - em, dn = nord[i] - nm;
        d += du * du + dv * dv;
        sa += du * de + dv * dn;
        sb += du * dn - dv * de;
      }
      if (d < 1e-9) return null; // Bildpunkte deckungsgleich
      final a = sa / d, b = sb / d;
      if (a * a + b * b < 1e-18) return null; // Kartenpunkte deckungsgleich
      a11 = a;
      a12 = -b;
      a21 = b;
      a22 = a;
      tE = em - a * um + b * vm;
      tN = nm - b * um - a * vm;
    } else {
      // Affin nach kleinsten Quadraten: zwei unabhängige Ausgleichungen mit
      // derselben (zentrierten) Designmatrix.
      double suu = 0, svv = 0, suv = 0;
      double sue = 0, sve = 0, sun = 0, svn = 0;
      for (var i = 0; i < n; i++) {
        final du = u[i] - um, dv = v[i] - vm;
        suu += du * du;
        svv += dv * dv;
        suv += du * dv;
        sue += du * (e[i] - em);
        sve += dv * (e[i] - em);
        sun += du * (nord[i] - nm);
        svn += dv * (nord[i] - nm);
      }
      final det = suu * svv - suv * suv;
      // Kollinear (oder fast): Ebene nicht bestimmbar.
      if (det <= 1e-6 * pow(suu + svv, 2)) return null;
      a11 = (sue * svv - sve * suv) / det;
      a12 = (sve * suu - sue * suv) / det;
      a21 = (sun * svv - svn * suv) / det;
      a22 = (svn * suu - sun * suv) / det;
      tE = em - a11 * um - a12 * vm;
      tN = nm - a21 * um - a22 * vm;
    }

    // Residuen: wie weit liegt jeder transformierte Passpunkt daneben?
    final residuen = <double>[];
    var quadratsumme = 0.0;
    for (var i = 0; i < n; i++) {
      final de = a11 * u[i] + a12 * v[i] + tE - e[i];
      final dn = a21 * u[i] + a22 * v[i] + tN - nord[i];
      final r = sqrt(de * de + dn * dn);
      residuen.add(r);
      quadratsumme += r * r;
    }

    return Georeferenz._(a11, a12, a21, a22, tE, tN, lat0, lng0, mLng,
        residuenMeter: List.unmodifiable(residuen),
        rmsMeter: sqrt(quadratsumme / n));
  }

  /// Bildpixel → Kartenposition.
  Kartenpunkt bildZuKarte(double px, double py) {
    final u = px, v = -py;
    final ost = _a11 * u + _a12 * v + _tE;
    final nord = _a21 * u + _a22 * v + _tN;
    return (lat: _lat0 + nord / _mProGradLat, lng: _lng0 + ost / _mLng);
  }

  /// Die drei Bild-Ecken fürs Karten-Overlay (flutter_map
  /// `OverlayImage.withRotation`-Konvention: oben links, unten links,
  /// unten rechts).
  ({Kartenpunkt topLeft, Kartenpunkt bottomLeft, Kartenpunkt bottomRight})
      ecken(double bildBreite, double bildHoehe) => (
            topLeft: bildZuKarte(0, 0),
            bottomLeft: bildZuKarte(0, bildHoehe),
            bottomRight: bildZuKarte(bildBreite, bildHoehe),
          );
}

/// (De-)Serialisierung der Passpunkte für die JSONB-Spalte
/// `events.lageplan_punkte` — bewusst nur die Rohpunkte plus Bildmasse: die
/// Transformation wird immer frisch gerechnet (eine Wahrheit, nachjustierbar).
List<Passpunkt> passpunkteAusJson(List<dynamic> json) => [
      for (final e in json.cast<Map<String, dynamic>>())
        (
          px: (e['px'] as num).toDouble(),
          py: (e['py'] as num).toDouble(),
          lat: (e['lat'] as num).toDouble(),
          lng: (e['lng'] as num).toDouble(),
        ),
    ];

List<Map<String, double>> passpunkteZuJson(List<Passpunkt> punkte) => [
      for (final p in punkte)
        {'px': p.px, 'py': p.py, 'lat': p.lat, 'lng': p.lng},
    ];
