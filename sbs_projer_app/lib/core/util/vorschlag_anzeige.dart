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

String _formatSaison(dynamic wert) {
  if (wert is! Map) return _kKeineAngabe;
  final teile = <String>[];
  final sommerVon = _parseDatum(wert['sommer_start_datum']);
  final sommerBis = _parseDatum(wert['sommer_ende_datum']);
  final winterVon = _parseDatum(wert['winter_start_datum']);
  final winterBis = _parseDatum(wert['winter_ende_datum']);
  final hatSommer = sommerVon != null && sommerBis != null;
  final hatWinter = winterVon != null && winterBis != null;
  if (hatSommer) {
    teile.add(
      hatWinter
          ? 'Sommer ${_kurz(sommerVon)}–${_kurz(sommerBis)}'
          : '${_kurz(sommerVon)}–${_kurz(sommerBis)}',
    );
  }
  if (hatWinter) {
    teile.add(
      hatSommer
          ? 'Winter ${_kurz(winterVon)}–${_kurz(winterBis)}'
          : '${_kurz(winterVon)}–${_kurz(winterBis)}',
    );
  }
  if (teile.isEmpty) return _kKeineAngabe;
  return teile.join(' / ');
}

String _formatStatus(dynamic wert) {
  final status = wert is Map ? wert['status']?.toString() : wert?.toString();
  if (status == null || status.isEmpty) return _kKeineAngabe;
  return _statusText[status] ?? status;
}
