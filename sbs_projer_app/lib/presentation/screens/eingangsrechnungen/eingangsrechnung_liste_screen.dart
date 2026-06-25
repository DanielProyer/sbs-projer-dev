import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Listen-Screen für Eingangsrechnungen (Kreditoren).
///
/// Zeigt die geladenen Rechnungen nach Status gruppiert (TP-2). Der Upload-/
/// Erkennungs-Screen ist über den FloatingActionButton erreichbar (TP-1).
class EingangsrechnungListeScreen extends ConsumerWidget {
  const EingangsrechnungListeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eingangsrechnungenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Eingangsrechnungen')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Fehler beim Laden:\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (rechnungen) => _buildList(context, rechnungen),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/buchhaltung/eingangsrechnungen/upload'),
        icon: const Icon(Icons.upload_file),
        label: const Text('Rechnung hochladen'),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Eingangsrechnung> rechnungen,
  ) {
    // Gruppen-Zuordnung (Provider liefert bereits nach Datum absteigend).
    final zuBestaetigen = <Eingangsrechnung>[];
    final offen = <Eingangsrechnung>[];
    final bezahlt = <Eingangsrechnung>[];
    final infoAblage = <Eingangsrechnung>[];

    for (final e in rechnungen) {
      final status = e.status ?? '';
      if (e.istNurInfo || status == 'abgelegt') {
        infoAblage.add(e);
      } else if (status == 'erkannt') {
        zuBestaetigen.add(e);
      } else if (status == 'bestaetigt' ||
          status == 'gebucht' ||
          status == 'zahlung_vorgemerkt' ||
          status == 'exportiert') {
        offen.add(e);
      } else if (status == 'bezahlt') {
        bezahlt.add(e);
      }
    }

    if (rechnungen.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Noch keine Eingangsrechnungen erfasst.\n'
            'Tippe auf "Rechnung hochladen", um zu starten.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final children = <Widget>[];
    _addGroup(children, 'Zu bestätigen', zuBestaetigen, context);
    _addGroup(children, 'Offen', offen, context);
    _addGroup(children, 'Bezahlt', bezahlt, context);
    _addGroup(children, 'Info / Ablage', infoAblage, context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: children,
    );
  }

  void _addGroup(
    List<Widget> out,
    String titel,
    List<Eingangsrechnung> items,
    BuildContext context,
  ) {
    if (items.isEmpty) return;
    out.add(_GruppenUeberschrift(titel: titel, anzahl: items.length));
    for (final e in items) {
      out.add(_RechnungZeile(eingangsrechnung: e));
    }
  }
}

class _GruppenUeberschrift extends StatelessWidget {
  const _GruppenUeberschrift({required this.titel, required this.anzahl});

  final String titel;
  final int anzahl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        '$titel ($anzahl)',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _RechnungZeile extends StatelessWidget {
  const _RechnungZeile({required this.eingangsrechnung});

  final Eingangsrechnung eingangsrechnung;

  @override
  Widget build(BuildContext context) {
    final e = eingangsrechnung;
    final titel = (e.ausstellerName?.trim().isNotEmpty ?? false)
        ? e.ausstellerName!.trim()
        : 'Unbekannt';
    final betrag = 'CHF ${e.betragBrutto.toStringAsFixed(2)}';
    final datum =
        e.rechnungsdatum != null ? _dateFormat.format(e.rechnungsdatum!) : '–';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(titel),
        subtitle: Text('$betrag · $datum'),
        trailing: _StatusChip(status: e.status, istNurInfo: e.istNurInfo),
        onTap: () =>
            context.push('/buchhaltung/eingangsrechnungen/${e.id}'),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.istNurInfo});

  final String? status;
  final bool istNurInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _label();
    final farbe = _farbe(theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: farbe,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _label() {
    if (istNurInfo && (status == null || status == 'abgelegt')) {
      return 'Info';
    }
    switch (status) {
      case 'erkannt':
        return 'Erkannt';
      case 'bestaetigt':
        return 'Bestätigt';
      case 'gebucht':
        return 'Gebucht';
      case 'zahlung_vorgemerkt':
        return 'Zahlung vorgemerkt';
      case 'exportiert':
        return 'Exportiert';
      case 'bezahlt':
        return 'Bezahlt';
      case 'abgelegt':
        return 'Abgelegt';
      default:
        return status ?? '–';
    }
  }

  Color _farbe(ThemeData theme) {
    switch (status) {
      case 'erkannt':
        return Colors.orange.shade800;
      case 'bezahlt':
        return theme.colorScheme.primary;
      case 'abgelegt':
        return Colors.grey.shade600;
      default:
        return Colors.blue.shade700;
    }
  }
}
