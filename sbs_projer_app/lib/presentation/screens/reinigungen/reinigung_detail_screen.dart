import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/pdf/reinigung_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/heineken_rapport_service.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/reinigung_providers.dart';

class ReinigungDetailScreen extends ConsumerWidget {
  final String reinigungId;

  const ReinigungDetailScreen({super.key, required this.reinigungId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<ReinigungLocal?>(
      future: ReinigungRepository.getById(reinigungId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final reinigung = snapshot.data;
        if (reinigung == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Reinigung nicht gefunden')),
          );
        }

        return _ReinigungDetailContent(reinigung: reinigung);
      },
    );
  }
}

class _ReinigungDetailContent extends ConsumerWidget {
  final ReinigungLocal reinigung;

  const _ReinigungDetailContent({required this.reinigung});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reinigung ${_formatDate(reinigung.datum)}'),
        actions: [
          if (reinigung.status == 'abgeschlossen')
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'PDF drucken / teilen',
              onPressed: () => _showPdf(context, reinigung),
            ),
          if (reinigung.istBergkunde)
            IconButton(
              icon: const Icon(Icons.terrain),
              tooltip: 'Anfahrtspauschale PDF',
              onPressed: () => _showAnfahrtspauschale(context, reinigung),
            ),
          if (!SupabaseService.isGuest) ...[
            if (reinigung.status == 'offen')
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Bearbeiten',
                onPressed: () =>
                    context.push('/reinigungen/${reinigung.routeId}/bearbeiten'),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Löschen',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status & Info
          _StatusRow(reinigung: reinigung),
          const SizedBox(height: 16),

          // Betrieb & Anlage
          _BetriebAnlageCard(reinigung: reinigung),

          // Zeiterfassung
          _SectionCard(
            title: 'Zeiterfassung',
            icon: Icons.schedule,
            children: [
              _InfoRow('Datum', _formatDate(reinigung.datum)),
              if (reinigung.uhrzeitStart != null)
                _InfoRow('Start', reinigung.uhrzeitStart!),
              if (reinigung.uhrzeitEnde != null)
                _InfoRow('Ende', reinigung.uhrzeitEnde!),
            ],
          ),

          // Checkliste
          _ChecklisteCard(reinigung: reinigung),

          // Preis
          if (reinigung.preisNetto != null || reinigung.preisBrutto != null)
            _SectionCard(
              title: 'Preis',
              icon: Icons.payments,
              children: [
                if (reinigung.serviceTyp != null)
                  _InfoRow('Service-Typ', reinigung.serviceTyp!),
                _InfoRow('Hähne Eigen', '${reinigung.anzahlHaehneEigen}'),
                if (reinigung.anzahlHaehneOrion > 0)
                  _InfoRow('Hähne Orion', '${reinigung.anzahlHaehneOrion}'),
                if (reinigung.anzahlHaehneFremd > 0)
                  _InfoRow('Hähne Fremd', '${reinigung.anzahlHaehneFremd}'),
                if (reinigung.anzahlHaehneWein > 0)
                  _InfoRow('Hähne Wein', '${reinigung.anzahlHaehneWein}'),
                if (reinigung.anzahlHaehneAndererStandort > 0)
                  _InfoRow('Anderer Standort',
                      '${reinigung.anzahlHaehneAndererStandort}'),
                if (reinigung.istBergkunde)
                  _InfoRow('Bergkunde', 'Ja (+100 CHF)'),
                const Divider(),
                if (reinigung.preisGrundtarif != null)
                  _InfoRow('Grundtarif',
                      '${reinigung.preisGrundtarif!.toStringAsFixed(2)} CHF'),
                if (reinigung.preisZusatzHaehne != null &&
                    reinigung.preisZusatzHaehne! > 0)
                  _InfoRow('Zusatz Hähne',
                      '${reinigung.preisZusatzHaehne!.toStringAsFixed(2)} CHF'),
                if (reinigung.bergkundenZuschlag != null &&
                    reinigung.bergkundenZuschlag! > 0)
                  _InfoRow('Bergkunden-Zuschlag',
                      '${reinigung.bergkundenZuschlag!.toStringAsFixed(2)} CHF'),
                if (reinigung.preisNetto != null) ...[
                  _InfoRow('Netto',
                      '${reinigung.preisNetto!.toStringAsFixed(2)} CHF'),
                  if (reinigung.preisBrutto != null) ...[
                    Builder(builder: (_) {
                      final brutto = _roundTo5Rappen(reinigung.preisBrutto!);
                      final mwst = brutto - reinigung.preisNetto!;
                      return _InfoRow(
                        'MwSt (${reinigung.mwstSatz?.toStringAsFixed(1) ?? '8.1'}%)',
                        '${mwst.toStringAsFixed(2)} CHF',
                      );
                    }),
                  ],
                ],
                if (reinigung.preisBrutto != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 130,
                          child: Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${_roundTo5Rappen(reinigung.preisBrutto!).toStringAsFixed(2)} CHF',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

          // Unterschriften
          if (reinigung.unterschriftTechniker != null ||
              reinigung.unterschriftKunde != null)
            _SectionCard(
              title: 'Unterschriften',
              icon: Icons.draw,
              children: [
                if (reinigung.unterschriftTechniker != null) ...[
                  const Text('Techniker',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(
                        base64Decode(reinigung.unterschriftTechniker!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (reinigung.unterschriftKunde != null) ...[
                  Text(
                    reinigung.unterschriftKundeName != null
                        ? 'Kunde: ${reinigung.unterschriftKundeName}'
                        : 'Kunde',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(
                        base64Decode(reinigung.unterschriftKunde!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ],
            ),

          // Notizen
          if (reinigung.notizen != null)
            _SectionCard(
              title: 'Notizen',
              icon: Icons.note,
              children: [_InfoRow('', reinigung.notizen!)],
            ),

          // Sync-Info
          if (!reinigung.isSynced)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(50)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      color: AppColors.warning, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Noch nicht synchronisiert',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  static double _roundTo5Rappen(double value) {
    return (value * 20).roundToDouble() / 20;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _showPdf(
      BuildContext context, ReinigungLocal reinigung) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfBytes = await ReinigungPdfService.generate(reinigung);
      if (context.mounted) {
        Navigator.of(context).pop(); // Dialog schliessen
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name:
              'Reinigungsprotokoll_${_formatDate(reinigung.datum).replaceAll('.', '_')}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF-Fehler: $e')),
        );
      }
    }
  }

  Future<void> _showAnfahrtspauschale(
      BuildContext context, ReinigungLocal reinigung) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String kunde = '';
      String ort = '';
      final betrieb =
          await BetriebRepository.getByServerId(reinigung.betriebId);
      if (betrieb != null) {
        kunde = betrieb.name;
        ort = '${betrieb.plz ?? ''} ${betrieb.ort ?? ''}'.trim();
      }

      final pdfBytes = await HeinekenRapportService.generateAnfahrtspauschale(
        referenzNr: _formatDate(reinigung.datum).replaceAll('.', '_'),
        datum: reinigung.datum,
        kunde: kunde,
        ort: ort,
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name:
              'Rapport_Anfahrtspauschale_${_formatDate(reinigung.datum).replaceAll('.', '_')}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF-Fehler: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reinigung löschen'),
        content: Text(
          'Reinigung vom ${_formatDate(reinigung.datum)} wirklich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => ctx.pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ReinigungRepository.delete(reinigung.routeId);
        ref.invalidate(reinigungenStreamProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Löschen nur mit Internetverbindung möglich')),
          );
        }
      }
    }
  }
}

class _BetriebAnlageCard extends StatelessWidget {
  final ReinigungLocal reinigung;

  const _BetriebAnlageCard({required this.reinigung});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String?>>(
      future: Future.wait([
        _getBetriebName(),
        _getAnlageBezeichnung(),
      ]),
      builder: (context, snapshot) {
        final names = snapshot.data ?? [null, null];
        final betriebName = names[0];
        final anlageBezeichnung = names[1];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              if (betriebName != null)
                ListTile(
                  leading:
                      const Icon(Icons.store, color: AppColors.primary),
                  title: Text(betriebName),
                  subtitle: const Text('Betrieb'),
                  dense: true,
                  trailing:
                      const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    final b = await BetriebRepository.getByServerId(
                        reinigung.betriebId);
                    if (b != null && context.mounted) {
                      context.push('/betriebe/${b.routeId}');
                    }
                  },
                ),
              if (anlageBezeichnung != null)
                ListTile(
                  leading: const Icon(Icons.precision_manufacturing,
                      color: AppColors.info),
                  title: Text(anlageBezeichnung),
                  subtitle: const Text('Anlage'),
                  dense: true,
                  trailing:
                      const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    final a = await AnlageRepository.getByServerId(
                        reinigung.anlageId);
                    if (a != null && context.mounted) {
                      context.push('/anlagen/${a.routeId}');
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _getBetriebName() async {
    final b = await BetriebRepository.getByServerId(reinigung.betriebId);
    return b?.name;
  }

  Future<String?> _getAnlageBezeichnung() async {
    final a = await AnlageRepository.getByServerId(reinigung.anlageId);
    return a?.bezeichnung ?? a?.typAnlage;
  }
}

class _ChecklisteCard extends StatelessWidget {
  final ReinigungLocal reinigung;

  const _ChecklisteCard({required this.reinigung});

  @override
  Widget build(BuildContext context) {
    final notizen = reinigung.checklisteNotizenJson != null
        ? Map<String, String>.from(jsonDecode(reinigung.checklisteNotizenJson!))
        : <String, String>{};

    final items = [
      ('Begleitkühlung kontrolliert',
          reinigung.begleitkuehlungKontrolliert,
          'begleitkuehlung_kontrolliert'),
      ('Installation allgemein kontrolliert',
          reinigung.installationAllgemeinKontrolliert,
          'installation_allgemein_kontrolliert'),
      ('Aligal-Anschlüsse kontrolliert',
          reinigung.aligalAnschluesseKontrolliert,
          'aligal_anschluesse_kontrolliert'),
      ('Durchlaufkühler ausgeblasen',
          reinigung.durchlaufkuehlerAusgeblasen,
          'durchlaufkuehler_ausgeblasen'),
      ('Wasserstand kontrolliert', reinigung.wasserstandKontrolliert,
          'wasserstand_kontrolliert'),
      ('Wasser gewechselt', reinigung.wasserGewechselt,
          'wasser_gewechselt'),
      ('Leitung mit Wasser vorgespült',
          reinigung.leitungWasserVorgespuelt,
          'leitung_wasser_vorgespuelt'),
      ('Leitungsreinigung mit Reinigungsmittel',
          reinigung.leitungsreinigungReinigungsmittel,
          'leitungsreinigung_reinigungsmittel'),
      ('Förderdruck kontrolliert', reinigung.foerderdruckKontrolliert,
          'foerderdruck_kontrolliert'),
      ('Zapfhahn zerlegt & gereinigt',
          reinigung.zapfhahnZerlegtGereinigt,
          'zapfhahn_zerlegt_gereinigt'),
      ('Zapfkopf zerlegt & gereinigt',
          reinigung.zapfkopfZerlegtGereinigt,
          'zapfkopf_zerlegt_gereinigt'),
      ('Servicekarte ausgefüllt', reinigung.servicekarteAusgefuellt,
          'servicekarte_ausgefuellt'),
    ];

    final anlagenItems = [
      ('Durchlaufkühler', reinigung.hatDurchlaufkuehler,
          'hat_durchlaufkuehler'),
      ('Buffetanstich', reinigung.hatBuffetanstich,
          'hat_buffetanstich'),
      ('Kühlkeller', reinigung.hatKuehlkeller,
          'hat_kuehlkeller'),
      ('Fasskühler', reinigung.hatFasskuehler,
          'hat_fasskuehler'),
    ];

    final checkedCount =
        items.where((i) => i.$2).length +
        anlagenItems.where((i) => i.$2).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Checkliste ($checkedCount/${items.length + anlagenItems.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                _ProgressIndicator(
                    value: checkedCount /
                        (items.length + anlagenItems.length)),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => _CheckItem(
                  label: item.$1,
                  checked: item.$2,
                  note: notizen[item.$3],
                )),
            if (anlagenItems.any((i) => i.$2)) ...[
              const Divider(),
              const Text(
                'Anlagen-Checks',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              ...anlagenItems
                  .where((i) => i.$2)
                  .map((item) => _CheckItem(
                        label: item.$1,
                        checked: item.$2,
                        note: notizen[item.$3],
                      )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final double value;

  const _ProgressIndicator({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 1.0
        ? AppColors.success
        : value >= 0.5
            ? AppColors.warning
            : AppColors.inaktiv;

    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: 3,
        backgroundColor: color.withAlpha(25),
        color: color,
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final bool checked;
  final String? note;

  const _CheckItem({required this.label, required this.checked, this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                checked ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: checked ? AppColors.success : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: checked ? null : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (note != null && note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2, bottom: 4),
              child: Text(
                note!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final ReinigungLocal reinigung;

  const _StatusRow({required this.reinigung});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(
          label: reinigung.status,
          color: _statusColor(reinigung.status),
          icon: _statusIcon(reinigung.status),
        ),
        if (reinigung.istBergkunde)
          const _StatusChip(
            label: 'Bergkunde',
            color: AppColors.info,
            icon: Icons.terrain,
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'offen':
        return AppColors.warning;
      case 'abgeschlossen':
        return AppColors.success;
      case 'abgebrochen':
        return AppColors.inaktiv;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'offen':
        return Icons.hourglass_top;
      case 'abgeschlossen':
        return Icons.check_circle;
      case 'abgebrochen':
        return Icons.cancel;
      default:
        return Icons.circle;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusChip(
      {required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
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
    if (children.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
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
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
