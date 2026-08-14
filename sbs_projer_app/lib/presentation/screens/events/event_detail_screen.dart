import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/util/georeferenz.dart';
import 'package:sbs_projer_app/core/util/stand_position.dart';
import 'package:sbs_projer_app/presentation/screens/events/stand_position_dialog.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/event_aufwand_slots.dart';
import 'package:sbs_projer_app/core/util/event_mail_empfaenger.dart';
import 'package:sbs_projer_app/core/util/event_status.dart';
import 'package:sbs_projer_app/core/util/event_technik.dart';
import 'package:sbs_projer_app/core/util/inbetriebnahme.dart';
import 'package:sbs_projer_app/core/util/whatsapp_link.dart';
import 'package:sbs_projer_app/data/local/event_aufwand_local_export.dart';
import 'package:sbs_projer_app/data/local/event_dokument_local_export.dart';
import 'package:sbs_projer_app/data/local/event_einsatz_local_export.dart';
import 'package:sbs_projer_app/data/local/event_geraet_local_export.dart';
import 'package:sbs_projer_app/data/local/event_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/local/event_leitung_local_export.dart';
import 'package:sbs_projer_app/data/local/event_local_export.dart';
import 'package:sbs_projer_app/data/local/event_stand_local_export.dart';
import 'package:sbs_projer_app/data/local/kontakt_local_export.dart';
import 'package:sbs_projer_app/data/models/event_kontakt.dart';
import 'package:sbs_projer_app/data/models/event_stand.dart';
import 'package:sbs_projer_app/data/models/event_stand_anlage.dart';
import 'package:sbs_projer_app/data/repositories/event_aufwand_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_einsatz_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/event_stand_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/presentation/providers/kontakt_providers.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_abschluss_sheet.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_aufwand_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_einsatz_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_staende_map.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_stand_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_technik_tab.dart';
import 'package:sbs_projer_app/presentation/screens/montagen/montage_form_screen.dart';
import 'package:sbs_projer_app/services/gps/gps_service.dart';
import 'package:sbs_projer_app/services/pdf/event_abschluss_pdf_service.dart';
import 'package:sbs_projer_app/services/storage/event_dokument_storage.dart';

