import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/util/jahresrechnung_kennzahlen.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/services/steuern/jahresrechnung_ablage.dart';

/// Die Verdrahtung «PDF → Dossier → Steuerjahr» ohne Supabase: Upload und
/// Steuerjahr sind hier Attrappen, die mitschreiben, was ankommt.
class _Attrappe {
  final List<Map<String, Object?>> hochgeladen = [];
  final List<Steuerjahr> gespeichert = [];
  int steuerjahreGeladen = 0;
  Object? uploadFehler;
  Object? steuerjahrFehler;
  List<Steuerjahr> steuerjahre = const [];

  JahresrechnungAblage get ablage => JahresrechnungAblage(
    hochladen: ({
      required int jahr,
      required String titel,
      required String dateiname,
      required double betrag,
      required Uint8List bytes,
    }) async {
      if (uploadFehler != null) throw uploadFehler!;
      hochgeladen.add({
        'jahr': jahr,
        'titel': titel,
        'dateiname': dateiname,
        'betrag': betrag,
        'bytes': bytes.length,
      });
    },
    steuerjahreLaden: () async {
      steuerjahreGeladen++;
      if (steuerjahrFehler != null) throw steuerjahrFehler!;
      return steuerjahre;
    },
    steuerjahrSpeichern: (s) async => gespeichert.add(s),
  );
}

const k = JahresrechnungKennzahlen(
  jahr: 2025,
  gewinn: 15235.70,
  gewinnvortrag: 35060.71,
  stammkapital: 20000,
  debitoren: 105351.96,
  delkredere: 5267.60,
  rueckstellung: 2800,
  bank: 12202.73,
  kasse: 6670.24,
  aufrechnungenAuto: 320,
);

Future<Uint8List> pdf() async => Uint8List.fromList([1, 2, 3]);

void main() {
  test('Upload-Fehler: Meldung, Steuerjahr bleibt unberührt', () async {
    final a = _Attrappe()..uploadFehler = Exception('Bucket voll');
    final e = await a.ablage.ablegen(k: k, fassung: 2, pdf: pdf);
    expect(e.abgelegt, isFalse);
    expect(e.meldung, startsWith('Jahresrechnung nicht abgelegt:'));
    expect(a.steuerjahreGeladen, 0);
    expect(a.gespeichert, isEmpty);
  });

  test('PDF-Fehler zählt wie ein Upload-Fehler', () async {
    final a = _Attrappe();
    final e = await a.ablage.ablegen(
      k: k,
      fassung: 1,
      pdf: () async => throw StateError('Schrift fehlt'),
    );
    expect(e.abgelegt, isFalse);
    expect(a.hochgeladen, isEmpty);
  });

  test('Upload trägt Gewinn, Titel und Dateiname der Fassung', () async {
    final a = _Attrappe();
    final e = await a.ablage.ablegen(k: k, fassung: 2, pdf: pdf);
    expect(e.abgelegt, isTrue);
    final u = a.hochgeladen.single;
    expect(u['jahr'], 2025);
    // W1: am Betrag misst Schritt 5 später, ob die Fassung veraltet ist.
    expect(u['betrag'], 15235.70);
    expect(u['titel'], endsWith(' — Fassung 2'));
    expect(u['dateiname'], 'Jahresrechnung_2025_Fassung2.pdf');
    expect(u['bytes'], 3);
  });

  test('leeres Steuerjahr wird vorbefüllt', () async {
    final a = _Attrappe();
    final e = await a.ablage.ablegen(k: k, fassung: 1, pdf: pdf);
    final s = a.gespeichert.single;
    expect(s.jahr, 2025);
    expect(s.steuerbarerGewinn, 15555.70);
    expect(s.steuerbaresKapital, 70296.41);
    expect(e.meldung, contains('im Dossier abgelegt'));
    expect(e.meldung, contains('im Steuerjahr eingetragen'));
  });

  test('gesetzte, abweichende Werte bleiben und werden gemeldet', () async {
    final a = _Attrappe()
      ..steuerjahre = const [
        Steuerjahr(jahr: 2024, steuerbarerGewinn: 1),
        Steuerjahr(
          jahr: 2025,
          status: 'eingereicht',
          steuerbarerGewinn: 21201.23,
          steuerbaresKapital: 75950.93,
        ),
      ];
    final e = await a.ablage.ablegen(k: k, fassung: 2, pdf: pdf);
    expect(a.gespeichert, isEmpty);
    expect(
      e.meldung,
      contains(
        "Steuerjahr behält Gewinn 21'201.23 (neu 15'555.70), Kapital "
        "75'950.93 (neu 70'296.41) — im Steuerjahr anpassen",
      ),
    );
  });

  test('Steuerjahr nicht ladbar: abgelegt, aber gemeldet', () async {
    final a = _Attrappe()..steuerjahrFehler = Exception('offline');
    final e = await a.ablage.ablegen(k: k, fassung: 1, pdf: pdf);
    expect(e.abgelegt, isTrue);
    expect(e.meldung, contains('Steuerjahr nicht vorbefüllt'));
  });
}
