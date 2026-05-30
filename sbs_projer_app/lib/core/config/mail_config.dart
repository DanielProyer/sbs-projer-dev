/// Zentrale Mail-Konfiguration für die Testphase.
///
/// Solange [testModus] = true, werden ALLE ausgehenden Mails
/// an [testEmpfaenger] gesendet statt an die echten Empfänger.
///
/// Zum Scharfstellen einzelner Bereiche:
/// - Reinigungsrechnungen: [reinigungScharf]
/// - Heineken Monatsrechnungen: [heinekenScharf]
/// - Montage/HeiGenie Protokolle: [montageScharf]
class MailConfig {
  /// Master-Schalter: wenn true, gehen ALLE Mails an [testEmpfaenger]
  static const testModus = false;

  /// Test-Empfänger für alle Bereiche
  static const testEmpfaenger = 'dani.proyer@gmail.com';

  /// Einzelne Bereiche scharfstellen (nur relevant wenn [testModus] = false)
  // Vorübergehend false (30.05.2026): Testphase — Reinigungsrechnungen gehen
  // beim Service-Abschluss an testEmpfaenger. Nach Test (ca. 06.06.2026) auf true.
  static const reinigungScharf = false;
  static const heinekenScharf = true;
  static const montageScharf = true;
  static const heigenieScharf = true;
  static const bestellungScharf = false;
  static const mahnwesenScharf = false;

  /// Gibt den tatsächlichen Empfänger zurück.
  /// Im Testmodus immer [testEmpfaenger], sonst [echterEmpfaenger].
  static String empfaenger(String? echterEmpfaenger, {String bereich = ''}) {
    if (testModus) return testEmpfaenger;

    // Bereichsweise Steuerung
    switch (bereich) {
      case 'reinigung':
        if (!reinigungScharf) return testEmpfaenger;
      case 'heineken':
        if (!heinekenScharf) return testEmpfaenger;
      case 'montage':
        if (!montageScharf) return testEmpfaenger;
      case 'heigenie':
        if (!heigenieScharf) return testEmpfaenger;
      case 'bestellung':
        if (!bestellungScharf) return testEmpfaenger;
      case 'mahnwesen':
        if (!mahnwesenScharf) return testEmpfaenger;
    }

    return echterEmpfaenger ?? testEmpfaenger;
  }
}
