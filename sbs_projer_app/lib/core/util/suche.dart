/// Die Suche über Betriebe, Personen, Rechnungen und Bereiche (v0.133.0).
///
/// WARUM reines Dart ohne Flutter/Riverpod: Die Regeln (was trifft, in
/// welcher Reihenfolge, wie viele) sind der Teil, der falsch werden kann —
/// hier lassen sie sich ohne Widget und ohne Datenbank prüfen. Der
/// Provider liefert nur die Listen, der Screen nur die Darstellung.
/// Spec: docs/superpowers/specs/2026-09-22-suche-design.md
library;

import 'package:sbs_projer_app/core/util/betrieb_status.dart';

const kSuchMindestLaenge = 2;
const kSuchDeckel = 5;

/// Nach Unicode-Codepunkt (nicht als String-Key), damit [normalisiere]
/// ohne Substring-Allokation pro Zeichen auskommt — siehe dort.
const _ersatz = <int, String>{
  0x00E4: 'a', // ä
  0x00F6: 'o', // ö
  0x00FC: 'u', // ü
  0x00DF: 'ss', // ß
  0x00E0: 'a', // à
  0x00E1: 'a', // á
  0x00E2: 'a', // â
  0x00E9: 'e', // é
  0x00E8: 'e', // è
  0x00EA: 'e', // ê
  0x00EB: 'e', // ë
  0x00EE: 'i', // î
  0x00EF: 'i', // ï
  0x00EC: 'i', // ì
  0x00ED: 'i', // í
  0x00F4: 'o', // ô
  0x00F2: 'o', // ò
  0x00F3: 'o', // ó
  0x00F5: 'o', // õ
  0x00F9: 'u', // ù
  0x00FB: 'u', // û
  0x00FA: 'u', // ú
  0x00E7: 'c', // ç
  0x00F1: 'n', // ñ
};

