import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/event_status.dart';
import 'package:sbs_projer_app/core/util/inbetriebnahme.dart';
import 'package:sbs_projer_app/core/util/whatsapp_link.dart';
import 'package:sbs_projer_app/data/local/event_dokument_local_export.dart';
import 'package:sbs_projer_app/data/local/event_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/event_kontakt.dart';
import 'package:sbs_projer_app/data/models/event_stand.dart';
import 'package:sbs_projer_app/data/models/event_stand_anlage.dart';
import 'package:sbs_projer_app/data/repositories/event_dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/presentation/providers/kontakt_providers.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_stand_form_screen.dart';
import 'package:sbs_projer_app/services/storage/event_dokument_storage.dart';

/// Event-Detail: Kopf mit Termin/Status, darunter Tabs Kontakte | Stände |
/// Dokumente. Der FAB wechselt je nach aktivem Tab (E2).
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // FAB je Tab neu aufbauen.
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          floatingActionButton: _buildFab(eventServerId),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _KopfCard(
                  event: event,
                  name: name,
                  ort: betriebOrte[event.betriebId],
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Kontakte'),
                  Tab(text: 'Stände'),
                  Tab(text: 'Dokumente'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _KontakteTab(eventServerId: eventServerId),
                    _StaendeTab(event: event),
                    _DokumenteTab(eventServerId: eventServerId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// FAB je aktivem Tab: 0 Kontakt zuordnen, 1 Stand hinzufügen,
  /// 2 Dokument hochladen.
  Widget? _buildFab(String eventServerId) {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: () => _zeigeZuordnenSheet(eventServerId),
          icon: const Icon(Icons.person_add),
          label: const Text('Kontakt zuordnen'),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: () => _standHinzufuegen(eventServerId),
          icon: const Icon(Icons.add_business),
          label: const Text('Stand hinzufügen'),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: () => _dokumentHochladen(eventServerId),
          icon: const Icon(Icons.upload_file),
          label: const Text('Dokument hochladen'),
        );
      default:
        return null;
    }
  }

  /// Öffnet das Stand-Formular (neu) und aktualisiert danach die Stände-Liste.
  Future<void> _standHinzufuegen(String eventServerId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventStandFormScreen(eventId: eventServerId),
      ),
    );
    ref.invalidate(eventStaendeProvider(eventServerId));
  }

  /// PDF wählen (file_picker), Bezeichnung erfragen, in den Storage-Bucket
  /// laden und den Datensatz anlegen (Muster Eingangsrechnung-Upload).
  Future<void> _dokumentHochladen(String eventServerId) async {
    Uint8List? bytes;
    String? dateiname;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (picked == null || picked.files.single.bytes == null) return;
      bytes = picked.files.single.bytes!;
      dateiname = picked.files.single.name;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Datei konnte nicht ausgewählt werden: $e')),
        );
      }
      return;
    }
    if (bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datei ist leer')),
        );
      }
      return;
    }

    // Vorschlag = Dateiname ohne .pdf-Endung.
    final vorschlag = dateiname.toLowerCase().endsWith('.pdf')
        ? dateiname.substring(0, dateiname.length - 4)
        : dateiname;
    final bezeichnung = await _bezeichnungAbfragen(vorschlag);
    if (bezeichnung == null || bezeichnung.isEmpty) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dokument wird hochgeladen …')),
      );
    }
    try {
      final pfad = await EventDokumentStorage.upload(eventServerId, bytes);
      await EventDokumentRepository.save(
        EventDokumentLocal()
          ..eventId = eventServerId
          ..bezeichnung = bezeichnung
          ..dateiPfad = pfad,
      );
      ref.invalidate(eventDokumenteProvider(eventServerId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«$bezeichnung» hochgeladen')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Hochladen: $e')),
        );
      }
    }
  }

  /// Dialog zur Eingabe der Dokument-Bezeichnung (Vorschlag = Dateiname).
  Future<String?> _bezeichnungAbfragen(String vorschlag) {
    final ctrl = TextEditingController(text: vorschlag);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bezeichnung'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Bezeichnung',
            hintText: 'z. B. Lageplan',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Hochladen'),
          ),
        ],
      ),
    );
  }
}

/// Kontakte-Tab: Kontaktliste gruppiert nach Rollen, WhatsApp/Anruf-
/// Schnellaktionen, Wisch-/Longpress-Entfernen der Zuordnung (E1, unverändert).
class _KontakteTab extends ConsumerWidget {
  final String eventServerId;

