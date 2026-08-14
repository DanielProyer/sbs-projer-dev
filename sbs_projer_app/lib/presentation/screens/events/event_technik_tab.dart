import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/event_technik.dart';
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_anlage_local_export.dart';
import 'package:sbs_projer_app/data/models/event_geraet.dart';
import 'package:sbs_projer_app/data/models/event_stand_anlage.dart';
import 'package:sbs_projer_app/data/repositories/event_geraet_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_leitung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';

/// Technik-Tab im Event-Detail: Anstiche (Orion, Mehrfachanstich) mit ihren
/// Leitungen, darunter die Durchlaufkühler. Erfassungswerkzeug fürs Openair
/// Gampel — Spec: docs/superpowers/specs/2026-08-14-event-anstiche-leitungen-design.md
///
/// CanvasKit-Regel: KEIN ExpansionTile — Karten-Köpfe aus InkWell+Row mit
/// eigenem Auf/Zu-Zustand (Vorbild _StandCard, drei bestätigte Render-Vorfälle).
class EventTechnikTab extends ConsumerStatefulWidget {
  final EventLocal event;
  const EventTechnikTab({super.key, required this.event});

  @override
  ConsumerState<EventTechnikTab> createState() => _EventTechnikTabState();
}

class _EventTechnikTabState extends ConsumerState<EventTechnikTab> {
  final _suchController = TextEditingController();
  String _suche = '';

  EventLocal get event => widget.event;
  String get eventId => event.serverId!;

  @override
  void dispose() {
    _suchController.dispose();
    super.dispose();
  }

  void _neuLaden() {
    ref.invalidate(eventGeraeteProvider(eventId));
    ref.invalidate(eventLeitungenProvider(eventId));
  }

