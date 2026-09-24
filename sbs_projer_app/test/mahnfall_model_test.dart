import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';

void main() {
  test('Mahnfall.fromJson liest alle Felder, Datumswerte als UTC-Tage', () {
    final f = Mahnfall.fromJson({
      'id': 'f1',
      'user_id': 'u',
      'betrieb_id': 'b1',
      'rechnung_ids': ['r1', 'r2'],
      'eroeffnet_am': '2026-10-20',
      'status': 'betreibung',
      'test': true,
      'heineken_kontakt_am': '2026-10-20',
      'heineken_empfaenger': 'x@heineken.ch',
      'heineken_ergebnis': 'betreibung',
      'heineken_ergebnis_am': '2026-11-05',
      'heineken_frist_bis': null,
      'schuldner_name': 'Muster GmbH',
      'schuldner_adresse': 'Bahnhofstr. 1, 7000 Chur',
      'rechtsform': 'gmbh',
      'betreibungsamt': 'Betreibungsamt Plessur',
      'eingereicht_am': '2026-11-06',
      'zahlungsbefehl_am': '2026-11-20',
      'rechtsvorschlag': false,
      'fortsetzung_am': null,
      'kosten_vorschuss': 40,
      'erledigt_am': null,
      'erledigung': null,
      'notiz': 'n',
      'erstellt_am': '2026-10-20T10:00:00Z',
      'aktualisiert_am': '2026-10-20T10:00:00Z',
    });
    expect(f.rechnungIds, ['r1', 'r2']);
    expect(f.status, 'betreibung');
    expect(f.zahlungsbefehlAm, DateTime.utc(2026, 11, 20));
    expect(f.kostenVorschuss, 40.0);
    expect(f.rechtsvorschlag, isFalse);
    expect(f.offen, isTrue);
  });

  test('offen ist false bei status erledigt', () {
    final f = Mahnfall.fromJson({
      'id': 'f1', 'user_id': 'u', 'betrieb_id': 'b1', 'rechnung_ids': <String>[],
      'eroeffnet_am': '2026-10-20', 'status': 'erledigt', 'test': false,
      'erstellt_am': '2026-10-20T10:00:00Z', 'aktualisiert_am': '2026-10-20T10:00:00Z',
    });
    expect(f.offen, isFalse);
  });
}
