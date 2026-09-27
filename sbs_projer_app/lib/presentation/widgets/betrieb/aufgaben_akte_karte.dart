import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart' show faelligText;
import 'package:sbs_projer_app/data/models/eigene_aufgabe.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_aktionen.dart';
import 'package:sbs_projer_app/presentation/widgets/detail/detail_karte.dart';

/// Sektion «Aufgaben (n)» auf der Betriebsseite (Migration 212, Entscheid
/// Daniel 27.09.2026): die offenen Aufgaben dieses Betriebs, darunter die
/// der letzten 30 Tage erledigten mit Haken. «+ Neue Aufgabe» belegt den
/// Betrieb vor.
///
/// Gleicher Aufbau wie `EinsaetzeAkteKarte`: dünne Anbindung hier, die
/// Darstellung in [AufgabenAkteInhalt] (testbar ohne Provider).
class AufgabenAkteKarte extends ConsumerWidget {
  final String betriebId;
  const AufgabenAkteKarte({super.key, required this.betriebId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AufgabenAkteInhalt(
      aufgaben: ref.watch(aufgabenFuerBetriebProvider(betriebId)),
      heute: DateTime.now(),
      onNeu: () => neueAufgabeDialog(context, ref, betriebId: betriebId),
      onBearbeiten: (a) => aufgabeBearbeitenDialog(context, ref, a),
      onErledigen: (a) => eigeneAufgabeErledigen(context, ref, a.id),
    );
  }
}

/// Darstellung ohne Datenanbindung — testbar ohne Provider.
///
/// CanvasKit: Zeilen und Aktionen aus `InkWell` + `Row`, kein `ListTile`,
/// keine Material-Buttons (CLAUDE.md).
class AufgabenAkteInhalt extends StatelessWidget {
  final AsyncValue<List<EigeneAufgabe>> aufgaben;
  final DateTime heute;
  final VoidCallback onNeu;
  final ValueChanged<EigeneAufgabe> onBearbeiten;
  final ValueChanged<EigeneAufgabe> onErledigen;

  const AufgabenAkteInhalt({
    super.key,
    required this.aufgaben,
    required this.heute,
    required this.onNeu,
    required this.onBearbeiten,
    required this.onErledigen,
  });

  @override
  Widget build(BuildContext context) {
    final alle = aufgaben.valueOrNull;
    final offen = alle?.where((a) => !a.erledigt).length;
    return DetailKarte(
      titel: offen == null ? 'Aufgaben' : 'Aufgaben ($offen)',
      icon: Icons.task_alt,
      aktion: InkWell(
        key: const Key('aufgabe_betrieb_neu'),
        onTap: onNeu,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                'Neue Aufgabe',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
      kinder: aufgaben.when(
        loading: () => const [_Hinweis('Wird geladen …')],
        error: (e, _) => [_Hinweis('Aufgaben nicht geladen: $e', rot: true)],
        data: (liste) => [
          if (liste.isEmpty) const _Hinweis('Keine offenen Aufgaben'),
          for (final a in liste)
            _AufgabeZeile(
              aufgabe: a,
              heute: heute,
              onTap: () => onBearbeiten(a),
              onErledigen: () => onErledigen(a),
            ),
        ],
      ),
    );
  }
}

class _AufgabeZeile extends StatelessWidget {
  final EigeneAufgabe aufgabe;
  final DateTime heute;
  final VoidCallback onTap;
  final VoidCallback onErledigen;

  const _AufgabeZeile({
    required this.aufgabe,
    required this.heute,
    required this.onTap,
    required this.onErledigen,
  });

  @override
  Widget build(BuildContext context) {
    final erledigt = aufgabe.erledigt;
    final zeit = erledigt
        ? 'erledigt ${DateFormat('dd.MM.').format(aufgabe.erledigtAm!.toLocal())}'
        : faelligText(aufgabe.faelligAm, heute);
    final ueberfaellig = !erledigt && zeit.startsWith('überfällig');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            // Offen: der Kreis hakt ab (wie «Erledigt» in der
            // Aufgabenliste). Erledigt: nur Anzeige.
            if (erledigt)
              const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.check_circle,
                  size: 20,
                  color: AppColors.success,
                  semanticLabel: 'erledigt',
                ),
              )
            else
              Semantics(
                button: true,
                label: 'Erledigt',
                child: InkWell(
                  key: Key('aufgabe_erledigen_${aufgabe.id}'),
                  onTap: onErledigen,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.radio_button_unchecked,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aufgabe.titel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: erledigt
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: erledigt ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (zeit.isNotEmpty)
                    Text(
                      zeit,
                      style: TextStyle(
                        fontSize: 12,
                        color: ueberfaellig
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Hinweis extends StatelessWidget {
  final String text;
  final bool rot;
  const _Hinweis(this.text, {this.rot = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: TextStyle(
        color: rot ? AppColors.error : AppColors.textSecondary,
        fontSize: 13,
      ),
    ),
  );
}
