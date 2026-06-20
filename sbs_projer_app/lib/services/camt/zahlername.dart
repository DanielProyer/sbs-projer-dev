/// Liefert den besten verfügbaren Zahlernamen: partyName, sonst aus
/// "Gutschrift <Name>" im AddtlNtryInf. Null wenn nichts Brauchbares.
String? effektiverZahlername({required String? partyName, required String? additionalInfo}) {
  final pn = partyName?.trim();
  if (pn != null && pn.isNotEmpty) return pn;
  final info = additionalInfo?.trim() ?? '';
  final m = RegExp(r'^Gutschrift\s+(.+)$', caseSensitive: false).firstMatch(info);
  if (m != null) {
    final name = m.group(1)!.trim();
    if (name.isNotEmpty) return name;
  }
  return null;
}
