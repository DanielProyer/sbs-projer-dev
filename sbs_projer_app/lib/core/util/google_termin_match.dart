// Reine Matching-Logik für Google-Kalender K2: ordnet einen Termin-Titel
// konservativ einem Betrieb zu (Name + harte Ort-Bestätigung).

enum MatchBucket { eindeutig, mehrdeutig, keinTreffer }

class BetriebKandidat {
  final String betriebId; // serverId
  final String name;
  final String ort;
  const BetriebKandidat({
    required this.betriebId,
    required this.name,
    required this.ort,
  });
}

class TerminMatch {
  final MatchBucket bucket;
  final BetriebKandidat? treffer; // gesetzt bei eindeutig
  final List<BetriebKandidat> kandidaten; // gültige Kandidaten (bei mehrdeutig ≥2)
  final String grund;
  const TerminMatch({
    required this.bucket,
    this.treffer,
    this.kandidaten = const [],
    required this.grund,
  });
}

/// Umlaut-/Akzent-Faltung auf ASCII-Basis.
String _falte(String s) {
  const map = {
    'ä': 'a', 'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a',
    'ö': 'o', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o',
    'ü': 'u', 'ù': 'u', 'ú': 'u', 'û': 'u',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ç': 'c', 'ñ': 'n', 'ß': 'ss',
  };
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(map[ch] ?? ch);
  }
  return b.toString();
}

/// Normalisiert beliebigen Text: falten, Satzzeichen -> Space, Whitespace-Kollaps.
String normalisiereText(String s) {
  final gefaltet = _falte(s);
  final ersetzt = gefaltet.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return ersetzt.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Ort zusätzlich: Teil vor '/' oder '-' nehmen, Davos-Suffix entfernen.
String normalisiereOrt(String s) {
  final vor = s.split('/').first.split('-').first;
  var n = normalisiereText(vor);
  if (n.startsWith('davos')) n = 'davos';
  if (n.isEmpty) n = normalisiereText(s);
  return n;
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final prev = List<int>.generate(b.length + 1, (i) => i);
  final cur = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    cur[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      cur[j + 1] = [cur[j] + 1, prev[j + 1] + 1, prev[j] + cost]
          .reduce((x, y) => x < y ? x : y);
    }
    for (var j = 0; j <= b.length; j++) {
      prev[j] = cur[j];
    }
  }
  return prev[b.length];
}

/// Kommt [needle] (normalisiert, Token-Folge) im [haystackTokens] vor — exakt
/// oder mit ≤[maxDist] Editierdistanz über ein gleitendes Fenster?
bool _enthaelt(List<String> haystackTokens, String needle, int maxDist) {
  final needleTokens = needle.split(' ');
  final n = needleTokens.length;
  if (n == 0 || haystackTokens.length < n) return false;
  for (var i = 0; i + n <= haystackTokens.length; i++) {
    final fenster = haystackTokens.sublist(i, i + n).join(' ');
    if (fenster == needle) return true;
    if (_levenshtein(fenster, needle) <= maxDist) return true;
  }
  return false;
}

int _maxTippfehler(String normName) =>
    normName.replaceAll(' ', '').length <= 6 ? 1 : 2;

/// Matcht einen Titel gegen die Betriebe. Konservativ:
/// Name (exakt/≤Tippfehler) UND Ort (exakt/≤1) müssen im Titel stehen.
TerminMatch matcheTitel(String titel, List<BetriebKandidat> betriebe) {
  final normTitel = normalisiereText(titel);
  if (normTitel.isEmpty) {
    return const TerminMatch(
        bucket: MatchBucket.keinTreffer, grund: 'Leerer Titel');
  }
  final titelTokens = normTitel.split(' ');
  final gueltig = <BetriebKandidat>[];
  for (final b in betriebe) {
    final normName = normalisiereText(b.name);
    if (normName.isEmpty) continue;
    if (!_enthaelt(titelTokens, normName, _maxTippfehler(normName))) continue;
    final normOrt = normalisiereOrt(b.ort);
    if (normOrt.isEmpty) continue;
    if (!_enthaelt(titelTokens, normOrt, 1)) continue;
    gueltig.add(b);
  }
  if (gueltig.isEmpty) {
    return const TerminMatch(
        bucket: MatchBucket.keinTreffer,
        grund: 'Kein Betrieb mit Name + Ort erkannt');
  }
  if (gueltig.length == 1) {
    return TerminMatch(
        bucket: MatchBucket.eindeutig,
        treffer: gueltig.first,
        kandidaten: gueltig,
        grund: 'Name + Ort eindeutig');
  }
  return TerminMatch(
      bucket: MatchBucket.mehrdeutig,
      kandidaten: gueltig,
      grund: '${gueltig.length} mögliche Betriebe');
}
