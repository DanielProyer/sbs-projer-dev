import 'dart:typed_data';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_beleg_repository.dart';
import 'package:sbs_projer_app/services/pdf/bankbeleg_pdf_service.dart';

/// Ergebnis eines camt-Imports.
class CamtImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;

  CamtImportResult({
    required this.imported,
    required this.skipped,
    required this.errors,
  });
}

/// Orchestriert den Import von camt.053-Transaktionen:
/// Buchung erstellen → Bankbeleg-PDF generieren → hochladen.
class CamtImportService {
  /// Importiert ausgewählte Transaktionen als Buchungen.
  static Future<CamtImportResult> importTransactions({
    required List<CamtTransaction> transactions,
    required Map<String, BuchungsVorlage> vorlagenById,
    required CamtStatement statement,
  }) async {
    int imported = 0;
    int skipped = 0;
    final errors = <String>[];

    for (final tx in transactions) {
      if (!tx.selected) {
        skipped++;
        continue;
      }

      try {
        // Vorlage bestimmen
        final vorlage = tx.selectedVorlageId != null
            ? vorlagenById[tx.selectedVorlageId]
            : null;

        // Buchung erstellen
        final buchung = await _createBuchung(tx, vorlage);

        // Bankbeleg-PDF generieren und hochladen
        await _generateAndUploadBeleg(tx, buchung, statement);

        imported++;
      } catch (e) {
        errors.add('${tx.partyName ?? "Unbekannt"}: $e');
      }
    }

    return CamtImportResult(
      imported: imported,
      skipped: skipped,
      errors: errors,
    );
  }

  static Future<Buchung> _createBuchung(
    CamtTransaction tx,
    BuchungsVorlage? vorlage,
  ) async {
    final betrag = tx.amount;
    final mwstSatz = vorlage?.mwstSatz ?? 0;
    final betragNetto = mwstSatz > 0
        ? (betrag / (1 + mwstSatz / 100) * 100).roundToDouble() / 100
        : betrag;
    final mwstBetrag = betrag - betragNetto;

    // Standard-Konten für Zahlungseingang: 1020 (Bank) an 3400 (Dienstleistungsertrag)
    final sollKonto = vorlage?.sollKonto ?? (tx.isCredit ? 1020 : (vorlage?.sollKonto ?? 6000));
    final habenKonto = vorlage?.habenKonto ?? (tx.isCredit ? 3400 : 1020);

    final beschreibung = tx.partyName != null
        ? '${tx.isCredit ? "Zahlung" : "Belastung"} ${tx.partyName}'
        : (tx.additionalInfo ?? 'camt.053 Import');

    return BuchungRepository.create({
      'datum': tx.bookingDate.toIso8601String().split('T').first,
      'belegnummer': tx.accountServiceRef,
      'vorlage_id': vorlage?.id,
      'soll_konto': sollKonto,
      'haben_konto': habenKonto,
      'mwst_konto': vorlage?.mwstKonto,
      'betrag_netto': betragNetto,
      'mwst_satz': mwstSatz,
      'mwst_betrag': (mwstBetrag * 100).roundToDouble() / 100,
      'betrag_brutto': betrag,
      'beschreibung': beschreibung,
      'zahlungsweg': vorlage?.zahlungsweg ?? 'bank',
      'belegordner': vorlage?.belegordner ?? 'bank',
      'beleg_typ': 'camt053',
      'geschaeftsjahr': tx.bookingDate.year,
      'notizen': _buildNotizen(tx),
    });
  }

  static String _buildNotizen(CamtTransaction tx) {
    final parts = <String>[];
    if (tx.remittanceInfo != null) parts.add('Referenz: ${tx.remittanceInfo}');
    if (tx.partyIban != null) parts.add('IBAN: ${tx.partyIban}');
    if (tx.endToEndId != null) parts.add('E2E: ${tx.endToEndId}');
    if (tx.accountServiceRef != null) parts.add('Ref: ${tx.accountServiceRef}');
    return parts.join('\n');
  }

  static Future<void> _generateAndUploadBeleg(
    CamtTransaction tx,
    Buchung buchung,
    CamtStatement statement,
  ) async {
    try {
      final Uint8List pdfBytes = await BankbelegPdfService.generate(
        transaction: tx,
        iban: statement.iban,
        kontoinhaber: statement.ownerName,
      );

      final dateiname = 'Bankbeleg_${tx.bookingDate.toIso8601String().split('T').first}'
          '_${tx.amount.toStringAsFixed(2).replaceAll('.', '-')}.pdf';

      await BuchungsBelegRepository.upload(
        buchungId: buchung.id,
        dateiname: dateiname,
        dateityp: 'pdf',
        bytes: pdfBytes,
        belegQuelle: 'camt053',
        beschreibung: 'Auto-generierter Bankbeleg aus camt.053',
      );
    } catch (_) {
      // Beleg-Fehler soll Import nicht abbrechen
    }
  }
}
