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
  final String titel;
  final String? start;
  final bool ganztags;
  final TerminMatch match;
  _EintragVorschau(this.titel, this.start, this.ganztags, this.match);
}

class _GoogleTermineScreenState extends ConsumerState<GoogleTermineScreen> {
  DateTime _von =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _bis = DateTime(
      DateTime.now().year + 2, DateTime.now().month, DateTime.now().day);
  bool _laden = false;
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
        // Private/ausgeschlossene Termine (Geburtstag/Ferien) nicht anzeigen.
        if (match.bucket == MatchBucket.privat) {
          privat++;
          continue;
        }
        out.add(_EintragVorschau(
            titel, m['start'] as String?, m['is_all_day'] == true, match));
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
      appBar: AppBar(title: const Text('Google-Termine zuordnen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan zeigt, welche bestehenden Kalender-Termine sich einem Betrieb '
              'zuordnen lassen. Es wird noch NICHTS geändert (Taggen folgt).',
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
              Expanded(child: _Liste(eintraege: e, df: df)),
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
          break; // ausgeblendet
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
        Chip(
            label: Text('$pik Pikett'),
            backgroundColor: Colors.red.shade100),
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
  const _Liste({required this.eintraege, required this.df});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: eintraege.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final x = eintraege[i];
        final m = x.match;
        final (IconData icon, Color farbe, String sub) = switch (m.bucket) {
          MatchBucket.eindeutig => (
              Icons.check_circle,
              Colors.green,
              '→ ${m.treffer!.name}, ${m.treffer!.ort}'
            ),
          MatchBucket.mehrdeutig => (
              Icons.help_outline,
              Colors.orange,
              'mehrdeutig: ${m.kandidaten.map((k) => '${k.name} (${k.ort})').join(' / ')}'
            ),
          MatchBucket.pikett => (
              Icons.notifications_active,
              Colors.red,
              'Pikett (kein Betrieb)'
            ),
          MatchBucket.privat => (
              Icons.lock_outline,
              Colors.grey,
              'privat'
            ),
          MatchBucket.keinTreffer => (
              Icons.remove_circle_outline,
              Colors.grey,
              m.grund
            ),
        };
        final datum = x.start == null
            ? ''
            : df.format(DateTime.tryParse(x.start!)?.toLocal() ?? DateTime(2000));
        return ListTile(
          dense: true,
          leading: Icon(icon, color: farbe),
          title: Text(x.titel.isEmpty ? '(ohne Titel)' : x.titel),
          subtitle: Text('$datum   $sub'),
        );
      },
    );
  }
}
