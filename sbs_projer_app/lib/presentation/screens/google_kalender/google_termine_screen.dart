import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/util/google_termin_match.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';

class GoogleTermineScreen extends ConsumerStatefulWidget {
  const GoogleTermineScreen({super.key});
  @override
  ConsumerState<GoogleTermineScreen> createState() =>
      _GoogleTermineScreenState();
}

class _EintragVorschau {
  final String eventId;
  final String titel;
  final String? start;
  final bool ganztags;
  final TerminMatch match;
  bool selected;
  String? chosenBetriebId; // gewählter Betrieb (eindeutig fix, mehrdeutig wählbar)
  _EintragVorschau(this.eventId, this.titel, this.start, this.ganztags,
      this.match)
      : selected = match.bucket == MatchBucket.eindeutig,
        chosenBetriebId = switch (match.bucket) {
          MatchBucket.eindeutig => match.treffer!.betriebId,
          MatchBucket.mehrdeutig => match.kandidaten.first.betriebId,
          _ => null,
        };

  bool get taggbar =>
      match.bucket == MatchBucket.eindeutig ||
      match.bucket == MatchBucket.mehrdeutig;
}

class _GoogleTermineScreenState extends ConsumerState<GoogleTermineScreen> {
  DateTime _von =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _bis = DateTime(
      DateTime.now().year + 2, DateTime.now().month, DateTime.now().day);
  bool _laden = false;
  bool _tagge = false;
  String? _fehler;
  List<_EintragVorschau>? _eintraege;
  int _skippedTagged = 0;
  int _privatCount = 0;

  Future<void> _scan() async {
    setState(() {
      _laden = true;
      _fehler = null;
    });
    try {
      final betriebeLocals = ref.read(betriebeProvider);
      final kandidaten = [
        for (final b in betriebeLocals)
          if ((b.serverId ?? '').isNotEmpty && (b.ort ?? '').trim().isNotEmpty)
            BetriebKandidat(betriebId: b.serverId!, name: b.name, ort: b.ort!),
      ];
      final res = await GoogleCalendarSyncService.scanManuelleTermine(
        _von.toUtc().toIso8601String(),
        _bis.toUtc().toIso8601String(),
      );
      final rawEvents = (res['events'] as List?) ?? [];
      final out = <_EintragVorschau>[];
      var privat = 0;
      for (final e in rawEvents) {
        final m = e as Map;
        final titel = (m['summary'] as String?) ?? '';
        final match = matcheTitel(titel, kandidaten);
        if (match.bucket == MatchBucket.privat) {
          privat++;
          continue;
        }
        out.add(_EintragVorschau((m['event_id'] as String?) ?? '', titel,
            m['start'] as String?, m['is_all_day'] == true, match));
      }
      out.sort((a, b) => (a.start ?? '').compareTo(b.start ?? ''));
      setState(() {
        _eintraege = out;
        _skippedTagged = (res['skipped_tagged'] as int?) ?? 0;
        _privatCount = privat;
      });
    } catch (e) {
      setState(() => _fehler = '$e');
    } finally {
      if (mounted) setState(() => _laden = false);
    }
  }

  int get _auswahlAnzahl =>
      _eintraege?.where((x) => x.taggbar && x.selected).length ?? 0;

