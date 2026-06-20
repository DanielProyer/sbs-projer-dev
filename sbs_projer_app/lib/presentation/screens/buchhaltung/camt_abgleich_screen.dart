import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
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
      if (!mounted) return;
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
    final verbuchteTreffer = <AutoTreffer>[];
    for (final t in treffer) {
      try {
        await ForderungsAbgleichService.verbuche(
          zahlbetrag: t.gutschrift.amount,
          datum: t.gutschrift.bookingDate,
          forderungen: t.forderungen,
        );
        verbuchteTreffer.add(t);
      } catch (e) {
        fehler.add('${t.gutschrift.amount.toStringAsFixed(2)} CHF: $e');
      }
    }
    ref.invalidate(rechnungenStreamProvider);
    ref.invalidate(buchungenStreamProvider);
    if (mounted) {
      setState(() =>
          _ergebnis!.auto.removeWhere((t) => verbuchteTreffer.contains(t)));
      final verbucht = treffer.length - fehler.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fehler.isEmpty
            ? '$verbucht Zahlung(en) verbucht.'
            : '$verbucht verbucht, ${fehler.length} fehlgeschlagen: ${fehler.join('; ')}'),
      ));
    }
  }

  Future<void> _oeffneManuell(ManuellFall f) async {
    // Lokale Auswahl-Mengen für den Dialog (Sammelzahlung ↔ mehrere Forderungen).
    final gewaehlteGutschriften = <CamtTransaction>{};
    final gewaehlteForderungen = <Rechnung>{};

    final verbucht = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Live-Summen + 5-Rappen-gerundete Differenz.
            final zahlSumme =
                gewaehlteGutschriften.fold<double>(0, (s, g) => s + g.amount);
            final fordSumme = gewaehlteForderungen.fold<double>(
                0, (s, r) => s + r.betragBrutto);
            final diff = ((zahlSumme - fordSumme) * 20).roundToDouble() / 20;
            final kannVerbuchen = gewaehlteGutschriften.isNotEmpty &&
                gewaehlteForderungen.isNotEmpty;

            return AlertDialog(
              title: Text('Manuelle Zuordnung — ${f.betriebName}'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zahlungseingänge (Gutschriften) als Mehrfachauswahl.
                    const Text('Zahlungseingänge',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final g in f.gutschriften)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: gewaehlteGutschriften.contains(g),
                        title: Text(
                          '${g.amount.toStringAsFixed(2)} CHF — '
                          '${_dateFormat.format(g.bookingDate)}',
                        ),
                        onChanged: (sel) => setDialogState(() {
                          if (sel == true) {
                            gewaehlteGutschriften.add(g);
                          } else {
                            gewaehlteGutschriften.remove(g);
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    // Offene Forderungen als Mehrfachauswahl.
                    const Text('Offene Forderungen',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final r in f.forderungen)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: gewaehlteForderungen.contains(r),
                        title: Text(
                          '${r.rechnungsnummer ?? '?'} — '
                          '${r.betragBrutto.toStringAsFixed(2)} CHF',
                        ),
                        onChanged: (sel) => setDialogState(() {
                          if (sel == true) {
                            gewaehlteForderungen.add(r);
                          } else {
                            gewaehlteForderungen.remove(r);
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    // Summen + Differenz-Hinweis (gespiegelt aus rechnung_detail_screen).
                    Text(
                      'Zahlung: CHF ${zahlSumme.toStringAsFixed(2)}\n'
                      'Forderung: CHF ${fordSumme.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (diff.abs() >= 0.01) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: diff < 0
                              ? AppColors.warning.withAlpha(25)
                              : AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: diff < 0
                                ? AppColors.warning.withAlpha(80)
                                : AppColors.success.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              diff < 0
                                  ? Icons.trending_down
                                  : Icons.trending_up,
                              size: 18,
                              color: diff < 0
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                diff < 0
                                    ? 'Unterzahlung: CHF ${diff.abs().toStringAsFixed(2)}\n'
                                        'Wird als Debitorenverlust (3805) gebucht'
                                    : 'Mehrzahlung: CHF ${diff.toStringAsFixed(2)}\n'
                                        'Wird als a.o. Ertrag (8000) gebucht',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: diff < 0
                                      ? AppColors.warning
                                      : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: kannVerbuchen
                      ? () async {
                          try {
                            await ForderungsAbgleichService.verbuche(
                              zahlbetrag: zahlSumme,
                              datum: gewaehlteGutschriften.first.bookingDate,
                              forderungen: gewaehlteForderungen.toList(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content:
                                      Text('Verbuchungs-Fehler: $e')));
                            }
                          }
                        }
                      : null,
                  child: const Text('Verbuchen'),
                ),
              ],
            );
          },
        );
      },
    );

    if (verbucht != true) return;

    ref.invalidate(rechnungenStreamProvider);
    ref.invalidate(buchungenStreamProvider);
    if (!mounted) return;
    setState(() {
      // Verbuchte Forderungen + konsumierte Gutschriften aus dem Fall entfernen.
      f.forderungen.removeWhere((r) => gewaehlteForderungen.contains(r));
      f.gutschriften.removeWhere((g) => gewaehlteGutschriften.contains(g));
      // Bleiben keine Forderungen mehr offen, fällt der ganze Fall weg.
      // Forderungs-getrieben: ein Fall verschwindet, sobald keine offene Forderung mehr da ist.
      // Eine evtl. übrige (nicht zugeordnete) Gutschrift wird hier bewusst nicht weiter angezeigt
      // — sie ist eine Bankzeile ohne offene Forderung (analog zum Scoping in ForderungsAbgleichService).
      if (f.forderungen.isEmpty) {
        _ergebnis!.manuell.remove(f);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
    }
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
