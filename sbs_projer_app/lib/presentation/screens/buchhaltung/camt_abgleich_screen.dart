import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/abgleich_vorschau.dart';
import 'package:sbs_projer_app/services/camt/camt053_parser.dart';
import 'package:sbs_projer_app/services/camt/file_picker_export.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';

/// Forderungs-getriebener camt-Abgleich: Datei wählen → Vorschau (3 Gruppen)
/// → Auto-Treffer verbuchen. Manuelle Fälle: Dialog mit Sammelzahlung-Split
/// und 5-Rappen-Differenz (Debitorenverlust 3805 / a.o. Ertrag 8000).
class CamtAbgleichScreen extends ConsumerStatefulWidget {
  const CamtAbgleichScreen({super.key});

  @override
  ConsumerState<CamtAbgleichScreen> createState() => _CamtAbgleichScreenState();
}

class _CamtAbgleichScreenState extends ConsumerState<CamtAbgleichScreen> {
  AbgleichErgebnis? _ergebnis;
  bool _loading = false;
  String? _dateiname;

  // Pool aller offenen Forderungen + Betriebsnamen für die manuelle Zuordnung
  // der „Nicht zugeordnet"-Gutschriften.
  List<Rechnung> _alleOffenen = [];
  Map<String, String> _betriebName = {};

  final _dateFormat = DateFormat('dd.MM.yyyy');

  // Lesebreite auf Desktop; auf schmalen Fenstern füllt der Inhalt die Breite.
  static const _maxBreite = 880.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forderungs-Abgleich')),
      body: _ergebnis == null ? _buildPicker() : _buildErgebnis(_ergebnis!),
    );
  }

  // === Datei wählen ===
  Widget _buildPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare_arrows, size: 64, color: AppColors.primary.withAlpha(100)),
            const SizedBox(height: 24),
            Text(
              'Zahlungseingänge mit offenen Forderungen abgleichen',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_loading)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _waehleDatei,
                icon: const Icon(Icons.upload_file),
                label: const Text('camt-Datei wählen'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _waehleDatei() async {
    setState(() => _loading = true);
    try {
      final picked = await pickXmlFile();
      if (picked == null) {
        setState(() => _loading = false);
        return;
      }
      _dateiname = picked.name;

      var xml = picked.content;
      if (xml.startsWith('﻿')) xml = xml.substring(1); // BOM entfernen
      final stmt = Camt053Parser.parse(xml);

      // Doppel-Upload-Schutz: ist dieser Zeitraum (IBAN + von/bis) schon archiviert?
      final bereitsErfasst = await CamtDateiRepository.existsZeitraum(
          stmt.iban, stmt.fromDate, stmt.toDate);
      if (bereitsErfasst) {
        if (!mounted) {
          setState(() => _loading = false);
          return;
        }
        final trotzdem = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Zeitraum bereits erfasst'),
            content: Text(
              'Für diese IBAN ist der Zeitraum '
              '${_dateFormat.format(stmt.fromDate)} – '
              '${_dateFormat.format(stmt.toDate)} bereits archiviert.\n\n'
              'Trotzdem archivieren?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Trotzdem archivieren'),
              ),
            ],
          ),
        );
        if (trotzdem != true) {
          setState(() => _loading = false);
          return;
        }
      }

      // Archivieren (XML in Bucket + Metadaten-Record).
      final gut = stmt.transactions.where((t) => t.isCredit).length;
      // Archiv-Kopie: UTF-8-normalisiert (Picker liefert dekodierten Text, keine Roh-Bytes).
      final bytes = Uint8List.fromList(utf8.encode(picked.content));
      await CamtDateiRepository.speichern(
        CamtDatei(
          id: '',
          userId: '',
          dateiname: _dateiname ?? 'camt.xml',
          zeitraumVon: stmt.fromDate,
          zeitraumBis: stmt.toDate,
          iban: stmt.iban,
          anzahlEintraege: stmt.transactions.length,
          anzahlGutschriften: gut,
          storagePfad: '',
        ),
        bytes,
      );

      // Offene Kundenrechnungen laden (wie camt_import_screen).
      final offen = (await RechnungRepository.getAll())
          .where((r) =>
              r.rechnungstyp == 'kundenrechnung' &&
              (r.zahlungsstatus == 'offen' || r.zahlungsstatus == 'gesendet'))
          .toList();
      final betriebe = ref
          .read(betriebeProvider)
          .where((b) => b.serverId != null)
          .map((b) => {
                'id': b.serverId!,
                'name': b.name,
                'ort': b.ort ?? '',
                'aliase': b.zahlerAliase.join('\n'),
              })
          .toList();

      final erg = ForderungsAbgleichService.abgleich(
        gutschriften: stmt.transactions,
        offeneForderungen: offen,
        betriebe: betriebe,
      );

      setState(() {
        _ergebnis = erg;
        _alleOffenen = offen;
        _betriebName = {
          for (final b in betriebe)
            b['id']!: (b['ort'] ?? '').isEmpty
                ? b['name']!
                : '${b['name']} · ${b['ort']}'
        };
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler beim Abgleich: $e')));
      }
    }
  }

  // === Ergebnis (breitenbegrenzt) — Inhalt im wiederverwendbaren Widget ===
  Widget _buildErgebnis(AbgleichErgebnis erg) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxBreite),
        child: AbgleichVorschau(
          ergebnis: erg,
          alleOffenen: _alleOffenen,
          betriebName: _betriebName,
        ),
      ),
    );
  }
}
