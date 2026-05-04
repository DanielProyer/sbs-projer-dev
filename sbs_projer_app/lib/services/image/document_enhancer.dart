import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Protokoll-Foto optimieren: Ausrichtung → Zuschnitt → Kontrast.
/// Erkennt weisses Formular gegen dunkleren Hintergrund.
class DocumentEnhancer {
  DocumentEnhancer._();

  /// Debug-Info der letzten Verarbeitung.
  static String lastDebugInfo = '';

  /// Pipeline: Decode → Rotate → Trim → Crop → Kontrast → Encode.
  static Future<Uint8List> enhance(
    Uint8List bytes, {
    void Function(String)? onStep,
  }) async {
    final dbg = StringBuffer();
    try {
      var image = img.decodeImage(bytes);
      if (image == null) {
        lastDebugInfo = 'decode failed';
        return bytes;
      }
      dbg.write('${image.width}x${image.height}');
      await _pause();

      // ── Phase 1: Rotation via Projection Sharpness ───────────────────
      onStep?.call('Ausrichtung wird geprüft...');
      await _pause();

      var gray = _toGray(image);
      final otsu = _otsu(gray);
      final threshold = (otsu + 10).clamp(80, 220);
      dbg.write(' o=$otsu');

      final angleInfo = _detectAngleProjection(gray, threshold);
      final angle = angleInfo.$1;
      dbg.write(' ${angleInfo.$2}');

      if (angle != null) {
        onStep?.call('Bild wird gerade gerichtet...');
        await _pause();

        image = img.copyRotate(image, angle: -angle);
        await _pause();

        image = _trimRotationCorners(image, angle);
        gray = _toGray(image);
        dbg.write(' rot→${image.width}x${image.height}');
        await _pause();
      }

      // ── Phase 2: Zuschnitt ────────────────────────────────────────────
      onStep?.call('Formular wird erkannt...');
      await _pause();

      final cropInfo = _cropDebug(image, gray);
      image = cropInfo.$1;
      dbg.write(' ${cropInfo.$2}');
      await _pause();

      // ── Phase 3: Kontrast ─────────────────────────────────────────────
      onStep?.call('Kontrast wird optimiert...');
      await _pause();

      image = img.contrast(image, contrast: 115);
      await _pause();

      onStep?.call('Wird gespeichert...');
      lastDebugInfo = dbg.toString();
      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      lastDebugInfo = 'ERR: $e | $dbg';
      return bytes;
    }
  }

  static Future<void> _pause() =>
      Future.delayed(const Duration(milliseconds: 30));

