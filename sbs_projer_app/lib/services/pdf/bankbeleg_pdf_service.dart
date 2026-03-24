import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sbs_projer_app/data/models/camt_transaction.dart';

/// Generiert ein A4-PDF als Bankbeleg für eine camt.053-Transaktion.
class BankbelegPdfService {
  static const _darkBlue = PdfColor.fromInt(0xFF1A3A5C);
  static const _grey = PdfColor.fromInt(0xFF666666);
  static const _lightGrey = PdfColor.fromInt(0xFFF5F5F5);

  static Future<Uint8List> generate({
    required CamtTransaction transaction,
    required String iban,
    required String kontoinhaber,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd.MM.yyyy');
    final tx = transaction;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Bankbeleg',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkBlue,
                    ),
                  ),
                  pw.Text(
                    dateFormat.format(tx.bookingDate),
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: _grey,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: _darkBlue, thickness: 2),
              pw.SizedBox(height: 20),

              // Betrag
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: _lightGrey,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      tx.isCredit ? 'Gutschrift' : 'Belastung',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${tx.isCredit ? "+" : "-"} ${tx.amount.toStringAsFixed(2)} ${tx.currency}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkBlue,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Kontoangaben
              _sectionTitle('Konto'),
              _infoRow('Kontoinhaber', kontoinhaber),
              _infoRow('IBAN', _formatIban(iban)),
              pw.SizedBox(height: 16),

              // Gegenpartei
              if (tx.partyName != null) ...[
                _sectionTitle(tx.isCredit ? 'Auftraggeber' : 'Empfänger'),
                _infoRow('Name', tx.partyName!),
                if (tx.partyAddress.isNotEmpty)
                  _infoRow('Adresse', tx.partyAddress),
                if (tx.partyIban != null)
                  _infoRow('IBAN', _formatIban(tx.partyIban!)),
                pw.SizedBox(height: 16),
              ],

              // Buchungsdetails
              _sectionTitle('Buchungsdetails'),
              _infoRow('Buchungsdatum', dateFormat.format(tx.bookingDate)),
              if (tx.valueDate != null)
                _infoRow('Valutadatum', dateFormat.format(tx.valueDate!)),
              if (tx.accountServiceRef != null)
                _infoRow('Bankreferenz', tx.accountServiceRef!),
              if (tx.endToEndId != null)
                _infoRow('End-to-End-ID', tx.endToEndId!),
              if (tx.transactionId != null)
                _infoRow('Transaktions-ID', tx.transactionId!),
              pw.SizedBox(height: 16),

              // Zahlungsreferenz
              if (tx.remittanceInfo != null) ...[
                _sectionTitle('Zahlungsreferenz'),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    tx.remittanceInfo!,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 4),
              pw.Text(
                'Automatisch generiert aus camt.053-Bankauszug',
                style: pw.TextStyle(fontSize: 8, color: _grey),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _darkBlue,
        ),
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, color: _grey),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatIban(String iban) {
    final clean = iban.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }
}
