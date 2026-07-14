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
  // Scharfgestellt 30.05.2026 nach erfolgreichem Test: Reinigungsrechnungen
  // gehen beim Service-Abschluss und im Nachversand an die echten Kunden.
  static const reinigungScharf = true;
  static const heinekenScharf = true;
  static const montageScharf = true;
  static const heigenieScharf = true;
  // Scharfgestellt 14.07.2026: Materialbestellungen gehen an den echten
  // Heineken-Kontakt (Daniel Mani) statt an den Testempfänger.
  static const bestellungScharf = true;
  static const mahnwesenScharf = false;
  // Events-Abschlussmail: scharfgestellt 10.07.2026 nach erfolgreichem Test —
  // Versand geht an die echten Empfänger (Eventverantwortlicher/RSL).
  static const eventScharf = true;
  // Anlagen-Steckbrief an RSL: scharfgestellt 10.07.2026 nach erfolgreichem
  // Test — geht an den zugewiesenen RSL-Kontakt.
  static const anlageScharf = true;

  /// Unsichtbare Zeichen, die beim Copy-Paste in E-Mail-Adressen geraten und
  /// z.B. beim Gmail-Versand "Invalid To header" auslösen:
  /// Zero-Width-Space/Non-Joiner/Joiner (U+200B–U+200D), BOM (U+FEFF),
  /// Non-Breaking-Space (U+00A0).
  static const _unsichtbareCodes = {0x200B, 0x200C, 0x200D, 0xFEFF, 0x00A0};

  /// Gibt den tatsächlichen Empfänger zurück.
  /// Im Testmodus immer [testEmpfaenger], sonst [echterEmpfaenger].
  /// Die zurückgegebene Adresse wird immer via [bereinige] gesäubert.
  static String empfaenger(String? echterEmpfaenger, {String bereich = ''}) {
    if (testModus) return bereinige(testEmpfaenger);

    // Bereichsweise Steuerung
    switch (bereich) {
      case 'reinigung':
        if (!reinigungScharf) return bereinige(testEmpfaenger);
      case 'heineken':
        if (!heinekenScharf) return bereinige(testEmpfaenger);
      case 'montage':
        if (!montageScharf) return bereinige(testEmpfaenger);
      case 'heigenie':
        if (!heigenieScharf) return bereinige(testEmpfaenger);
      case 'bestellung':
        if (!bestellungScharf) return bereinige(testEmpfaenger);
      case 'mahnwesen':
        if (!mahnwesenScharf) return bereinige(testEmpfaenger);
      case 'event':
        if (!eventScharf) return bereinige(testEmpfaenger);
      case 'anlage':
        if (!anlageScharf) return bereinige(testEmpfaenger);
    }

    return bereinige(echterEmpfaenger ?? testEmpfaenger);
  }

  /// Ob der Versand für [bereich] tatsächlich an den echten Empfänger geht
  /// (true = scharf) oder an den Test-Empfänger umgeleitet wird (false).
  /// Verwenden, um `versendet_am` NUR bei echtem Versand zu setzen.
  static bool istScharf(String bereich) {
    if (testModus) return false;
    switch (bereich) {
      case 'reinigung':
        return reinigungScharf;
      case 'heineken':
        return heinekenScharf;
      case 'montage':
        return montageScharf;
      case 'heigenie':
        return heigenieScharf;
      case 'bestellung':
        return bestellungScharf;
      case 'mahnwesen':
        return mahnwesenScharf;
      case 'event':
        return eventScharf;
      case 'anlage':
        return anlageScharf;
    }
    return true;
  }

  /// Entfernt unsichtbare Zeichen ([_unsichtbareCodes]) und umschliessende
  /// Leerzeichen aus einer E-Mail-Adresse. Umlaute u.ä. bleiben erhalten.
  static String bereinige(String email) {
    final buffer = StringBuffer();
    for (final rune in email.runes) {
      if (!_unsichtbareCodes.contains(rune)) buffer.writeCharCode(rune);
    }
    return buffer.toString().trim();
  }
}
