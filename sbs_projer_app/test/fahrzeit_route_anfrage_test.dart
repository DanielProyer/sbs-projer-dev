import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/repositories/fahrzeit_repository.dart';

/// Body der Anfrage an die Edge Function `fahrzeit-route` (Migration 213).
///
/// Die Function (`supabase/functions/fahrzeit-route/anfrage.ts`) lehnt ein
/// Ende mit Betrieb UND Punkt als unklare Anfrage ab — deshalb gehen nur die
/// gesetzten Felder hinaus.
void main() {
  // Rollout-Entkopplung: Betrieb → Betrieb geht zusätzlich im Format vor
  // Migration 213 hinaus, damit die neue App auch gegen die alte Function
  // läuft. Die neue liest `von`/`nach` und prüft, dass das alte Format
  // dasselbe sagt (`anfrage.ts`).
  test('Betrieb → Betrieb (Tourenplan): neues UND altes Format', () {
    expect(
      FahrzeitRepository.anfrageBody(
        (betriebId: 'a', lat: null, lng: null),
        (betriebId: 'b', lat: null, lng: null),
      ),
      {
        'von': {'betriebId': 'a'},
        'nach': {'betriebId': 'b'},
        'vonBetriebId': 'a',
        'nachBetriebId': 'b',
      },
    );
  });

  test('GPS-Position → Betrieb: Punkt als lat/lng', () {
    expect(
      FahrzeitRepository.anfrageBody(
        (betriebId: null, lat: 47.37, lng: 8.54),
        (betriebId: 'a', lat: null, lng: null),
      ),
      {
        'von': {'lat': 47.37, 'lng': 8.54},
        'nach': {'betriebId': 'a'},
      },
    );
  });

  test('Startort → Startort: zwei Punkte, ungerundet', () {
    // Gerundet wird nur der Cache-Schlüssel (in der Function) — geroutet
    // wird ab der genauen Position.
    expect(
      FahrzeitRepository.anfrageBody(
        (betriebId: null, lat: 46.8328452, lng: 9.4529918),
        (betriebId: null, lat: 46.8639692, lng: 9.5278708),
      ),
      {
        'von': {'lat': 46.8328452, 'lng': 9.4529918},
        'nach': {'lat': 46.8639692, 'lng': 9.5278708},
      },
    );
  });
}