/// Event-Detail: Kopf mit Termin/Status, darunter Tabs Kontakte | Stände |
/// Einsätze | Dokumente. Der FAB wechselt je nach aktivem Tab (E2/E3).
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
    _tabController = TabController(length: 6, vsync: this);
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
      final vorjahr = await EventRepository.getVorjahr(
        event.betriebId,
        event.jahr,
      );
      if (vorjahr == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kein Vorjahres-Event vorhanden')),
          );
        }
        return;
      }
      final n = await EventKontaktRepository.uebernehmeVon(
        vorjahr.serverId!,
        event.serverId!,
      );
      // Stände inkl. Position mitnehmen (Daniel 11.08.2026) — die Methode gab
      // es schon, sie wurde hier nur nie aufgerufen. Positionen gelten im
      // neuen Jahr als geplant, der Inbetriebnahme-Status startet bei null.
      final nStaende = await EventStandRepository.uebernehmeVon(
        vorjahr.serverId!,
        event.serverId!,
      );
      ref.invalidate(eventKontakteProvider(event.serverId!));
      ref.invalidate(eventStaendeProvider(event.serverId!));
      if (mounted) {
        final teile = <String>[
          if (n > 0) n == 1 ? '1 Kontakt' : '$n Kontakte',
          if (nStaende > 0) nStaende == 1 ? '1 Stand' : '$nStaende Stände',
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              teile.isEmpty
                  ? 'Nichts zu übernehmen — alles schon vorhanden'
                  : '${teile.join(' und ')} übernommen',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  /// Sammelt Event-Daten, baut das Abschluss-PDF und öffnet das Versand-Sheet.
  Future<void> _abschlussMailSenden(EventLocal event) async {
    final eventId = event.serverId!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final betriebName =
          ref.read(betriebNameMapProvider)[event.betriebId] ?? 'Event';

      final staende = await ref.read(eventStaendeProvider(eventId).future);
      final einsaetze = await ref.read(eventEinsaetzeProvider(eventId).future);
      final aufwaende = await ref.read(eventAufwaendeProvider(eventId).future);
      final zuordnungen = await ref.read(eventKontakteProvider(eventId).future);
      final kontakteMap = <String, KontaktLocal>{
        for (final k in await ref.read(kontakteProvider.future))
          if (k.serverId != null) k.serverId!: k,
      };

      final standDaten =
          <({String name, String anlagenText, String inbetriebLabel})>[];
      final standNamen = <String, String>{};
      var anlagenTotal = 0;
      var anlagenInBetrieb = 0;
      for (final s in staende) {
        if (s.serverId != null) standNamen[s.serverId!] = s.name;
        final anlagen = await EventStandAnlageRepository.getByStand(
          s.serverId!,
        );
        final f = inbetriebnahmeFortschritt(
          anlagen
              .map((a) => (anzahl: a.anzahl, inBetrieb: a.inBetrieb))
              .toList(),
        );
        anlagenTotal += f.total;
        anlagenInBetrieb += f.inBetrieb;
        standDaten.add((
          name: s.name,
          anlagenText: EventStand.anlagenText(
            anlagen.map((a) => (typ: a.typ, anzahl: a.anzahl)).toList(),
          ),
          inbetriebLabel: f.label,
        ));
      }

      final daten = EventAbschlussDaten(
        eventName: betriebName,
        zeitraum: _abschlussZeitraum(event),
        staende: standDaten,
        anlagenTotal: anlagenTotal,
        anlagenInBetrieb: anlagenInBetrieb,
        aufwaende: [
          for (final a in aufwaende)
            (
              datum: a.datum,
              kategorie: a.kategorie,
              notiz: a.notiz,
              stunden: a.stunden,
            ),
        ],
        einsaetze: [
          for (final e in einsaetze)
            (
              zeitpunkt: e.zeitpunkt.toLocal(),
              beschreibung: e.beschreibung,
              material: _einsatzMaterialText(e),
              standName: e.standId != null ? standNamen[e.standId] : null,
            ),
        ],
      );

      final pdf = await EventAbschlussPdfService.build(daten);

      String? mailVon(String kontaktId) => kontakteMap[kontaktId]?.email;
      String nameVon(String kontaktId) {
        final k = kontakteMap[kontaktId];
        return k == null
            ? 'Unbekannt'
            : '${k.vorname} ${k.nachname ?? ''}'.trim();
      }

      final vorschlaege = abschlussEmpfaenger([
        for (final z in zuordnungen)
          (
            name: nameVon(z.kontaktId),
            rolle: z.rolle,
            email: mailVon(z.kontaktId),
          ),
      ]);
      final vorschlagRollen = {'event_heineken', 'rsl'};
      final weitere = <({String name, String email})>[
        for (final z in zuordnungen)
          if (!vorschlagRollen.contains(z.rolle) &&
              (mailVon(z.kontaktId)?.trim().isNotEmpty ?? false))
            (name: nameVon(z.kontaktId), email: mailVon(z.kontaktId)!.trim()),
      ];

      if (!mounted) return;
      Navigator.pop(context); // Ladehinweis schliessen
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => EventAbschlussSheet(
          eventName: betriebName,
          jahr: event.jahr,
          vorschlaege: vorschlaege,
          weitereKontakte: weitere,
          pdf: pdf,
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Ladehinweis schliessen
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  /// Aggregiert die erfassten Zeiten je Tag und öffnet das Montage-Formular
  /// (Typ Anlass) vorbefüllt. Vom 3-Punkte-Menü aus.
  Future<void> _montageGenerieren(EventLocal event) async {
    final zeilen = await ref.read(
      eventAufwaendeProvider(event.serverId!).future,
    );
    if (zeilen.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Zeiten erfasst — nichts zu generieren.'),
          ),
        );
      }
      return;
    }
    final slots = montageSlotsAusAufwand([
      for (final a in zeilen)
        (
          datum: a.datum,
          stunden: a.stunden,
          kategorie: a.kategorie,
          notiz: a.notiz,
        ),
    ]);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MontageFormScreen(
          vorbefuellung: MontageVorbefuellung(
            montageTyp: 'anlass',
            betriebId: event.betriebId,
            datum: event.terminVon ?? DateTime.now(),
            slots: slots,
          ),
        ),
      ),
    );
  }

  /// Zeitraum-String fürs PDF: „dd.-dd.MM.yyyy" wenn Termin gesetzt, sonst Jahr.
  String _abschlussZeitraum(EventLocal event) {
    final von = event.terminVon;
    final bis = event.terminBis;
    String z(int v) => v.toString().padLeft(2, '0');
    if (von != null && bis != null) {
      return '${z(von.day)}.-${z(bis.day)}.${z(bis.month)}.${bis.year}';
    }
    if (von != null) {
      return '${z(von.day)}.${z(von.month)}.${von.year}';
    }
    return '${event.jahr}';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name gelöscht')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
                    case 'montage':
                      _montageGenerieren(event);
                    case 'abschluss':
                      _abschlussMailSenden(event);
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
                    value: 'montage',
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, size: 20),
                        SizedBox(width: 8),
                        Text('Montage generieren'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'abschluss',
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_read_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Abschluss-Mail senden'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'loeschen',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Event löschen',
                          style: TextStyle(color: AppColors.error),
                        ),
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
                // Nicht scrollbar → alle 5 Tabs füllen die Breite gleichmässig
                // (auf dem Handy zentriert, kein Scrollen). Kompaktere Abstände
                // und Schrift, damit «Dokumente» auf schmalen Displays passt.
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 12.5),
                tabs: const [
                  Tab(text: 'Kontakte'),
                  Tab(text: 'Stände'),
                  Tab(text: 'Technik'),
                  Tab(text: 'Einsätze'),
                  Tab(text: 'Zeit'),
                  Tab(text: 'Dokumente'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _KontakteTab(eventServerId: eventServerId),
                    _StaendeTab(event: event),
                    EventTechnikTab(event: event),
                    _EinsaetzeTab(event: event),
                    _ZeitTab(event: event),
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
  /// 2 Technik (kein FAB — der Tab hat eigene «+ Anstich»/«+ Kühler»-Knöpfe),
  /// 3 Einsatz erfassen, 4 Zeit erfassen, 5 Dokument hochladen.
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
      case 3:
        return FloatingActionButton.extended(
          onPressed: () => _einsatzHinzufuegen(eventServerId),
          icon: const Icon(Icons.bolt),
          label: const Text('Einsatz erfassen'),
        );
      case 4:
        return FloatingActionButton.extended(
          onPressed: () => _zeitErfassen(eventServerId),
          icon: const Icon(Icons.schedule),
          label: const Text('Zeit erfassen'),
        );
      case 5:
        return FloatingActionButton.extended(
          onPressed: () => _dokumentHochladen(eventServerId),
          icon: const Icon(Icons.upload_file),
          label: const Text('Dokument hochladen'),
        );
      default:
        return null;
    }
  }

  /// Öffnet das Einsatz-Formular (neu) und aktualisiert danach die Liste.
  Future<void> _einsatzHinzufuegen(String eventServerId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventEinsatzFormScreen(eventId: eventServerId),
      ),
    );
    ref.invalidate(eventEinsaetzeProvider(eventServerId));
  }

  /// Öffnet das Zeit-Formular (neu) und aktualisiert danach die Liste.
  Future<void> _zeitErfassen(String eventServerId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventAufwandFormScreen(eventId: eventServerId),
      ),
    );
    ref.invalidate(eventAufwaendeProvider(eventServerId));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Datei ist leer')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('«$bezeichnung» hochgeladen')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Hochladen: $e')));
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
  Future<bool> _zuordnungEntfernen(
    BuildContext context,
    WidgetRef ref,
    EventKontaktLocal z,
    String name,
  ) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
    // false: Liste wird über den Provider neu geladen, nicht per Dismiss-Animation
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zuordnungenAsync = ref.watch(eventKontakteProvider(eventServerId));
    final kontakteMap = <String, KontaktLocal>{
      for (final k
          in ref.watch(kontakteProvider).valueOrNull ?? <KontaktLocal>[])
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
                    Icon(
                      Icons.contacts,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
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
        ..sort(
          (a, b) => anzeigeName(
            a,
          ).toLowerCase().compareTo(anzeigeName(b).toLowerCase()),
        );
      if (inGruppe.isEmpty) continue;

      widgets.add(
        Padding(
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
        ),
      );

      for (final z in inGruppe) {
        final k = kontakteMap[z.kontaktId];
        final name = anzeigeName(z);
        widgets.add(
          Dismissible(
            key: ValueKey(z.serverId ?? 'isar-${z.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              color: AppColors.error,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) => _zuordnungEntfernen(context, ref, z, name),
            child: Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
                        onPressed: () => launchUrl(
                          whatsappUri(k!.telefon!),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    if (k?.telefon != null)
                      IconButton(
                        tooltip: 'Anrufen',
                        icon: const Icon(Icons.phone),
                        onPressed: () => launchUrl(
                          Uri.parse('tel:${k!.telefon!.replaceAll(' ', '')}'),
                        ),
                      ),
                  ],
                ),
                onLongPress: () => _zuordnungEntfernen(context, ref, z, name),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

/// Stände-Tab: Liste der Event-Stände (aufklappbar mit Anlagen + Notizen),
/// Bearbeiten/Löschen je Stand, «Aus Vorjahr übernehmen» im Kopf (E2);
/// Umschalter Liste ↔ Karte (swisstopo-Luftbild) mit Markern je Stand (E3).
class _StaendeTab extends ConsumerStatefulWidget {
  final EventLocal event;

  const _StaendeTab({required this.event});

  @override
  ConsumerState<_StaendeTab> createState() => _StaendeTabState();
}

class _StaendeTabState extends ConsumerState<_StaendeTab> {
  /// false = Liste, true = Karte.
  bool _karte = false;

  EventLocal get event => widget.event;

  // Signierte URL des Lageplan-Bilds — gecacht pro Pfad, sonst würde jeder
  // setState (z. B. beim Positionieren) eine neue URL ziehen und das Overlay
  // flackerte durch Neuladen.
  String? _lageplanUrl;
  String? _lageplanUrlPfad;

  @override
  void initState() {
    super.initState();
    _lageplanUrlLaden();
  }

  @override
  void didUpdateWidget(covariant _StaendeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lageplanUrlLaden();
  }

  void _lageplanUrlLaden() {
    final pfad = event.lageplanPfad;
    if (pfad == _lageplanUrlPfad) return;
    _lageplanUrlPfad = pfad;
    _lageplanUrl = null;
    if (pfad == null) return;
    EventDokumentStorage.getSignedUrl(pfad)
        .then((url) {
          if (mounted && _lageplanUrlPfad == pfad) {
            setState(() => _lageplanUrl = url);
          }
        })
        .catchError((_) {});
  }

  /// Overlay-Daten aus den gespeicherten Passpunkten — null, solange kein
  /// Bild, keine URL oder weniger als zwei Punkte vorliegen.
  LageplanOverlay? get _lageplanOverlay {
    final url = _lageplanUrl;
    final json = event.lageplanPunkteJson;
    if (url == null || json == null) return null;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      final b = (m['bildBreite'] as num?)?.toDouble();
      final h = (m['bildHoehe'] as num?)?.toDouble();
      final punkte = passpunkteAusJson(m['punkte'] as List? ?? []);
      if (b == null || h == null || punkte.length < 2) return null;
      final g = Georeferenz.berechne(punkte);
      if (g == null) return null;
      final e = g.ecken(b, h);
      return (
        url: url,
        topLeft: LatLng(e.topLeft.lat, e.topLeft.lng),
        bottomLeft: LatLng(e.bottomLeft.lat, e.bottomLeft.lng),
        bottomRight: LatLng(e.bottomRight.lat, e.bottomRight.lng),
      );
    } catch (_) {
      return null;
    }
  }

  /// Übernimmt die Stände (inkl. Anlagen) aus dem Vorjahres-Event.
  Future<void> _ausVorjahrUebernehmen() async {
    try {
      final vorjahr = await EventRepository.getVorjahr(
        event.betriebId,
        event.jahr,
      );
      if (vorjahr == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kein Vorjahres-Event vorhanden')),
          );
        }
        return;
      }
      final n = await EventStandRepository.uebernehmeVon(
        vorjahr.serverId!,
        event.serverId!,
      );
      ref.invalidate(eventStaendeProvider(event.serverId!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              n == 1 ? '1 Stand übernommen' : '$n Stände übernommen',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _standLoeschen(EventStandLocal stand) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stand löschen'),
        content: Text(
          '«${stand.name}» wirklich löschen?\n\n'
          'Alle zugeordneten Schankanlagen werden mit entfernt.',
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
      await EventStandRepository.delete(stand.routeId);
      ref.invalidate(eventStaendeProvider(event.serverId!));
      // DB nullt stand_id per SET NULL — der Leitungs-Cache (nicht-
      // autoDispose) muss mitgezogen werden, sonst schreibt das Sheet die
      // tote Id zurück (FK 23503).
      ref.invalidate(eventLeitungenProvider(event.serverId!));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${stand.name} gelöscht')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _standBearbeiten(EventStandLocal stand) async {
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
  Widget build(BuildContext context) {
    final staendeAsync = ref.watch(eventStaendeProvider(event.serverId!));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.list, size: 18),
                    label: Text('Liste'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.map, size: 18),
                    label: Text('Karte'),
                  ),
                ],
                selected: {_karte},
                onSelectionChanged: (s) => setState(() => _karte = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
                ),
              ),
              const Spacer(),
              // Im Karten-Modus zählt der Lageplan, in der Liste die
              // Vorjahres-Übernahme — beide zusammen sprengen die Zeile
              // auf dem Handy.
              if (_karte)
                TextButton.icon(
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Lageplan'),
                  onPressed: () async {
                    await context.push('/events/${event.routeId}/lageplan');
                    // Screen invalidiert eventByIdProvider; URL-Cache neu
                    // prüfen, sobald das frische Event durchgereicht ist.
                    if (mounted) _lageplanUrlLaden();
                  },
                )
              else
                TextButton.icon(
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Aus Vorjahr übernehmen'),
                  onPressed: _ausVorjahrUebernehmen,
                ),
            ],
          ),
        ),
        Expanded(
          child: staendeAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fehler: $e')),
            data: (staende) {
              if (_karte) {
                return EventStaendeMap(
                  staende: staende,
                  onStandTap: (s) => _standBearbeiten(s),
                  lageplan: _lageplanOverlay,
                  // Planung am PC: Position per Tap auf die Karte setzen.
                  onPositionSetzen: (stand, punkt) async {
                    stand
                      ..latitude = punkt.latitude
                      ..longitude = punkt.longitude
                      ..positionQuelle = quelleKarte
                      ..positionErfasstAm = DateTime.now()
                      // Auf der Karte gesetzt heisst: Standbereich stimmt,
                      // die genaue Ecke nicht zwingend. Im Formular
                      // änderbar.
                      ..positionGenauigkeit ??= genauMittel;
                    await EventStandRepository.save(stand);
                    ref.invalidate(eventStaendeProvider(stand.eventId));
                  },
                );
              }
              if (staende.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.storefront,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
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
                  onEdit: () => _standBearbeiten(staende[i]),
                  onDelete: () => _standLoeschen(staende[i]),
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
class _StandCard extends ConsumerStatefulWidget {
  final EventStandLocal stand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StandCard({
    required this.stand,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<_StandCard> createState() => _StandCardState();
}

class _StandCardState extends ConsumerState<_StandCard> {
  EventStandLocal get stand => widget.stand;

  bool _offen = false;

  /// Erfasst die aktuelle GPS-Position und speichert sie am Stand.
  ///
  /// Existiert bereits eine Position (am PC geplant oder früher gemessen),
  /// kommt zuerst die Rückfrage mit Kartenanzeige und Abstand — überschrieben
  /// wird nie stillschweigend (Daniel 11.08.2026). Nach der Übernahme gilt der
  /// gemessene Standort als Realität und wandert auch ins Folgejahr.
  Future<void> _standortErfassen(
    BuildContext context,
    WidgetRef ref,
    EventStandLocal stand,
  ) async {
    try {
      final pos = await GpsService.aktuellePosition();
      final abgleich = positionsAbgleich(
        bisherLat: stand.latitude,
        bisherLng: stand.longitude,
        bisherQuelle: stand.positionQuelle,
        neuLat: pos.latitude,
        neuLng: pos.longitude,
      );

      if (abgleich.brauchtRueckfrage) {
        if (!context.mounted) return;
        final uebernehmen = await zeigeStandPositionDialog(
          context,
          standName: stand.name,
          bisherLat: stand.latitude!,
          bisherLng: stand.longitude!,
          neuLat: pos.latitude,
          neuLng: pos.longitude,
          distanzMeter: abgleich.distanzMeter!,
          bisherWarGeplant: abgleich.bisherWarGeplant,
        );
        if (!uebernehmen) return;
      }

      stand
        ..latitude = pos.latitude
        ..longitude = pos.longitude
        ..positionQuelle = quelleGps
        ..positionErfasstAm = DateTime.now()
        // Stufe aus der gemeldeten Messgenauigkeit — bei GPS muss sie
        // niemand von Hand einschätzen.
        ..positionGenauigkeit = genauigkeitAusMessung(pos.accuracy);
      await EventStandRepository.save(stand);
      ref.invalidate(eventStaendeProvider(stand.eventId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📍 Standort gemessen '
              '(±${pos.accuracy.round()} m)',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Standort nicht möglich: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final anlagenAsync = ref.watch(eventStandAnlagenProvider(stand.serverId!));
    final anlagen = anlagenAsync.valueOrNull ?? [];
    final untertitel = EventStand.anlagenText(
      anlagen.map((a) => (typ: a.typ, anzahl: a.anzahl)).toList(),
    );
    final fortschritt = inbetriebnahmeFortschritt(
      anlagen.map((a) => (anzahl: a.anzahl, inBetrieb: a.inBetrieb)).toList(),
    );
    final zuordnungen =
        ref.watch(eventKontakteProvider(stand.eventId)).valueOrNull ??
        <EventKontaktLocal>[];
    final kontakteMap = <String, KontaktLocal>{
      for (final k
          in ref.watch(kontakteProvider).valueOrNull ?? <KontaktLocal>[])
        if (k.serverId != null) k.serverId!: k,
    };
    final standKontakte = [
      for (final z in zuordnungen)
        if (stand.serverId != null &&
            z.standId == stand.serverId &&
            kontakteMap[z.kontaktId] != null)
          kontakteMap[z.kontaktId]!,
    ];
    final kontaktText = standKontakte.isEmpty
        ? null
        : standKontakte
              .map(
                (k) =>
                    ('${k.vorname} ${k.nachname ?? ''}').trim() +
                    ((k.telefon != null && k.telefon!.isNotEmpty)
                        ? ' · ${k.telefon}'
                        : ''),
              )
              .join(', ');

    // Kompakt-Umbau (Daniel 11.08.2026) + Nachbesserung (13.08.2026): Name,
    // Standnummer und GENAUIGKEIT müssen zwingend in der Zeile stehen — die
    // Icon-Farbe allein (v0.81.0) war zu subtil. Und am Fest zählt der
    // direkte Draht zum Standbetreiber: Telefon/WhatsApp als Ein-Tipp-Aktion
    // rechts in der Zeile (Bearbeiten/Löschen bleiben im aufgeklappten
    // Bereich — die braucht man am Fest nicht).
    final telKontakt = standKontakte
        .where((k) => k.telefon != null && k.telefon!.trim().isNotEmpty)
        .firstOrNull;

    // Gegenrichtung der Event-Technik: «7, 9 ← Anstich A» — der Pikett-Anruf
    // nennt den Stand, nicht die Leitung (Spec Anstiche & Leitungen 14.08.).
    final geraete =
        ref.watch(eventGeraeteProvider(stand.eventId)).valueOrNull ??
            <EventGeraetLocal>[];
    final alleLeitungen =
        ref.watch(eventLeitungenProvider(stand.eventId)).valueOrNull ??
            <EventLeitungLocal>[];
    final leitungsHinweise = stand.serverId == null
        ? const <String>[]
        : leitungsHinweiseFuerStand(
            standId: stand.serverId!,
            leitungen: [
              for (final l in alleLeitungen)
                (nummer: l.nummer, quelleId: l.quelleId, standId: l.standId),
            ],
            quelleNamen: {
              for (final g in geraete)
                if (g.serverId != null) g.serverId!: g.bezeichnung,
            },
          );

    // KEIN ExpansionTile/ListTile mehr: Auf Daniels CanvasKit rendert das
    // ExpansionTile (dense + visualDensity compact, seit v0.81) title und
    // subtitle schlicht NICHT — sichtbar blieb nur das gestreckte
    // Nummern-Badge (Screenshot 13.08.2026: «ich sehe immer noch nur die
    // Nummer»). Der aufgeklappte Bereich (reine Rows/Columns) rendert
    // einwandfrei — also besteht jetzt auch der Kopf nur aus Rows/Columns
    // mit eigenem Auf/Zu-Zustand. Gleiche Familie wie die CanvasKit-toten
    // Material-Buttons (20.06./13.08.2026).
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _offen = !_offen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _NrBadge(standnummer: stand.standnummer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stand.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _StandortKennung(stand: stand, groesse: 13),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                // Ohne verknüpften Kontakt zeigt die Notiz
                                // den Ansprechpartner — beim Churerfest
                                // stehen die Namen dort.
                                [
                                  untertitel,
                                  kontaktText ??
                                      ((stand.notizen ?? '').trim().isNotEmpty
                                          ? stand.notizen!.trim()
                                          : null),
                                ].whereType<String>().join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (fortschritt.total > 0) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${fortschritt.inBetrieb}/${fortschritt.total}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: fortschritt.komplett
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Direktwahl (Ein-Tipp), sobald ein Kontakt mit Nummer
                  // am Stand hängt — am Fest wichtiger als jede Verwaltung.
                  if (telKontakt != null) ...[
                    if (whatsappNummer(telKontakt.telefon) != null)
                      _DirektwahlKnopf(
                        tooltip: 'WhatsApp ${telKontakt.vorname}',
                        icon: Icons.chat,
                        farbe: const Color(0xFF25D366),
                        onTap: () => launchUrl(
                          whatsappUri(telKontakt.telefon!),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    _DirektwahlKnopf(
                      tooltip: 'Anrufen: ${telKontakt.telefon}',
                      icon: Icons.phone,
                      farbe: AppColors.primary,
                      onTap: () => launchUrl(
                        Uri.parse(
                          'tel:${telKontakt.telefon!.replaceAll(' ', '')}',
                        ),
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
                  // Standort im Klartext + Erfassen — die Zeile beantwortet die
                  // Feld-Frage «kann ich mich auf die Position verlassen?».
                  Row(
                    children: [
                      _StandortKennung(
                        stand: stand,
                        mitText: false,
                        groesse: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stand.latitude == null
                              ? 'Noch kein Standort erfasst'
                              : '${stand.positionQuelle == quelleGps ? 'Gemessen' : 'Geplant'}'
                                    ' · ${genauigkeitText(stand.positionGenauigkeit)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.my_location, size: 16),
                        label: Text(
                          stand.latitude == null ? 'Erfassen' : 'Neu erfassen',
                        ),
                        onPressed: () => _standortErfassen(context, ref, stand),
                      ),
                    ],
                  ),
                  if (kontaktText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              kontaktText,
                              style: const TextStyle(fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (leitungsHinweise.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.water_drop_outlined,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              leitungsHinweise.join('\n'),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (anlagen.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Keine Anlagen erfasst.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...anlagen.map(
                      (a) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Checkbox(
                              value: a.inBetrieb,
                              visualDensity: VisualDensity.compact,
                              onChanged: (v) async {
                                a
                                  ..inBetrieb = v ?? false
                                  ..inBetriebAm = (v ?? false)
                                      ? DateTime.now().toUtc()
                                      : null;
                                await EventStandAnlageRepository.save(a);
                                ref.invalidate(
                                  eventStandAnlagenProvider(stand.serverId!),
                                );
                              },
                            ),
                            const Icon(
                              Icons.sports_bar,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  // Aktionen zum Stand — bewusst nicht in der Listenzeile:
                  // Löschen gehört nicht als Ein-Tipp-Aktion in jede Zeile.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Bearbeiten'),
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.error,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Löschen'),
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Direktwahl-Knopf (Tel/WhatsApp) — GestureDetector statt IconButton, weil
/// Material-Widgets auf manchen CanvasKit-Screens nicht rendern.
class _DirektwahlKnopf extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color farbe;
  final VoidCallback onTap;

  const _DirektwahlKnopf({
    required this.tooltip,
    required this.icon,
    required this.farbe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: farbe),
        ),
      ),
    );
  }
}

/// Standnummer als feste Spalte am Zeilenanfang — die Nummer ist am Fest der
/// primäre Suchschlüssel («wo ist Stand 69?»), links ausgerichtet entsteht
/// eine scanbare Spalte. Ohne Nummer ein neutrales Platzhalter-Symbol, damit
/// die Namen bündig bleiben.
class _NrBadge extends StatelessWidget {
  final String? standnummer;

  const _NrBadge({required this.standnummer});

  @override
  Widget build(BuildContext context) {
    final nr = standnummer?.trim() ?? '';
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: nr.isEmpty
          ? const Icon(
              Icons.storefront,
              size: 14,
              color: AppColors.textSecondary,
            )
          : Text(
              nr,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
    );
  }
}

/// Einsätze-Tab: Liste der Pikett-Einsätze (neueste zuerst) mit Zeitpunkt,
/// Beschreibung, Material und optionalem Stand-Chip. Tap bearbeitet,
/// Trailing löscht nach Bestätigung (E3).
class _EinsaetzeTab extends ConsumerWidget {
  final EventLocal event;

  const _EinsaetzeTab({required this.event});

  Future<void> _einsatzBearbeiten(
    BuildContext context,
    WidgetRef ref,
    EventEinsatzLocal einsatz,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventEinsatzFormScreen(
          eventId: event.serverId!,
          einsatzId: einsatz.routeId,
        ),
      ),
    );
    ref.invalidate(eventEinsaetzeProvider(event.serverId!));
  }

  Future<void> _einsatzLoeschen(
    BuildContext context,
    WidgetRef ref,
    EventEinsatzLocal einsatz,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Einsatz löschen'),
        content: const Text('Diesen Einsatz wirklich löschen?'),
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
      await EventEinsatzRepository.delete(einsatz.routeId);
      ref.invalidate(eventEinsaetzeProvider(event.serverId!));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Einsatz gelöscht')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final einsaetzeAsync = ref.watch(eventEinsaetzeProvider(event.serverId!));
    // Stand-Namen für den optionalen Chip nachschlagen.
    final standNamen = <String, String>{
      for (final s
          in ref.watch(eventStaendeProvider(event.serverId!)).valueOrNull ??
              <EventStandLocal>[])
        if (s.serverId != null) s.serverId!: s.name,
    };

    return einsaetzeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (einsaetze) {
        if (einsaetze.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              children: [
                Icon(
                  Icons.bolt,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Noch keine Einsätze.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          itemCount: einsaetze.length,
          itemBuilder: (ctx, i) {
            final e = einsaetze[i];
            final standName = e.standId != null ? standNamen[e.standId] : null;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                title: Text(
                  e.beschreibung,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _ddMMHHmm(e.zeitpunkt.toLocal()),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (e.material != null && e.material!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.build,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              e.material!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (standName != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          standName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.error,
                  ),
                  tooltip: 'Löschen',
                  onPressed: () => _einsatzLoeschen(context, ref, e),
                ),
                onTap: () => _einsatzBearbeiten(context, ref, e),
              ),
            );
          },
        );
      },
    );
  }
}

/// Zeit-Tab: erfasste Aufwand-Zeilen (Kategorie/Datum/Stunden) mit Total-Chip,
/// «Montage generieren» (aggregiert je Tag zu Anlass-Slots) sowie Bearbeiten/
/// Löschen je Zeile (E4).
class _ZeitTab extends ConsumerWidget {
  final EventLocal event;
  const _ZeitTab({required this.event});

  Future<void> _bearbeiten(
    BuildContext context,
    WidgetRef ref,
    EventAufwandLocal a,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventAufwandFormScreen(
          eventId: event.serverId!,
          aufwandId: a.routeId,
        ),
      ),
    );
    ref.invalidate(eventAufwaendeProvider(event.serverId!));
  }

  Future<void> _loeschen(
    BuildContext context,
    WidgetRef ref,
    EventAufwandLocal a,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zeit löschen'),
        content: const Text('Diese Zeile wirklich löschen?'),
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
    if (ok != true) return;
    try {
      await EventAufwandRepository.delete(a.routeId);
      ref.invalidate(eventAufwaendeProvider(event.serverId!));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Zeit gelöscht')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(eventAufwaendeProvider(event.serverId!));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (zeilen) {
        final total = zeilen.fold<double>(0, (s, a) => s + a.stunden);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text('Total ${total.toStringAsFixed(2)} h'),
                  backgroundColor: AppColors.surface,
                ),
              ),
            ),
            if (zeilen.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Noch keine Zeiten erfasst.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                  itemCount: zeilen.length,
                  itemBuilder: (ctx, i) {
                    final a = zeilen[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _bearbeiten(context, ref, a),
                        title: Text(
                          kAufwandKategorien[a.kategorie] ?? a.kategorie,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${_ddMMyyyy(a.datum)}'
                          '${(a.notiz != null && a.notiz!.isNotEmpty) ? ' · ${a.notiz}' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${a.stunden.toStringAsFixed(2)} h',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: () => _loeschen(context, ref, a),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
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
    BuildContext context,
    EventDokumentLocal dok,
  ) async {
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
    BuildContext context,
    WidgetRef ref,
    EventDokumentLocal dok,
  ) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${dok.bezeichnung} gelöscht')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
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
                Icon(
                  Icons.picture_as_pdf,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
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
                leading: const Icon(
                  Icons.picture_as_pdf,
                  color: AppColors.error,
                ),
                title: Text(
                  dok.bezeichnung,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: dok.createdAt != null
                    ? Text('Hochgeladen ${_ddMMyyyy(dok.createdAt!.toLocal())}')
                    : null,
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.error,
                  ),
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
    // Kompakt-Umbau (Daniel 11.08.2026, «halbe Höhe»): Der Event-Name stand
    // doppelt — in der AppBar UND hier. Er fällt aus der Karte raus; übrig
    // bleibt eine Zeile Termin · Ort · Status, Notizen ellipsiert darunter.
    // So gewinnt die Liste Platz, ohne dass eine Information verschwindet.
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  _terminText(event),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (ort != null && ort!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.place,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      ort!,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                _StatusBadge(event: event),
              ],
            ),
            if (notizen != null && notizen.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  notizen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
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
        final tage = DateTime(
          start.year,
          start.month,
          start.day,
        ).difference(DateTime(heute.year, heute.month, heute.day)).inDays;
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
  String? _standId;
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
    var result = alle.where((k) => k.serverId != null).toList();
    if (_suchText.isNotEmpty) {
      final q = _suchText.toLowerCase();
      result = result.where((k) {
        final name = '${k.vorname} ${k.nachname ?? ''}'.toLowerCase();
        final tel = (k.telefon ?? '').toLowerCase();
        final kat = _kategorieLabel(k.kategorie).toLowerCase();
        return name.contains(q) || tel.contains(q) || kat.contains(q);
      }).toList();
    }
    result.sort(
      (a, b) => a.vorname.toLowerCase().compareTo(b.vorname.toLowerCase()),
    );
    return result;
  }

  Future<void> _zuordnen() async {
    final kontakt = _ausgewaehlt;
    if (kontakt == null) return;
    setState(() => _speichert = true);
    try {
      // Duplikat (kontaktId, rolle) abfangen statt DB-Constraint-Fehler
      final vorhandene = await EventKontaktRepository.getByEvent(
        widget.eventServerId,
      );
      final duplikat = vorhandene.any(
        (z) => z.kontaktId == kontakt.serverId && z.rolle == _rolle,
      );
      if (duplikat) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Bereits zugeordnet')));
        }
        return;
      }

      final bemerkung = _bemerkungCtrl.text.trim();
      final z = EventKontaktLocal()
        ..eventId = widget.eventServerId
        ..kontaktId = kontakt.serverId!
        ..rolle = _rolle
        ..standId = _rolle == 'stand' ? _standId : null
        ..bemerkung = bemerkung.isEmpty ? null : bemerkung;
      await EventKontaktRepository.save(z);

      ref.invalidate(eventKontakteProvider(widget.eventServerId));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(EventKontakt.rolleLabel(r)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null)
                    setState(() {
                      _rolle = v;
                      if (v != 'stand') _standId = null;
                    });
                },
              ),
              if (_rolle == 'stand') ...[
                const SizedBox(height: 12),
                ref
                    .watch(eventStaendeProvider(widget.eventServerId))
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (staende) => DropdownButtonFormField<String?>(
                        initialValue: _standId,
                        decoration: const InputDecoration(
                          labelText: 'Stand',
                          prefixIcon: Icon(Icons.storefront),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— (kein bestimmter Stand)'),
                          ),
                          for (final s in staende)
                            DropdownMenuItem<String?>(
                              value: s.serverId,
                              child: Text(s.name),
                            ),
                        ],
                        onChanged: (v) => setState(() => _standId = v),
                      ),
                    ),
              ],
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
  final eintaegig =
      start.year == ende.year &&
      start.month == ende.month &&
      start.day == ende.day;
  if (eintaegig) return _ddMMyyyy(start);
  return '${_ddMM(start)}–${_ddMMyyyy(ende)}';
}

String _zwei(int v) => v.toString().padLeft(2, '0');

String _ddMM(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.';

String _ddMMyyyy(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.${d.year}';

/// Material-Text für das PDF: Freitext/Lager-Name + optional Menge.
String? _einsatzMaterialText(EventEinsatzLocal e) {
  final m = e.material;
  if (m == null || m.isEmpty) return null;
  final menge = e.materialMenge;
  if (menge == null || menge <= 0) return m;
  final mengeStr = menge % 1 == 0 ? menge.toStringAsFixed(0) : menge.toString();
  return '$m x$mengeStr';
}

String _ddMMHHmm(DateTime d) =>
    '${_zwei(d.day)}.${_zwei(d.month)}. ${_zwei(d.hour)}:${_zwei(d.minute)}';

/// Standort-Kennung eines Stands (Daniel 11.08./13.08.2026): «Genauigkeit
/// muss zwingend in der Übersicht sein» — Icon plus Klartext, flach (ohne
/// Pill-Hintergrund):
///
///   Form  = Herkunft    (Pinnadel geplant · Fadenkreuz gemessen ·
///                        durchgestrichen keiner)
///   Farbe = Genauigkeit (grün genau · orange mittel · rot ungefähr/keiner)
///   Text  = Genauigkeit ausgeschrieben («genau» / «mittel» / «ungefähr» /
///           «kein Standort»)
///
/// [mitText] aus, wo daneben schon Klartext steht (aufgeklappter Bereich).
class _StandortKennung extends StatelessWidget {
  final EventStandLocal stand;
  final bool mitText;
  final double groesse;

  const _StandortKennung({
    required this.stand,
    this.mitText = true,
    this.groesse = 14,
  });

  @override
  Widget build(BuildContext context) {
    final ohnePosition = stand.latitude == null || stand.longitude == null;
    final gemessen = stand.positionQuelle == quelleGps;

    final farbe = switch (stand.positionGenauigkeit) {
      _ when ohnePosition => AppColors.error,
      genauGenau => AppColors.success,
      genauMittel => Colors.orange,
      genauUngefaehr => AppColors.error,
      _ => AppColors.textSecondary,
    };
    final text = ohnePosition
        ? 'kein Standort'
        : switch (stand.positionGenauigkeit) {
            genauGenau => 'genau',
            genauMittel => 'mittel',
            genauUngefaehr => 'ungefähr',
            _ => '—',
          };

    return Tooltip(
      message: ohnePosition
          ? 'Noch kein Standort erfasst'
          : '${gemessen ? 'Im Feld gemessen' : 'Auf der Karte geplant'} · '
                'Genauigkeit: ${genauigkeitText(stand.positionGenauigkeit)}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ohnePosition
                ? Icons.location_off
                : (gemessen ? Icons.gps_fixed : Icons.push_pin),
            size: groesse,
            color: farbe,
          ),
          if (mitText) ...[
            const SizedBox(width: 3),
            Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: farbe,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