  const _KontakteTab({required this.eventServerId});

  /// Entfernt eine Kontakt-Zuordnung nach Bestätigung (nicht den Kontakt).
  Future<bool> _zuordnungEntfernen(BuildContext context, WidgetRef ref,
      EventKontaktLocal z, String name) async {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
    // false: Liste wird über den Provider neu geladen, nicht per Dismiss-Animation
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zuordnungenAsync = ref.watch(eventKontakteProvider(eventServerId));
    final kontakteMap = <String, KontaktLocal>{
      for (final k in ref.watch(kontakteProvider).valueOrNull ??
          <KontaktLocal>[])
        if (k.serverId != null) k.serverId!: k,
    };

    return zuordnungenAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (zuordnungen) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          children: [
            if (zuordnungen.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  children: [
                    Icon(Icons.contacts,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    const Text(
                      'Noch keine Kontakte zugeordnet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ..._buildRollenGruppen(context, ref, zuordnungen, kontakteMap),
          ],
        );
      },
    );
  }

  /// Baut pro Rolle (feste Reihenfolge) Abschnittstitel + Kontakt-Zeilen.
  List<Widget> _buildRollenGruppen(
    BuildContext context,
    WidgetRef ref,
    List<EventKontaktLocal> zuordnungen,
    Map<String, KontaktLocal> kontakteMap,
  ) {
    String anzeigeName(EventKontaktLocal z) {
      final k = kontakteMap[z.kontaktId];
      if (k == null) return 'Unbekannter Kontakt';
      return '${k.vorname} ${k.nachname ?? ''}'.trim();
    }

    final widgets = <Widget>[];
    for (final rolle in EventKontakt.rollenReihenfolge) {
      final inGruppe = zuordnungen.where((z) => z.rolle == rolle).toList()
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
              _zuordnungEntfernen(context, ref, z, name),
          child: Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              title: Text(
                name,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
              onLongPress: () =>
                  _zuordnungEntfernen(context, ref, z, name),
            ),
          ),
        ));
      }
    }
    return widgets;
  }
}

/// Stände-Tab: Liste der Event-Stände (aufklappbar mit Anlagen + Notizen),
/// Bearbeiten/Löschen je Stand, «Aus Vorjahr übernehmen» im Kopf (E2).
class _StaendeTab extends ConsumerWidget {
  final EventLocal event;

  const _StaendeTab({required this.event});