  @override
  Widget build(BuildContext context) {
    final geraete =
        ref.watch(eventGeraeteProvider(eventId)).valueOrNull ??
            <EventGeraetLocal>[];
    final leitungen =
        ref.watch(eventLeitungenProvider(eventId)).valueOrNull ??
            <EventLeitungLocal>[];
    final anstiche =
        geraete.where((g) => EventGeraet.istAnstich(g.typ)).toList();
    final kuehler =
        geraete.where((g) => !EventGeraet.istAnstich(g.typ)).toList();

    // Nummernsuche: exakte Treffer über alle Anstiche (Nummern sind nur je
    // Anstich eindeutig — bei Mehrdeutigkeit erscheinen alle Treffer).
    final treffer = _suche.trim().isEmpty
        ? <EventLeitungLocal>[]
        : leitungen.where((l) => leitungNummerPasst(_suche, l.nummer)).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Nummernsuche ──
        TextField(
          controller: _suchController,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
            hintText: 'Leitungsnummer suchen …',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: _suche.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _suchController.clear();
                      setState(() => _suche = '');
                    },
                  ),
          ),
          onChanged: (v) => setState(() => _suche = v),
        ),
        if (_suche.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          if (treffer.isEmpty)
            const Text(
              'Keine Leitung mit dieser Nummer.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            for (final l in treffer)
              _LeitungZeile(
                leitung: l,
                geraete: geraete,
                eventId: eventId,
                mitQuelle: true,
                onChanged: _neuLaden,
              ),
          const Divider(height: 24),
        ],
        const SizedBox(height: 12),

        // ── Anstiche ──
        Row(
          children: [
            const Expanded(
              child: Text(
                'Anstiche',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Anstich'),
              onPressed: () => _geraetBearbeiten(anstich: true),
            ),
          ],
        ),
        if (anstiche.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Noch keine Anstiche erfasst.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        for (final g in anstiche)
          _GeraetCard(
            geraet: g,
            geraete: geraete,
            leitungen: leitungen.where((l) => l.quelleId == g.serverId).toList(),
            eventId: eventId,
            onEdit: () => _geraetBearbeiten(geraet: g, anstich: true),
            onChanged: _neuLaden,
          ),
        const SizedBox(height: 16),

        // ── Durchlaufkühler ──
        Row(
          children: [
            const Expanded(
              child: Text(
                'Durchlaufkühler',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Kühler'),
              onPressed: () => _geraetBearbeiten(anstich: false),
            ),
          ],
        ),
        if (kuehler.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Noch keine Durchlaufkühler erfasst.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        for (final g in kuehler)
          _GeraetCard(
            geraet: g,
            geraete: geraete,
            leitungen:
                leitungen.where((l) => l.kuehlerId == g.serverId).toList(),
            eventId: eventId,
            onEdit: () => _geraetBearbeiten(geraet: g, anstich: false),
            onChanged: _neuLaden,
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  /// Formular-Sheet für Anstich oder Kühler (neu + bearbeiten).
  Future<void> _geraetBearbeiten({
    EventGeraetLocal? geraet,
    required bool anstich,
  }) async {
    final gespeichert = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _GeraetFormSheet(
        eventId: eventId,
        geraet: geraet,
        anstich: anstich,
      ),
    );
    if (gespeichert == true) _neuLaden();
  }
}

// ─── Geräte-Karte (CanvasKit-sicher: InkWell + Rows, kein ExpansionTile) ───

class _GeraetCard extends ConsumerStatefulWidget {
  final EventGeraetLocal geraet;
  final List<EventGeraetLocal> geraete;
  final List<EventLeitungLocal> leitungen;
  final String eventId;
  final VoidCallback onEdit;
  final VoidCallback onChanged;

  const _GeraetCard({
    required this.geraet,
    required this.geraete,
    required this.leitungen,
    required this.eventId,
    required this.onEdit,
    required this.onChanged,
  });

  @override
  ConsumerState<_GeraetCard> createState() => _GeraetCardState();
}

class _GeraetCardState extends ConsumerState<_GeraetCard> {
  bool _offen = false;

  EventGeraetLocal get g => widget.geraet;
  bool get istAnstich => EventGeraet.istAnstich(g.typ);

  @override
  Widget build(BuildContext context) {
    final leitungen = List.of(widget.leitungen)
      ..sort((a, b) => vergleicheLeitungsNummern(a.nummer, b.nummer));
    final angeschlossen = leitungen.where((l) => l.standId != null).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _offen = !_offen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    istAnstich ? Icons.propane_tank : Icons.ac_unit,
                    size: 22,
                    color: g.inBetrieb ? AppColors.success : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.bezeichnung,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            EventGeraet.typLabel(g.typ),
                            if (g.typ == 'mehrfachanstich' &&
                                g.anzahlTanks != null)
                              '${g.anzahlTanks} Tanks',
                            if ((g.standortNotiz ?? '').trim().isNotEmpty)
                              g.standortNotiz!.trim(),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (leitungen.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      istAnstich
                          ? '$angeschlossen/${leitungen.length}'
                          : '${leitungen.length}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: istAnstich && angeschlossen == leitungen.length
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    _offen ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_offen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Inbetriebnahme + Verwaltung
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            g.inBetrieb = !g.inBetrieb;
                            g.inBetriebAm =
                                g.inBetrieb ? DateTime.now() : null;
                            await EventGeraetRepository.save(g);
                            widget.onChanged();
                          },
                          child: Row(
                            children: [
                              Icon(
                                g.inBetrieb
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: g.inBetrieb
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                g.inBetrieb ? 'In Betrieb' : 'Nicht in Betrieb',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (istAnstich)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.playlist_add, size: 18),
                          label: const Text('Leitungen'),
                          onPressed: () => _leitungenErzeugen(context),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _loeschen(context),
                      ),
                    ],
                  ),
                  if ((g.notizen ?? '').trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        g.notizen!.trim(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  // Leitungen des Anstichs (beim Kühler: durchlaufende)
                  if (leitungen.isEmpty && istAnstich)
                    const Text(
                      'Noch keine Leitungen — über «Leitungen» erzeugen.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  for (final l in leitungen)
                    _LeitungZeile(
                      leitung: l,
                      geraete: widget.geraete,
                      eventId: widget.eventId,
                      onChanged: widget.onChanged,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _leitungenErzeugen(BuildContext context) async {
    final vonC = TextEditingController(text: '1');
    final bisC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leitungen erzeugen — ${g.bezeichnung}'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: vonC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Von'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: bisC,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Bis'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erzeugen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final von = int.tryParse(vonC.text.trim());
    final bis = int.tryParse(bisC.text.trim());
    if (von == null || bis == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte Zahlen eingeben (z. B. 1 bis 12)')),
        );
      }
      return;
    }
    try {
      final n = await EventLeitungRepository.erzeugeLeitungen(
        eventId: widget.eventId,
        quelleId: g.serverId!,
        von: von,
        bis: bis,
      );
      widget.onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              n == 0
                  ? 'Alle Nummern existieren schon'
                  : '$n Leitungen angelegt',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _loeschen(BuildContext context) async {
    final anzahl = widget.leitungen.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${istAnstich ? 'Anstich' : 'Kühler'} löschen'),
        content: Text(
          '«${g.bezeichnung}» wirklich löschen?'
          '${istAnstich && anzahl > 0 ? '\n\n$anzahl Leitungen werden mit gelöscht.' : ''}'
          '${!istAnstich && anzahl > 0 ? '\n\n$anzahl Leitungen verlieren ihre Kühler-Zuordnung.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await EventGeraetRepository.delete(g.routeId);
      widget.onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}

// ─── Leitungs-Zeile ───

class _LeitungZeile extends ConsumerWidget {
  final EventLeitungLocal leitung;
  final List<EventGeraetLocal> geraete;
  final String eventId;
  final bool mitQuelle;
  final VoidCallback onChanged;

  const _LeitungZeile({
    required this.leitung,
    required this.geraete,
    required this.eventId,
    this.mitQuelle = false,
    required this.onChanged,
  });

  String? _geraetName(String? id) {
    if (id == null) return null;
    for (final g in geraete) {
      if (g.serverId == id) return g.bezeichnung;
    }
    return '?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staende =
        ref.watch(eventStaendeProvider(eventId)).valueOrNull ?? [];
    String? standName;
    for (final s in staende) {
      if (s.serverId == leitung.standId) {
        standName = s.standnummer != null && s.standnummer!.isNotEmpty
            ? '${s.standnummer} ${s.name}'
            : s.name;
        break;
      }
    }
    final teile = <String>[
      if (mitQuelle) '${_geraetName(leitung.quelleId)}',
      standName ?? 'kein Ziel',
      if (leitung.kuehlerId != null) 'über ${_geraetName(leitung.kuehlerId)}',
      if ((leitung.notiz ?? '').trim().isNotEmpty) leitung.notiz!.trim(),
    ];

    return InkWell(
      onTap: () async {
        final gespeichert = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => _LeitungFormSheet(
            leitung: leitung,
            geraete: geraete,
            eventId: eventId,
          ),
        );
        if (gespeichert == true) onChanged();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                leitung.nummer,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                teile.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: leitung.standId == null
                      ? AppColors.textSecondary
                      : null,
                ),
              ),
            ),
            InkWell(
              onTap: () async {
                leitung.inBetrieb = !leitung.inBetrieb;
                leitung.inBetriebAm =
                    leitung.inBetrieb ? DateTime.now() : null;
                await EventLeitungRepository.save(leitung);
                onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  leitung.inBetrieb
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: leitung.inBetrieb
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Geräte-Formular ───

class _GeraetFormSheet extends StatefulWidget {
  final String eventId;
  final EventGeraetLocal? geraet;
  final bool anstich;

  const _GeraetFormSheet({
    required this.eventId,
    this.geraet,
    required this.anstich,
  });

  @override
  State<_GeraetFormSheet> createState() => _GeraetFormSheetState();
}

class _GeraetFormSheetState extends State<_GeraetFormSheet> {
  late String _typ;
  late final TextEditingController _bezeichnung;
  late final TextEditingController _standort;
  late final TextEditingController _notizen;
  int _anzahlTanks = 1;
  bool _speichert = false;

  @override
  void initState() {
    super.initState();
    final g = widget.geraet;
    _typ = g?.typ ?? (widget.anstich ? 'orion_1000' : 'durchlaufkuehler');
    _bezeichnung = TextEditingController(text: g?.bezeichnung ?? '');
    _standort = TextEditingController(text: g?.standortNotiz ?? '');
    _notizen = TextEditingController(text: g?.notizen ?? '');
    _anzahlTanks = g?.anzahlTanks ?? 1;
  }

  @override
  void dispose() {
    _bezeichnung.dispose();
    _standort.dispose();
    _notizen.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    if (_speichert) return; // Doppeltipp-Riegel vor dem ersten await
    final bezeichnung = _bezeichnung.text.trim();
    if (bezeichnung.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bezeichnung fehlt')),
      );
      return;
    }
    setState(() => _speichert = true);
    try {
      final g = widget.geraet ?? EventGeraetLocal();
      g
        ..eventId = widget.eventId
        ..typ = _typ
        ..bezeichnung = bezeichnung
        ..anzahlTanks = _typ == 'mehrfachanstich' ? _anzahlTanks : null
        ..standortNotiz =
            _standort.text.trim().isEmpty ? null : _standort.text.trim()
        ..notizen = _notizen.text.trim().isEmpty ? null : _notizen.text.trim();
      await EventGeraetRepository.save(g);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _speichert = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typen = widget.anstich
        ? EventGeraet.typen.where(EventGeraet.istAnstich).toList()
        : ['durchlaufkuehler'];
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.geraet == null
                ? (widget.anstich ? 'Neuer Anstich' : 'Neuer Kühler')
                : 'Bearbeiten',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (typen.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _typ,
              decoration: const InputDecoration(labelText: 'Typ'),
              items: [
                for (final t in typen)
                  DropdownMenuItem(
                    value: t,
                    child: Text(EventGeraet.typLabel(t)),
                  ),
              ],
              onChanged: (v) => setState(() => _typ = v ?? _typ),
            ),
          if (_typ == 'mehrfachanstich') ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _anzahlTanks,
              decoration: const InputDecoration(labelText: 'Anzahl Tanks'),
              items: [
                for (var n = 1; n <= 4; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (v) => setState(() => _anzahlTanks = v ?? 1),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _bezeichnung,
            autofocus: widget.geraet == null,
            decoration: const InputDecoration(
              labelText: 'Bezeichnung *',
              hintText: 'z. B. Anstich A, Kühlzelt Nord',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _standort,
            decoration: const InputDecoration(
              labelText: 'Standort',
              hintText: 'z. B. Kühlzelt hinter Hauptbühne',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notizen,
            decoration: const InputDecoration(labelText: 'Notizen'),
          ),
          const SizedBox(height: 16),
          // CanvasKit-sicherer Speichern-Knopf (kein FilledButton — der war
          // am 13.08. im Lageplan-Screen klick-tot).
          InkWell(
            onTap: _speichert ? null : _speichern,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _speichert ? 'Speichert …' : 'Speichern',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leitungs-Formular ───

class _LeitungFormSheet extends ConsumerStatefulWidget {
  final EventLeitungLocal leitung;
  final List<EventGeraetLocal> geraete;
  final String eventId;

  const _LeitungFormSheet({
    required this.leitung,
    required this.geraete,
    required this.eventId,
  });

  @override
  ConsumerState<_LeitungFormSheet> createState() => _LeitungFormSheetState();
}

class _LeitungFormSheetState extends ConsumerState<_LeitungFormSheet> {
  late String? _standId;
  late String? _standAnlageId;
  late String? _kuehlerId;
  late final TextEditingController _notiz;
  bool _speichert = false;

  EventLeitungLocal get l => widget.leitung;

  @override
  void initState() {
    super.initState();
    _standId = l.standId;
    _standAnlageId = l.standAnlageId;
    _kuehlerId = l.kuehlerId;
    _notiz = TextEditingController(text: l.notiz ?? '');
  }

  @override
  void dispose() {
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    if (_speichert) return;
    setState(() => _speichert = true);
    try {
      l
        ..standId = _standId
        ..standAnlageId = _standAnlageId
        ..kuehlerId = _kuehlerId
        ..notiz = _notiz.text.trim().isEmpty ? null : _notiz.text.trim();
      await EventLeitungRepository.save(l);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _speichert = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _loeschen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leitung löschen'),
        content: Text('Leitung ${l.nummer} wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await EventLeitungRepository.delete(l.routeId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staende =
        ref.watch(eventStaendeProvider(widget.eventId)).valueOrNull ?? [];
    final kuehler = widget.geraete
        .where((g) => !EventGeraet.istAnstich(g.typ))
        .toList();
    // Gerätezeilen des gewählten Stands (abhängiges Dropdown).
    final anlagen = _standId == null
        ? <EventStandAnlageLocal>[]
        : (ref.watch(eventStandAnlagenProvider(_standId!)).valueOrNull ??
            <EventStandAnlageLocal>[]);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Leitung ${l.nummer}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: _loeschen,
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _standId,
            decoration: const InputDecoration(labelText: 'Ziel-Stand'),
            items: [
              const DropdownMenuItem(value: null, child: Text('— kein Ziel —')),
              for (final s in staende)
                if (s.serverId != null)
                  DropdownMenuItem(
                    value: s.serverId,
                    child: Text(
                      s.standnummer != null && s.standnummer!.isNotEmpty
                          ? '${s.standnummer} ${s.name}'
                          : s.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            ],
            onChanged: (v) => setState(() {
              _standId = v;
              _standAnlageId = null; // Gerätezeile hängt am Stand
            }),
          ),
          if (anlagen.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _standAnlageId,
              decoration: const InputDecoration(labelText: 'Gerät am Stand'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('— nicht zugeordnet —'),
                ),
                for (final a in anlagen)
                  if (a.serverId != null)
                    DropdownMenuItem(
                      value: a.serverId,
                      child: Text(
                        '${EventStandAnlage.typKurz(a.typ)}'
                        '${a.anzahl > 1 ? ' (${a.anzahl}×)' : ''}',
                      ),
                    ),
              ],
              onChanged: (v) => setState(() => _standAnlageId = v),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _kuehlerId,
            decoration: const InputDecoration(
              labelText: 'Begleitkühlung (Durchlaufkühler)',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('— ohne —')),
              for (final k in kuehler)
                if (k.serverId != null)
                  DropdownMenuItem(
                    value: k.serverId,
                    child: Text(k.bezeichnung),
                  ),
            ],
            onChanged: (v) => setState(() => _kuehlerId = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notiz,
            decoration: const InputDecoration(labelText: 'Notiz'),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _speichert ? null : _speichern,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _speichert ? 'Speichert …' : 'Speichern',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
