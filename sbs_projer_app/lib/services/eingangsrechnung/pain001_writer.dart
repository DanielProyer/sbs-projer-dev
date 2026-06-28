import 'package:xml/xml.dart';

/// Auftraggeber (Dbtr) einer pain.001-Zahlung.
class Pain001Debtor {
  final String name;
  final String iban;
  final String strtNm;
  final String bldgNb;
  final String pstCd;
  final String twnNm;
  final String ctry;
  final String? bic;

  const Pain001Debtor({
    required this.name,
    required this.iban,
    required this.strtNm,
    required this.bldgNb,
    required this.pstCd,
    required this.twnNm,
    required this.ctry,
    this.bic,
  });
}

/// Eine einzelne Gutschrifts-Transaktion (CdtTrfTxInf) innerhalb der pain.001.
class Pain001Payment {
  final String endToEndId;
  final String cdtrName;
  final String cdtrIban;

  /// 'QRR' | 'SCOR' | 'NON' — steuert die Remittance-Information.
  final String referenzTyp;

  final String? cdtrStrtNm;
  final String? cdtrBldgNb;
  final String? cdtrPstCd;
  final String? cdtrTwnNm;
  final String? cdtrCtry;

  /// Strukturierte Referenz (QRR/SCOR). Null bei [referenzTyp] == 'NON'.
  final String? referenz;

  /// Unstrukturierte Mitteilung (nur bei [referenzTyp] == 'NON').
  final String? mitteilung;

  final double betrag;
  final String waehrung;

  const Pain001Payment({
    required this.endToEndId,
    required this.cdtrName,
    required this.cdtrIban,
    required this.referenzTyp,
    this.cdtrStrtNm,
    this.cdtrBldgNb,
    this.cdtrPstCd,
    this.cdtrTwnNm,
    this.cdtrCtry,
    this.referenz,
    this.mitteilung,
    required this.betrag,
    required this.waehrung,
  });
}

/// Erzeugt eine ISO-20022-Zahlungsdatei `pain.001.001.09` (Swiss Implementation
/// Guidelines, Customer Credit Transfer Initiation) als XML-String.
///
/// Reine Funktion ohne Seiteneffekte — voll testbar. Verwendet `package:xml`.
class Pain001Writer {
  static const String _ns = 'urn:iso:std:iso:20022:tech:xsd:pain.001.001.09';

