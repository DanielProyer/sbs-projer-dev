import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung.dart';
import 'package:sbs_projer_app/data/models/eingangsrechnung_kategorie.dart';
import 'package:sbs_projer_app/presentation/providers/eingangsrechnung_providers.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Listen-Screen für Eingangsrechnungen (Kreditoren).
///
/// Zeigt die geladenen Rechnungen nach Status gruppiert (TP-2). Ein Umschalter
/// trennt "Rechnungen" von der "Ablage" (Info-Dokumente); ein Kategorie-Filter
/// schränkt zusätzlich auf eine Kategorie ein. Der Upload-/Erkennungs-Screen
/// ist über den FloatingActionButton erreichbar (TP-1).
class EingangsrechnungListeScreen extends ConsumerStatefulWidget {
  const EingangsrechnungListeScreen({super.key});

  @override
  ConsumerState<EingangsrechnungListeScreen> createState() =>
      _EingangsrechnungListeScreenState();
}

class _EingangsrechnungListeScreenState
    extends ConsumerState<EingangsrechnungListeScreen> {
  // 'rechnungen' = echte Rechnungen, 'ablage' = Info-/abgelegte Dokumente.
  String _ansicht = 'rechnungen';
  // null = "Alle"; sonst der code einer Kategorie.
  String? _katFilter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eingangsrechnungenProvider);
    // Lookup code -> bezeichnung für die Kategorie-Labels.
    final kategorien =
        ref.watch(eingangsrechnungKategorienProvider).valueOrNull ?? const [];
    final katLabels = {for (final k in kategorien) k.code: k.bezeichnung};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eingangsrechnungen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'GKB-Zahlungsfile',
            onPressed: () =>
                context.push('/buchhaltung/eingangsrechnungen/zahlungsfile'),
          ),
          IconButton(
            icon: const Icon(Icons.rule),
            tooltip: 'Rechnungsregeln',
            onPressed: () =>
                context.push('/buchhaltung/eingangsrechnungen/regeln'),
          ),
        ],
      ),
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
        data: (rechnungen) => _buildBody(context, rechnungen, kategorien,
            katLabels),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/buchhaltung/eingangsrechnungen/upload'),
        icon: const Icon(Icons.upload_file),
        label: const Text('Rechnung hochladen'),
      ),
    );
  }

  /// Ablage = Info-Dokumente oder abgelegte Dokumente.
  bool _istAblage(Eingangsrechnung e) =>
      e.istNurInfo || (e.status ?? '') == 'abgelegt';

  Widget _buildBody(
    BuildContext context,
    List<Eingangsrechnung> rechnungen,
    List<EingangsrechnungKategorie> kategorien,
    Map<String, String> katLabels,
  ) {
    // 1) Ansicht-Filter: Rechnungen vs. Ablage.
    var gefiltert = rechnungen
        .where((e) => _ansicht == 'ablage' ? _istAblage(e) : !_istAblage(e))
        .toList();
    // 2) Kategorie-Filter (optional).
    if (_katFilter != null) {
      gefiltert = gefiltert.where((e) => e.kategorie == _katFilter).toList();
    }

    return Column(
      children: [
        _filterLeiste(kategorien),
        Expanded(
          child: rechnungen.isEmpty
              ? const _LeerHinweis(
                  text: 'Noch keine Eingangsrechnungen erfasst.\n'
                      'Tippe auf "Rechnung hochladen", um zu starten.',
                )
              : gefiltert.isEmpty
                  ? const _LeerHinweis(
                      text: 'Keine Einträge für diese Auswahl.',
                    )
                  : _buildList(context, gefiltert, katLabels),
        ),
      ],
    );
  }

  Widget _filterLeiste(List<EingangsrechnungKategorie> kategorien) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'rechnungen',
                label: Text('Rechnungen'),
                icon: Icon(Icons.receipt_long),
              ),
              ButtonSegment(
                value: 'ablage',
                label: Text('Ablage'),
                icon: Icon(Icons.inventory_2_outlined),
              ),
            ],
            selected: {_ansicht},
            onSelectionChanged: (s) =>
                setState(() => _ansicht = s.first),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _katFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kategorie',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Alle'),
              ),
              for (final k in kategorien)
                DropdownMenuItem<String?>(
                  value: k.code,
                  child: Text(k.bezeichnung),
                ),
            ],
            onChanged: (v) => setState(() => _katFilter = v),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Eingangsrechnung> rechnungen,
    Map<String, String> katLabels,
  ) {
    // Gruppen-Zuordnung (Provider liefert bereits nach Datum absteigend).
    final zuBestaetigen = <Eingangsrechnung>[];
    final offen = <Eingangsrechnung>[];
    final bezahlt = <Eingangsrechnung>[];
    final ablage = <Eingangsrechnung>[];

    for (final e in rechnungen) {
      final status = e.status ?? '';
      if (_istAblage(e)) {
        ablage.add(e);
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

    final children = <Widget>[];
    _addGroup(children, 'Zu bestätigen', zuBestaetigen, katLabels);
    _addGroup(children, 'Offen', offen, katLabels);
    _addGroup(children, 'Bezahlt', bezahlt, katLabels);
    _addGroup(children, 'Info / Ablage', ablage, katLabels);

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: children,
    );
  }

  void _addGroup(
    List<Widget> out,
    String titel,
    List<Eingangsrechnung> items,
    Map<String, String> katLabels,
  ) {
    if (items.isEmpty) return;
    out.add(_GruppenUeberschrift(titel: titel, anzahl: items.length));
    for (final e in items) {
      out.add(_RechnungZeile(eingangsrechnung: e, katLabels: katLabels));
    }
  }
}

class _LeerHinweis extends StatelessWidget {
  const _LeerHinweis({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
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
  const _RechnungZeile({
    required this.eingangsrechnung,
    required this.katLabels,
  });

  final Eingangsrechnung eingangsrechnung;
  final Map<String, String> katLabels;

  @override
  Widget build(BuildContext context) {
    final e = eingangsrechnung;
    final titel = (e.ausstellerName?.trim().isNotEmpty ?? false)
        ? e.ausstellerName!.trim()
        : 'Unbekannt';
    final betrag = 'CHF ${e.betragBrutto.toStringAsFixed(2)}';
    final datum =
        e.rechnungsdatum != null ? _dateFormat.format(e.rechnungsdatum!) : '–';
    // Bezeichnung aus dem Lookup; Fallback ist der code selbst.
    final katLabel = e.kategorie == null
        ? null
        : (katLabels[e.kategorie] ?? e.kategorie);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(titel),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$betrag · $datum'),
            if (katLabel != null) ...[
              const SizedBox(height: 4),
              _KategorieLabel(text: katLabel),
            ],
          ],
        ),
        trailing: _StatusChip(status: e.status, istNurInfo: e.istNurInfo),
        onTap: () =>
            context.push('/buchhaltung/eingangsrechnungen/${e.id}'),
      ),
    );
  }
}

class _KategorieLabel extends StatelessWidget {
  const _KategorieLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline, size: 13, color: farbe),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: farbe,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
