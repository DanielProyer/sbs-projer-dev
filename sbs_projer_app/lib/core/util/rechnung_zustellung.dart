/// Baut den Anzeigetext für die Zustellung einer Rechnung aus den beiden
/// unabhängigen Zeitpunkten `uebergebenAm` (persönlich am Tresen) und
/// `versendetAm` (Mail/Post). Beide können nebeneinander stehen — eine
/// Tresen-Übergabe schliesst einen späteren Mailversand nicht aus.
///
/// - Beide gesetzt: "Übergeben 07.07.2026 · Versendet 04.08.2026"
/// - Nur übergeben: "Übergeben 07.07.2026"
/// - Nur versendet: "Versendet 04.08.2026"
/// - Keines gesetzt: "—"
String zustellungsText({DateTime? uebergebenAm, DateTime? versendetAm}) {
  final teile = <String>[
    if (uebergebenAm != null) 'Übergeben ${_formatDatum(uebergebenAm)}',
    if (versendetAm != null) 'Versendet ${_formatDatum(versendetAm)}',
  ];
  if (teile.isEmpty) return '—';
  return teile.join(' · ');
}

String _formatDatum(DateTime datum) {
  final tag = datum.day.toString().padLeft(2, '0');
  final monat = datum.month.toString().padLeft(2, '0');
  return '$tag.$monat.${datum.year}';
}
