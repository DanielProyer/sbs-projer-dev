import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ZuletztEintrag {
  final String titel;
  final String? untertitel;
  final String route;

  const ZuletztEintrag({
    required this.titel,
    required this.untertitel,
    required this.route,
  });

  Map<String, dynamic> toJson() =>
      {'titel': titel, 'untertitel': untertitel, 'route': route};

  static ZuletztEintrag fromJson(Map<String, dynamic> j) => ZuletztEintrag(
        titel: j['titel'] as String,
        untertitel: j['untertitel'] as String?,
        route: j['route'] as String,
      );
}

/// Die letzten fünf über die Suche geöffneten Treffer — nur in diesem
/// Browser. Der zweite Griff zum selben Betrieb soll ein Tipp sein, ohne
/// Server-Tabelle für etwas, das nur hier gebraucht wird.
class ZuletztGeoeffnet {
  static const _schluessel = 'suche_zuletzt';
  static const _max = 5;

  static Future<List<ZuletztEintrag>> lade() async {
    final prefs = await SharedPreferences.getInstance();
    final roh = prefs.getString(_schluessel);
    if (roh == null) return const [];
    try {
      final liste = jsonDecode(roh) as List<dynamic>;
      return liste
          .map((e) => ZuletztEintrag.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Kaputter Inhalt (alte Fassung, manuell gelöscht) ist kein Grund,
      // die Suchseite zu stören.
      return const [];
    }
  }

  static Future<void> merke(ZuletztEintrag e) async {
    final alt = await lade();
    final neu = [e, ...alt.where((x) => x.route != e.route)].take(_max);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _schluessel,
      jsonEncode(neu.map((x) => x.toJson()).toList()),
    );
  }
}
