import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_mapper.dart';
import 'package:sbs_projer_app/data/models/betrieb.dart';

/// Der Merker «Nächste Reinigung auf Kulanz» am Betrieb (Migration 193).
///
/// ANLASS Chleina Pub: Der Freitext-Hinweis stand ab 07.08.2026 am Betrieb und
/// wurde beim Abschluss auch angezeigt — am 27.08. wurde trotzdem regulär
/// verrechnet (Rechnung 2026-08-1386). Ein Hinweis erinnert nur, er stellt
/// nichts ein. Und er verfiel nie: 40 Tage später stand er noch da, obwohl der
/// Fall längst anders gelöst war.
void main() {
  Betrieb dto({bool kulanz = false, String? hinweis}) => Betrieb(
    id: 'b1',
    userId: 'u1',
    name: 'Chleina Pub',
    serviceHinweis: hinweis,
    naechsteReinigungKulanz: kulanz,
  );

  group('Feld reist durch alle Schichten', () {
    test('Standard ist false — kein Betrieb verschenkt ungefragt', () {
      expect(dto().naechsteReinigungKulanz, isFalse);
      expect(BetriebMapper.fromDto(dto()).naechsteReinigungKulanz, isFalse);
    });

    test('true ueberlebt DTO → Local → JSON', () {
      final local = BetriebMapper.fromDto(dto(kulanz: true));
      expect(local.naechsteReinigungKulanz, isTrue);
      expect(BetriebMapper.toJson(local)['naechste_reinigung_kulanz'], isTrue);
    });

    test('fehlendes Feld aus der DB wird false, nicht null', () {
      final b = Betrieb.fromJson({
        'id': 'b1',
        'user_id': 'u1',
        'name': 'Alt',
        // naechste_reinigung_kulanz fehlt — Zeile von vor Migration 193
      });
      expect(b.naechsteReinigungKulanz, isFalse);
    });

    test('DB-Wert wird uebernommen', () {
      final b = Betrieb.fromJson({
        'id': 'b1',
        'user_id': 'u1',
        'name': 'Chleina Pub',
        'naechste_reinigung_kulanz': true,
      });
      expect(b.naechsteReinigungKulanz, isTrue);
    });
  });

  group('Merker und Freitext bleiben getrennt', () {
    test('ein Service-Hinweis allein loest KEINE Kulanz aus', () {
      final b = dto(hinweis: 'Hintereingang benutzen, Schlüssel beim Wirt');
      expect(
        b.naechsteReinigungKulanz,
        isFalse,
        reason: 'aus dem Freitext auf Kulanz zu schliessen hiesse raten',
      );
    });

    test('auch ein Hinweis MIT dem Wort Kulanz loest nichts aus', () {
      final b = dto(hinweis: 'Letzte Reinigung war Kulanz — diesmal normal');
      expect(b.naechsteReinigungKulanz, isFalse);
    });

    test('Merker wirkt ohne Hinweistext', () {
      final b = dto(kulanz: true);
      expect(b.serviceHinweis, isNull);
      expect(b.naechsteReinigungKulanz, isTrue);
    });
  });
}
