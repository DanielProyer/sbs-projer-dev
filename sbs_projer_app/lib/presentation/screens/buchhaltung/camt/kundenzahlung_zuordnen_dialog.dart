import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/zahlungsdifferenz_text.dart';
import 'package:sbs_projer_app/data/models/camt_pruefliste_eintrag.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/camt_pruefliste_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_pruefliste_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';

/// Ordnet eine in der Prüfliste geparkte **Kundenzahlung** (Kategorie
/// `kundenzahlung`, Gutschrift) offenen Rechnungen zu und verbucht sie —
/// derselbe Buchungspfad wie der Import-Abgleich
/// ([ForderungsAbgleichService.verbuche], reversibel über den camt-Schlüssel).
/// Nach der Buchung wird der Prüflisten-Eintrag entfernt.
Future<void> showKundenzahlungZuordnenDialog(
  BuildContext context,
  WidgetRef ref,
  CamtPrueflisteEintrag e,
) async {
  final dateFormat = DateFormat('dd.MM.yyyy');

  // Offene Kundenrechnungen frisch laden (die Prüfliste kann Tage alt sein).
  final List<Rechnung> offene;
  try {
    final alle = await RechnungRepository.getAll();
    offene = alle
        .where((r) =>
            r.rechnungstyp == 'kundenrechnung' &&
            (r.zahlungsstatus == 'offen' || r.zahlungsstatus == 'gesendet'))
        .toList()
      ..sort((a, b) => b.rechnungsdatum.compareTo(a.rechnungsdatum));
  } catch (err) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rechnungen konnten nicht geladen werden: $err')));
    }
    return;
  }
  final betriebName = {
    for (final b in ref.read(betriebeProvider))
      if (b.serverId != null)
        b.serverId!: (b.ort ?? '').isEmpty ? b.name : '${b.name} · ${b.ort}'
  };

  if (!context.mounted) return;
  final gewaehlt = <Rechnung>{};
  var suche = '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final gefiltert = offene.where((r) {
          if (suche.isEmpty) return true;
          final q = suche.toLowerCase();
          return (r.rechnungsnummer ?? '').toLowerCase().contains(q) ||
              (betriebName[r.betriebId] ?? '').toLowerCase().contains(q);
        }).toList();
        final fordSumme =
            gewaehlt.fold<double>(0, (s, r) => s + r.betragBrutto);
        final info = bewerteDifferenz(e.betrag, fordSumme);
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          title: Text('Zahlung zuordnen — ${e.betrag.toStringAsFixed(2)} CHF'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info zur geparkten Zahlung.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${dateFormat.format(e.bookingDatum)} — '
                        '${e.betrag.toStringAsFixed(2)} CHF',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if ((e.parteiName ?? '').isNotEmpty ||
                          (e.referenz ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if ((e.parteiName ?? '').isNotEmpty) e.parteiName!,
                            if ((e.referenz ?? '').isNotEmpty) e.referenz!,
                          ].join(' · '),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Suche (Rechnungsnr. oder Betrieb)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setDialogState(() => suche = v),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final r in gefiltert.take(50))
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: gewaehlt.contains(r),
                          title: Text(
                              '${dateFormat.format(r.rechnungsdatum)} — '
                              '${r.betragBrutto.toStringAsFixed(2)} CHF'),
                          subtitle: Text('Rechnung ${r.rechnungsnummer ?? '?'} · '
                              '${betriebName[r.betriebId] ?? '?'}'),
                          onChanged: (sel) => setDialogState(() {
                            if (sel == true) {
                              gewaehlt.add(r);
                            } else {
                              gewaehlt.remove(r);
                            }
                          }),
                        ),
                      if (gefiltert.length > 50)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '… und ${gefiltert.length - 50} weitere — Suche eingrenzen',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (!info.istKeine && gewaehlt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      info.text,
                      style: TextStyle(
                          fontSize: 12,
                          color: info.istMinder
                              ? AppColors.error
                              : AppColors.success),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            FilledButton(
              onPressed: gewaehlt.isEmpty
                  ? null
                  : () async {
                      try {
                        await ForderungsAbgleichService.verbuche(
                          zahlbetrag: e.betrag,
                          datum: e.bookingDatum,
                          forderungen: gewaehlt.toList(),
                          camtTxKey: e.txKey,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (err) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('Verbuchungs-Fehler: $err')));
                        }
                      }
                    },
              child: const Text('Verbuchen'),
            ),
          ],
        );
      },
    ),
  );

  if (ok == true) {
    // Buchung erledigt → Eintrag räumen (wie beim Buchen eines Vorschlags).
    await CamtPrueflisteRepository.deleteByTxKey(e.txKey);
    ref.invalidate(camtPrueflisteProvider);
    ref.invalidate(rechnungenStreamProvider);
    ref.invalidate(buchungenStreamProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
    }
  }
}
