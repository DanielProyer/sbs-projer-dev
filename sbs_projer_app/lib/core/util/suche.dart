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

const _ersatz = {
  'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss',
  'à': 'a', 'á': 'a', 'â': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'ô': 'o', 'ù': 'u', 'û': 'u', 'ç': 'c',
};

/// Klein, Umlaute/Akzente aufgelöst, Mehrfach-Leerzeichen zu einem.
String normalisiere(String s) {
  final b = StringBuffer();
  for (final z in s.toLowerCase().split('')) {
    b.write(_ersatz[z] ?? z);
  }
  return b.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Telefon als reine Ziffern, in beiden Schreibweisen (+41… und 0…):
/// «+41 79 108 41 08» → «41791084108» und «0791084108».
List<String> _telefonVarianten(String? telefon) {
  if (telefon == null || telefon.isEmpty) return const [];
  final ziffern = telefon.replaceAll(RegExp(r'\D'), '');
  if (ziffern.startsWith('41') && ziffern.length > 9) {
    return [ziffern, '0${ziffern.substring(2)}'];
  }
  if (ziffern.startsWith('0041')) {
    return [ziffern, '0${ziffern.substring(4)}'];
  }
  return [ziffern];
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

  const SuchEingabe({
    required this.betriebe,
    required this.personen,
    required this.rechnungen,
    required this.bereiche,
  });
}

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
    final x = a[i], y = b[i];
    final c = x is num && y is num
        ? x.compareTo(y)
        : x.toString().compareTo(y.toString());
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
  final q = normalisiere(text);
  if (q.length < kSuchMindestLaenge) return const SuchErgebnis([]);
  final woerter = q.split(' ');
  final nurZiffern = RegExp(r'^[0-9 ]+$').hasMatch(q);

  final betriebe = _gruppe(SuchGruppe.betriebe, [
    for (final b in e.betriebe)
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
  ], woerter);

  final personen = _gruppe(SuchGruppe.personen, [
    for (final p in e.personen)
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
  ], woerter);

  final rechnungen = _gruppe(SuchGruppe.rechnungen, [
    for (final r in e.rechnungen)
      _Kandidat(
        SuchTreffer(
          gruppe: SuchGruppe.rechnungen,
          titel: r.nummer ?? 'ohne Nummer',
          untertitel: '${r.betriebName ?? '–'} · '
              '${r.brutto.toStringAsFixed(2)} · ${r.zahlungsstatus}',
          route: '/rechnungen/${r.id}',
        ),
        [normalisiere(r.nummer ?? ''), normalisiere(r.betriebName ?? '')],
        // Neueste zuerst: negativer Zeitstempel sortiert aufsteigend richtig.
        [-r.datum.millisecondsSinceEpoch],
      ),
  ], woerter);

  final bereiche = _gruppe(
    SuchGruppe.bereiche,
    [
      for (final b in e.bereiche)
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
    ],
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
  final klein = text.toLowerCase();
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
