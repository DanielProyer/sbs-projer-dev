// lib/presentation/screens/buchhaltung/widgets/erfolgsrechnung_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/services/buchhaltung/erfolgsrechnung_service.dart';

class ErfolgsrechnungView extends ConsumerWidget {
  final Zeitraum zeitraum;
  const ErfolgsrechnungView({super.key, required this.zeitraum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stufenAsync = ref.watch(erfolgsrechnungZeitraumProvider(zeitraum));
    final kontenAsync = ref.watch(erKontenAufstellungProvider(zeitraum));
    final df = DateFormat('dd.MM.yyyy');
    final titel = 'Erfolgsrechnung ${df.format(zeitraum.von)} – ${df.format(zeitraum.bis)}';

    return stufenAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (er) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _stufenCard(context, titel, er),
          const SizedBox(height: 12),
          kontenAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('Konten-Fehler: $e'),
            data: (auf) => Column(
              children: [
                _klassenCard(auf),
                const SizedBox(height: 12),
                _kontenCard(auf),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stufenCard(BuildContext context, String titel, ErfolgsrechnungDaten er) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titel, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _z('Nettoerlös (3)', er.nettoerloes, AppColors.success),
              _z('− Materialaufwand (4)', -er.materialaufwand, AppColors.error),
              const Divider(),
              _z('Bruttoergebnis 1', er.bruttoergebnis1, _c(er.bruttoergebnis1), bold: true),
              _z('− Personalaufwand (5)', -er.personalaufwand, AppColors.error),
              const Divider(),
              _z('Bruttoergebnis 2', er.bruttoergebnis2, _c(er.bruttoergebnis2), bold: true),
              _z('− Übriger Aufwand (6000–6799)', -er.uebrigerAufwand, AppColors.error),
              const Divider(),
              _z('EBITDA', er.ebitda, _c(er.ebitda), bold: true),
              _z('− Abschreibungen (6800)', -er.abschreibungen, AppColors.error),
              const Divider(),
              _z('EBIT', er.ebit, _c(er.ebit), bold: true),
              _z('± Finanzerfolg (6900)', er.finanzerfolg, _c(er.finanzerfolg)),
              const Divider(),
              _z('EBT (vor Steuern)', er.ebt, _c(er.ebt), bold: true),
              _z('± Betriebsfremd/a.o. (7/8000–8800)', er.nebenerfolg, _c(er.nebenerfolg)),
              _z('− Direkte Steuern (8900)', -er.steuern, AppColors.error),
              const Divider(thickness: 2),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: _c(er.jahresergebnis).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _z('Jahresergebnis', er.jahresergebnis, _c(er.jahresergebnis), bold: true),
              ),
            ],
          ),
        ),
      );

  Widget _klassenCard(ErKontenAufstellung auf) => Card(
        child: ExpansionTile(
          title: const Text('Kontenklassen', style: TextStyle(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final kl in auf.klassen)
              if (kl.konten.any((k) => k.summe != 0)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: _z('Klasse ${kl.klasse}', kl.summe, AppColors.textPrimary, bold: true),
                ),
                for (final kt in kl.konten.where((k) => k.summe != 0))
                  _z('${kt.nr}  ${kt.bezeichnung ?? ''}', kt.summe, AppColors.textPrimary),
              ],
          ],
        ),
      );

  Widget _kontenCard(ErKontenAufstellung auf) => Card(
        child: ExpansionTile(
          title: const Text('Alle Konten', style: TextStyle(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final kl in auf.klassen) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Text('Klasse ${kl.klasse}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              for (final kt in kl.konten)
                _z('${kt.nr}  ${kt.bezeichnung ?? ''}', kt.summe, AppColors.textPrimary),
            ],
          ],
        ),
      );

  Color _c(double v) => v >= 0 ? AppColors.success : AppColors.error;

  Widget _z(String label, double betrag, Color color, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: 14)),
            ),
            Text('${chf(betrag)} CHF',
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600, fontSize: 14, color: color)),
          ],
        ),
      );
}
