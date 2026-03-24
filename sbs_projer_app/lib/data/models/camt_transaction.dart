/// Repräsentiert einen geparsten camt.053 Auszug (Statement).
class CamtStatement {
  final String statementId;
  final String iban;
  final String currency;
  final String ownerName;
  final DateTime fromDate;
  final DateTime toDate;
  final double openingBalance;
  final double closingBalance;
  final List<CamtTransaction> transactions;

  CamtStatement({
    required this.statementId,
    required this.iban,
    required this.currency,
    required this.ownerName,
    required this.fromDate,
    required this.toDate,
    required this.openingBalance,
    required this.closingBalance,
    required this.transactions,
  });
}

/// Repräsentiert eine einzelne Transaktion aus einem camt.053 Auszug.
class CamtTransaction {
  final double amount;
  final String currency;
  final bool isCredit;
  final DateTime bookingDate;
  final DateTime? valueDate;
  final String? accountServiceRef;
  final String? endToEndId;
  final String? transactionId;

  // Gegenpartei
  final String? partyName;
  final String? partyIban;
  final String? partyStreet;
  final String? partyBuildingNr;
  final String? partyPostCode;
  final String? partyCity;
  final String? partyCountry;
  final List<String> partyAddressLines;

  // Zahlungsreferenz
  final String? remittanceInfo;
  final String? additionalInfo;

  // Import-Zustand (nicht aus XML, wird im UI gesetzt)
  bool selected;
  bool isDuplicate;
  String? matchedBetriebId;
  String? matchedBetriebName;
  String? selectedVorlageId;

  CamtTransaction({
    required this.amount,
    required this.currency,
    required this.isCredit,
    required this.bookingDate,
    this.valueDate,
    this.accountServiceRef,
    this.endToEndId,
    this.transactionId,
    this.partyName,
    this.partyIban,
    this.partyStreet,
    this.partyBuildingNr,
    this.partyPostCode,
    this.partyCity,
    this.partyCountry,
    this.partyAddressLines = const [],
    this.remittanceInfo,
    this.additionalInfo,
    this.selected = true,
    this.isDuplicate = false,
    this.matchedBetriebId,
    this.matchedBetriebName,
    this.selectedVorlageId,
  });

  /// Formatierte Adresse der Gegenpartei.
  String get partyAddress {
    if (partyAddressLines.isNotEmpty) {
      return partyAddressLines.join(', ');
    }
    final parts = <String>[];
    if (partyStreet != null) {
      parts.add(partyBuildingNr != null
          ? '$partyStreet $partyBuildingNr'
          : partyStreet!);
    }
    if (partyPostCode != null || partyCity != null) {
      parts.add([partyPostCode, partyCity].whereType<String>().join(' '));
    }
    return parts.join(', ');
  }

  /// Vorzeichen-berücksichtigter Betrag (positiv = Gutschrift, negativ = Belastung).
  double get signedAmount => isCredit ? amount : -amount;
}
