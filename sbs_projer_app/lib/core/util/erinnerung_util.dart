import 'dart:convert';

import 'package:sbs_projer_app/data/models/termin_erinnerung.dart';

/// Lesbares Label für eine Vorlaufzeit in Minuten.
String minutenLabel(int minuten) {
  if (minuten <= 0) return 'Zum Zeitpunkt';
  if (minuten % 1440 == 0) {
    final t = minuten ~/ 1440;
    return t == 1 ? '1 Tag vorher' : '$t Tage vorher';
  }
  if (minuten % 60 == 0) {
    final h = minuten ~/ 60;
    return h == 1 ? '1 Std. vorher' : '$h Std. vorher';
  }
  return '$minuten Min. vorher';
}

/// Parst Erinnerungen aus jsonb (List), einem JSON-String oder null. Max 5.
List<TerminErinnerung> parseErinnerungen(dynamic raw) {
  dynamic value = raw;
  if (value is String) {
    if (value.trim().isEmpty) return const [];
    value = jsonDecode(value);
  }
  if (value is! List) return const [];
  final out = <TerminErinnerung>[];
  for (final e in value) {
    if (e is Map) {
      final min = (e['minuten'] as num?)?.toInt();
      if (min == null || min < 0) continue;
      out.add(TerminErinnerung(
        methode: e['methode'] == 'email' ? 'email' : 'popup',
        minuten: min,
      ));
      if (out.length >= 5) break;
    }
  }
  return out;
}

/// Serialisiert (max 5) Erinnerungen zu einem JSON-String (für Isar-Local).
String erinnerungenToJson(List<TerminErinnerung> list) =>
    jsonEncode(list.take(5).map((e) => e.toJson()).toList());
