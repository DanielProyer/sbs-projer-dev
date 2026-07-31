/// Reine Formatierungs-Funktionen für die Prüfliste `betrieb_vorschlaege`
/// (Spec docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md,
/// Abschnitt "Prüfliste").
///
/// Wandelt die rohen jsonb-Werte (`alt_wert`/`neu_wert`) je nach `feld` in
/// eine lesbare Zeile um — nie rohes JSON in der Oberfläche.
library;

const _wochentagOrder = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

const _kKeineAngabe = 'keine Angabe';

/// Google-`businessStatus`-Werte, die einen `feld == 'status'`-Vorschlag
/// auslösen (siehe Spec Abschnitt "F + Google").
const _statusText = {
  'CLOSED_TEMPORARILY': 'bei Google vorübergehend geschlossen',
  'CLOSED_PERMANENTLY': 'bei Google dauerhaft geschlossen',
  'OPERATIONAL': 'bei Google als geöffnet gemeldet',
};

/// Formatiert `alt_wert`/`neu_wert` eines `betrieb_vorschlaege`-Eintrags für
/// [feld] als lesbare Zeile. [wert] ist das per Supabase dekodierte jsonb
/// (also `Map`, `List`, `String`, `num`, `bool` oder `null`).
String vorschlagWertAnzeige(String feld, dynamic wert) {
  switch (feld) {
    case 'ruhetage':
      return _formatRuhetage(wert);
    case 'oeffnungszeiten':
      return _formatOeffnungszeiten(wert);
    case 'ferien':
      return _formatFerien(wert);
    case 'saison':
      return _formatSaison(wert);
    case 'status':
      return _formatStatus(wert);
    default:
      return wert?.toString() ?? _kKeineAngabe;
  }
}

/// Menschlich lesbares Label für ein `feld` der Prüfliste.
String vorschlagFeldLabel(String feld) {
  switch (feld) {
    case 'ruhetage':
      return 'Ruhetage';
    case 'oeffnungszeiten':
      return 'Öffnungszeiten';
    case 'ferien':
      return 'Betriebsferien';
    case 'saison':
      return 'Saison';
    case 'status':
      return 'Status';
    default:
      return feld;
  }
}

/// Menschlich lesbares Label für eine `quelle` der Prüfliste.
String vorschlagQuelleLabel(String quelle) {
  switch (quelle) {
    case 'google':
      return 'Google';
    case 'website':
      return 'Website';
    case 'google_website':
      return 'Google + Website';
    default:
      return quelle;
  }
}

String _dd(DateTime d) => d.day.toString().padLeft(2, '0');
String _mm(DateTime d) => d.month.toString().padLeft(2, '0');
String _kurz(DateTime d) => '${_dd(d)}.${_mm(d)}.';
String _lang(DateTime d) => '${_dd(d)}.${_mm(d)}.${d.year}';

DateTime? _parseDatum(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
}

String _formatRuhetage(dynamic wert) {
  if (wert is! List) return _kKeineAngabe;
  if (wert.isEmpty) return 'kein Ruhetag';
  return wert.map((t) => t.toString()).join(', ');
}

String _formatOeffnungszeiten(dynamic wert) {
  if (wert is! Map) return _kKeineAngabe;
  final zeilen = <String>[];
  for (final tag in _wochentagOrder) {
    final slots = wert[tag];
    if (slots is! List || slots.isEmpty) continue;
    final slotsStr = slots
        .whereType<Map>()
        .map((s) => '${s['von'] ?? '?'}–${s['bis'] ?? '?'}')
        .join(', ');
    if (slotsStr.isEmpty) continue;
    zeilen.add('$tag $slotsStr');
  }
  if (zeilen.isEmpty) return _kKeineAngabe;
  return zeilen.join(' · ');
}

String _formatFerien(dynamic wert) {
  if (wert is! List || wert.isEmpty) return _kKeineAngabe;
  final teile = <String>[];
  for (final p in wert.whereType<Map>()) {
    final von = _parseDatum(p['von']);
    final bis = _parseDatum(p['bis']);
    if (von == null || bis == null) continue;
    teile.add(
      von.year == bis.year
          ? '${_kurz(von)}–${_lang(bis)}'
          : '${_lang(von)}–${_lang(bis)}',
    );
  }
  if (teile.isEmpty) return _kKeineAngabe;
  return teile.join('; ');
}

/// Saison-Vorschlaege tragen bewusst NUR Tag und Monat, nie ein Jahr:
/// Kundenwebsites schreiben «Sommersaison 15. Juni bis 20. Oktober», und ein
/// Winterfenster laeuft ueber den Jahreswechsel. Die Jahreszuordnung macht
/// erst die Uebernahme mit `saisonFenster()` aus core/util/saison_jahr.dart.
///
/// Erwartete Form: `{"sommer": {"von_tag":15,"von_monat":6,"bis_tag":20,
/// "bis_monat":10}, "winter": null}`. Der Ist-Zustand des Betriebs kommt als
/// dieselbe Struktur herein, aus den vier Datumsspalten reduziert.
String _formatSaison(dynamic wert) {
  if (wert is! Map) return _kKeineAngabe;
  final teile = <String>[];
  final sommer = _saisonFenstertext(wert['sommer']);
  final winter = _saisonFenstertext(wert['winter']);
  if (sommer != null) {
    teile.add(winter != null ? 'Sommer $sommer' : sommer);
  }
  if (winter != null) {
    teile.add(sommer != null ? 'Winter $winter' : winter);
  }
  if (teile.isEmpty) return _kKeineAngabe;
  return teile.join(' / ');
}

/// «15.06.–20.10.» aus einem Tag/Monat-Fenster, oder null wenn unvollstaendig.
String? _saisonFenstertext(dynamic fenster) {
  if (fenster is! Map) return null;
  final vonTag = _alsZahl(fenster['von_tag']);
  final vonMonat = _alsZahl(fenster['von_monat']);
  final bisTag = _alsZahl(fenster['bis_tag']);
  final bisMonat = _alsZahl(fenster['bis_monat']);
  if (vonTag == null ||
      vonMonat == null ||
      bisTag == null ||
      bisMonat == null) {
    return null;
  }
  return '${_zwei(vonTag)}.${_zwei(vonMonat)}.–${_zwei(bisTag)}.${_zwei(bisMonat)}.';
}

int? _alsZahl(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String _zwei(int n) => n.toString().padLeft(2, '0');

String _formatStatus(dynamic wert) {
  final status = wert is Map ? wert['status']?.toString() : wert?.toString();
  if (status == null || status.isEmpty) return _kKeineAngabe;
  return _statusText[status] ?? status;
}
