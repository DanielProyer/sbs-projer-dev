import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/presentation/providers/preis_providers.dart';
import 'package:sbs_projer_app/presentation/screens/einstellungen/widgets/geschaeft_form.dart';

class EinstellungenScreen extends ConsumerStatefulWidget {
  const EinstellungenScreen({super.key});

  @override
  ConsumerState<EinstellungenScreen> createState() =>
      _EinstellungenScreenState();
}

class _EinstellungenScreenState extends ConsumerState<EinstellungenScreen> {
  Future<void> _editPoNummer(String preisId, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PO-Nummer'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'PO-Nummer',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result != null) {
      await PreisRepository.updateFields(
          preisId, {'heineken_po_nummer': result});
      ref.invalidate(aktuellePreiseProvider);
    }
  }

  Future<void> _editMwst(
      String preisId, double normal, double reduziert) async {
    final normalCtrl =
        TextEditingController(text: normal.toStringAsFixed(2));
    final reduzCtrl =
        TextEditingController(text: reduziert.toStringAsFixed(2));
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('MwSt-Sätze'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: normalCtrl,
              decoration: const InputDecoration(
                labelText: 'Normal (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reduzCtrl,
              decoration: const InputDecoration(
                labelText: 'Reduziert (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (result == true) {
      final n = double.tryParse(normalCtrl.text);
      final r = double.tryParse(reduzCtrl.text);
      if (n != null && r != null) {
        await PreisRepository.updateFields(preisId, {
          'mwst_satz': n,
          'mwst_satz_reduziert': r,
        });
        ref.invalidate(aktuellePreiseProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aktuellePreise = ref.watch(aktuellePreiseProvider);
    final geschaeftAsync = ref.watch(geschaeftProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: aktuellePreise.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (preis) {
          if (preis == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Keine Preise hinterlegt.'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/einstellungen/preise/neu'),
                    icon: const Icon(Icons.add),
                    label: const Text('Erste Preisversion erstellen'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Geschäft (neu)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: const Icon(Icons.store, color: AppColors.primary),
                  title: const Text('Geschäft',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Firma, Geschäftsführer, Kontakt, MWST/UID'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    geschaeftAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Fehler: $e'),
                      data: (g) => GeschaeftForm(key: ValueKey(g.id), geschaeft: g),
                    ),
                  ],
                ),
              ),

              // Lohn (Einstieg)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.payments, color: AppColors.primary),
                  title: const Text('Lohn-Einstellungen',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sozialversicherungssätze & BVG pro Jahr'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/buchhaltung/lohn/einstellungen'),
                ),
              ),

              // Biersorten verwalten
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.local_drink, color: AppColors.primary),
                  title: const Text('Biersorten',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Eigen/Fremd/Orion/Wein Zuordnung'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/einstellungen/biersorten'),
                ),
              ),

              // Heineken
              _SectionCard(
                title: 'Heineken',
                icon: Icons.business,
                children: [
                  _EditableInfoRow(
                    'PO-Nummer',
                    preis.heinekenPoNummer ?? 'Nicht gesetzt',
                    onEdit: () => _editPoNummer(preis.id, preis.heinekenPoNummer),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.assignment_ind, size: 20, color: AppColors.primary),
                    title: const Text('Kontakt-Zuweisungen',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Monatsrechnung, Raster, Heigenie, Material'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => context.push('/heineken/zuweisungen'),
                  ),
                ],
              ),

              // Aktuelle Preise Header
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.check_circle, color: AppColors.success),
                title: const Text('Aktuelle Preise',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Gültig ab ${DateFormat('dd.MM.yyyy').format(preis.gueltigAb)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),

              // Reinigungspreise
              _SectionCard(
                title: 'Reinigungspreise',
                icon: Icons.cleaning_services,
                children: [
                  _InfoRow('Bier',
                      '${preis.grundtarifReinigungBier.toStringAsFixed(2)} CHF'),
                  _InfoRow('Orion',
                      '${preis.grundtarifReinigungOrion.toStringAsFixed(2)} CHF'),
                  _InfoRow('Heigenie',
                      '${preis.grundtarifHeigenie.toStringAsFixed(2)} CHF'),
                  _InfoRow('Fremd',
                      '${preis.grundtarifReinigungFremd.toStringAsFixed(2)} CHF'),
                  _InfoRow('Wein',
                      '${preis.grundtarifWein.toStringAsFixed(2)} CHF'),
                  const Divider(height: 16),
                  const Text('Zusatz pro Hahn',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  _InfoRow('Eigen',
                      '${preis.zusatzHahnEigen.toStringAsFixed(2)} CHF'),
                  _InfoRow('Orion',
                      '${preis.zusatzHahnOrion.toStringAsFixed(2)} CHF'),
                  _InfoRow('Fremd',
                      '${preis.zusatzHahnFremd.toStringAsFixed(2)} CHF'),
                  _InfoRow('Wein',
                      '${preis.zusatzHahnWein.toStringAsFixed(2)} CHF'),
                  _InfoRow('Anderer Standort',
                      '${preis.zusatzHahnAndererStandort.toStringAsFixed(2)} CHF'),
                ],
              ),

              // Störungspreise
              _SectionCard(
                title: 'Störungspreise',
                icon: Icons.warning_amber,
                children: [
                  _TwoColRow('Bereich', 'Normal', 'Bergkunde'),
                  _TwoColRow('1',
                      preis.stoerung1Normal.toStringAsFixed(2),
                      preis.stoerung1Bergkunde.toStringAsFixed(2)),
                  _TwoColRow('2',
                      preis.stoerung2Normal.toStringAsFixed(2),
                      preis.stoerung2Bergkunde.toStringAsFixed(2)),
                  _TwoColRow('3',
                      preis.stoerung3Normal.toStringAsFixed(2),
                      preis.stoerung3Bergkunde.toStringAsFixed(2)),
                  _TwoColRow('4',
                      preis.stoerung4Normal.toStringAsFixed(2),
                      preis.stoerung4Bergkunde.toStringAsFixed(2)),
                  _TwoColRow('5',
                      preis.stoerung5Normal.toStringAsFixed(2),
                      preis.stoerung5Bergkunde.toStringAsFixed(2)),
                  const Divider(height: 16),
                  _InfoRow('Anfahrt-Pauschale',
                      '${preis.stoerungAnfahrtPauschale.toStringAsFixed(2)} CHF'),
                  _InfoRow('km-Grenze',
                      '${preis.stoerungAnfahrtKmGrenze} km'),
                  _InfoRow('km-Satz',
                      '${preis.stoerungAnfahrtKmSatz.toStringAsFixed(3)} CHF'),
                  _InfoRow('Wochenende-Zuschlag',
                      '${preis.stoerungWochenendeZuschlag.toStringAsFixed(2)} CHF'),
                ],
              ),

              // Weitere Preise
              _SectionCard(
                title: 'Weitere Preise',
                icon: Icons.attach_money,
                children: [
                  _InfoRow('Eigenauftrag-Pauschale',
                      '${preis.eigenauftragPauschale.toStringAsFixed(2)} CHF'),
                  _InfoRow('Montage-Stundensatz',
                      '${preis.montageStundensatz.toStringAsFixed(2)} CHF'),
                  _InfoRow('Pikett-Pauschale',
                      '${preis.pikettPauschale.toStringAsFixed(2)} CHF'),
                  _InfoRow('Pikett Feiertag-Zuschlag',
                      '${preis.pikettFeiertagZuschlag.toStringAsFixed(2)} CHF'),
                  _InfoRow('Eröffnung Normal',
                      '${preis.eroeffnungPreisNormal.toStringAsFixed(2)} CHF'),
                  _InfoRow('Eröffnung Bergkunde',
                      '${preis.eroeffnungPreisBergkunde.toStringAsFixed(2)} CHF'),
                  _InfoRow('Bergkunden-Zuschlag',
                      '${preis.bergkundenZuschlag.toStringAsFixed(2)} CHF'),
                ],
              ),

              // MwSt-Sätze
              _SectionCard(
                title: 'MwSt-Sätze',
                icon: Icons.percent,
                trailing: IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'MwSt-Sätze ändern',
                  onPressed: () => _editMwst(
                      preis.id, preis.mwstSatz, preis.mwstSatzReduziert),
                ),
                children: [
                  _InfoRow('Normal', '${preis.mwstSatz.toStringAsFixed(1)}%'),
                  _InfoRow('Reduziert',
                      '${preis.mwstSatzReduziert.toStringAsFixed(1)}%'),
                ],
              ),

              // Neue Preise erfassen Button
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/einstellungen/preise/neu'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Neue Preise erfassen'),
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: trailing,
        initiallyExpanded: false,
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EditableInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _EditableInfoRow(this.label, this.value, {required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onEdit,
            child: const Icon(Icons.edit, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _TwoColRow extends StatelessWidget {
  final String label;
  final String col1;
  final String col2;

  const _TwoColRow(this.label, this.col1, this.col2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(
              child: Text(col1,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          const SizedBox(width: 16),
          Expanded(
              child: Text(col2,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