  /// Übernimmt die Stände (inkl. Anlagen) aus dem Vorjahres-Event.
  Future<void> _ausVorjahrUebernehmen(
      BuildContext context, WidgetRef ref) async {
    try {
      final vorjahr =
          await EventRepository.getVorjahr(event.betriebId, event.jahr);
      if (vorjahr == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kein Vorjahres-Event vorhanden')),
          );
        }
        return;
      }
      final n = await EventStandRepository.uebernehmeVon(
          vorjahr.serverId!, event.serverId!);
      ref.invalidate(eventStaendeProvider(event.serverId!));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(n == 1 ? '1 Stand übernommen' : '$n Stände übernommen')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _standLoeschen(
      BuildContext context, WidgetRef ref, EventStandLocal stand) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stand löschen'),
        content: Text('«${stand.name}» wirklich löschen?\n\n'
            'Alle zugeordneten Schankanlagen werden mit entfernt.'),
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
      await EventStandRepository.delete(stand.routeId);
      ref.invalidate(eventStaendeProvider(event.serverId!));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${stand.name} gelöscht')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _standBearbeiten(
      BuildContext context, WidgetRef ref, EventStandLocal stand) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventStandFormScreen(
          eventId: event.serverId!,
          standId: stand.routeId,
        ),
      ),
    );
    ref.invalidate(eventStaendeProvider(event.serverId!));
    ref.invalidate(eventStandAnlagenProvider(stand.serverId!));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staendeAsync = ref.watch(eventStaendeProvider(event.serverId!));

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: TextButton.icon(
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Aus Vorjahr übernehmen'),
              onPressed: () => _ausVorjahrUebernehmen(context, ref),
            ),
          ),
        ),
        Expanded(
          child: staendeAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fehler: $e')),
            data: (staende) {
              if (staende.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Column(
                    children: [
                      Icon(Icons.storefront,
                          size: 64,
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      const Text(
                        'Noch keine Stände.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                itemCount: staende.length,
                itemBuilder: (ctx, i) => _StandCard(
                  stand: staende[i],
                  onEdit: () => _standBearbeiten(context, ref, staende[i]),
                  onDelete: () => _standLoeschen(context, ref, staende[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Aufklappbare Karte für einen Stand: Titel + Standnummer-Chip,
/// Untertitel = Anlagen-Zusammenfassung, aufgeklappt Anlagen + Notizen.
class _StandCard extends ConsumerWidget {
  final EventStandLocal stand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StandCard({
    required this.stand,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anlagenAsync = ref.watch(eventStandAnlagenProvider(stand.serverId!));
    final anlagen = anlagenAsync.valueOrNull ?? [];
    final untertitel = EventStand.anlagenText(
        anlagen.map((a) => (typ: a.typ, anzahl: a.anzahl)).toList());
    final fortschritt = inbetriebnahmeFortschritt(
        anlagen.map((a) => (anzahl: a.anzahl, inBetrieb: a.inBetrieb)).toList());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                stand.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (stand.standnummer != null && stand.standnummer!.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Nr. ${stand.standnummer!}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (fortschritt.total > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (fortschritt.komplett
                          ? AppColors.success
                          : AppColors.textSecondary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  fortschritt.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fortschritt.komplett
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          untertitel,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: 'Bearbeiten',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.error),
              tooltip: 'Löschen',
              onPressed: onDelete,
            ),
          ],
        ),
        children: [
          if (anlagen.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Keine Anlagen erfasst.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            ...anlagen.map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Checkbox(
                        value: a.inBetrieb,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) async {
                          a
                            ..inBetrieb = v ?? false
                            ..inBetriebAm =
                                (v ?? false) ? DateTime.now().toUtc() : null;
                          await EventStandAnlageRepository.save(a);
                          ref.invalidate(
                              eventStandAnlagenProvider(stand.serverId!));
                        },
                      ),
                      const Icon(Icons.sports_bar,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          EventStandAnlage.typLabel(a.typ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '×${a.anzahl}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )),
          if (stand.notizen != null && stand.notizen!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                stand.notizen!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

}

/// Dokumente-Tab: PDF-Liste pro Event-Jahr, Tap öffnet den nativen PDF-Viewer
/// über eine signierte URL, Trailing löscht Datei + Datensatz (E2).
class _DokumenteTab extends ConsumerWidget {
  final String eventServerId;

  const _DokumenteTab({required this.eventServerId});

  /// Öffnet das PDF über eine signierte URL im externen Viewer.
  Future<void> _dokumentOeffnen(
      BuildContext context, EventDokumentLocal dok) async {
    try {
      final url = await EventDokumentStorage.getSignedUrl(dok.dateiPfad);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dokument konnte nicht geöffnet werden: $e')),
        );
      }
    }
  }

  /// Löscht ein Dokument nach Bestätigung — zuerst die Storage-Datei,
  /// dann den Datensatz.
  Future<void> _dokumentLoeschen(
      BuildContext context, WidgetRef ref, EventDokumentLocal dok) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dokument löschen'),
        content: Text('«${dok.bezeichnung}» wirklich löschen?'),
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
      await EventDokumentStorage.delete(dok.dateiPfad);
      await EventDokumentRepository.delete(dok.routeId);
      ref.invalidate(eventDokumenteProvider(eventServerId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${dok.bezeichnung} gelöscht')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dokumenteAsync = ref.watch(eventDokumenteProvider(eventServerId));

    return dokumenteAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (dokumente) {
        if (dokumente.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              children: [
                Icon(Icons.picture_as_pdf,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                const Text(
                  'Noch keine Dokumente.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          itemCount: dokumente.length,
          itemBuilder: (ctx, i) {
            final dok = dokumente[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf,
                    color: AppColors.error),
                title: Text(
                  dok.bezeichnung,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: dok.createdAt != null
                    ? Text('Hochgeladen ${_ddMMyyyy(dok.createdAt!.toLocal())}')
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.error),
                  tooltip: 'Löschen',
                  onPressed: () => _dokumentLoeschen(context, ref, dok),
                ),
                onTap: () => _dokumentOeffnen(context, dok),
              ),
            );
          },
        );
      },
    );
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