  Future<void> _taggen() async {
    final zuTaggen = (_eintraege ?? [])
        .where((x) => x.taggbar && x.selected && x.chosenBetriebId != null)
        .toList();
    if (zuTaggen.isEmpty) return;
    setState(() => _tagge = true);
    try {
      final items = [
        for (final x in zuTaggen)
          {'event_id': x.eventId, 'betrieb_id': x.chosenBetriebId!},
      ];
      final res = await GoogleCalendarSyncService.applyTags(items);
      final tagged = (res['tagged'] as int?) ?? 0;
      final fehlerIds = <String>{
        for (final e in (res['errors'] as List? ?? []))
          if (e is Map && e['event_id'] != null) e['event_id'].toString(),
      };
      // Erfolgreich getaggte aus der Liste entfernen.
      final erfolg = zuTaggen
          .where((x) => !fehlerIds.contains(x.eventId))
          .map((x) => x.eventId)
          .toSet();
      setState(() {
        _eintraege = _eintraege!
            .where((x) => !erfolg.contains(x.eventId))
            .toList();
      });
      _snack(fehlerIds.isEmpty
          ? '$tagged Termine getaggt.'
          : '$tagged getaggt, ${fehlerIds.length} Fehler.');
    } catch (e) {
      _snack('Taggen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _tagge = false);
    }
  }

  Future<void> _tagsEntfernen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('K2-Tags entfernen?'),
        content: const Text(
            'Entfernt Farbe, Erinnerung und Betrieb-Tag von ALLEN per K2 '
            'getaggten Google-Terminen. Titel/Notizen bleiben unberührt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Entfernen')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _tagge = true);
    try {
      final res = await GoogleCalendarSyncService.untagManuelle();
      _snack('${res['untagged'] ?? 0} Tags entfernt.');
    } catch (e) {
      _snack('Entfernen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _tagge = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _pickDatum(bool von) async {
    final d = await showDatePicker(
      context: context,
      initialDate: von ? _von : _bis,
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => von ? _von = d : _bis = d);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');
    final e = _eintraege;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google-Termine zuordnen'),
        actions: [
          TextButton(
            onPressed: _tagge ? null : _tagsEntfernen,
            child: const Text('Tags entfernen',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan ordnet bestehende Kalender-Termine den Betrieben zu. '
              'Getaggt werden nur die angehakten (Lavendel + Erinnerung), '
              'Titel/Notizen bleiben unverändert.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _pickDatum(true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Von: ${df.format(_von)}'))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _pickDatum(false),
                      icon: const Icon(Icons.event, size: 16),
                      label: Text('Bis: ${df.format(_bis)}'))),
            ]),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _laden ? null : _scan,
              icon: _laden
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(_laden ? 'Scanne …' : 'Kalender scannen'),
            ),
            if (_fehler != null) ...[
              const SizedBox(height: 12),
              Text(_fehler!, style: const TextStyle(color: Colors.red)),
            ],
            if (e != null) ...[
              const SizedBox(height: 12),
              _Statistik(
                  eintraege: e,
                  skippedTagged: _skippedTagged,
                  privatCount: _privatCount),
              const SizedBox(height: 8),
              Expanded(
                child: _Liste(
                  eintraege: e,
                  df: df,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_tagge || _auswahlAnzahl == 0) ? null : _taggen,
                  icon: _tagge
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.label),
                  label: Text(_tagge
                      ? 'Tagge …'
                      : '$_auswahlAnzahl Termine taggen'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Statistik extends StatelessWidget {
  final List<_EintragVorschau> eintraege;
  final int skippedTagged;
  final int privatCount;
  const _Statistik({
    required this.eintraege,
    required this.skippedTagged,
    required this.privatCount,
  });
  @override
  Widget build(BuildContext context) {
    int eind = 0, mehr = 0, kein = 0, pik = 0;
    for (final x in eintraege) {
      switch (x.match.bucket) {
        case MatchBucket.eindeutig:
          eind++;
          break;
        case MatchBucket.mehrdeutig:
          mehr++;
          break;
        case MatchBucket.pikett:
          pik++;
          break;
        case MatchBucket.keinTreffer:
          kein++;
          break;
        case MatchBucket.privat:
          break;
      }
    }
    return Wrap(spacing: 8, runSpacing: 4, children: [
      Chip(
          label: Text('$eind eindeutig'),
          backgroundColor: Colors.green.shade100),
      Chip(
          label: Text('$mehr mehrdeutig'),
          backgroundColor: Colors.orange.shade100),
      if (pik > 0)
        Chip(label: Text('$pik Pikett'), backgroundColor: Colors.red.shade100),
      Chip(label: Text('$kein ohne Treffer')),
      if (skippedTagged > 0) Chip(label: Text('$skippedTagged bereits SBS')),
      if (privatCount > 0)
        Chip(label: Text('$privatCount privat ausgeblendet')),
    ]);
  }
}

class _Liste extends StatelessWidget {
  final List<_EintragVorschau> eintraege;
  final DateFormat df;
  final VoidCallback onChanged;
  const _Liste(
      {required this.eintraege, required this.df, required this.onChanged});

  String _datum(_EintragVorschau x) => x.start == null
      ? ''
      : df.format(DateTime.tryParse(x.start!)?.toLocal() ?? DateTime(2000));

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: eintraege.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final x = eintraege[i];
        final m = x.match;
        final datum = _datum(x);
        switch (m.bucket) {
          case MatchBucket.eindeutig:
            return CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: x.selected,
              onChanged: (v) {
                x.selected = v ?? false;
                onChanged();
              },
              secondary: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(x.titel.isEmpty ? '(ohne Titel)' : x.titel),
              subtitle: Text('$datum   → ${m.treffer!.name}, ${m.treffer!.ort}'),
            );
          case MatchBucket.mehrdeutig:
            return CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: x.selected,
              onChanged: (v) {
                x.selected = v ?? false;
                onChanged();
              },
              secondary: const Icon(Icons.help_outline, color: Colors.orange),
              title: Text(x.titel.isEmpty ? '(ohne Titel)' : x.titel),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isDense: true,
                      isExpanded: true,
                      value: x.chosenBetriebId,
                      items: [
                        for (final k in m.kandidaten)
                          DropdownMenuItem(
                            value: k.betriebId,
                            child: Text('${k.name}, ${k.ort}',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (val) {
                        x.chosenBetriebId = val;
                        onChanged();
                      },
                    ),
                  ),
                  if (datum.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(datum,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                ]),
              ),
            );
          case MatchBucket.pikett:
            return ListTile(
              dense: true,
              leading: const Icon(Icons.notifications_active, color: Colors.red),
              title: Text(x.titel.isEmpty ? '(ohne Titel)' : x.titel),
              subtitle: Text('$datum   Pikett (kein Betrieb)'),
            );
          case MatchBucket.keinTreffer:
            return ListTile(
              dense: true,
              leading:
                  const Icon(Icons.remove_circle_outline, color: Colors.grey),
              title: Text(x.titel.isEmpty ? '(ohne Titel)' : x.titel),
              subtitle: Text('$datum   ${m.grund}'),
            );
          case MatchBucket.privat:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
