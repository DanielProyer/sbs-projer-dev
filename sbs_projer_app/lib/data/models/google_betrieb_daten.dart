/// Normalisierte Betrieb-Daten aus einem Google-Places-Resultat.
class GoogleBetriebDaten {
  final String? name;
  final String? strasse;
  final String? nr;
  final String? plz;
  final String? ort;
  final String? telefon;
  final String? website;
  final double? latitude;
  final double? longitude;
  final String? mapsUri;

  /// App-Format: Wochentag ('Mo'..'So') -> Liste {'von':'HH:MM','bis':'HH:MM'}.
  final Map<String, List<Map<String, String>>> oeffnungszeiten;

  /// Wochentage ('Mo'..'So'), die laut Google geschlossen sind.
  final List<String> ruhetage;

  GoogleBetriebDaten({
    this.name,
    this.strasse,
    this.nr,
    this.plz,
    this.ort,
    this.telefon,
    this.website,
    this.latitude,
    this.longitude,
    this.mapsUri,
    required this.oeffnungszeiten,
    required this.ruhetage,
  });
}

/// Google-`open.day` (0=So..6=Sa) -> App-Wochentag-Kürzel.
const _googleDayToTag = {
  0: 'So',
  1: 'Mo',
  2: 'Di',
  3: 'Mi',
  4: 'Do',
  5: 'Fr',
  6: 'Sa',
};

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

String? _addressComponent(List components, String type) {
  for (final c in components) {
    final types = (c['types'] as List?)?.map((t) => t.toString()) ?? const [];
    if (types.contains(type)) {
      return c['longText']?.toString() ?? c['shortText']?.toString();
    }
  }
  return null;
}

String _hhmm(Map timePoint) {
  final h = (timePoint['hour'] as num?)?.toInt() ?? 0;
  final m = (timePoint['minute'] as num?)?.toInt() ?? 0;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Wandelt ein rohes Google-Place-Objekt in [GoogleBetriebDaten] um.
GoogleBetriebDaten betriebAusGooglePlace(Map place) {
  final components = (place['addressComponents'] as List?) ?? const [];

  final loc = place['location'];
  double? lat, lng;
  if (loc is Map) {
    lat = (loc['latitude'] as num?)?.toDouble();
    lng = (loc['longitude'] as num?)?.toDouble();
  }

  final oeffnungszeiten = <String, List<Map<String, String>>>{
    for (final t in _wochentage) t: [],
  };
  final ruhetage = <String>[];

  final oh = place['regularOpeningHours'];
  if (oh is Map && oh['periods'] is List) {
    for (final p in (oh['periods'] as List)) {
      if (p is! Map) continue;
      final open = p['open'];
      final close = p['close'];
      if (open is! Map) continue;
      final tag = _googleDayToTag[(open['day'] as num?)?.toInt()];
      if (tag == null) continue;
      oeffnungszeiten[tag]!.add({
        'von': _hhmm(open),
        'bis': close is Map ? _hhmm(close) : '',
      });
    }
    for (final t in _wochentage) {
      if (oeffnungszeiten[t]!.isEmpty) ruhetage.add(t);
    }
  }

  return GoogleBetriebDaten(
    name: place['displayName'] is Map
        ? place['displayName']['text']?.toString()
        : null,
    strasse: _addressComponent(components, 'route'),
    nr: _addressComponent(components, 'street_number'),
    plz: _addressComponent(components, 'postal_code'),
    ort: _addressComponent(components, 'locality'),
    telefon: place['nationalPhoneNumber']?.toString() ??
        place['internationalPhoneNumber']?.toString(),
    website: place['websiteUri']?.toString(),
    latitude: lat,
    longitude: lng,
    mapsUri: place['googleMapsUri']?.toString(),
    oeffnungszeiten: oeffnungszeiten,
    ruhetage: ruhetage,
  );
}

/// Baut [GoogleBetriebDaten] (nur Öffnungszeiten + Ruhetage) aus dem JSON der
/// Edge-Function `parse-oeffnungszeiten` (Website-Fallback via AI).
/// Erwartetes Format: `{'oeffnungszeiten': {'Mo': [{'von','bis'}], ...},
/// 'ruhetage': ['Di', ...]}`. Ruhetage werden NICHT aus leeren Tagen abgeleitet
/// (nur was die KI explizit als geschlossen meldet).
GoogleBetriebDaten oeffnungszeitenAusWebsiteJson(Map json) {
  final oeffnungszeiten = <String, List<Map<String, String>>>{
    for (final t in _wochentage) t: [],
  };
  final rawOz = json['oeffnungszeiten'];
  if (rawOz is Map) {
    for (final t in _wochentage) {
      final slots = rawOz[t];
      if (slots is! List) continue;
      for (final s in slots) {
        if (s is! Map) continue;
        final von = s['von']?.toString() ?? '';
        final bis = s['bis']?.toString() ?? '';
        if (von.isEmpty) continue;
        oeffnungszeiten[t]!.add({'von': von, 'bis': bis});
      }
    }
  }
  final ruhetage = <String>[];
  final rawRuhe = json['ruhetage'];
  if (rawRuhe is List) {
    for (final r in rawRuhe) {
      final t = r.toString();
      if (_wochentage.contains(t)) ruhetage.add(t);
    }
  }
  return GoogleBetriebDaten(
    oeffnungszeiten: oeffnungszeiten,
    ruhetage: ruhetage,
  );
}
