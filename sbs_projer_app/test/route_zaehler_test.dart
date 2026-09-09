import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/nutzung/route_zaehler.dart';

/// Sammelt statt zu senden — so lässt sich prüfen, wann und was übertragen
/// würde, ohne Supabase.
class _Empfaenger {
  final gesendet = <List<NutzungEintrag>>[];
  bool faellt = false;

  Future<void> call(List<NutzungEintrag> e) async {
    if (faellt) throw Exception('kein Netz');
    gesendet.add(List.of(e));
  }
}

RouteZaehler _zaehler(_Empfaenger e, {String? gespeichert}) {
  final speicher = _Speicher(gespeichert);
  return RouteZaehler(
    senden: e.call,
    lesen: speicher.lesen,
    schreiben: speicher.schreiben,
    heute: () => DateTime(2026, 9, 9),
    breite: () => 400,
  );
}

class _Speicher {
  String? wert;
  _Speicher(this.wert);
  Future<String?> lesen() async => wert;
  Future<void> schreiben(String? s) async => wert = s;
}

void main() {
  group('Geräteklasse', () {
    test('unter 600 px ist Handy, darüber Desktop', () {
      expect(geraeteKlasse(360), 'handy');
      expect(geraeteKlasse(599), 'handy');
      expect(geraeteKlasse(600), 'desktop');
      expect(geraeteKlasse(1920), 'desktop');
    });
  });

  group('Was gezählt wird', () {
    test('Routen-Muster mit Platzhalter bleibt erhalten, IDs nicht', () {
      // Der Observer liefert '/betriebe/:id' — kein konkreter Datensatz.
      expect(routeZaehlbar('/betriebe/:id'), isTrue);
      expect(routeZaehlbar('/buchhaltung/lohn'), isTrue);
    });

    test('Login und Unbenanntes werden nicht gezählt', () {
      // Der Login sagt nichts über Nutzung; ein Name-loser Übergang
      // (Dialog, Sheet) wäre nur Rauschen.
      expect(routeZaehlbar('/login'), isFalse);
      expect(routeZaehlbar(null), isFalse);
      expect(routeZaehlbar(''), isFalse);
    });
  });

  group('Puffern und senden', () {
    test('sammelt, bis die Schwelle erreicht ist — dann ein Sendevorgang',
        () async {
      final e = _Empfaenger();
      final z = _zaehler(e);
      await z.laden();

      for (var i = 0; i < RouteZaehler.schwelle - 1; i++) {
        await z.zaehle('/betriebe');
      }
      expect(e.gesendet, isEmpty, reason: 'unter der Schwelle wird gesammelt');

      await z.zaehle('/betriebe');
      expect(e.gesendet.length, 1);
      expect(e.gesendet.first.single.route, '/betriebe');
      expect(e.gesendet.first.single.anzahl, RouteZaehler.schwelle);
      expect(e.gesendet.first.single.geraet, 'handy');
    });

    test('fasst gleiche Route zusammen, trennt verschiedene', () async {
      final e = _Empfaenger();
      final z = _zaehler(e);
      await z.laden();

      await z.zaehle('/betriebe');
      await z.zaehle('/betriebe');
      await z.zaehle('/reinigungen');
      await z.senden();

      final eintraege = e.gesendet.single;
      expect(eintraege.length, 2);
      expect(eintraege.firstWhere((x) => x.route == '/betriebe').anzahl, 2);
      expect(eintraege.firstWhere((x) => x.route == '/reinigungen').anzahl, 1);
    });

    test('nach dem Senden ist der Puffer leer', () async {
      final e = _Empfaenger();
      final z = _zaehler(e);
      await z.laden();
      await z.zaehle('/betriebe');
      await z.senden();
      await z.senden();
      expect(e.gesendet.length, 1, reason: 'nichts Neues, nichts zu senden');
    });

    test('ohne Netz bleibt gezählt und geht beim nächsten Mal mit', () async {
      // Daniel ist regelmässig im Keller ohne Empfang. Gingen die Zahlen
      // dort verloren, wäre ausgerechnet die Werkstatt-Nutzung untererfasst
      // — also genau das, was gemessen werden soll.
      final e = _Empfaenger()..faellt = true;
      final z = _zaehler(e);
      await z.laden();

      await z.zaehle('/reinigungen');
      await z.zaehle('/reinigungen');
      await z.senden();
      expect(e.gesendet, isEmpty);

      e.faellt = false;
      await z.zaehle('/reinigungen');
      await z.senden();
      expect(e.gesendet.single.single.anzahl, 3,
          reason: 'die zwei aus dem Funkloch fehlen sonst');
    });

    test('überlebt einen Neustart: Puffer wird gespeichert und gelesen',
        () async {
      final e1 = _Empfaenger()..faellt = true;
      final speicher = _Speicher(null);
      final z1 = RouteZaehler(
        senden: e1.call,
        lesen: speicher.lesen,
        schreiben: speicher.schreiben,
        heute: () => DateTime(2026, 9, 9),
        breite: () => 400,
      );
      await z1.laden();
      await z1.zaehle('/touren');
      await z1.senden();
      expect(speicher.wert, isNotNull, reason: 'Ungesendetes wird abgelegt');

      final e2 = _Empfaenger();
      final z2 = RouteZaehler(
        senden: e2.call,
        lesen: speicher.lesen,
        schreiben: speicher.schreiben,
        heute: () => DateTime(2026, 9, 10),
        breite: () => 1400,
      );
      await z2.laden();
      await z2.senden();

      final eintrag = e2.gesendet.single.single;
      expect(eintrag.route, '/touren');
      expect(eintrag.tag, DateTime(2026, 9, 9),
          reason: 'der Tag von damals, nicht der von heute');
      expect(eintrag.geraet, 'handy',
          reason: 'das Gerät von damals, nicht das aktuelle');
    });

    test('trennt nach Tag und Gerät', () async {
      final e = _Empfaenger();
      final speicher = _Speicher(null);
      var tag = DateTime(2026, 9, 9);
      var breite = 400.0;
      final z = RouteZaehler(
        senden: e.call,
        lesen: speicher.lesen,
        schreiben: speicher.schreiben,
        heute: () => tag,
        breite: () => breite,
      );
      await z.laden();

      await z.zaehle('/betriebe');
      breite = 1400;
      await z.zaehle('/betriebe');
      tag = DateTime(2026, 9, 10);
      await z.zaehle('/betriebe');
      await z.senden();

      expect(e.gesendet.single.length, 3,
          reason: 'Handy 09., Desktop 09., Desktop 10. sind drei Zeilen');
    });
  });
}
