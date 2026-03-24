import 'package:xml/xml.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';

/// Parser für camt.053 XML-Dateien (Kontoauszüge).
/// Namespace-agnostisch via localName, unterstützt beide Adress-Formate.
class Camt053Parser {
  /// Parst einen camt.053-XML-String und gibt ein CamtStatement zurück.
  static CamtStatement parse(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final stmt = _findElement(document.rootElement, 'Stmt');
    if (stmt == null) {
      throw FormatException('Kein <Stmt>-Element im camt.053 gefunden');
    }

    // Account-Info
    final acct = _findElement(stmt, 'Acct');
    final iban = _text(_findElement(acct, 'IBAN')) ?? '';
    final ccy = _text(_findElement(acct, 'Ccy')) ?? 'CHF';
    final ownerName = _text(_findElement(_findElement(acct, 'Ownr'), 'Nm')) ?? '';

    // Zeitraum
    final frToDt = _findElement(stmt, 'FrToDt');
    final fromDate = DateTime.parse(
        _text(_findElement(frToDt, 'FrDtTm')) ?? DateTime.now().toIso8601String());
    final toDate = DateTime.parse(
        _text(_findElement(frToDt, 'ToDtTm')) ?? DateTime.now().toIso8601String());

    // Salden
    double openingBalance = 0;
    double closingBalance = 0;
    for (final bal in _findElements(stmt, 'Bal')) {
      final code = _text(_findElement(_findElement(bal, 'CdOrPrtry'), 'Cd'));
      final amount = double.tryParse(_attr(_findElement(bal, 'Amt')) ?? '0') ?? 0;
      final isCredit = _text(_findElement(bal, 'CdtDbtInd')) == 'CRDT';
      final signed = isCredit ? amount : -amount;
      if (code == 'OPBD') openingBalance = signed;
      if (code == 'CLBD') closingBalance = signed;
    }

    // Transaktionen (Ntry)
    final transactions = <CamtTransaction>[];
    for (final ntry in _findElements(stmt, 'Ntry')) {
      final tx = _parseEntry(ntry, ccy);
      if (tx != null) transactions.add(tx);
    }

    return CamtStatement(
      statementId: _text(_findElement(stmt, 'Id')) ?? '',
      iban: iban,
      currency: ccy,
      ownerName: ownerName,
      fromDate: fromDate,
      toDate: toDate,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      transactions: transactions,
    );
  }

  static CamtTransaction? _parseEntry(XmlElement ntry, String defaultCcy) {
    final amountStr = _attr(_findElement(ntry, 'Amt'));
    final amount = double.tryParse(amountStr ?? '0') ?? 0;
    final ccy = _findElement(ntry, 'Amt')?.getAttribute('Ccy') ?? defaultCcy;
    final isCredit = _text(_findElement(ntry, 'CdtDbtInd')) == 'CRDT';

    // Buchungsdatum
    final bookingDtStr = _text(_findElement(_findElement(ntry, 'BookgDt'), 'Dt'));
    if (bookingDtStr == null) return null;
    final bookingDate = DateTime.parse(bookingDtStr);

    final valueDtStr = _text(_findElement(_findElement(ntry, 'ValDt'), 'Dt'));
    final valueDate = valueDtStr != null ? DateTime.parse(valueDtStr) : null;

    final acctSvcrRef = _text(_findElement(ntry, 'AcctSvcrRef'));

    // Transaction Details (in NtryDtls/TxDtls)
    final ntryDtls = _findElement(ntry, 'NtryDtls');
    final txDtls = _findElement(ntryDtls, 'TxDtls');

    String? endToEndId;
    String? txId;
    String? partyName;
    String? partyIban;
    String? partyStreet;
    String? partyBuildingNr;
    String? partyPostCode;
    String? partyCity;
    String? partyCountry;
    List<String> partyAddressLines = [];
    String? remittanceInfo;
    String? additionalInfo;

    if (txDtls != null) {
      // Referenzen
      final refs = _findElement(txDtls, 'Refs');
      endToEndId = _text(_findElement(refs, 'EndToEndId'));
      txId = _text(_findElement(refs, 'TxId'));
      if (endToEndId == 'NOTPROVIDED') endToEndId = null;

      // Gegenpartei (Dbtr bei Gutschrift, Cdtr bei Belastung)
      final rltdPties = _findElement(txDtls, 'RltdPties');
      if (rltdPties != null) {
        final party = isCredit
            ? _findElement(rltdPties, 'Dbtr')
            : _findElement(rltdPties, 'Cdtr');
        final partyAcct = isCredit
            ? _findElement(rltdPties, 'DbtrAcct')
            : _findElement(rltdPties, 'CdtrAcct');

        if (party != null) {
          partyName = _text(_findElement(party, 'Nm'));
          final addr = _findElement(party, 'PstlAdr');
          if (addr != null) {
            partyStreet = _text(_findElement(addr, 'StrtNm'));
            partyBuildingNr = _text(_findElement(addr, 'BldgNb'));
            partyPostCode = _text(_findElement(addr, 'PstCd'));
            partyCity = _text(_findElement(addr, 'TwnNm'));
            partyCountry = _text(_findElement(addr, 'Ctry'));
            // AdrLine-Format (falls vorhanden)
            partyAddressLines = _findElements(addr, 'AdrLine')
                .map((e) => e.innerText.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
        }
        if (partyAcct != null) {
          partyIban = _text(_findElement(_findElement(partyAcct, 'Id'), 'IBAN'));
        }
      }

      // Zahlungsreferenz
      final rmtInf = _findElement(txDtls, 'RmtInf');
      remittanceInfo = _text(_findElement(rmtInf, 'Ustrd'));

      additionalInfo = _text(_findElement(txDtls, 'AddtlTxInf'));
    }

    // Fallback: AddtlNtryInf auf Ntry-Ebene
    additionalInfo ??= _text(_findElement(ntry, 'AddtlNtryInf'));

    return CamtTransaction(
      amount: amount,
      currency: ccy,
      isCredit: isCredit,
      bookingDate: bookingDate,
      valueDate: valueDate,
      accountServiceRef: acctSvcrRef,
      endToEndId: endToEndId,
      transactionId: txId,
      partyName: partyName,
      partyIban: partyIban,
      partyStreet: partyStreet,
      partyBuildingNr: partyBuildingNr,
      partyPostCode: partyPostCode,
      partyCity: partyCity,
      partyCountry: partyCountry,
      partyAddressLines: partyAddressLines,
      remittanceInfo: remittanceInfo,
      additionalInfo: additionalInfo,
    );
  }

  // === Namespace-agnostische Helper ===

  /// Findet das erste Kind-Element mit dem gegebenen localName.
  static XmlElement? _findElement(XmlNode? parent, String localName) {
    if (parent == null) return null;
    for (final child in parent.children) {
      if (child is XmlElement && child.name.local == localName) {
        return child;
      }
    }
    return null;
  }

  /// Findet alle Kind-Elemente mit dem gegebenen localName.
  static Iterable<XmlElement> _findElements(XmlNode? parent, String localName) {
    if (parent == null) return [];
    return parent.children
        .whereType<XmlElement>()
        .where((e) => e.name.local == localName);
  }

  /// Text-Inhalt eines Elements.
  static String? _text(XmlElement? element) {
    if (element == null) return null;
    final text = element.innerText.trim();
    return text.isEmpty ? null : text;
  }

  /// Text-Inhalt (für Amt-Elemente die den Betrag als Text haben).
  static String? _attr(XmlElement? element) {
    return _text(element);
  }
}
