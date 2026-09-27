/// Supabase-DTO für eine eigene Aufgabe (Tabelle `aufgaben`, `typ =
/// 'eigene'`, Migration 150 + 212).
///
/// Dieselbe Tabelle trägt auch Marker- und Snooze-Zeilen der automatischen
/// Aufgaben — die haben weder Titel noch Betrieb und laufen weiter als rohe
/// Zeilen durch `baueAufgabenListe`. Dieses DTO ist nur für die eigenen
/// Aufgaben, die Daniel anlegt, bearbeitet und einem Betrieb zuordnet.
///
/// Web/Supabase only — kein Isar (Aufgaben sind nie offline gelaufen, und
/// Isar ist eingefroren).
class EigeneAufgabe {
  /// Leer bei einer Aufgabe, die erst angelegt wird.
  final String id;
  final String titel;

  /// Kalendertag (Spalte `date`), ohne Uhrzeit.
  final DateTime? faelligAm;
  final DateTime? erledigtAm;

  /// Betriebsbezug (Migration 212, Entscheid Daniel 27.09.2026). Optional:
  /// «Steuererklärung einreichen» gehört zu keinem Betrieb.
  final String? betriebId;

  const EigeneAufgabe({
    this.id = '',
    required this.titel,
    this.faelligAm,
    this.erledigtAm,
    this.betriebId,
  });

  bool get erledigt => erledigtAm != null;

  factory EigeneAufgabe.fromJson(Map<String, dynamic> json) {
    final titel = (json['titel'] as String?)?.trim();
    final betriebId = (json['betrieb_id'] as String?)?.trim();
    return EigeneAufgabe(
      id: json['id'] as String? ?? '',
      titel: titel == null || titel.isEmpty ? '?' : titel,
      faelligAm: DateTime.tryParse(json['faellig_am'] as String? ?? ''),
      erledigtAm: DateTime.tryParse(json['erledigt_am'] as String? ?? ''),
      betriebId: betriebId == null || betriebId.isEmpty ? null : betriebId,
    );
  }

  /// Die Felder, die die App schreibt — beim Anlegen und beim Bearbeiten.
  /// `id`, `user_id`, `typ` und `erledigt_am` setzt das Repository selbst.
  ///
  /// `betrieb_id` steht immer drin, auch als `null`: Beim Bearbeiten heisst
  /// `null` «Betrieb entfernt», und das muss in der Zeile ankommen.
  Map<String, dynamic> toJson() => {
    'titel': titel,
    'faellig_am': faelligAm == null ? null : _datumsText(faelligAm!),
    'betrieb_id': betriebId,
  };
}

/// «2026-09-28» — der Kalendertag, wie ihn eine `date`-Spalte erwartet.
/// Aus den Feldern gebaut, nie über `toUtc()`: Ein lokales Mitternachtsdatum
/// rutschte sonst in der Sommerzeit auf den Vortag.
String _datumsText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
