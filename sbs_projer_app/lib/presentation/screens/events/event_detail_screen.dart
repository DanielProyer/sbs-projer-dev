import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/event_status.dart';
import 'package:sbs_projer_app/core/util/whatsapp_link.dart';
import 'package:sbs_projer_app/data/local/event_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/event_kontakt.dart';
import 'package:sbs_projer_app/data/repositories/event_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/presentation/providers/kontakt_providers.dart';

/// Event-Detail: Kopf mit Termin/Status, Kontaktliste gruppiert nach Rollen,
/// Kontakt-Zuordnung per Sheet, WhatsApp/Anruf-Schnellaktionen (E1).
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  /// Übernimmt Kontakte aus dem Vorjahres-Event (PopupMenu-Aktion).
  Future<void> _ausVorjahrUebernehmen(EventLocal event) async {
    try {
      final vorjahr =
          await EventRepository.getVorjahr(event.betriebId, event.jahr);
      if (vorjahr == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kein Vorjahres-Event vorhanden')),
          );
        }
        return;
      }
      final n = await EventKontaktRepository.uebernehmeVon(
          vorjahr.serverId!, event.serverId!);
      ref.invalidate(eventKontakteProvider(event.serverId!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  n == 1 ? '1 Kontakt übernommen' : '$n Kontakte übernommen')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  /// Löscht das Event nach Bestätigung — zuerst die Zuordnungen, dann das
  /// Event selbst (lokal räumt kein CASCADE auf).
  Future<void> _eventLoeschen(EventLocal event, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Event löschen'),
        content: Text(
          '«$name» wirklich löschen?\n\n'
          'Alle Kontakt-Zuordnungen werden entfernt — '
          'die Kontakte selbst bleiben erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await EventKontaktRepository.deleteByEvent(event.serverId!);
      await EventRepository.delete(event.routeId);
      ref.invalidate(eventsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name gelöscht')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  /// Entfernt eine Kontakt-Zuordnung nach Bestätigung (nicht den Kontakt).
  Future<bool> _zuordnungEntfernen(
      EventKontaktLocal z, String name, String eventServerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zuordnung entfernen'),
        content: Text(
          '«$name» aus der Kontaktliste entfernen?\n\n'
          'Nur die Zuordnung wird entfernt, nicht der Kontakt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      await EventKontaktRepository.delete(z.routeId);
      ref.invalidate(eventKontakteProvider(eventServerId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
    // false: Liste wird über den Provider neu geladen, nicht per Dismiss-Animation
    return false;
  }

  /// Öffnet das Zuordnungs-Sheet (Kontakt wählen → Rolle + Bemerkung).
  void _zeigeZuordnenSheet(String eventServerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _KontaktZuordnenSheet(eventServerId: eventServerId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventByIdProvider(widget.eventId));

    return eventAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Event')),
        body: Center(child: Text('Fehler: $e')),
      ),
      data: (event) {
        if (event == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Event')),
            body: const Center(child: Text('Event nicht gefunden.')),
          );
        }

        final betriebNamen = ref.watch(betriebNameMapProvider);
        final betriebOrte = ref.watch(betriebOrtMapProvider);
        final name =
            '${betriebNamen[event.betriebId] ?? 'Unbekannter Betrieb'} ${event.jahr}';
        final eventServerId = event.serverId!;
        final zuordnungenAsync = ref.watch(eventKontakteProvider(eventServerId));
        final kontakteMap = <String, KontaktLocal>{
          for (final k in ref.watch(kontakteProvider).valueOrNull ??
              <KontaktLocal>[])
            if (k.serverId != null) k.serverId!: k,
        };

        return Scaffold(
          appBar: AppBar(
            title: Text(name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Bearbeiten',
                onPressed: () async {
                  await context.push('/events/${widget.eventId}/bearbeiten');
                  ref.invalidate(eventByIdProvider(widget.eventId));
                  ref.invalidate(eventsProvider);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'vorjahr':
                      _ausVorjahrUebernehmen(event);
                    case 'loeschen':
                      _eventLoeschen(event, name);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'vorjahr',
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 20),
                        SizedBox(width: 8),
                        Text('Aus Vorjahr übernehmen'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'loeschen',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 20, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Event löschen',
                            style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _zeigeZuordnenSheet(eventServerId),
            icon: const Icon(Icons.person_add),
            label: const Text('Kontakt zuordnen'),
          ),
          body: zuordnungenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fehler: $e')),
            data: (zuordnungen) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: [
                  _KopfCard(
                    event: event,
                    name: name,
                    ort: betriebOrte[event.betriebId],
                  ),
                  const SizedBox(height: 12),
                  if (zuordnungen.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                        children: [
                          Icon(Icons.contacts,
                              size: 64,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          const Text(
                            'Noch keine Kontakte zugeordnet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._buildRollenGruppen(
                        zuordnungen, kontakteMap, eventServerId),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Baut pro Rolle (feste Reihenfolge) Abschnittstitel + Kontakt-Zeilen.
  List<Widget> _buildRollenGruppen(
    List<EventKontaktLocal> zuordnungen,
    Map<String, KontaktLocal> kontakteMap,
    String eventServerId,
  ) {
    String anzeigeName(EventKontaktLocal z) {
      final k = kontakteMap[z.kontaktId];
      if (k == null) return 'Unbekannter Kontakt';
      return '${k.vorname} ${k.nachname ?? ''}'.trim();
    }

    final widgets = <Widget>[];
    for (final rolle in EventKontakt.rollenReihenfolge) {
      final inGruppe =
          zuordnungen.where((z) => z.rolle == rolle).toList()
            ..sort((a, b) => anzeigeName(a)
                .toLowerCase()
                .compareTo(anzeigeName(b).toLowerCase()));
      if (inGruppe.isEmpty) continue;

      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        child: Row(
          children: [
            Text(
              EventKontakt.rolleLabel(rolle),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${inGruppe.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ));

      for (final z in inGruppe) {
        final k = kontakteMap[z.kontaktId];
        final name = anzeigeName(z);
        widgets.add(Dismissible(
          key: ValueKey(z.serverId ?? 'isar-${z.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            color: AppColors.error,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) =>
              _zuordnungEntfernen(z, name, eventServerId),
          child: Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              title: Text(
                name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: (z.bemerkung != null && z.bemerkung!.isNotEmpty)
                  ? Text(z.bemerkung!)
                  : (k?.telefon != null ? Text(k!.telefon!) : null),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (whatsappNummer(k?.telefon) != null)
                    IconButton(
                      tooltip: 'WhatsApp',
                      icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                      onPressed: () => launchUrl(whatsappUri(k!.telefon!),
                          mode: LaunchMode.externalApplication),
                    ),
                  if (k?.telefon != null)
                    IconButton(
                      tooltip: 'Anrufen',
                      icon: const Icon(Icons.phone),
                      onPressed: () => launchUrl(
                          Uri.parse('tel:${k!.telefon!.replaceAll(' ', '')}')),
                    ),
                ],
              ),
              onLongPress: () => _zuordnungEntfernen(z, name, eventServerId),
            ),
          ),
        ));
      }
    }
    return widgets;
  }
}

/// Kopf-Card: Name, Status-Badge, Termin, Ort, Notizen.
class _KopfCard extends StatelessWidget {
  final EventLocal event;
  final String name;
  final String? ort;

  const _KopfCard({required this.event, required this.name, this.ort});

  @override
  Widget build(BuildContext context) {
    final notizen = event.notizen;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                _StatusBadge(event: event),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_month,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(_terminText(event), style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (ort != null && ort!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(ort!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ],
            if (notizen != null && notizen.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              Text(
                notizen,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status-Badge wie in der Events-Liste (laufend/kommend/offen/vorbei).
class _StatusBadge extends StatelessWidget {
  final EventLocal event;

  const _StatusBadge({required this.event});

  @override
  Widget build(BuildContext context) {
    final heute = DateTime.now();
    final status = eventStatus(event.terminVon, event.terminBis, heute);

    final String label;
    final Color color;
    switch (status) {
      case EventStatus.laufend:
        label = 'laufend';
        color = AppColors.success;
      case EventStatus.kommend:
        final start = event.terminVon ?? event.terminBis!;
        final tage = DateTime(start.year, start.month, start.day)
            .difference(DateTime(heute.year, heute.month, heute.day))
            .inDays;
        label = 'in $tage Tag${tage == 1 ? '' : 'en'}';
        color = AppColors.info;
      case EventStatus.offen:
        label = 'Termin offen';
        color = AppColors.textSecondary;
      case EventStatus.vorbei:
        label = 'vorbei';
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Sheet «Kontakt zuordnen»: Schritt 1 Kontakt suchen/wählen (oder neu
/// anlegen), Schritt 2 Rolle + Bemerkung, dann Zuordnung speichern.
class _KontaktZuordnenSheet extends ConsumerStatefulWidget {
  final String eventServerId;

  const _KontaktZuordnenSheet({required this.eventServerId});

  @override
  ConsumerState<_KontaktZuordnenSheet> createState() =>
      _KontaktZuordnenSheetState();
}

class _KontaktZuordnenSheetState extends ConsumerState<_KontaktZuordnenSheet> {
  String _suchText = '';
  KontaktLocal? _ausgewaehlt;
  String _rolle = 'stand';
  final _bemerkungCtrl = TextEditingController();
  bool _speichert = false;

  @override
  void dispose() {
    _bemerkungCtrl.dispose();
    super.dispose();
  }

  String _kategorieLabel(String kategorie) => switch (kategorie) {
        'betrieb' => 'Betrieb',
        'heineken' => 'Heineken',
        'event' => 'Event',
        _ => kategorie,
      };

  List<KontaktLocal> _gefiltert(List<KontaktLocal> alle) {
    // Bereits zugeordnete Kontakte bleiben sichtbar — Mehrfachrollen erlaubt.
    var result =
        alle.where((k) => k.serverId != null).toList();
    if (_suchText.isNotEmpty) {
      final q = _suchText.toLowerCase();
      result = result.where((k) {
        final name = '${k.vorname} ${k.nachname ?? ''}'.toLowerCase();
        final tel = (k.telefon ?? '').toLowerCase();
        final kat = _kategorieLabel(k.kategorie).toLowerCase();
        return name.contains(q) || tel.contains(q) || kat.contains(q);
      }).toList();
    }
    result.sort((a, b) => a.vorname.toLowerCase().compareTo(
        b.vorname.toLowerCase()));
    return result;
  }

  Future<void> _zuordnen() async {
    final kontakt = _ausgewaehlt;
    if (kontakt == null) return;
    setState(() => _speichert = true);
    try {
      // Duplikat (kontaktId, rolle) abfangen statt DB-Constraint-Fehler
      final vorhandene =
          await EventKontaktRepository.getByEvent(widget.eventServerId);
      final duplikat = vorhandene.any(
          (z) => z.kontaktId == kontakt.serverId && z.rolle == _rolle);
      if (duplikat) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bereits zugeordnet')),
          );
        }
        return;
      }

      final bemerkung = _bemerkungCtrl.text.trim();
      final z = EventKontaktLocal()
        ..eventId = widget.eventServerId
        ..kontaktId = kontakt.serverId!
        ..rolle = _rolle
        ..bemerkung = bemerkung.isEmpty ? null : bemerkung;
      await EventKontaktRepository.save(z);

      ref.invalidate(eventKontakteProvider(widget.eventServerId));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return _ausgewaehlt == null
              ? _buildKontaktWahl(scrollController)
              : _buildRolleWahl(scrollController);
        },
      ),
    );
  }

  /// Schritt 1: Suchfeld + Liste aller Kontakte + «Neuer Kontakt».
  Widget _buildKontaktWahl(ScrollController scrollController) {
    final kontakteAsync = ref.watch(kontakteProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Text(
                'Kontakt zuordnen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Neuer Kontakt'),
                onPressed: () async {
                  await context.push('/kontakte/neu?kategorie=event');
                  // Sheet-Liste mit dem neu angelegten Kontakt aktualisieren
                  ref.invalidate(kontakteProvider);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Suche nach Name, Telefon, Kategorie...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _suchText = v),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: kontakteAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fehler: $e')),
            data: (alle) {
              final kontakte = _gefiltert(alle);
              if (kontakte.isEmpty) {
                return const Center(
                  child: Text(
                    'Keine Kontakte gefunden.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return ListView.builder(
                controller: scrollController,
                itemCount: kontakte.length,
                itemBuilder: (ctx, i) {
                  final k = kontakte[i];
                  final name = '${k.vorname} ${k.nachname ?? ''}'.trim();
                  return ListTile(
                    dense: true,
                    title: Text(name),
                    subtitle: k.telefon != null && k.telefon!.isNotEmpty
                        ? Text(k.telefon!)
                        : null,
                    trailing: Text(
                      _kategorieLabel(k.kategorie),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    onTap: () => setState(() => _ausgewaehlt = k),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Schritt 2: Rolle wählen, Bemerkung erfassen, zuordnen.
  Widget _buildRolleWahl(ScrollController scrollController) {
    final kontakt = _ausgewaehlt!;
    final name = '${kontakt.vorname} ${kontakt.nachname ?? ''}'.trim();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Zurück zur Kontaktwahl',
                onPressed: () => setState(() => _ausgewaehlt = null),
              ),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _rolle,
                decoration: const InputDecoration(
                  labelText: 'Rolle *',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: EventKontakt.rollenReihenfolge
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(EventKontakt.rolleLabel(r)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _rolle = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bemerkungCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bemerkung',
                  prefixIcon: Icon(Icons.note),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _speichert ? null : _zuordnen,
                child: _speichert
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Zuordnen'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Termin als «dd.MM.–dd.MM.yyyy», eintägig «dd.MM.yyyy», sonst «Termin offen».
String _terminText(EventLocal e) {
  final von = e.terminVon;
  final bis = e.terminBis;
  if (von == null && bis == null) return 'Termin offen';
  final start = von ?? bis!;
  final ende = bis ?? von!;
  final eintaegig = start.year == ende.year &&
      start.month == ende.month &&
      start.day == ende.day;
  if (eintaegig) return _ddMMyyyy(start);
  return '${_ddMM(start)}–${_ddMMyyyy(ende)}';
}

String _zwei(int v) => v.toString().padLeft(2, '0');

String _ddMM(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.';

String _ddMMyyyy(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.${d.year}';
