import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/camt/camt053_parser.dart';
import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';

const _batchXml = '''<?xml version="1.0"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.04"><BkToCstmrStmt><Stmt>
<Id>T</Id><Acct><Id><IBAN>CH6600774010376550601</IBAN></Id><Ccy>CHF</Ccy>
<Ownr><Nm>SBS Projer GmbH</Nm></Ownr></Acct>
<FrToDt><FrDtTm>2026-07-01T00:00:00</FrDtTm><ToDtTm>2026-07-31T23:59:59</ToDtTm></FrToDt>
<Ntry><Amt Ccy="CHF">200.00</Amt><CdtDbtInd>DBIT</CdtDbtInd><Sts>BOOK</Sts>
<BookgDt><Dt>2026-07-10</Dt></BookgDt><ValDt><Dt>2026-07-10</Dt></ValDt>
<AcctSvcrRef>ZV20260710/111</AcctSvcrRef>
<NtryDtls>
<TxDtls><Refs><AcctSvcrRef>ZV20260710/111/1</AcctSvcrRef></Refs><Amt Ccy="CHF">120.00</Amt>
<CdtDbtInd>DBIT</CdtDbtInd><RltdPties><Cdtr><Nm>Swisscom AG</Nm></Cdtr></RltdPties>
<RmtInf><Strd><CdtrRefInf><Ref>001329672833009201211220224</Ref></CdtrRefInf></Strd></RmtInf></TxDtls>
<TxDtls><Refs><AcctSvcrRef>ZV20260710/111/2</AcctSvcrRef></Refs><Amt Ccy="CHF">80.00</Amt>
<CdtDbtInd>DBIT</CdtDbtInd><RltdPties><Cdtr><Nm>Suva</Nm></Cdtr></RltdPties></TxDtls>
</NtryDtls></Ntry>
</Stmt></BkToCstmrStmt></Document>''';

void main() {
  test('Sammelauftrag wird in zwei Transaktionen gesplittet', () {
    final stmt = Camt053Parser.parse(_batchXml);
    expect(stmt.transactions.length, 2);
    final swisscom = stmt.transactions.firstWhere((t) => t.partyName == 'Swisscom AG');
    expect(swisscom.amount, 120.00);
    expect(swisscom.isBatchChild, true);
    expect(swisscom.strukturierteReferenz, '001329672833009201211220224');
    expect(swisscom.txKey, 'ZV20260710/111/1');
  });

  test('txKey ist pro Teiltransaktion eindeutig', () {
    final stmt = Camt053Parser.parse(_batchXml);
    final keys = stmt.transactions.map((t) => t.txKey).toSet();
    expect(keys.length, 2);
  });

  test('Stichtag: vor 11.03.2026 nicht automatisiert', () {
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 10)), false);
    expect(CamtStichtag.istAutomatisierbar(DateTime(2026, 3, 11)), true);
  });

  test('Kollidierende Fallback-txKeys werden disambiguiert', () {
    const xml = '''<?xml version="1.0"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.04"><BkToCstmrStmt><Stmt>
<Id>T</Id><Acct><Id><IBAN>CH66</IBAN></Id><Ccy>CHF</Ccy><Ownr><Nm>X</Nm></Ownr></Acct>
<FrToDt><FrDtTm>2026-07-01T00:00:00</FrDtTm><ToDtTm>2026-07-31T23:59:59</ToDtTm></FrToDt>
<Ntry><Amt Ccy="CHF">130.30</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts>BOOK</Sts>
<BookgDt><Dt>2026-07-05</Dt></BookgDt><AddtlNtryInf>Gutschrift Goodfast AG</AddtlNtryInf></Ntry>
<Ntry><Amt Ccy="CHF">130.30</Amt><CdtDbtInd>CRDT</CdtDbtInd><Sts>BOOK</Sts>
<BookgDt><Dt>2026-07-05</Dt></BookgDt><AddtlNtryInf>Gutschrift Goodfast AG</AddtlNtryInf></Ntry>
</Stmt></BkToCstmrStmt></Document>''';
    final stmt = Camt053Parser.parse(xml);
    expect(stmt.transactions.length, 2);
    final keys = stmt.transactions.map((t) => t.txKey).toSet();
    expect(keys.length, 2, reason: 'beide Transaktionen müssen eindeutige txKeys haben');
  });

  test('Salden OPBD/CLBD werden aus Bal>Tp>CdOrPrtry gelesen', () {
    const xml = '''<?xml version="1.0"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.04"><BkToCstmrStmt><Stmt>
<Id>T</Id><Acct><Id><IBAN>CH66</IBAN></Id><Ccy>CHF</Ccy><Ownr><Nm>X</Nm></Ownr></Acct>
<FrToDt><FrDtTm>2026-07-01T00:00:00</FrDtTm><ToDtTm>2026-07-31T23:59:59</ToDtTm></FrToDt>
<Bal><Tp><CdOrPrtry><Cd>OPBD</Cd></CdOrPrtry></Tp><Amt Ccy="CHF">1000.00</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
<Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="CHF">1500.50</Amt><CdtDbtInd>CRDT</CdtDbtInd></Bal>
</Stmt></BkToCstmrStmt></Document>''';
    final stmt = Camt053Parser.parse(xml);
    expect(stmt.openingBalance, 1000.00);
    expect(stmt.closingBalance, 1500.50);
  });

  test('Debit-Saldo (CLBD DBIT) wird negativ gelesen', () {
    const xml = '''<?xml version="1.0"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.04"><BkToCstmrStmt><Stmt>
<Id>T</Id><Acct><Id><IBAN>CH66</IBAN></Id><Ccy>CHF</Ccy><Ownr><Nm>X</Nm></Ownr></Acct>
<FrToDt><FrDtTm>2026-07-01T00:00:00</FrDtTm><ToDtTm>2026-07-31T23:59:59</ToDtTm></FrToDt>
<Bal><Tp><CdOrPrtry><Cd>CLBD</Cd></CdOrPrtry></Tp><Amt Ccy="CHF">42.00</Amt><CdtDbtInd>DBIT</CdtDbtInd></Bal>
</Stmt></BkToCstmrStmt></Document>''';
    final stmt = Camt053Parser.parse(xml);
    expect(stmt.closingBalance, -42.00);
  });
}