  /// 1/4 Grayscale-Kopie.
  static img.Image _toGray(img.Image src) {
    final w = max(100, src.width ~/ 4);
    final h = max(100, src.height ~/ 4);
    return img.grayscale(img.copyResize(src, width: w, height: h));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OTSU
  // ═══════════════════════════════════════════════════════════════════════════

  static int _otsu(img.Image g) {
    final hist = List<int>.filled(256, 0);
    for (int y = 0; y < g.height; y++) {
      for (int x = 0; x < g.width; x++) {
        hist[g.getPixel(x, y).luminance.round().clamp(0, 255)]++;
      }
    }
    final total = g.width * g.height;
    if (total == 0) return 128;

    double sumAll = 0;
    for (int i = 0; i < 256; i++) sumAll += i * hist[i];

    double sumBg = 0;
    int wBg = 0;
    double maxVar = 0;
    int best = 128;

    for (int t = 0; t < 256; t++) {
      wBg += hist[t];
      if (wBg == 0) continue;
      final wFg = total - wBg;
      if (wFg == 0) break;
      sumBg += t * hist[t];
      final mBg = sumBg / wBg;
      final mFg = (sumAll - sumBg) / wFg;
      final v = wBg.toDouble() * wFg * (mBg - mFg) * (mBg - mFg);
      if (v > maxVar) {
        maxVar = v;
        best = t;
      }
    }
    return best;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ROTATION: Projection Sharpness (Radon-inspiriert)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Rotationswinkel via Projection Sharpness.
  ///
  /// Prinzip: Helle Pixel (= Papier) auf eine Achse projizieren.
  /// Bei korrektem Winkel erzeugen die Papierkanten scharfe Übergänge
  /// im Projektions-Histogramm → maximaler Sharpness-Score.
  ///
  /// WICHTIG: Bildränder werden maskiert (10% pro Seite), damit die
  /// pixel-scharfen Bildgrenzen bei 0° nicht den echten Papierwinkel
  /// übertrumpfen.
  ///
  /// Coarse-to-Fine: 1° → 0.2° → 0.1° Schritte.
  static (double?, String) _detectAngleProjection(
      img.Image gray, int threshold) {
    try {
      // ── Helle Pixel sammeln (mit Rand-Maskierung) ────────────────────
      // 10% Rand pro Seite ignorieren → Bildgrenzen-Effekt eliminiert
      final marginX = (gray.width * 0.10).round();
      final marginY = (gray.height * 0.10).round();
      final xStart = marginX;
      final xEnd = gray.width - marginX;
      final yStart = marginY;
      final yEnd = gray.height - marginY;

      final pts = <(double, double)>[];
      for (int y = yStart; y < yEnd; y++) {
        for (int x = xStart; x < xEnd; x++) {
          if (gray.getPixel(x, y).luminance >= threshold) {
            pts.add((x.toDouble(), y.toDouble()));
          }
        }
      }

      final dbg = StringBuffer('P${pts.length}');

      if (pts.length < 200) {
        dbg.write(' →tooFew');
        return (null, dbg.toString());
      }

      // Subsample für Performance (max 25000 Punkte)
      List<(double, double)> sample;
      if (pts.length > 25000) {
        final rng = Random(42);
        sample = List.generate(25000, (_) => pts[rng.nextInt(pts.length)]);
        dbg.write('→25K');
      } else {
        sample = pts;
      }

      final nBins = 300;

      // ── Coarse: -20° bis +20° in 1° Schritten ───────────────────────
      double bestAngle = 0;
      double bestScore = -1;

      for (int deg = -20; deg <= 20; deg++) {
        final score = _projScore(sample, deg.toDouble(), nBins);
        if (score > bestScore) {
          bestScore = score;
          bestAngle = deg.toDouble();
        }
      }
      dbg.write(' c=${bestAngle.toStringAsFixed(0)}°');

      // ── Fine: ±2° in 0.2° Schritten ─────────────────────────────────
      final fineStart = bestAngle - 2.0;
      final fineEnd = bestAngle + 2.0;
      for (double deg = fineStart; deg <= fineEnd; deg += 0.2) {
        final score = _projScore(sample, deg, nBins);
        if (score > bestScore) {
          bestScore = score;
          bestAngle = deg;
        }
      }
      dbg.write(' f=${bestAngle.toStringAsFixed(1)}°');

      // ── Ultra-fine: ±0.4° in 0.1° Schritten ─────────────────────────
      final ultraStart = bestAngle - 0.4;
      final ultraEnd = bestAngle + 0.4;
      for (double deg = ultraStart; deg <= ultraEnd; deg += 0.1) {
        final score = _projScore(sample, deg, nBins);
        if (score > bestScore) {
          bestScore = score;
          bestAngle = deg;
        }
      }
      dbg.write(' u=${bestAngle.toStringAsFixed(1)}°');

      // Sehr kleine Winkel (<0.5°) = Rauschen → nicht korrigieren
      if (bestAngle.abs() < 0.5) {
        dbg.write(' →skip');
        return (null, dbg.toString());
      }
      if (bestAngle.abs() > 20.0) {
        dbg.write(' →tooLarge');
        return (null, dbg.toString());
      }

      dbg.write(' →${bestAngle.toStringAsFixed(1)}°');
      return (bestAngle, dbg.toString());
    } catch (e) {
      return (null, 'projERR:$e');
    }
  }

  /// Sharpness-Score: Summe der vierten Potenz der ersten Differenzen
  /// des Projektions-Histogramms.
  ///
  /// diff⁴ betont scharfe Übergänge (Papierkanten) viel stärker als
  /// sanfte Verläufe (Hintergrund-Gradienten).
  static double _projScore(
      List<(double, double)> pts, double angleDeg, int nBins) {
    final rad = angleDeg * pi / 180;
    final cosA = cos(rad);
    final sinA = sin(rad);

    // Punkte auf Achse senkrecht zum Winkel projizieren
    // u = -x*sin(α) + y*cos(α)
    double minU = double.infinity;
    double maxU = double.negativeInfinity;

    final uValues = Float64List(pts.length);
    for (int i = 0; i < pts.length; i++) {
      final u = -pts[i].$1 * sinA + pts[i].$2 * cosA;
      uValues[i] = u;
      if (u < minU) minU = u;
      if (u > maxU) maxU = u;
    }

    final range = maxU - minU;
    if (range < 1e-6) return 0;

    // Histogramm aufbauen
    final hist = List<int>.filled(nBins, 0);
    final scale = (nBins - 1) / range;
    for (int i = 0; i < uValues.length; i++) {
      final bin = ((uValues[i] - minU) * scale).round().clamp(0, nBins - 1);
      hist[bin]++;
    }

    // Score = Summe von diff⁴ (betont scharfe Kanten extrem)
    double score = 0;
    for (int i = 1; i < nBins; i++) {
      final diff = (hist[i] - hist[i - 1]).toDouble();
      final d2 = diff * diff;
      score += d2 * d2; // diff⁴
    }

    return score;
  }

  /// Schwarze Ecken nach copyRotate() entfernen.
  static img.Image _trimRotationCorners(img.Image image, double angleDeg) {
    try {
      final a = angleDeg.abs() * pi / 180;
      final sinA = sin(a);
      final trimX = (image.height * sinA / 2).ceil() + 2;
      final trimY = (image.width * sinA / 2).ceil() + 2;
      if (trimX * 2 >= image.width || trimY * 2 >= image.height) {
        return image;
      }
      return img.copyCrop(image,
          x: trimX,
          y: trimY,
          width: image.width - 2 * trimX,
          height: image.height - 2 * trimY);
    } catch (_) {
      return image;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ZUSCHNITT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Papier-Erkennung: Von Bildmitte nach aussen scannen.
  static (img.Image, String) _cropDebug(img.Image image, img.Image gray) {
    try {
      final otsu = _otsu(gray);
      final paperT = (otsu + 10).clamp(80, 220);

      final dbg = StringBuffer('o=$otsu');

      final midY = gray.height ~/ 2;
      final midX = gray.width ~/ 2;

      // ── Vertikal: Mitte → oben/unten ──────────────────────────────────
      // 3 aufeinanderfolgende dunkle Zeilen nötig (Header/Unterschrift
      // sind dunkel aber gehören zum Dokument)
      int top = 0;
      for (int y = midY; y >= 2; y--) {
        if (_rowRatio(gray, y, paperT) < 0.40 &&
            _rowRatio(gray, y - 1, paperT) < 0.40 &&
            _rowRatio(gray, y - 2, paperT) < 0.40) {
          top = y + 1;
          break;
        }
      }
      int bottom = gray.height - 1;
      for (int y = midY; y < gray.height - 2; y++) {
        if (_rowRatio(gray, y, paperT) < 0.40 &&
            _rowRatio(gray, y + 1, paperT) < 0.40 &&
            _rowRatio(gray, y + 2, paperT) < 0.40) {
          bottom = y - 1;
          break;
        }
      }

      // ── Horizontal: Mitte → links/rechts (innerhalb T-B) ─────────────
      // Gleich: 3 aufeinanderfolgende dunkle Spalten
      int left = 0;
      for (int x = midX; x >= 2; x--) {
        if (_colRatio(gray, x, top, bottom, paperT) < 0.40 &&
            _colRatio(gray, x - 1, top, bottom, paperT) < 0.40 &&
            _colRatio(gray, x - 2, top, bottom, paperT) < 0.40) {
          left = x + 1;
          break;
        }
      }
      int right = gray.width - 1;
      for (int x = midX; x < gray.width - 2; x++) {
        if (_colRatio(gray, x, top, bottom, paperT) < 0.40 &&
            _colRatio(gray, x + 1, top, bottom, paperT) < 0.40 &&
            _colRatio(gray, x + 2, top, bottom, paperT) < 0.40) {
          right = x - 1;
          break;
        }
      }

      // Sicherheits-Einzug (2 Gray-Pixel ≈ 8 Full-Pixel)
      top = min(top + 2, midY);
      bottom = max(bottom - 2, midY);
      left = min(left + 2, midX);
      right = max(right - 2, midX);

      dbg.write(' T$top B$bottom L$left R$right');

      final sx = image.width / gray.width;
      final sy = image.height / gray.height;
      int cx = (left * sx).round();
      int cy = (top * sy).round();
      int cw = ((right - left + 1) * sx).round();
      int ch = ((bottom - top + 1) * sy).round();

      final origArea = image.width * image.height;
      final cropArea = cw * ch;
      final pct = (cropArea * 100 / origArea).round();
      dbg.write(' ${pct}%');

      if (cropArea < origArea * 0.95 &&
          cropArea > origArea * 0.15 &&
          cw > 100 &&
          ch > 100) {
        dbg.write(' →CROP');
        return (
          img.copyCrop(image, x: cx, y: cy, width: cw, height: ch),
          dbg.toString()
        );
      }
      dbg.write(' →noCrop');
      return (image, dbg.toString());
    } catch (e) {
      return (image, 'cropERR:$e');
    }
  }

  static double _rowRatio(img.Image g, int y, int t) {
    int c = 0;
    for (int x = 0; x < g.width; x++) {
      if (g.getPixel(x, y).luminance >= t) c++;
    }
    return c / g.width;
  }

  static double _colRatio(img.Image g, int x, int top, int bot, int t) {
    final h = bot - top + 1;
    if (h <= 0) return 0;
    int c = 0;
    for (int y = top; y <= bot; y++) {
      if (g.getPixel(x, y).luminance >= t) c++;
    }
    return c / h;
  }
}
