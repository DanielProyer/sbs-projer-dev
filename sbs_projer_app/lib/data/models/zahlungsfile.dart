/// DTO für ein erstelltes Zahlungsfile (ISO-20022 pain.001, GKB-E-Banking).
///
/// Plain-Dart-Klasse mit fromJson-Factory + toJson (snake_case Keys),
/// passend zur Supabase-Tabelle `zahlungsfile` (Migration 112).
class Zahlungsfile {
  final String id;
  final String userId;
  final String? msgId;
  final String format;
  final int anzahlTx;
  final double ctrlSum;
  final String status;
  final DateTime? erstelltAm;

  Zahlungsfile({
    required this.id,
    required this.userId,
    this.msgId,
    this.format = 'pain.001.001.09',
    this.anzahlTx = 0,
    this.ctrlSum = 0,
    this.status = 'erstellt',
    this.erstelltAm,
  });

  factory Zahlungsfile.fromJson(Map<String, dynamic> json) {
    return Zahlungsfile(
      id: json['id'],
      userId: json['user_id'],
      msgId: json['msg_id'],
      format: json['format'] ?? 'pain.001.001.09',
      anzahlTx: _toInt(json['anzahl_tx']) ?? 0,
      ctrlSum: _toDouble(json['ctrl_sum']) ?? 0,
      status: json['status'] ?? 'erstellt',
      erstelltAm: _toDate(json['erstellt_am']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'msg_id': msgId,
      'format': format,
      'anzahl_tx': anzahlTx,
      'ctrl_sum': ctrlSum,
      'status': status,
      'erstellt_am': erstelltAm?.toIso8601String(),
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
