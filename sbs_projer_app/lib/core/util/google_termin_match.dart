// Reine Matching-Logik für Google-Kalender K2: ordnet einen Termin-Titel
// konservativ einem Betrieb zu (Anker-Name + Ort, mit Gattungswort-Toleranz),
// und klassifiziert Privates (Geburtstag/Ferien) sowie Pikett vorab.

enum MatchBucket { eindeutig, mehrdeutig, keinTreffer, privat, pikett }

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

/// Gattungswörter, die für das Matching NICHT als unterscheidend zählen
/// (Betrieb heisst „Gasthof Löwen", Kalender-Titel oft nur „Löwen").
const _stopwords = {
  'restaurant', 'hotel', 'gasthof', 'gasthaus', 'pizzeria', 'cafe', 'kaffee',
  'pension', 'hostellerie', 'bistro', 'osteria', 'trattoria', 'taverne',
  'motel', 'openair', 'beizli',
};

/// Titel-Stichwörter, die einen Eintrag als privat/ausgeschlossen markieren.
const _privatKeywords = [
  'geburtstag', 'geburi', 'birthday', 'ferien', 'urlaub',
];

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

/// Kommt [needle] als EXAKTE Token-Folge im [haystackTokens] vor?
bool _enthaeltExakt(List<String> haystackTokens, String needle) {
  if (needle.isEmpty) return false;
  final nt = needle.split(' ');
  final n = nt.length;
  for (var i = 0; i + n <= haystackTokens.length; i++) {
    if (haystackTokens.sublist(i, i + n).join(' ') == needle) return true;
  }
  return false;
}

