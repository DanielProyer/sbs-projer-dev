import 'package:xml/xml.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';

/// Parser für camt.053 XML-Dateien (Kontoauszüge).
/// Namespace-agnostisch via localName, unterstützt beide Adress-Formate.
class Camt053Parser {
  /// Parst einen camt.053-XML-String und gibt ein CamtStatement zurück.
  static CamtStatement parse(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    // camt.053: <Document> → <BkToCstmrStmt> → <Stmt>
    final bkToCstmrStmt = _findElement(document.rootElement, 'BkToCstmrStmt');
    final stmt = _findElement(bkToCstmrStmt, 'Stmt')
        ?? _findElementDeep(document.rootElement, 'Stmt');
    if (stmt == null) {
      throw FormatException('Kein <Stmt>-Element im camt.053 gefunden');
    }

    // Account-Info: <Acct> → <Id> → <IBAN>
    final acct = _findElement(stmt, 'Acct');
    final acctId = _findElement(acct, 'Id');
    final iban = _text(_findElement(acctId, 'IBAN')) ?? '';
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
      // CdOrPrtry liegt unter Tp (Bal > Tp > CdOrPrtry > Cd), nicht direkt unter Bal.
      final code = _text(
          _findElement(_findElement(_findElement(bal, 'Tp'), 'CdOrPrtry'), 'Cd'));
      final amount = double.tryParse(_attr(_findElement(bal, 'Amt')) ?? '0') ?? 0;
      final isCredit = _text(_findElement(bal, 'CdtDbtInd')) == 'CRDT';
      final signed = isCredit ? amount : -amount;
      if (code == 'OPBD') openingBalance = signed;
      if (code == 'CLBD') closingBalance = signed;
    }

    // Transaktionen (Ntry) — Sammelaufträge werden in TxDtls-Einzeltransaktionen gesplittet
    final transactions = <CamtTransaction>[];
    for (final ntry in _findElements(stmt, 'Ntry')) {
      transactions.addAll(_parseEntries(ntry, ccy));
    }
    _disambiguateKeys(transactions);

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

