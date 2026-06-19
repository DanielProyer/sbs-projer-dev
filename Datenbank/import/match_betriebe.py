"""Mappt Excel-Betriebsnamen auf betrieb_id (exakt/fuzzy/alias).
Aufruf: python match_betriebe.py --selftest
build_betrieb_index() laedt in/betriebe.json + betrieb_aliase.csv.
"""
import csv, json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))


# Excel transliteriert Umlaute/Akzente teils (ü->ue, é->e). Beidseitig auf ASCII falten.
_FOLD = str.maketrans({
    'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss',
    'à': 'a', 'á': 'a', 'â': 'a', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ò': 'o', 'ó': 'o', 'ô': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ç': 'c', 'ñ': 'n', '‘': "'", '’': "'", '`': "'",
})


def _norm(s):
    s = (s or '').lower().strip().translate(_FOLD)
    return re.sub(r'\s+', ' ', s)


IGNORE = {'gmbh', 'ag', 'und', 'the', 'zum', 'zur', 'der', 'die', 'das', 'von',
          'restaurant', 'hotel', 'bar'}


def _words(s):
    return {w for w in re.split(r'[\s,.\-/+&]+', _norm(s)) if len(w) >= 3 and w not in IGNORE}


def build_betrieb_index():
    with open(os.path.join(HERE, 'in', 'betriebe.json'), encoding='utf-8') as f:
        rows = [{'id': r['id'], 'name': r['name'], 'ort': r.get('ort', '') or ''}
                for r in json.load(f)]
    aliase = {}
    ap = os.path.join(HERE, 'betrieb_aliase.csv')
    if os.path.exists(ap):
        with open(ap, encoding='utf-8') as f:
            for r in csv.DictReader(f, delimiter=';'):
                if r.get('excel_name') and r.get('betrieb_id'):
                    aliase[_norm(r['excel_name'])] = r['betrieb_id']
    return rows, aliase


def match(name, ort, rows, aliase):
    n = _norm(name)
    if n in aliase:
        return aliase[n], 100
    for b in rows:                                  # exakt
        if _norm(b['name']) == n:
            return b['id'], 100
    nd = n.replace(' ', '')                          # despaced-exakt (Pop Corn==Popcorn)
    for b in rows:
        if _norm(b['name']).replace(' ', '') == nd:
            return b['id'], 95
    for b in rows:                                  # contains
        bn = _norm(b['name'])
        if bn and (n in bn or bn in n):
            return b['id'], 80
    nw = _words(name)                                # wort-overlap (+ort-bonus)
    best, bs = None, 0
    for b in rows:
        ov = len(nw & _words(b['name']))
        sc = ov * 30 + (10 if _norm(b['ort']) == _norm(ort) and ort else 0)
        if ov >= 2 and sc > bs:
            bs, best = sc, b['id']
    return (best, bs) if best else (None, 0)


def _selftest():
    rows = [{'id': 'X', 'name': 'Restaurant Hemingway', 'ort': 'Chur'},
            {'id': 'Y', 'name': 'Alte Post', 'ort': 'Davos'}]
    assert match('Hemingway', 'Chur', rows, {})[0] == 'X'        # contains
    assert match('Alte Post', 'Davos', rows, {})[0] == 'Y'       # exakt
    assert match('Unbekannt XY', 'Zug', rows, {})[0] is None     # kein match
    assert match('Foo', 'Zug', rows, {'foo': 'Z'})[0] == 'Z'     # alias
    # echte Daten ladbar
    real, _ = build_betrieb_index()
    assert len(real) > 250, len(real)
    print('OK', len(real), 'Betriebe')


if __name__ == '__main__':
    _selftest()
