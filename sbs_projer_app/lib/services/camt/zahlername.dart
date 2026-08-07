/// Generische Bank-Platzhalter, die als Zahlername nichts taugen: Die GKB
/// setzt bei Schaltereinzahlungen den Debtor-Namen wörtlich auf
/// «Schaltereinzahlung» — der echte Einzahler steht nur im AddtlNtryInf
/// («Gutschrift <Name>»). Solche Werte zählen nicht als Name, sonst bleibt
/// der Rohtext in Abgleich/Dialogen versteckt und das Matching läuft ins Leere.
const _kPlatzhalterNamen = {'schaltereinzahlung'};

/// Liefert den besten verfügbaren Zahlernamen: partyName, sonst aus
/// `Gutschrift <Name>` im AddtlNtryInf. Null wenn nichts Brauchbares.
String? effektiverZahlername({required String? partyName, required String? additionalInfo}) {
  final pn = partyName?.trim();
  if (pn != null &&
      pn.isNotEmpty &&
      !_kPlatzhalterNamen.contains(zahlernameNorm(pn))) {
    return pn;
  }
  final info = additionalInfo?.trim() ?? '';
  final m = RegExp(r'^Gutschrift\s+(.+)$', caseSensitive: false).firstMatch(info);
  if (m != null) {
    final name = m.group(1)!.trim();
    if (name.isNotEmpty) return name;
  }
  return null;
}

/// Normalisiert einen Zahlernamen für den Alias-Vergleich:
/// trim, Kleinschreibung, Mehrfach-Whitespace zu einfachem Leerzeichen.
/// Reine Funktion — identisch in Lernen (Speichern) und Anwenden (Matching).
String zahlernameNorm(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
