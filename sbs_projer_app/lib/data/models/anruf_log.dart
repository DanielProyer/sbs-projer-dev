class AnrufLog {
  final String id;
  final String userId;
  final String kontaktId;
  final DateTime anrufZeitpunkt;
  final String? notiz;
  final DateTime? createdAt;

  AnrufLog({
    required this.id,
    required this.userId,
    required this.kontaktId,
    required this.anrufZeitpunkt,
    this.notiz,
    this.createdAt,
  });

  factory AnrufLog.fromJson(Map<String, dynamic> json) {
    return AnrufLog(
      id: json['id'],
      userId: json['user_id'],
      kontaktId: json['kontakt_id'],
      anrufZeitpunkt: DateTime.parse(json['anruf_zeitpunkt']),
      notiz: json['notiz'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'kontakt_id': kontaktId,
      'anruf_zeitpunkt': anrufZeitpunkt.toIso8601String(),
      'notiz': notiz,
    };
  }
}
