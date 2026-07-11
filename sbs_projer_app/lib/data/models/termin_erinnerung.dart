/// Eine einzelne Termin-Erinnerung (1:1 auf Google `reminders.overrides`).
class TerminErinnerung {
  final String methode; // 'email' | 'popup'
  final int minuten; // Vorlaufzeit in Minuten (0 = zum Zeitpunkt)

  const TerminErinnerung({required this.methode, required this.minuten});

  factory TerminErinnerung.fromJson(Map<String, dynamic> j) => TerminErinnerung(
        methode: j['methode'] == 'email' ? 'email' : 'popup',
        minuten: (j['minuten'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'methode': methode, 'minuten': minuten};
}
