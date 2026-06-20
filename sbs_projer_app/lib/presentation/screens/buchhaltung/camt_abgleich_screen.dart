import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/services/camt/camt053_parser.dart';
import 'package:sbs_projer_app/services/camt/file_picker_export.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';

/// Forderungs-getriebener camt-Abgleich: Datei wählen → Vorschau (3 Gruppen)
/// → Auto-Treffer verbuchen. Manuelle Fälle öffnen (Task 9) ist noch ein Stub.
class CamtAbgleichScreen extends ConsumerStatefulWidget {
  const CamtAbgleichScreen({super.key});

  @override
  ConsumerState<CamtAbgleichScreen> createState() => _CamtAbgleichScreenState();
}

class _CamtAbgleichScreenState extends ConsumerState<CamtAbgleichScreen> {
  AbgleichErgebnis? _ergebnis;
  bool _loading = false;
  String? _dateiname;

  final _dateFormat = DateFormat('dd.MM.yyyy');

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

      // Archivieren (XML in Bucket + Metadaten-Record).
      final gut = stmt.transactions.where((t) => t.isCredit).length;
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
          .map((b) => {'id': b.serverId!, 'name': b.name})
          .toList();

      final erg = ForderungsAbgleichService.abgleich(
        gutschriften: stmt.transactions,
        offeneForderungen: offen,
        betriebe: betriebe,
      );

      setState(() {
        _ergebnis = erg;
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

  // === Ergebnis (3 Gruppen) ===
  Widget _buildErgebnis(AbgleichErgebnis erg) {
    return ListView(
      children: [
        // 🟢 Auto-gematcht
        _Gruppe(
          titel: '🟢 Auto-gematcht (${erg.auto.length})',
          children: [
            if (erg.auto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _verbucheAlle,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Alle auto-Treffer verbuchen'),
                  ),
                ),
              ),
            for (final t in erg.auto)
              ListTile(
                title: Text(
                  '${t.gutschrift.amount.toStringAsFixed(2)} CHF — '
                  '${t.forderungen.map((r) => r.rechnungsnummer ?? '?').join(', ')}',
                ),
                subtitle: Text(_dateFormat.format(t.gutschrift.bookingDate)),
                trailing: FilledButton(
                  onPressed: () => _verbuche(t),
                  child: const Text('Verbuchen'),
                ),
              ),
          ],
        ),

        // 🟡 Manuell zuordnen
        _Gruppe(
          titel: '🟡 Manuell zuordnen (${erg.manuell.length})',
          children: [
            for (final f in erg.manuell)
              ListTile(
                title: Text(f.betriebName),
                subtitle: Text(
                  '${f.gutschriften.length} Zahlung(en), '
                  '${f.forderungen.length} offene Forderung(en)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _oeffneManuell(f),
              ),
          ],
        ),

        // 🔴 Keine Zahlung gefunden
        _Gruppe(
          titel: '🔴 Keine Zahlung gefunden (${erg.keineZahlung.length})',
          children: [
            for (final r in erg.keineZahlung)
              ListTile(
                dense: true,
                title: Text(
                  '${r.rechnungsnummer ?? '?'} — ${r.betragBrutto.toStringAsFixed(2)} CHF',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _verbuche(AutoTreffer t) async {
    try {
      await ForderungsAbgleichService.verbuche(
        zahlbetrag: t.gutschrift.amount,
        datum: t.gutschrift.bookingDate,
        forderungen: t.forderungen,
      );
      ref.invalidate(rechnungenStreamProvider);
      ref.invalidate(buchungenStreamProvider);
      setState(() => _ergebnis!.auto.remove(t));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Verbuchungs-Fehler: $e')));
      }
    }
  }

  Future<void> _verbucheAlle() async {
    final treffer = List<AutoTreffer>.from(_ergebnis!.auto);
    final fehler = <String>[];
    for (final t in treffer) {
      try {
        await ForderungsAbgleichService.verbuche(
          zahlbetrag: t.gutschrift.amount,
          datum: t.gutschrift.bookingDate,
          forderungen: t.forderungen,
        );
        setState(() => _ergebnis!.auto.remove(t));
      } catch (e) {
        fehler.add('${t.gutschrift.amount.toStringAsFixed(2)} CHF: $e');
      }
    }
    ref.invalidate(rechnungenStreamProvider);
    ref.invalidate(buchungenStreamProvider);
    if (mounted) {
      final verbucht = treffer.length - fehler.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fehler.isEmpty
            ? '$verbucht Zahlung(en) verbucht.'
            : '$verbucht verbucht, ${fehler.length} fehlgeschlagen: ${fehler.join('; ')}'),
      ));
    }
  }

  void _oeffneManuell(ManuellFall f) {
    // TODO(Task 9): Dialog zur manuellen Zuordnung der Zahlungen ↔ Forderungen.
  }
}

/// Titel-Sektion mit darunterliegenden Einträgen.
class _Gruppe extends StatelessWidget {
  final String titel;
  final List<Widget> children;

  const _Gruppe({required this.titel, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            titel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        if (children.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('—', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ...children,
        const Divider(height: 24),
      ],
    );
  }
}
