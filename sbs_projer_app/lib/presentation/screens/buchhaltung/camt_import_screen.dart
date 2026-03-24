import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchungs_vorlage_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/services/camt/camt053_parser.dart';
import 'package:sbs_projer_app/services/camt/camt_betrieb_matcher.dart';
import 'package:sbs_projer_app/services/camt/camt_import_service.dart';

class CamtImportScreen extends ConsumerStatefulWidget {
  const CamtImportScreen({super.key});

  @override
  ConsumerState<CamtImportScreen> createState() => _CamtImportScreenState();
}

class _CamtImportScreenState extends ConsumerState<CamtImportScreen> {
  // State
  int _step = 0; // 0=Datei wählen, 1=Prüfen, 2=Ergebnis
  CamtStatement? _statement;
  CamtImportResult? _result;
  bool _loading = false;
  String? _error;
  int _duplicateCount = 0;

  final _dateFormat = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bankauszug Import'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return _buildFilePickerStep();
      case 1:
        return _buildReviewStep();
      case 2:
        return _buildResultStep();
      default:
        return const SizedBox();
    }
  }

  // === Schritt 1: Datei wählen ===
  Widget _buildFilePickerStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 64,
              color: AppColors.primary.withAlpha(100),
            ),
            const SizedBox(height: 24),
            Text(
              'camt.053 Bankauszug importieren',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Wählen Sie eine XML-Datei aus dem GKB-Onlinebanking.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_loading)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('XML-Datei wählen'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      setState(() { _loading = true; _error = null; });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        setState(() => _loading = false);
        return;
      }

      final xmlString = utf8.decode(result.files.single.bytes!, allowMalformed: true);
      final statement = Camt053Parser.parse(xmlString);

      // Duplikat-Erkennung: bestehende Belegnummern laden
      final existingBuchungen = await BuchungRepository.getAll();
      final existingRefs = <String>{};
      for (final b in existingBuchungen) {
        if (b.belegnummer != null) existingRefs.add(b.belegnummer!);
      }

      // Transaktionen gegen bestehende Belegnummern prüfen
      int dupes = 0;
      for (final tx in statement.transactions) {
        if (tx.accountServiceRef != null && existingRefs.contains(tx.accountServiceRef)) {
          tx.isDuplicate = true;
          tx.selected = false; // Duplikate standardmässig abwählen
          dupes++;
        }
      }

      // Auto-Match Betriebe
      final betriebe = ref.read(betriebeProvider);
      final betriebMaps = betriebe.map((b) => {
        'id': b.routeId,
        'name': b.name,
      }).toList();
      CamtBetriebMatcher.matchAll(statement.transactions, betriebMaps);

      // Auto-Assign Vorlage "Zahlungseingang" wenn vorhanden
      final vorlagen = ref.read(buchungsVorlagenProvider);
      final zahlungsVorlage = vorlagen.cast<BuchungsVorlage?>().firstWhere(
        (v) => v!.autoTrigger == 'zahlungseingang',
        orElse: () => null,
      );
      if (zahlungsVorlage != null) {
        for (final tx in statement.transactions) {
          if (tx.isCredit) {
            tx.selectedVorlageId = zahlungsVorlage.id;
          }
        }
      }

      setState(() {
        _statement = statement;
        _duplicateCount = dupes;
        _step = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Parsen: $e';
        _loading = false;
      });
    }
  }

  // === Schritt 2: Transaktionen prüfen ===
  Widget _buildReviewStep() {
    final stmt = _statement!;
    final txs = stmt.transactions;
    final vorlagen = ref.watch(buchungsVorlagenProvider);
    final selectedCount = txs.where((t) => t.selected).length;
    final totalAmount = txs
        .where((t) => t.selected)
        .fold<double>(0, (sum, t) => sum + t.signedAmount);

    return Column(
      children: [
        // Auszugs-Header
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.primary.withAlpha(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bankauszug ${_dateFormat.format(stmt.fromDate)} – ${_dateFormat.format(stmt.toDate)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '${stmt.ownerName} · IBAN ${stmt.iban} · ${txs.length} Transaktionen',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_duplicateCount > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Text(
                        '$_duplicateCount Transaktion${_duplicateCount == 1 ? '' : 'en'} bereits importiert (abgewählt)',
                        style: const TextStyle(fontSize: 12, color: AppColors.warning),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Transaktions-Liste
        Expanded(
          child: ListView.builder(
            itemCount: txs.length,
            itemBuilder: (context, index) {
              final tx = txs[index];
              return _TransactionTile(
                tx: tx,
                vorlagen: vorlagen,
                dateFormat: _dateFormat,
                onToggle: (val) => setState(() => tx.selected = val ?? false),
                onVorlageChanged: (id) => setState(() => tx.selectedVorlageId = id),
              );
            },
          ),
        ),

        // Bottom-Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$selectedCount von ${txs.length} ausgewählt',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Total: ${totalAmount.toStringAsFixed(2)} CHF',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => setState(() { _step = 0; _statement = null; }),
                child: const Text('Zurück'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: selectedCount > 0 && !_loading ? _doImport : null,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Importieren'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _doImport() async {
    setState(() => _loading = true);

    try {
      final vorlagen = ref.read(buchungsVorlagenProvider);
      final vorlagenById = {for (final v in vorlagen) v.id: v};

      final result = await CamtImportService.importTransactions(
        transactions: _statement!.transactions,
        vorlagenById: vorlagenById,
        statement: _statement!,
      );

      ref.invalidate(buchungenStreamProvider);

      setState(() {
        _result = result;
        _step = 2;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import-Fehler: $e')),
        );
      }
    }
  }

  // === Schritt 3: Ergebnis ===
  Widget _buildResultStep() {
    final r = _result!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              r.errors.isEmpty ? Icons.check_circle : Icons.warning,
              size: 64,
              color: r.errors.isEmpty ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(height: 24),
            Text(
              'Import abgeschlossen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _ResultRow(Icons.check, '${r.imported} Buchungen importiert', AppColors.success),
            if (r.skipped > 0)
              _ResultRow(Icons.skip_next, '${r.skipped} übersprungen', AppColors.textSecondary),
            if (r.errors.isNotEmpty)
              _ResultRow(Icons.error_outline, '${r.errors.length} Fehler', AppColors.error),
            if (r.errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    children: r.errors.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(e, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                    )).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    _step = 0;
                    _statement = null;
                    _result = null;
                    _duplicateCount = 0;
                  }),
                  child: const Text('Weiteren Auszug importieren'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fertig'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// === Helper Widgets ===

class _TransactionTile extends StatelessWidget {
  final CamtTransaction tx;
  final List<BuchungsVorlage> vorlagen;
  final DateFormat dateFormat;
  final ValueChanged<bool?> onToggle;
  final ValueChanged<String?> onVorlageChanged;

  const _TransactionTile({
    required this.tx,
    required this.vorlagen,
    required this.dateFormat,
    required this.onToggle,
    required this.onVorlageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: tx.isDuplicate ? 0.5 : 1.0,
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: tx.selected,
                  onChanged: onToggle,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tx.partyName ?? 'Unbekannt',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tx.isDuplicate)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Duplikat',
                                style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${dateFormat.format(tx.bookingDate)} · ${tx.partyAddress}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${tx.isCredit ? "+" : "-"} ${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: tx.isCredit ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),

            // Referenz
            if (tx.remittanceInfo != null)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 4),
                child: Text(
                  tx.remittanceInfo!,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Match + Vorlage
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Row(
                children: [
                  // Betrieb-Match
                  if (tx.matchedBetriebName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link, size: 12, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            tx.matchedBetriebName!,
                            style: const TextStyle(fontSize: 11, color: AppColors.success),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.help_outline, size: 12, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text(
                            'Kein Betrieb',
                            style: TextStyle(fontSize: 11, color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(width: 8),

                  // Vorlage-Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: tx.selectedVorlageId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(),
                        labelText: 'Vorlage',
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Keine Vorlage', style: TextStyle(fontSize: 12)),
                        ),
                        ...vorlagen.map((v) => DropdownMenuItem<String?>(
                          value: v.id,
                          child: Text(
                            v.bezeichnung,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                      ],
                      onChanged: onVorlageChanged,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ResultRow(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