/// Klein, Umlaute/Akzente aufgelöst, Mehrfach-Leerzeichen zu einem.
///
/// WARUM `codeUnitAt` statt `split('')`: Ein Review-Messwert zeigte ~10 ms
/// VM-Zeit je Aufruf bei ~5000 Datensätzen (am Handy eher 3–5×) — `split('')`
/// legt dafür eine Liste aus Einzelzeichen-Strings an, nur um sie sofort
/// wegzuwerfen. Die Ersatztabelle deckt bewusst nur einzelne UTF-16-Einheiten
/// ab (BMP-Zeichen); das reicht für Umlaute/Akzente in unseren Namen.
String normalisiere(String s) {
  final klein = s.toLowerCase();
  final b = StringBuffer();
  for (var i = 0; i < klein.length; i++) {
    final code = klein.codeUnitAt(i);
    final ersatz = _ersatz[code];
    if (ersatz != null) {
      b.write(ersatz);
    } else {
      b.writeCharCode(code);
    }
  }
  return b.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Telefon als reine Ziffern, in allen drei Schreibweisen — unabhängig
/// davon, ob gespeichert wurde als «+41…», «0041…» oder «0…»:
/// «+41 79 108 41 08» → «0791084108», «41791084108», «0041791084108».
List<String> _telefonVarianten(String? telefon) {
  if (telefon == null || telefon.isEmpty) return const [];
  final ziffern = telefon.replaceAll(RegExp(r'\D'), '');
  if (ziffern.isEmpty) return const [];
  final String national;
  if (ziffern.startsWith('0041')) {
    national = ziffern.substring(4);
  } else if (ziffern.startsWith('41') && ziffern.length > 9) {
    national = ziffern.substring(2);
  } else if (ziffern.startsWith('0')) {
    national = ziffern.substring(1);
  } else {
    // Unbekanntes Format (kein Landes- oder Trunk-Präfix) — so übernehmen,
    // wie gespeichert, statt zu raten.
    national = ziffern;
  }
  if (national.isEmpty) return [ziffern];
  return ['0$national', '41$national', '0041$national'];
}

typedef SuchBetrieb = ({
  String id,
  String name,
  String? ort,
  String? betriebNr,
  String status,
});

typedef SuchPerson = ({
  String id,
  String vorname,
  String? nachname,
  String? telefon,
  String? betriebName,
});

typedef SuchRechnung = ({
  String id,
  String? nummer,
  String? betriebName,
  DateTime datum,
  double brutto,
  String zahlungsstatus,
});

typedef SuchBereich = ({
  String titel,
  String? untertitel,
  String gruppe,
  String ziel,
  List<String> stichwoerter,
});

class SuchEingabe {
  final List<SuchBetrieb> betriebe;
  final List<SuchPerson> personen;
  final List<SuchRechnung> rechnungen;
  final List<SuchBereich> bereiche;

  SuchEingabe({
    required this.betriebe,
    required this.personen,
    required this.rechnungen,
    required this.bereiche,
  });

  // WARUM `late final` statt Neuberechnung in jedem `suche()`-Aufruf: Vorher
  // normalisierte jeder Tastenanschlag alle ~5000 Datensätze neu (siehe
  // Kommentar bei `normalisiere`). `late final` rechnet einmal, beim ersten
  // Zugriff — nicht schon beim Bauen von `SuchEingabe`, das der Provider bei
  // jeder Datenänderung neu erzeugt, auch ausserhalb der Suchseite, wo das
  // Ergebnis nie gebraucht wird.
  late final List<_Kandidat> _betriebeKandidaten = [
    for (final b in betriebe)
      _Kandidat(
        SuchTreffer(
          gruppe: SuchGruppe.betriebe,
          titel: b.name,
          untertitel: b.ort,
          route: '/betriebe/${b.id}',
          status: b.status,
        ),
        [
          normalisiere(b.name),
          normalisiere(b.ort ?? ''),
          normalisiere(b.betriebNr ?? ''),
        ],
        [istBetriebOperativ(b.status) ? 0 : 1, normalisiere(b.name)],
      ),
  ];

  late final List<_Kandidat> _personenKandidaten = [
    for (final p in personen)
      () {
        final name = [p.vorname, p.nachname ?? '']
            .where((s) => s.isNotEmpty)
            .join(' ');
        return _Kandidat(
          SuchTreffer(
            gruppe: SuchGruppe.personen,
            titel: name,
            untertitel: p.betriebName,
            route: '/kontakte/${p.id}/bearbeiten',
            telefon: p.telefon,
          ),
          [
            normalisiere(p.vorname),
            normalisiere(p.nachname ?? ''),
            normalisiere(p.betriebName ?? ''),
            ..._telefonVarianten(p.telefon),
          ],
          [normalisiere(name)],
        );
      }(),
  ];

  late final List<_Kandidat> _rechnungenKandidaten = [
    for (final r in rechnungen)
      _Kandidat(
        SuchTreffer(
          gruppe: SuchGruppe.rechnungen,
          titel: r.nummer ?? 'ohne Nummer',
          untertitel: '${r.betriebName ?? '–'} · '
              '${formatiereBrutto(r.brutto)} · '
              '${zahlungsstatusLesbar(r.zahlungsstatus)}',
          route: '/rechnungen/${r.id}',
        ),
        [normalisiere(r.nummer ?? ''), normalisiere(r.betriebName ?? '')],
        // Neueste zuerst: negativer Zeitstempel sortiert aufsteigend richtig.
        // Bei gleichem Datum (z. B. zwei Rechnungen desselben Tages) sonst
        // eine undefinierte Reihenfolge — zweiter Schlüssel Rechnungsnummer
        // absteigend macht sie stabil.
        [-r.datum.millisecondsSinceEpoch, _Absteigend(r.nummer ?? '')],
      ),
  ];

  late final List<_Kandidat> _bereicheKandidaten = [
    for (final b in bereiche)
      _Kandidat(
        SuchTreffer(
          gruppe: SuchGruppe.bereiche,
          titel: b.titel,
          untertitel: b.gruppe,
          route: b.ziel,
        ),
        [
          normalisiere(b.titel),
          normalisiere(b.untertitel ?? ''),
          for (final s in b.stichwoerter) normalisiere(s),
        ],
        [normalisiere(b.titel)],
      ),
  ];
}

/// Schweizer Zahlenformat mit Tausender-Apostroph, zwei Nachkommastellen —
/// über `toStringAsFixed` statt eigener Rundung, damit Fliesskomma-Reste
/// (13966.089999…) nicht falsch runden.
String formatiereBrutto(double brutto) {
  final fest = brutto.toStringAsFixed(2);
  final negativ = fest.startsWith('-');
  final ohneVorzeichen = negativ ? fest.substring(1) : fest;
  final teile = ohneVorzeichen.split('.');
  final ganzzahl = teile[0];
  final b = StringBuffer();
  for (var i = 0; i < ganzzahl.length; i++) {
    if (i > 0 && (ganzzahl.length - i) % 3 == 0) b.write("'");
    b.write(ganzzahl[i]);
  }
  return '${negativ ? '-' : ''}$b.${teile[1]}';
}

/// Lesbarer Rechnungsstatus für die Trefferzeile — roher Wert («mahnung_1»)
/// ist für den Nutzer nicht selbsterklärend. Unbekannte/künftige Werte
/// kommen unverändert durch, statt eine Zeile zu leeren.
const _zahlungsstatusLabels = <String, String>{
  'offen': 'offen',
  'gesendet': 'gesendet',
  'freigegeben': 'freigegeben',
  'bezahlt': 'bezahlt',
  'erinnert': 'erinnert',
  'mahnung_1': '1. Mahnung',
  'mahnung_2': '2. Mahnung',
  'abgeschrieben': 'abgeschrieben',
};

String zahlungsstatusLesbar(String status) =>
    _zahlungsstatusLabels[status] ?? status;

enum SuchGruppe { betriebe, personen, rechnungen, bereiche }

class SuchTreffer {
  final SuchGruppe gruppe;
  final String titel;
  final String? untertitel;
  final String route;

  /// Nur Personen: für das Anruf-Symbol.
  final String? telefon;

  /// Nur Betriebe: für den Status-Punkt.
  final String? status;

  const SuchTreffer({
    required this.gruppe,
    required this.titel,
    this.untertitel,
    required this.route,
    this.telefon,
    this.status,
  });
}

class SuchGruppenErgebnis {
  final SuchGruppe gruppe;
  final List<SuchTreffer> treffer;

  /// Alle Treffer vor dem Deckel — für «alle N anzeigen».
  final int gesamt;

  const SuchGruppenErgebnis(this.gruppe, this.treffer, this.gesamt);
}

class SuchErgebnis {
  final List<SuchGruppenErgebnis> gruppen;
  const SuchErgebnis(this.gruppen);
  bool get leer => gruppen.isEmpty;
}

/// Ein Kandidat mit seinen normalisierten Suchfeldern.
class _Kandidat {
  final SuchTreffer treffer;
  final List<String> felder;
  final List<Object> sortierung;
  const _Kandidat(this.treffer, this.felder, this.sortierung);
}

/// Hüllt einen String, dessen `compareTo` absteigend statt aufsteigend
/// sortiert — für Sortierschlüssel wie «Rechnungsnummer absteigend als
/// zweites Kriterium», wo eine negative Zahl (wie beim Zeitstempel) nicht
/// geht.
class _Absteigend implements Comparable<_Absteigend> {
  final String wert;
  const _Absteigend(this.wert);
  @override
  int compareTo(_Absteigend other) => other.wert.compareTo(wert);
}

/// 0 = ein Feld beginnt mit dem ersten Wort, 1 = Treffer nur in der Mitte,
/// null = kein Treffer (nicht alle Wörter kommen vor).
int? _rang(List<String> felder, List<String> woerter) {
  final heuhaufen = felder.join(' ');
  for (final w in woerter) {
    if (!heuhaufen.contains(w)) return null;
  }
  return felder.any((f) => f.startsWith(woerter.first)) ? 0 : 1;
}

int _vergleiche(List<Object> a, List<Object> b) {
  for (var i = 0; i < a.length; i++) {
    final c = (a[i] as Comparable).compareTo(b[i]);
    if (c != 0) return c;
  }
  return 0;
}

SuchGruppenErgebnis? _gruppe(
  SuchGruppe g,
  Iterable<_Kandidat> kandidaten,
  List<String> woerter, {
  bool gedeckelt = true,
}) {
  final treffer = <(int, _Kandidat)>[];
  for (final k in kandidaten) {
    final r = _rang(k.felder, woerter);
    if (r != null) treffer.add((r, k));
  }
  if (treffer.isEmpty) return null;
  treffer.sort((a, b) {
    final r = a.$1.compareTo(b.$1);
    return r != 0 ? r : _vergleiche(a.$2.sortierung, b.$2.sortierung);
  });
  final liste = treffer.map((t) => t.$2.treffer).toList();
  return SuchGruppenErgebnis(
    g,
    gedeckelt ? liste.take(kSuchDeckel).toList() : liste,
    liste.length,
  );
}

SuchErgebnis suche(SuchEingabe e, String text) {
  // Ein führendes «+» direkt vor Ziffern («+41 79 108») ist Teil der
  // Landesvorwahl, keine Textsuche — sonst würde die reine-Ziffern-Prüfung
  // unten nie greifen und «+» selbst passt in keinem Feld.
  final ohnePlus = text.replaceFirst(RegExp(r'^\+(?=\d)'), '');
  final q = normalisiere(ohnePlus);
  if (q.length < kSuchMindestLaenge) return const SuchErgebnis([]);
  final woerter = q.split(' ');
  final nurZiffern = RegExp(r'^[0-9 ]+$').hasMatch(q);

  final betriebe = _gruppe(SuchGruppe.betriebe, e._betriebeKandidaten, woerter);
  final personen = _gruppe(SuchGruppe.personen, e._personenKandidaten, woerter);
  final rechnungen =
      _gruppe(SuchGruppe.rechnungen, e._rechnungenKandidaten, woerter);
  final bereiche = _gruppe(
    SuchGruppe.bereiche,
    e._bereicheKandidaten,
    woerter,
    gedeckelt: false,
  );

  // Nur Ziffern: meist eine Rechnungs- oder Betriebsnummer, seltener ein
  // Telefon — die Reihenfolge folgt dem, was man sucht.
  final reihenfolge = nurZiffern
      ? [rechnungen, betriebe, personen, bereiche]
      : [betriebe, personen, rechnungen, bereiche];
  return SuchErgebnis([
    for (final g in reihenfolge)
      if (g != null) g,
  ]);
}

/// Teilt [text] in Stücke; `true` = ein Suchwort trifft (fett darstellen).
/// Vergleicht nur Gross/Klein-unabhängig, ohne Umlaut-Auflösung — die
/// Positionen müssen im Originaltext stimmen. Findet ein Wort nichts, bleibt
/// der Text einfach normal.
List<(String, bool)> markiere(String text, String suchtext) {
  // WARUM zeichenweise statt `text.toLowerCase()` am Stück: Auf Web/JS macht
  // z. B. 'İ'.toLowerCase() aus einem Zeichen zwei (İ → i + Punkt oberhalb).
  // Mit der Gesamtstring-Variante verschieben sich danach alle Indizes
  // gegenüber `text`, und `fett[i]` griff mit einem zu grossen Index daneben
  // → RangeError. Zeichenweise wird ein solches Zeichen unverändert
  // übernommen (nicht kleingeschrieben), damit `klein.length == text.length`
  // garantiert bleibt — es bleibt dann halt bei diesem einen Zeichen
  // gross/klein-empfindlich, was fürs Hervorheben unerheblich ist.
  final kleinBuffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    final k = c.toLowerCase();
    kleinBuffer.write(k.length == 1 ? k : c);
  }
  final klein = kleinBuffer.toString();
  final fett = List<bool>.filled(text.length, false);
  for (final w in suchtext.toLowerCase().trim().split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    var start = klein.indexOf(w);
    while (start != -1) {
      for (var i = start; i < start + w.length; i++) {
        fett[i] = true;
      }
      start = klein.indexOf(w, start + w.length);
    }
  }
  final teile = <(String, bool)>[];
  var i = 0;
  while (i < text.length) {
    final f = fett[i];
    var j = i;
    while (j < text.length && fett[j] == f) {
      j++;
    }
    teile.add((text.substring(i, j), f));
    i = j;
  }
  return teile.isEmpty ? [(text, false)] : teile;
}
