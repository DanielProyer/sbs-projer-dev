/// Leitet aus den tatsächlich gefahrenen Besuchszeiten ein Servicefenster ab.
///
/// **Warum (Daniel, 08.09.2026):** 201 der 305 aktiven Betriebe haben gar
/// keine Servicezeit hinterlegt — der Tourenplan kann dort nicht warnen, wenn
/// ein Besuch ausserhalb liegt. Die Reinigungen seit 2019 tragen Start- und
/// Endzeit und sagen damit, wann Service dort tatsächlich möglich war.
///
/// **Grenze der Aussage:** Die Zahlen zeigen, wann Daniel dort WAR, nicht wann
/// er DURFTE. Wo er Schlüssel oder Badge hat, fällt beides auseinander — bei
/// Tödi Ilanz liegt der abgeleitete Start bei 07:05, hinterlegt sind 09:00.
/// Deshalb ist das ein Vorschlag zum Bestätigen, keine automatische Übernahme.
library;

/// Ein Besuch, reduziert auf Minuten seit Mitternacht.
class Besuchszeit {
  final int startMinuten;
  final int endeMinuten;
  const Besuchszeit({required this.startMinuten, required this.endeMinuten});
}

class ServicezeitVorschlag {
  final String? morgenAb;
  final String? morgenBis;
  final String? nachmittagAb;
  final String? nachmittagBis;
  final int morgenBesuche;
  final int nachmittagBesuche;

  const ServicezeitVorschlag({
    this.morgenAb,
    this.morgenBis,
    this.nachmittagAb,
    this.nachmittagBis,
    this.morgenBesuche = 0,
    this.nachmittagBesuche = 0,
  });

  bool get hatVorschlag => morgenAb != null || nachmittagAb != null;
}

/// Kopfzeile über der Besuchsliste: volle Spanne und die Stunde, in der die
/// meisten Besuche begannen. Beantwortet beim Durchgehen die Frage, ob der
/// Vorschlag zu dem passt, was tatsächlich gefahren wurde.
class BesuchsUebersicht {
  final String spanneVon;
  final String spanneBis;
  final int haeufigsteStunde;
  final int haeufigkeit;

  const BesuchsUebersicht({
    required this.spanneVon,
    required this.spanneBis,
    required this.haeufigsteStunde,
    required this.haeufigkeit,
  });

  /// «08–09 Uhr»
  String get stundenText =>
      '${haeufigsteStunde.toString().padLeft(2, '0')}–'
      '${(haeufigsteStunde + 1).toString().padLeft(2, '0')} Uhr';
}

/// Fasst [besuche] für die Kopfzeile zusammen. null bei leerer Liste.
BesuchsUebersicht? besuchsUebersicht(List<Besuchszeit> besuche) {
  if (besuche.isEmpty) return null;
  var frueheste = besuche.first.startMinuten;
  var spaeteste = besuche.first.endeMinuten;
  final jeStunde = <int, int>{};
  for (final b in besuche) {
    if (b.startMinuten < frueheste) frueheste = b.startMinuten;
    if (b.endeMinuten > spaeteste) spaeteste = b.endeMinuten;
    final stunde = b.startMinuten ~/ 60;
    jeStunde[stunde] = (jeStunde[stunde] ?? 0) + 1;
  }
  // Bei Gleichstand die frühere Stunde — sonst hinge die Anzeige von der
  // zufälligen Reihenfolge der Map ab.
  final stunden = jeStunde.keys.toList()..sort();
  var beste = stunden.first;
  for (final s in stunden) {
    if (jeStunde[s]! > jeStunde[beste]!) beste = s;
  }
  return BesuchsUebersicht(
    spanneVon: _hhmm(frueheste),
    spanneBis: _hhmm(spaeteste),
    haeufigsteStunde: beste,
    haeufigkeit: jeStunde[beste]!,
  );
}

/// Besuche unterhalb dieser Zahl ergeben kein Fenster: Ein einzelner
/// Sondereinsatz (Hürtel Küssnacht, 19:16) würde es sonst unbrauchbar
/// weit machen.
const _minBesuche = 3;

/// Trennlinie zwischen Vormittags- und Nachmittagsblock.
const _mittag = 12 * 60;

/// Wert an der Perzentil-Stelle [p] einer sortierten Liste.
int _perzentil(List<int> sortiert, double p) =>
    sortiert[((sortiert.length - 1) * p).round()];

String _hhmm(int minuten) {
  final m = minuten.clamp(0, 24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

/// Nach unten auf die viertel Stunde (Fensterbeginn).
int _abRunden(int m) => m - (m % 15);

/// Nach oben auf die viertel Stunde (Fensterende).
int _aufRunden(int m) => m % 15 == 0 ? m : m + (15 - m % 15);

({String? ab, String? bis}) _fenster(List<Besuchszeit> block) {
  if (block.length < _minBesuche) return (ab: null, bis: null);
  final starts = block.map((b) => b.startMinuten).toList()..sort();
  final enden = block.map((b) => b.endeMinuten).toList()..sort();
  return (
    ab: _hhmm(_abRunden(_perzentil(starts, 0.1))),
    bis: _hhmm(_aufRunden(_perzentil(enden, 0.9))),
  );
}

/// Rechnet aus [besuche] je einen Vorschlag für Vormittag und Nachmittag.
ServicezeitVorschlag servicezeitVorschlag(List<Besuchszeit> besuche) {
  final morgen = besuche.where((b) => b.startMinuten < _mittag).toList();
  final nachmittag = besuche.where((b) => b.startMinuten >= _mittag).toList();
  final m = _fenster(morgen);
  final n = _fenster(nachmittag);
  return ServicezeitVorschlag(
    morgenAb: m.ab,
    morgenBis: m.bis,
    nachmittagAb: n.ab,
    nachmittagBis: n.bis,
    morgenBesuche: morgen.length,
    nachmittagBesuche: nachmittag.length,
  );
}