  static String build({
    required String msgId,
    required DateTime creationDateTime,
    required DateTime requestedExecutionDate,
    required Pain001Debtor debtor,
    required List<Pain001Payment> payments,
  }) {
    final nbOfTxs = payments.length.toString();
    final ctrlSum = payments
        .fold<double>(0, (sum, p) => sum + p.betrag)
        .toStringAsFixed(2);

    final builder = XmlBuilder();
    builder.declaration(encoding: 'UTF-8');
    builder.element('Document', nest: () {
      builder.attribute('xmlns', _ns);
      builder.element('CstmrCdtTrfInitn', nest: () {
        // --- Group Header ---
        builder.element('GrpHdr', nest: () {
          builder.element('MsgId', nest: msgId);
          builder.element('CreDtTm', nest: _isoDateTime(creationDateTime));
          builder.element('NbOfTxs', nest: nbOfTxs);
          builder.element('CtrlSum', nest: ctrlSum);
          builder.element('InitgPty', nest: () {
            builder.element('Nm', nest: debtor.name);
          });
        });

        // --- Payment Information ---
        builder.element('PmtInf', nest: () {
          builder.element('PmtInfId', nest: '$msgId-1');
          builder.element('PmtMtd', nest: 'TRF');
          builder.element('BtchBookg', nest: 'true');
          builder.element('NbOfTxs', nest: nbOfTxs);
          builder.element('CtrlSum', nest: ctrlSum);
          builder.element('ReqdExctnDt', nest: () {
            builder.element('Dt', nest: _isoDate(requestedExecutionDate));
          });
          builder.element('Dbtr', nest: () {
            builder.element('Nm', nest: debtor.name);
            builder.element('PstlAdr', nest: () {
              _addr(builder, 'StrtNm', debtor.strtNm);
              _addr(builder, 'BldgNb', debtor.bldgNb);
              _addr(builder, 'PstCd', debtor.pstCd);
              _addr(builder, 'TwnNm', debtor.twnNm);
              _addr(builder, 'Ctry', debtor.ctry.isEmpty ? 'CH' : debtor.ctry);
            });
          });
          builder.element('DbtrAcct', nest: () {
            builder.element('Id', nest: () {
              builder.element('IBAN', nest: debtor.iban.replaceAll(' ', ''));
            });
          });
          if (debtor.bic != null && debtor.bic!.isNotEmpty) {
            builder.element('DbtrAgt', nest: () {
              builder.element('FinInstnId', nest: () {
                builder.element('BICFI', nest: debtor.bic);
              });
            });
          }
          builder.element('ChrgBr', nest: 'SLEV');

          for (final p in payments) {
            _txInf(builder, p);
          }
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  static void _txInf(XmlBuilder builder, Pain001Payment p) {
    builder.element('CdtTrfTxInf', nest: () {
      builder.element('PmtId', nest: () {
        builder.element('InstrId', nest: p.endToEndId);
        builder.element('EndToEndId', nest: p.endToEndId);
      });
      builder.element('Amt', nest: () {
        builder.element('InstdAmt', nest: () {
          builder.attribute('Ccy', p.waehrung);
          builder.text(p.betrag.toStringAsFixed(2));
        });
      });
      builder.element('Cdtr', nest: () {
        builder.element('Nm', nest: p.cdtrName);
        builder.element('PstlAdr', nest: () {
          _addr(builder, 'StrtNm', p.cdtrStrtNm);
          _addr(builder, 'BldgNb', p.cdtrBldgNb);
          _addr(builder, 'PstCd', p.cdtrPstCd);
          _addr(builder, 'TwnNm', p.cdtrTwnNm);
          final ctry =
              (p.cdtrCtry != null && p.cdtrCtry!.isNotEmpty) ? p.cdtrCtry! : 'CH';
          _addr(builder, 'Ctry', ctry);
        });
      });
      builder.element('CdtrAcct', nest: () {
        builder.element('Id', nest: () {
          builder.element('IBAN', nest: p.cdtrIban.replaceAll(' ', ''));
        });
      });
      _rmtInf(builder, p);
    });
  }

  static void _rmtInf(XmlBuilder builder, Pain001Payment p) {
    switch (p.referenzTyp) {
      case 'QRR':
        builder.element('RmtInf', nest: () {
          builder.element('Strd', nest: () {
            builder.element('CdtrRefInf', nest: () {
              builder.element('Tp', nest: () {
                builder.element('CdOrPrtry', nest: () {
                  builder.element('Prtry', nest: 'QRR');
                });
              });
              builder.element('Ref', nest: p.referenz ?? '');
            });
          });
        });
        break;
      case 'SCOR':
        builder.element('RmtInf', nest: () {
          builder.element('Strd', nest: () {
            builder.element('CdtrRefInf', nest: () {
              builder.element('Tp', nest: () {
                builder.element('CdOrPrtry', nest: () {
                  builder.element('Cd', nest: 'SCOR');
                });
                builder.element('Issr', nest: 'ISO');
              });
              builder.element('Ref', nest: p.referenz ?? '');
            });
          });
        });
        break;
      default: // 'NON'
        final mitteilung = (p.mitteilung ?? '').trim();
        if (mitteilung.isNotEmpty) {
          final ustrd = mitteilung.length > 140
              ? mitteilung.substring(0, 140)
              : mitteilung;
          builder.element('RmtInf', nest: () {
            builder.element('Ustrd', nest: ustrd);
          });
        }
    }
  }

  /// Schreibt ein Adress-Element nur, wenn [value] nicht null/leer ist.
  static void _addr(XmlBuilder builder, String name, String? value) {
    if (value != null && value.trim().isNotEmpty) {
      builder.element(name, nest: value);
    }
  }

  static String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _isoDateTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');
    return '${_isoDate(d)}T$hh:$mm:$ss';
  }
}