  /// Parst eine Ntry und gibt eine oder mehrere Transaktionen zurück.
  /// Sammelaufträge (mehrere TxDtls-Einträge) werden in Einzeltransaktionen gesplittet.
  static List<CamtTransaction> _parseEntries(XmlElement ntry, String defaultCcy) {
    final isCredit = _text(_findElement(ntry, 'CdtDbtInd')) == 'CRDT';
    final bookingDtStr = _text(_findElement(_findElement(ntry, 'BookgDt'), 'Dt'));
    if (bookingDtStr == null) return [];
    final bookingDate = DateTime.parse(bookingDtStr);
    final valueDtStr = _text(_findElement(_findElement(ntry, 'ValDt'), 'Dt'));
    final valueDate = valueDtStr != null ? DateTime.parse(valueDtStr) : null;
    final ntryRef = _text(_findElement(ntry, 'AcctSvcrRef'));
    final ntryAddtlInfo = _text(_findElement(ntry, 'AddtlNtryInf'));

    final ntryDtls = _findElement(ntry, 'NtryDtls');
    final txDtlsList = ntryDtls == null
        ? const <XmlElement>[]
        : _findElements(ntryDtls, 'TxDtls').toList();
    final isBatch = txDtlsList.length > 1;

    // Keine TxDtls: Saldovortrag, Bargeld o.ä. — eine Transaktion aus Ntry-Ebene
    if (txDtlsList.isEmpty) {
      final amount = double.tryParse(_attr(_findElement(ntry, 'Amt')) ?? '0') ?? 0;
      final ccy = _findElement(ntry, 'Amt')?.getAttribute('Ccy') ?? defaultCcy;
      return [CamtTransaction(
        amount: amount, currency: ccy, isCredit: isCredit,
        bookingDate: bookingDate, valueDate: valueDate,
        accountServiceRef: ntryRef, partyAddressLines: const [],
        additionalInfo: ntryAddtlInfo,
        txKey: _buildTxKey(ntryRef, null, bookingDate, amount, isCredit, null, null),
      )];
    }

    final result = <CamtTransaction>[];
    for (final txDtls in txDtlsList) {
      final amount = double.tryParse(_attr(_findElement(txDtls, 'Amt')) ?? '0') ?? 0;
      final ccy = _findElement(txDtls, 'Amt')?.getAttribute('Ccy') ?? defaultCcy;
      final refs = _findElement(txDtls, 'Refs');
      var endToEndId = _text(_findElement(refs, 'EndToEndId'));
      if (endToEndId == 'NOTPROVIDED') endToEndId = null;
      final txSvcrRef = _text(_findElement(refs, 'AcctSvcrRef')) ?? ntryRef;
      final txId = _text(_findElement(refs, 'TxId'));

      String? partyName, partyIban, partyStreet, partyBuildingNr,
          partyPostCode, partyCity, partyCountry;
      List<String> partyAddressLines = [];
      final rltdPties = _findElement(txDtls, 'RltdPties');
      if (rltdPties != null) {
        final party = isCredit ? _findElement(rltdPties, 'Dbtr') : _findElement(rltdPties, 'Cdtr');
        final partyAcct = isCredit ? _findElement(rltdPties, 'DbtrAcct') : _findElement(rltdPties, 'CdtrAcct');
        if (party != null) {
          partyName = _text(_findElement(party, 'Nm'));
          final addr = _findElement(party, 'PstlAdr');
          if (addr != null) {
            partyStreet = _text(_findElement(addr, 'StrtNm'));
            partyBuildingNr = _text(_findElement(addr, 'BldgNb'));
            partyPostCode = _text(_findElement(addr, 'PstCd'));
            partyCity = _text(_findElement(addr, 'TwnNm'));
            partyCountry = _text(_findElement(addr, 'Ctry'));
            partyAddressLines = _findElements(addr, 'AdrLine')
                .map((e) => e.innerText.trim()).where((s) => s.isNotEmpty).toList();
          }
        }
        if (partyAcct != null) {
          partyIban = _text(_findElement(_findElement(partyAcct, 'Id'), 'IBAN'));
        }
      }
      final rmtInf = _findElement(txDtls, 'RmtInf');
      final remittanceInfo = _text(_findElement(rmtInf, 'Ustrd'));
      final strd = _findElement(rmtInf, 'Strd');
      final strdRef = _text(_findElement(_findElement(strd, 'CdtrRefInf'), 'Ref'));
      final additionalInfo = _text(_findElement(txDtls, 'AddtlTxInf')) ?? ntryAddtlInfo;

      result.add(CamtTransaction(
        amount: amount, currency: ccy, isCredit: isCredit,
        bookingDate: bookingDate, valueDate: valueDate,
        accountServiceRef: txSvcrRef, endToEndId: endToEndId, transactionId: txId,
        partyName: partyName, partyIban: partyIban, partyStreet: partyStreet,
        partyBuildingNr: partyBuildingNr, partyPostCode: partyPostCode,
        partyCity: partyCity, partyCountry: partyCountry,
        partyAddressLines: partyAddressLines, remittanceInfo: remittanceInfo,
        additionalInfo: additionalInfo, strukturierteReferenz: strdRef,
        isBatchChild: isBatch,
        txKey: _buildTxKey(txSvcrRef, txId, bookingDate, amount, isCredit, partyName, endToEndId),
      ));
    }
    return result;
  }

  /// Macht txKeys eindeutig: kollidierende (Fallback-)Schlüssel erhalten
  /// in Parse-Reihenfolge ein Suffix #2, #3 …. Stabil über erneute Importe.
  static void _disambiguateKeys(List<CamtTransaction> txs) {
    final seen = <String, int>{};
    for (final tx in txs) {
      final count = (seen[tx.txKey] ?? 0) + 1;
      seen[tx.txKey] = count;
      if (count > 1) tx.txKey = '${tx.txKey}#$count';
    }
  }

  /// Baut einen eindeutigen Dedup-Schlüssel für eine Transaktion.
  static String _buildTxKey(String? svcrRef, String? txId, DateTime date,
      double amount, bool isCredit, String? party, String? e2e) {
    if (svcrRef != null && svcrRef.isNotEmpty) return svcrRef;
    if (txId != null && txId.isNotEmpty) return txId;
    final d = date.toIso8601String().split('T').first;
    return '$d|${amount.toStringAsFixed(2)}|${isCredit ? 'C' : 'D'}'
        '|${party ?? ''}|${e2e ?? ''}';
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

  /// Rekursive Tiefensuche nach einem Element (Fallback).
  static XmlElement? _findElementDeep(XmlNode? parent, String localName) {
    if (parent == null) return null;
    for (final child in parent.children) {
      if (child is XmlElement) {
        if (child.name.local == localName) return child;
        final found = _findElementDeep(child, localName);
        if (found != null) return found;
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
