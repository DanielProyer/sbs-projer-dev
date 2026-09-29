import 'package:sbs_projer_app/core/util/chf_format.dart';

/// Ergebnis der Dokument-Erkennung über die Edge Function `parse-dokument`
/// (29.09.2026). Füllt den Upload-Dialog vor; Daniel bestätigt oder
/// korrigiert. Robustes Parsing: ein falscher JSON-Typ wird zu null, nie zu
/// einer Exception — die Erkennung darf den Upload nie blockieren.
///
/// Die Function prüft Bereich/Typ/Kategorie bereits gegen den mitgeschickten
/// Katalog; der Dialog prüft sie trotzdem noch einmal gegen seine eigenen
/// Listen (eine ältere Function-Fassung kennt vielleicht eine Liste nicht).
class DokumentScanErgebnis {
  final String? bereich;
  final String? typ;
  final String? kategorie;
  final int? jahr;
  final DateTime? dokumentDatum;
  final double? betrag;
  final String? referenz;
  final String? titel;
  final String? dateiname;

  /// 0–1: wie sicher Bereich, Typ und Jahr stimmen.
  final double zuversicht;

  /// Typspezifische Werte, beim Zinsausweis `saldo_31_12`, `zins_brutto`,
  /// `verrechnungssteuer`, `zins_netto`, `konto`. Nie null, höchstens leer.
  final Map<String, Object?> felder;
  final String? hinweis;

  const DokumentScanErgebnis({
    this.bereich,
    this.typ,
    this.kategorie,
    this.jahr,
    this.dokumentDatum,
    this.betrag,
    this.referenz,
    this.titel,
    this.dateiname,
    this.zuversicht = 0,
    this.felder = const {},
    this.hinweis,
  });

  factory DokumentScanErgebnis.fromJson(Map<String, dynamic> j) {
    final felderRoh = j['felder'];
    return DokumentScanErgebnis(
      bereich: _text(j['bereich']),
      typ: _text(j['typ']),
      kategorie: _text(j['kategorie']),
      jahr: _jahr(j['jahr']),
      dokumentDatum: _datum(j['dokument_datum']),
      betrag: _zahl(j['betrag']),
      referenz: _text(j['referenz']),
      titel: _text(j['titel']),
      dateiname: _text(j['dateiname']),
      zuversicht: (_zahl(j['zuversicht']) ?? 0).clamp(0, 1).toDouble(),
      felder: felderRoh is Map
          ? {
              for (final e in felderRoh.entries)
                if (e.key is String) e.key as String: e.value,
            }
          : const {},
      hinweis: _text(j['hinweis']),
    );
  }

  /// Zahl aus [felder] (Zahl oder Text wie «10'869.26»).
  double? feldZahl(String schluessel) => _zahl(felder[schluessel]);

  /// Notiz für einen Zins-/Kapitalausweis, z. B.
  /// «Saldo 31.12.: 10'869.26 · Zins brutto 0.00 · VSt 0.00 · netto 0.00 ·
  /// Konto …0601». null, wenn es kein Zinsausweis ist oder keine Zahl dasteht.
  String? zinsausweisNotiz() {
    if (typ != 'zinsausweis') return null;
    final teile = <String>[
      if (feldZahl('saldo_31_12') case final v?) 'Saldo 31.12.: ${chf(v)}',
      if (feldZahl('zins_brutto') case final v?) 'Zins brutto ${chf(v)}',
      if (feldZahl('verrechnungssteuer') case final v?) 'VSt ${chf(v)}',
      if (feldZahl('zins_netto') case final v?) 'netto ${chf(v)}',
    ];
    if (teile.isEmpty) return null;
    if (_text(felder['konto']) case final konto?) teile.add('Konto $konto');
    return teile.join(' · ');
  }

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static double? _zahl(Object? v) {
    if (v is num) return v.isFinite ? v.toDouble() : null;
    if (v is! String) return null;
    return double.tryParse(
      v.replaceAll(RegExp(r"['’\s]"), '').replaceAll(',', '.'),
    );
  }

  static int? _jahr(Object? v) {
    final j = v is num
        ? (v == v.roundToDouble() ? v.toInt() : null)
        : v is String
        ? int.tryParse(v.trim())
        : null;
    return j != null && j >= 1990 && j <= 2100 ? j : null;
  }

  static DateTime? _datum(Object? v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v.trim());
    if (m == null) return null;
    final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    // 2025-02-30 rollt in Dart still in den März — das ist kein Datum.
    return d.month == int.parse(m[2]!) ? d : null;
  }
}
