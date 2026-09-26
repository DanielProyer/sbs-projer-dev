import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/betrieb_geld.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_akte_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/detail/detail_karte.dart';

/// «Geld» auf der Betriebsseite (Akte, T10): offener Saldo, Mahnstufe,
/// Kundenguthaben. Tippen öffnet die Rechnungsliste, gesucht nach dem
/// Betriebsnamen über alle Jahre (`/rechnungen?suche=`).
///
/// Nur im Web — Rechnungen und Buchungen liegen nicht in Isar.
class BetriebGeldBlock extends ConsumerWidget {
  final String betriebId;
  final String betriebName;
  const BetriebGeldBlock({
    super.key,
    required this.betriebId,
    required this.betriebName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kIsWeb) return const SizedBox.shrink();
    final stand = ref.watch(betriebGeldProvider(betriebId));
    return BetriebGeldInhalt(
      stand: stand,
      onTap: () => context.push(
        '/rechnungen?suche=${Uri.encodeQueryComponent(betriebName)}',
      ),
    );
  }
}

/// Darstellung ohne Datenanbindung — testbar ohne Provider.
class BetriebGeldInhalt extends StatelessWidget {
  final AsyncValue<BetriebGeldStand> stand;
  final VoidCallback onTap;
  const BetriebGeldInhalt({super.key, required this.stand, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final zeilen = stand.when<List<Widget>>(
      loading: () => const [_Zeile('Wird geladen …', grau: true)],
      // Nie eine 0 zeigen, wenn nichts geladen ist — das sähe aus wie
      // «alles bezahlt».
      error: (_, _) => const [_Zeile('Geld: nicht geladen', rot: true)],
      data: _zeilen,
    );
    return DetailKarte(
      titel: 'Geld',
      icon: Icons.payments,
      kinder: [
        InkWell(
          key: const Key('betrieb_geld_tap'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: zeilen,
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
      ],
    );
  }

  static List<Widget> _zeilen(BetriebGeldStand g) {
    final rechnungen = g.anzahlOffen == 1 ? 'Rechnung' : 'Rechnungen';
    return [
      if (g.anzahlOffen == 0)
        const _Zeile('Keine offenen Rechnungen')
      else
        _Zeile(
          'Offen CHF ${chf(g.offenCHF)} (${g.anzahlOffen} $rechnungen'
          '${g.anzahlUeberfaellig > 0 ? ', davon ${g.anzahlUeberfaellig} überfällig' : ''})',
          rot: g.anzahlUeberfaellig > 0,
        ),
      if (g.hoechsteMahnstufe > 0)
        _Zeile('Mahnstufe: ${mahnstufeLabel(g.hoechsteMahnstufe)}', rot: true),
      if (g.guthabenCHF > 0)
        _Zeile('Kundenguthaben CHF ${chf(g.guthabenCHF)}'),
    ];
  }
}

class _Zeile extends StatelessWidget {
  final String text;
  final bool rot;
  final bool grau;
  const _Zeile(this.text, {this.rot = false, this.grau = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: rot
              ? AppColors.error
              : grau
              ? AppColors.textSecondary
              : null,
          fontWeight: rot ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}
