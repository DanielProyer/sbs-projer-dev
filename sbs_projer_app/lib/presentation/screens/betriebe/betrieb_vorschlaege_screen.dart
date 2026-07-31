import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/vorschlag_anzeige.dart';
import 'package:sbs_projer_app/data/models/betrieb_vorschlag.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_vorschlag_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_vorschlag_providers.dart';

/// Prüfliste für Änderungsvorschläge aus Google und Kundenwebsites (Spec
/// docs/superpowers/specs/2026-07-31-betriebsdaten-aktuell-halten-design.md).
///
/// Öffnungszeiten, Ruhetage, Ferien, Saison und der Google-Status werden
/// NIE still in die Stammdaten übernommen — eine still überschriebene
/// Öffnungszeit wäre schlimmer als gar keine, weil sie gepflegt aussieht,
/// ohne es zu sein. Daniel entscheidet hier jede Zeile einzeln, mit einer
/// Sammelübernahme für den Fall, dass Google und Website sich einig sind.
///
/// Saison-Vorschläge sind von der Sammelübernahme IMMER ausgenommen — siehe
/// `BetriebVorschlagRepository.alleUebereinstimmendenUebernehmen`.
class BetriebVorschlaegeScreen extends ConsumerWidget {
  const BetriebVorschlaegeScreen({super.key});

  Future<void> _uebernehmen(
    BuildContext context,
    WidgetRef ref,
    BetriebVorschlagDto v,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BetriebVorschlagRepository.uebernehmen(v);
      ref.invalidate(offeneVorschlaegeProvider);
      ref.invalidate(betriebeStreamProvider);
      if (v.feld == 'ferien') ref.invalidate(ferienPeriodenProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Übernommen.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _verwerfen(
    BuildContext context,
    WidgetRef ref,
    BetriebVorschlagDto v,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await BetriebVorschlagRepository.verwerfen(v.id);
      ref.invalidate(offeneVorschlaegeProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Verworfen.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _alleUebereinstimmenden(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final anzahl =
          await BetriebVorschlagRepository.alleUebereinstimmendenUebernehmen();
      ref.invalidate(offeneVorschlaegeProvider);
      ref.invalidate(betriebeStreamProvider);
      ref.invalidate(ferienPeriodenProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('$anzahl Vorschläge übernommen.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(offeneVorschlaegeProvider);
    final betriebNamen = ref.watch(betriebNameMapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Änderungsvorschläge')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (vorschlaege) {
          if (vorschlaege.isEmpty) {
            return const Center(
              child: Text(
                'Keine offenen Vorschläge.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final uebereinstimmend = vorschlaege
              .where((v) => v.quelle == 'google_website' && v.feld != 'saison')
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              if (uebereinstimmend > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _alleUebereinstimmenden(context, ref),
                      icon: const Icon(Icons.done_all),
                      label: Text(
                        'Alle übernehmen, bei denen Google und Website '
                        'übereinstimmen ($uebereinstimmend)',
                      ),
                    ),
                  ),
                ),
              for (final v in vorschlaege)
                _VorschlagKarte(
                  vorschlag: v,
                  betriebName: betriebNamen[v.betriebId] ?? '?',
                  onUebernehmen: () => _uebernehmen(context, ref, v),
                  onVerwerfen: () => _verwerfen(context, ref, v),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _VorschlagKarte extends StatelessWidget {
  final BetriebVorschlagDto vorschlag;
  final String betriebName;
  final VoidCallback onUebernehmen;
  final VoidCallback onVerwerfen;

  const _VorschlagKarte({
    required this.vorschlag,
    required this.betriebName,
    required this.onUebernehmen,
    required this.onVerwerfen,
  });

  @override
  Widget build(BuildContext context) {
    final v = vorschlag;
    final istSaison = v.feld == 'saison';
    final istStatus = v.feld == 'status';
    final altText = vorschlagWertAnzeige(v.feld, v.altWert);
    final neuText = vorschlagWertAnzeige(v.feld, v.neuWert);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: istSaison
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.warning, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    betriebName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _QuelleBadge(quelle: v.quelle),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (istSaison) ...[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  vorschlagFeldLabel(v.feld),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: istSaison ? AppColors.warning : AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd.MM.yyyy').format(v.gefundenAm),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (istSaison)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _WertSpalte(label: 'Bisher', text: altText),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                  Expanded(
                    child: _WertSpalte(label: 'Neu', text: neuText),
                  ),
                ],
              )
            else
              Text(
                '$altText  →  $neuText',
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onVerwerfen,
                  child: const Text('Verwerfen'),
                ),
                const SizedBox(width: 4),
                if (!istStatus)
                  FilledButton(
                    onPressed: onUebernehmen,
                    child: const Text('Übernehmen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WertSpalte extends StatelessWidget {
  final String label;
  final String text;

  const _WertSpalte({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _QuelleBadge extends StatelessWidget {
  final String quelle;

  const _QuelleBadge({required this.quelle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        vorschlagQuelleLabel(quelle),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.info,
        ),
      ),
    );
  }
}
