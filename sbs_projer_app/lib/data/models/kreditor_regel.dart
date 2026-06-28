/// DTO für eine Lieferanten-Lernregel (Kreditor-Vorbelegung).
///
/// Plain-Dart-Klasse mit fromJson-Factory + toJson (snake_case Keys),
/// passend zur Supabase-Tabelle `kreditor_regel` (Migration 109).
///
/// Eine Regel ordnet einem Lieferanten (per Name-Substring, optional IBAN
/// und/oder Referenz-Präfix) ein Aufwandskonto + MwSt-/Vorsteuer-Logik zu.
/// Multi-Konto = mehrere Zeilen je Lieferant, unterschieden über
/// `referenz_praefix`.
class KreditorRegel {
  final String id;
  final String userId;
  final String lieferantNamePattern;
  final String? lieferantIban;
  final String? referenzPraefix;
  final int aufwandskonto;
  final String? geschaeftsfallId;
  final int? vorsteuerKonto;
  final double? mwstSatzPercent;
  final bool mwstPflichtig;
  final int prioritaet;
  final bool istAktiv;
  final String? lernquelle;
  final DateTime? gelerntAm;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  KreditorRegel({
    required this.id,
    required this.userId,
    required this.lieferantNamePattern,
    this.lieferantIban,
    this.referenzPraefix,
    this.aufwandskonto = 0,
    this.geschaeftsfallId,
    this.vorsteuerKonto,
    this.mwstSatzPercent,
    this.mwstPflichtig = true,
    this.prioritaet = 0,
    this.istAktiv = true,
    this.lernquelle,
    this.gelerntAm,
    this.createdAt,
    this.updatedAt,
  });

  factory KreditorRegel.fromJson(Map<String, dynamic> json) {
    return KreditorRegel(
      id: json['id'],
      userId: json['user_id'],
      lieferantNamePattern: json['lieferant_name_pattern'] ?? '',
      lieferantIban: json['lieferant_iban'],
      referenzPraefix: json['referenz_praefix'],
      aufwandskonto: _toInt(json['aufwandskonto']) ?? 0,
      geschaeftsfallId: json['geschaeftsfall_id'],
      vorsteuerKonto: _toInt(json['vorsteuer_konto']),
      mwstSatzPercent: _toDouble(json['mwst_satz_percent']),
      mwstPflichtig: json['mwst_pflichtig'] ?? true,
      prioritaet: _toInt(json['prioritaet']) ?? 0,
      istAktiv: json['ist_aktiv'] ?? true,
      lernquelle: json['lernquelle'],
      gelerntAm: _toDate(json['gelernt_am']),
      createdAt: _toDate(json['created_at']),
      updatedAt: _toDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'lieferant_name_pattern': lieferantNamePattern,
      'lieferant_iban': lieferantIban,
      'referenz_praefix': referenzPraefix,
      'aufwandskonto': aufwandskonto,
      'geschaeftsfall_id': geschaeftsfallId,
      'vorsteuer_konto': vorsteuerKonto,
      'mwst_satz_percent': mwstSatzPercent,
      'mwst_pflichtig': mwstPflichtig,
      'prioritaet': prioritaet,
      'ist_aktiv': istAktiv,
      'lernquelle': lernquelle,
      'gelernt_am': gelerntAm?.toIso8601String(),
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
