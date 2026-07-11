import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/repositories/preis_repository.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/presentation/providers/preis_providers.dart';
import 'package:sbs_projer_app/presentation/providers/google_calendar_providers.dart';
import 'package:sbs_projer_app/presentation/screens/einstellungen/widgets/geschaeft_form.dart';
import 'package:sbs_projer_app/presentation/screens/einstellungen/widgets/mwst_saetze_section.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_auth_service.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';

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

  Widget _buildGoogleKalender(GoogleCalendarStatus status) {
    if (status.connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Verbunden${status.email != null ? ' · ${status.email}' : ''}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Termine, Pikett und Events werden künftig automatisch in deinen Google Kalender geschrieben (folgt in einem nächsten Schritt).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Jetzt abgleichen'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Kalender wird abgeglichen …')),
                );
                try {
                  final r = await GoogleCalendarSyncService.reconcile();
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                        'Abgeglichen: ${r['pushed'] ?? 0} gesendet, ${r['deleted'] ?? 0} entfernt'),
                  ));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
                }
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Trennen'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () async {
                await GoogleCalendarAuthService.trennen();
                ref.invalidate(googleCalendarStatusProvider);
              },
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verbinde deinen Google Kalender, um Erinnerungen und Termin-Sync zu nutzen.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.event_available, size: 18),
            label: const Text('Mit Google Kalender verbinden'),
            onPressed: () => GoogleCalendarAuthService.verbinden(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final aktuellePreise = ref.watch(aktuellePreiseProvider);
    final geschaeftAsync = ref.watch(geschaeftProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Geschäft (preis-unabhängig)
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

          // Google Kalender
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: const Icon(Icons.event, color: AppColors.primary),
              title: const Text('Google Kalender',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Verbindung für Termine & Erinnerungen'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                ref.watch(googleCalendarStatusProvider).when(
                      data: (status) => _buildGoogleKalender(status),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Fehler: $e',
                          style: const TextStyle(color: AppColors.error)),
                    ),
              ],
            ),
          ),

          // Lohn (preis-unabhängig)
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

          // MwSt-Sätze (preis-unabhängig)
          const MwstSaetzeSection(),

          // Preis-abhängige Sektionen
          aktuellePreise.when(
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Fehler: $e'),
            data: (preis) {
              if (preis == null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Keine Preise hinterlegt.'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/einstellungen/preise/neu'),
                      icon: const Icon(Icons.add),
                      label: const Text('Erste Preisversion erstellen'),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Biersorten verwalten
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.local_drink,
                          color: AppColors.primary),
                      title: const Text('Biersorten',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle:
                          const Text('Eigen/Fremd/Orion/Wein Zuordnung'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('/einstellungen/biersorten'),
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
                        onEdit: () =>
                            _editPoNummer(preis.id, preis.heinekenPoNummer),
                      ),
                      const Divider(height: 16),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.assignment_ind,
                            size: 20, color: AppColors.primary),
                        title: const Text('Kontakt-Zuweisungen',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text(
                            'Monatsrechnung, Raster, Heigenie, Material'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => context.push('/heineken/zuweisungen'),
                      ),
                    ],
                  ),

                  // Aktuelle Preise Header
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(Icons.check_circle,
                        color: AppColors.success),
                    title: const Text('Aktuelle Preise',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Gültig ab ${DateFormat('dd.MM.yyyy').format(preis.gueltigAb)}',
                      style:
                          const TextStyle(color: AppColors.textSecondary),
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
                      _TwoColRow(
                          '1',
                          preis.stoerung1Normal.toStringAsFixed(2),
                          preis.stoerung1Bergkunde.toStringAsFixed(2)),
                      _TwoColRow(
                          '2',
                          preis.stoerung2Normal.toStringAsFixed(2),
                          preis.stoerung2Bergkunde.toStringAsFixed(2)),
                      _TwoColRow(
                          '3',
                          preis.stoerung3Normal.toStringAsFixed(2),
                          preis.stoerung3Bergkunde.toStringAsFixed(2)),
                      _TwoColRow(
                          '4',
                          preis.stoerung4Normal.toStringAsFixed(2),
                          preis.stoerung4Bergkunde.toStringAsFixed(2)),
                      _TwoColRow(
                          '5',
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

                  // Neue Preise erfassen Button
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          context.push('/einstellungen/preise/neu'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neue Preise erfassen'),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
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
