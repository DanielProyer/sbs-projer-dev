import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchungs_vorlage.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/data/repositories/buchung_repository.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_vorlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/data/repositories/camt_regel_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/camt/camt053_parser.dart';
import 'package:sbs_projer_app/services/camt/camt_auto_booker.dart';
import 'package:sbs_projer_app/services/camt/camt_bereich_router.dart';
import 'package:sbs_projer_app/services/camt/camt_stichtag.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';
import 'package:sbs_projer_app/services/camt/file_picker_export.dart';

class CamtImportScreen extends ConsumerStatefulWidget {
  const CamtImportScreen({super.key});

  @override
  ConsumerState<CamtImportScreen> createState() => _CamtImportScreenState();
}

class _CamtImportScreenState extends ConsumerState<CamtImportScreen> {
  // State
  int _step = 0; // 0=Datei wählen, 1=Bestätigen, 2=Ergebnis
  CamtStatement? _statement;
  String? _xmlRoh;
  AutoBookerResult? _result;
  AbgleichErgebnis? _abgleich;          // Bereich 1 Ergebnis
  List<Rechnung> _alleOffenen = [];     // Pool für ⚪-Zuordnung
  Map<String, String> _betriebName = {};
  bool _loading = false;
  String? _error;
  int _automatisierbarCount = 0;

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
        return _buildConfirmStep();
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
              Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    String schritt = 'Datei wählen';
    try {
      setState(() { _loading = true; _error = null; });

      final picked = await pickXmlFile();

      if (picked == null) {
        setState(() { _loading = false; _error = 'Keine Datei ausgewählt oder Datei konnte nicht gelesen werden.'; });
        return;
      }

      schritt = 'XML parsen';
      var xmlString = picked.content;
      // BOM entfernen falls vorhanden
      if (xmlString.startsWith('﻿')) {
        xmlString = xmlString.substring(1);
      }

      CamtStatement statement;
      try {
        statement = Camt053Parser.parse(xmlString);
      } catch (e) {
        setState(() {
          _error = 'XML-Parse-Fehler: $e';
          _loading = false;
        });
        return;
      }

      final automatisierbar = statement.transactions
          .where((t) => CamtStichtag.istAutomatisierbar(t.bookingDate))
          .length;

      setState(() {
        _statement = statement;
        _xmlRoh = xmlString;
        _automatisierbarCount = automatisierbar;
        _step = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler bei "$schritt": $e';
        _loading = false;
      });
    }
  }

  // === Schritt 2: Bestätigen ===
  Widget _buildConfirmStep() {
    final stmt = _statement!;
    final txs = stmt.transactions;

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
            ],
          ),
        ),

        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 56,
                    color: AppColors.primary.withAlpha(120),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Automatische Verbuchung & Rechnungskontrolle',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_automatisierbarCount von ${txs.length} Transaktion${txs.length == 1 ? '' : 'en'} '
                    'liegen am/nach dem Stichtag ${_dateFormat.format(CamtStichtag.stichtag)} '
                    'und werden automatisch verarbeitet.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (_automatisierbarCount == 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Alle Buchungen liegen vor dem Stichtag — '
                              'es wird nichts automatisch verbucht.',
                              style: TextStyle(fontSize: 12, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () => setState(() { _step = 0; _statement = null; }),
                child: const Text('Zurück'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: !_loading ? _doImport : null,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verarbeiten'),
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
      final stmt = _statement!;
      // Doppel-Upload-Schutz (wie Forderungs-Abgleich).
      final bereitsErfasst = await CamtDateiRepository.existsZeitraum(
          stmt.iban, stmt.fromDate, stmt.toDate);
      if (bereitsErfasst) {
        if (!mounted) { setState(() => _loading = false); return; }
        final weiter = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Zeitraum bereits erfasst'),
            content: Text('Für diese IBAN ist der Zeitraum '
                '${_dateFormat.format(stmt.fromDate)} – '
                '${_dateFormat.format(stmt.toDate)} bereits archiviert.\n\n'
                'Trotzdem importieren?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trotzdem')),
            ],
          ),
        );
        if (weiter != true) { setState(() => _loading = false); return; }
      }
      final gutAnzahl = stmt.transactions.where((t) => t.isCredit).length;
      // Archiv-Kopie (UTF-8-normalisiert).
      await CamtDateiRepository.speichern(
        CamtDatei(id: '', userId: '', dateiname: 'camt.xml',
          zeitraumVon: stmt.fromDate, zeitraumBis: stmt.toDate, iban: stmt.iban,
          anzahlEintraege: stmt.transactions.length, anzahlGutschriften: gutAnzahl, storagePfad: ''),
        Uint8List.fromList(utf8.encode(_xmlRoh ?? '')));

      final betriebe = ref.read(betriebeProvider)
          .where((b) => b.serverId != null)
          .map((b) => {'id': b.serverId!, 'name': b.name})
          .toList();
      final alleRechnungen = await RechnungRepository.getAll();
      final offeneRechnungen = alleRechnungen.where((r) =>
          r.rechnungstyp == 'kundenrechnung' &&
          (r.zahlungsstatus == 'offen' || r.zahlungsstatus == 'gesendet')).toList();
      final heinekenRechnungen = alleRechnungen.where((r) =>
          r.rechnungstyp == 'heineken_monat' && r.zahlungsstatus != 'bezahlt').toList();
      final bereitsVerarbeitet = <String>{
        ...await BuchungRepository.getAlleCamtTxKeys(),
        ...await CamtPrueflisteRepository.getAlleTxKeys(),
      };
      final regeln = await CamtRegelRepository.getAktive();
      final vorlagen = (await BuchungsVorlageRepository.getAll())
          .cast<BuchungsVorlage>();
      final vorlagenById = {for (final v in vorlagen) v.id: v};

      final stmtTx = _statement!.transactions;
      // Post-Stichtag + noch nicht verarbeitet → in Bereiche aufteilen.
      final post = stmtTx
          .where((t) => CamtStichtag.istAutomatisierbar(t.bookingDate))
          .where((t) => !bereitsVerarbeitet.contains(t.txKey))
          .toList();
      final bereich1 = post.where(istKundenzahlungsKandidat).toList();
      final bereich2 = post.where((t) => !istKundenzahlungsKandidat(t)).toList();
      // Pre-Stichtag / bereits-verarbeitet kommen mit in die Booker-Liste,
      // damit er sie als "übersprungen" korrekt zählt (er filtert selbst).
      final bookerTx = [
        ...bereich2,
        ...stmtTx.where((t) =>
            !CamtStichtag.istAutomatisierbar(t.bookingDate) ||
            bereitsVerarbeitet.contains(t.txKey)),
      ];

      final result = await CamtAutoBooker.run(
        transactions: bookerTx,
        betriebe: betriebe,
        offeneRechnungen: offeneRechnungen,
        heinekenRechnungen: heinekenRechnungen,
        bereitsVerarbeitet: bereitsVerarbeitet,
        regeln: regeln,
        vorlagenById: vorlagenById,
      );

      ref.invalidate(buchungenStreamProvider);
      ref.invalidate(camtPrueflisteProvider);

      // Bereich 1: Kundenzahlungen gegen offene Forderungen abgleichen.
      final abgleich = ForderungsAbgleichService.abgleich(
        gutschriften: bereich1,
        offeneForderungen: offeneRechnungen,
        betriebe: betriebe,
      );

      setState(() {
        _result = result;
        _abgleich = abgleich;
        _alleOffenen = offeneRechnungen;
        _betriebName = {for (final b in betriebe) b['id']!: b['name']!};
        _step = 2;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import-Fehler: $e')));
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
              r.fehler.isEmpty ? Icons.check_circle : Icons.warning,
              size: 64,
              color: r.fehler.isEmpty ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(height: 24),
            Text(
              'Verarbeitung abgeschlossen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _ResultRow(Icons.check, '${r.gebucht} verbucht', AppColors.success),
            if (r.pruefliste > 0)
              _ResultRow(Icons.info_outline, '${r.pruefliste} in Prüfliste', AppColors.warning),
            if (r.uebersprungen > 0)
              _ResultRow(Icons.skip_next,
                  '${r.uebersprungen} übersprungen (vor Stichtag / bereits verarbeitet)',
                  AppColors.textSecondary),
            if (r.fehler.isNotEmpty)
              _ResultRow(Icons.error_outline, '${r.fehler.length} Fehler', AppColors.error),
            if (r.fehler.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    children: r.fehler.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(e, style: const TextStyle(fontSize: 12, color: AppColors.error)),
                    )).toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push('/buchhaltung/camt-pruefliste'),
              icon: const Icon(Icons.fact_check),
              label: const Text('Zur Prüfliste'),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    _step = 0;
                    _statement = null;
                    _result = null;
                    _automatisierbarCount = 0;
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
          Flexible(child: Text(text, style: TextStyle(fontSize: 14, color: color))),
        ],
      ),
    );
  }
}
