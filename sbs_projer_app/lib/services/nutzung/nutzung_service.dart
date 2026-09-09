/// Verdrahtet den [RouteZaehler] mit App, Speicher und Supabase.
///
/// Der Zähler selbst kennt weder Flutter noch die Datenbank — hier kommen
/// die drei Aussenanschlüsse dazu: Bildschirmbreite, `shared_preferences`
/// und die RPC `route_nutzung_zaehlen` (Migration 190).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sbs_projer_app/services/nutzung/route_zaehler.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

const _pufferSchluessel = 'route_nutzung_puffer';

/// Nach dieser Zeit ohne Bildschirmwechsel geht der Rest trotzdem raus —
/// sonst bliebe die letzte Handvoll Aufrufe eines Arbeitstags liegen.
const _nachlaufZeit = Duration(minutes: 2);

RouteZaehler? _zaehler;
Timer? _nachlauf;

/// Beim App-Start aufrufen: holt Liegengebliebenes und schickt es weg.
Future<void> nutzungMessungStarten() async {
  _zaehler = RouteZaehler(
    senden: _anSupabase,
    lesen: () async =>
        (await SharedPreferences.getInstance()).getString(_pufferSchluessel),
    schreiben: (s) async {
      final p = await SharedPreferences.getInstance();
      if (s == null) {
        await p.remove(_pufferSchluessel);
      } else {
        await p.setString(_pufferSchluessel, s);
      }
    },
    heute: DateTime.now,
    breite: _breite,
  );
  await _zaehler!.laden();
  await _zaehler!.senden();
}

double _breite() {
  final v = PlatformDispatcher.instance.views.first;
  return v.physicalSize.width / v.devicePixelRatio;
}

Future<void> _anSupabase(List<NutzungEintrag> eintraege) async {
  for (final e in eintraege) {
    await SupabaseService.client.rpc(
      'route_nutzung_zaehlen',
      params: {
        'p_route': e.route,
        'p_geraet': e.geraet,
        'p_tag': e.tag.toIso8601String().substring(0, 10),
        'p_anzahl': e.anzahl,
      },
    );
  }
}

/// Hängt sich an die Navigation. Zählt nur, was einen Routen-Namen hat —
/// Dialoge und Sheets bleiben aussen vor.
class NutzungBeobachter extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _melde(route.settings.name);
  }

  // didReplace wird bewusst NICHT gezählt. `pushReplacement` gibt es an drei
  // Stellen, und alle drei sind ein Wechsel innerhalb eines Vorgangs, kein
  // neuer Einstieg: Betriebsauswahl → Reinigungsformular, Event-Formular →
  // Event, Rechnung erzeugen → Rechnung.
  //
  // Am 09.09.2026 hat das die erste Messung verzerrt: `/reinigungen/neu`
  // stand mit 15 Aufrufen da, tatsächlich waren es 7 Reinigungen — die Route
  // bedient Auswahl UND Formular, jeder Vorgang zählte doppelt.

  void _melde(String? name) {
    final z = _zaehler;
    if (z == null || !routeZaehlbar(name)) return;
    // Nicht awaiten: Die Messung darf die Navigation nie aufhalten oder
    // mit einem Fehler stören.
    unawaited(z.zaehle(name!).catchError((Object e) {
      if (kDebugMode) debugPrint('Nutzungsmessung: $e');
    }));
    _nachlauf?.cancel();
    _nachlauf = Timer(_nachlaufZeit, () => unawaited(z.senden()));
  }
}
