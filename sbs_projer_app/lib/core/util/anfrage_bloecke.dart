/// Blockgrösse für `inFilter`-Anfragen mit Id-Listen.
///
/// WARUM 50: PostgREST bekommt die Liste als GET-Parameter — jede UUID
/// kostet rund 45 Zeichen in der URL. 200 Ids waren 9 KB; im Funkloch am
/// Berghaus (16.09.2026, Sartons) brach «Failed to fetch» den Nachlauf ab,
/// und die Meldung zeigte Daniel eine bildschirmfüllende URL. 50 Ids sind
/// gut 2 KB — was auf schwachem Netz noch durchgeht. Die Zahl steht hier
/// einmal; `test/in_filter_block_test.dart` hält sie.
const int kInFilterBlock = 50;

/// Kürzt eine Ausnahme auf das, was auf dem Handy hilft: «keine Verbindung»
/// oder «Zeitüberschreitung» statt einer URL mit siebzig UUIDs.
String kurzeFehlermeldung(Object e) {
  final t = e.toString();
  if (t.contains('Failed to fetch') ||
      t.contains('ClientException') ||
      t.contains('SocketException')) {
    return 'keine Verbindung';
  }
  if (t.contains('TimeoutException')) return 'Zeitüberschreitung';
  final kurz = t.split('\n').first;
  return kurz.length > 80 ? '${kurz.substring(0, 80)}…' : kurz;
}