/// Kommt [needle] (normalisiert, Token-Folge) im [haystackTokens] vor — exakt
/// oder mit ≤[maxDist] Editierdistanz über ein gleitendes Fenster?
bool _enthaelt(List<String> haystackTokens, String needle, int maxDist) {
  if (needle.isEmpty) return false;
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

int _maxTippfehler(String s) => s.replaceAll(' ', '').length <= 6 ? 1 : 2;

/// Unterscheidende Namens-Tokens (ohne Gattungswörter, Länge ≥ 3).
List<String> _distinctiveTokens(String name) {
  final norm = normalisiereText(name);
  if (norm.isEmpty) return const [];
  final toks = norm.split(' ');
  final dist =
      toks.where((t) => t.length >= 3 && !_stopwords.contains(t)).toList();
  if (dist.isEmpty) {
    return toks.where((t) => t.length >= 3).toList();
  }
  return dist;
}

/// Anker = längstes unterscheidendes Token (>= 3 Zeichen), das NICHT gleich dem
/// eigenen Ort ist. Sonst null. So kapert z.B. „Hotel Chur" (Ort Chur) keine
/// „Chur - X"-Titel, weil sein einziges Token = der Ort ist.
String? _anchor(String name, String ort) {
  final ortTokens = normalisiereText(ort).split(' ').toSet();
  final dist = _distinctiveTokens(name)
      .where((t) => !ortTokens.contains(t))
      .toList();
  if (dist.isEmpty) return null;
  dist.sort((a, b) => b.length.compareTo(a.length));
  return dist.first;
}

String _distinctiveName(String name) => _distinctiveTokens(name).join(' ');

bool _istPrivat(String normTitle) =>
    _privatKeywords.any((k) => normTitle.contains(k));

bool _ortImTitel(String ort, List<String> titleTokens, String compactTitle) {
  final normOrt = normalisiereOrt(ort);
  if (normOrt.isEmpty) return false;
  if (_enthaelt(titleTokens, normOrt, 1)) return true;
  final compactOrt = normOrt.replaceAll(' ', '');
  if (compactOrt.length >= 4 && compactTitle.contains(compactOrt)) return true;
  return false;
}

class _Kand {
  final BetriebKandidat b;
  final bool ortOk;
  final bool nameStark; // voller unterscheidender Name zusammenhängend im Titel
  final bool unique; // Anker-Token global eindeutig
  final bool anchorExakt; // Anker exakt (nicht nur fuzzy) im Titel
  _Kand(this.b, this.ortOk, this.nameStark, this.unique, this.anchorExakt);
}

/// Matcht einen Titel gegen die Betriebe. Reihenfolge: privat → pikett →
/// Anker-Name + Ort. Ohne Ort nur bei global eindeutigem Namen.
TerminMatch matcheTitel(String titel, List<BetriebKandidat> betriebe) {
  final normTitle = normalisiereText(titel);
  if (normTitle.isEmpty) {
    return const TerminMatch(bucket: MatchBucket.keinTreffer, grund: 'Leerer Titel');
  }
  if (_istPrivat(normTitle)) {
    return const TerminMatch(
        bucket: MatchBucket.privat, grund: 'Privat (ausgeschlossen)');
  }
  if (normTitle.contains('pikett')) {
    return const TerminMatch(bucket: MatchBucket.pikett, grund: 'Pikett');
  }

  final titleTokens = normTitle.split(' ');
  final compactTitle = normTitle.replaceAll(' ', '');

  final anchorCount = <String, int>{};
  for (final b in betriebe) {
    final a = _anchor(b.name, b.ort);
    if (a != null) anchorCount[a] = (anchorCount[a] ?? 0) + 1;
  }

  final treffer = <_Kand>[];
  for (final b in betriebe) {
    final a = _anchor(b.name, b.ort);
    if (a == null) continue;
    final exakt = _enthaeltExakt(titleTokens, a);
    if (!exakt && !_enthaelt(titleTokens, a, _maxTippfehler(a))) continue;
    final ortOk = _ortImTitel(b.ort, titleTokens, compactTitle);
    final dist = _distinctiveName(b.name);
    final nameStark = _enthaelt(titleTokens, dist, _maxTippfehler(dist));
    treffer.add(_Kand(b, ortOk, nameStark, anchorCount[a] == 1, exakt));
  }

  if (treffer.isEmpty) {
    return const TerminMatch(
        bucket: MatchBucket.keinTreffer, grund: 'Kein Betrieb erkannt');
  }

  final withOrt = treffer.where((k) => k.ortOk).toList();
  if (withOrt.isNotEmpty) {
    final stark = withOrt.where((k) => k.nameStark).toList();
    if (stark.length == 1) {
      return TerminMatch(
          bucket: MatchBucket.eindeutig,
          treffer: stark.first.b,
          kandidaten: [stark.first.b],
          grund: 'Name + Ort');
    }
    if (withOrt.length == 1) {
      return TerminMatch(
          bucket: MatchBucket.eindeutig,
          treffer: withOrt.first.b,
          kandidaten: [withOrt.first.b],
          grund: 'Name + Ort');
    }
    return TerminMatch(
        bucket: MatchBucket.mehrdeutig,
        kandidaten: withOrt.map((k) => k.b).toList(),
        grund: '${withOrt.length} mögliche Betriebe');
  }

  // Kein Ort im Titel: nur EXAKTE Anker-Treffer zählen (Fuzzy-Rauschen wie
  // "crusch"~"grusch" ignorieren), und nur bei genau 1 mit global eindeutigem Namen.
  final exakteTreffer = treffer.where((k) => k.anchorExakt).toList();
  if (exakteTreffer.length == 1 && exakteTreffer.first.unique) {
    return TerminMatch(
        bucket: MatchBucket.eindeutig,
        treffer: exakteTreffer.first.b,
        kandidaten: [exakteTreffer.first.b],
        grund: 'Name eindeutig (Ort fehlt im Titel)');
  }
  return const TerminMatch(
      bucket: MatchBucket.keinTreffer,
      grund: 'Name erkannt, Ort fehlt/mehrdeutig');
}
