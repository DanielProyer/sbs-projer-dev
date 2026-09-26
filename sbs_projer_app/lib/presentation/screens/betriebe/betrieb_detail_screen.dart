import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/data/mappers/betrieb_rechnungsadresse_mapper.dart';
import 'package:sbs_projer_app/presentation/widgets/google_fehler_meldung.dart';
import 'package:sbs_projer_app/services/google/google_contacts_service.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/widgets/betrieb_ferien_liste.dart';
import 'package:sbs_projer_app/core/util/google_maps_route.dart';
import 'package:sbs_projer_app/core/util/rechnungsadresse_zeilen.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/data/local/anlage_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_kontakt_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_local_export.dart';
import 'package:sbs_projer_app/data/local/betrieb_rechnungsadresse_local_export.dart';
import 'package:sbs_projer_app/data/local/stoerung_local_export.dart';
import 'package:sbs_projer_app/data/local/eigenauftrag_local_export.dart';
import 'package:sbs_projer_app/data/local/reinigung_local_export.dart';
import 'package:sbs_projer_app/data/repositories/anlage_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_kontakt_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_rechnungsadresse_repository.dart';
import 'package:sbs_projer_app/data/repositories/betrieb_repository.dart';
import 'package:sbs_projer_app/data/repositories/region_repository.dart';
import 'package:sbs_projer_app/data/repositories/stoerung_repository.dart';
import 'package:sbs_projer_app/data/repositories/eigenauftrag_repository.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/data/repositories/reinigung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/geschaeft_providers.dart';
import 'package:sbs_projer_app/services/pdf/kontoauszug_pdf_service.dart';
import 'package:sbs_projer_app/services/pdf/protokolle_pdf_service.dart';
import 'package:sbs_projer_app/presentation/widgets/detail/detail_karte.dart';
import 'package:printing/printing.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/data/models/termin.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';
import 'package:sbs_projer_app/presentation/providers/termin_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/service_termin_dialog.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';

class BetriebDetailScreen extends ConsumerWidget {
  final String betriebId;

  const BetriebDetailScreen({super.key, required this.betriebId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<BetriebLocal?>(
      future: BetriebRepository.getById(betriebId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final betrieb = snapshot.data;
        if (betrieb == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nicht gefunden')),
            body: const Center(child: Text('Betrieb nicht gefunden')),
          );
        }

        return _BetriebDetailContent(betrieb: betrieb);
      },
    );
  }
}

class _BetriebDetailContent extends ConsumerWidget {
  final BetriebLocal betrieb;

  const _BetriebDetailContent({required this.betrieb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(betrieb.name),
        actions: [
          if (_routeUrl(betrieb) != null)
            IconButton(
              icon: const Icon(Icons.directions),
              tooltip: 'Route in Google Maps',
              onPressed: () => launchUrl(
                Uri.parse(_routeUrl(betrieb)!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (!SupabaseService.isGuest) ...[
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Kontoauszug (PDF) — alle Rechnungen & Zahlungen',
              onPressed: () => _zeigeKontoauszug(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Reinigungsprotokolle (PDF) — je Jahr',
              onPressed: () => _zeigeProtokolle(context),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Bearbeiten',
              onPressed: () =>
                  context.push('/betriebe/${betrieb.routeId}/bearbeiten'),
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
          // Status & Badges
          _StatusRow(betrieb: betrieb),
          const SizedBox(height: 16),

          // Adresse
          DetailKarte(
            titel: 'Adresse',
            icon: Icons.location_on,
            kinder: [
              if (betrieb.strasse != null)
                InfoZeile('Strasse', '${betrieb.strasse} ${betrieb.nr ?? ''}', labelBreite: 120),
              if (betrieb.plz != null || betrieb.ort != null)
                InfoZeile(
                  'Ort',
                  '${betrieb.plz ?? ''} ${betrieb.ort ?? ''}'.trim()
                , labelBreite: 120),
            ],
          ),

          // Kontakt
          DetailKarte(
            titel: 'Kontakt',
            icon: Icons.contact_phone,
            kinder: [
              if (betrieb.telefon != null)
                _LinkRow(
                  'Telefon',
                  betrieb.telefon!,
                  Uri.parse('tel:${betrieb.telefon!.replaceAll(' ', '')}'),
                ),
              if (betrieb.email != null)
                _LinkRow(
                  'E-Mail',
                  betrieb.email!,
                  Uri.parse('mailto:${betrieb.email!}'),
                ),
              if (betrieb.website != null)
                _LinkRow(
                  'Website',
                  betrieb.website!,
                  Uri.parse(
                    betrieb.website!.startsWith('http')
                        ? betrieb.website!
                        : 'https://${betrieb.website!}',
                  ),
                ),
            ],
          ),

          // Details
          DetailKarte(
            titel: 'Details',
            icon: Icons.info_outline,
            kinder: [
              InfoZeile('Status', betrieb.status, labelBreite: 120),
              if (betrieb.status == 'geschlossen') ...[
                InfoZeile(
                  'Schliessungsgrund',
                  _schliessungsgrundLabel(betrieb.schliessungsgrund)
                , labelBreite: 120),
                if (betrieb.schliessungsdatum != null)
                  InfoZeile(
                    'Schliessungsdatum',
                    _formatDate(betrieb.schliessungsdatum!)
                  , labelBreite: 120),
              ],
              InfoZeile(
                'Zapfsysteme',
                betrieb.zapfsysteme.isEmpty
                    ? '–'
                    : betrieb.zapfsysteme.join(', ')
              , labelBreite: 120),
              InfoZeile('Mein Kunde', betrieb.istMeinKunde ? 'Ja' : 'Nein', labelBreite: 120),
              InfoZeile('Bergkunde', betrieb.istBergkunde ? 'Ja' : 'Nein', labelBreite: 120),
              InfoZeile(
                'Saisonbetrieb',
                betrieb.istSaisonbetrieb ? 'Ja' : 'Nein'
              , labelBreite: 120),
              if (betrieb.istMeinKunde)
                InfoZeile(
                  'Rechnungsstellung',
                  _rechnungsstellungLabel(betrieb.rechnungsstellung)
                , labelBreite: 120),
              if (betrieb.regionId != null)
                FutureBuilder(
                  future: RegionRepository.getByServerId(betrieb.regionId!),
                  builder: (context, snap) =>
                      InfoZeile('Region', snap.data?.name ?? '–', labelBreite: 120),
                ),
            ],
          ),

          // Nummern (nur wenn mindestens eine gesetzt)
          if (betrieb.betriebNr != null ||
              betrieb.weNummer != null ||
              betrieb.agNummer != null)
            DetailKarte(
              titel: 'Nummern',
              icon: Icons.tag,
              kinder: [
                if (betrieb.betriebNr != null)
                  InfoZeile('Betrieb Nr.', betrieb.betriebNr!, labelBreite: 120),
                if (betrieb.weNummer != null)
                  InfoZeile('WE-Nummer', betrieb.weNummer!, labelBreite: 120),
                if (betrieb.agNummer != null)
                  InfoZeile('AG-Nummer', betrieb.agNummer!, labelBreite: 120),
              ],
            ),

          // Saison (nur bei Saisonbetrieb)
          if (betrieb.istSaisonbetrieb)
            DetailKarte(
              titel: 'Saison',
              icon: Icons.calendar_month,
              kinder: [
                if (betrieb.winterSaisonAktiv &&
                    betrieb.winterStartDatum != null)
                  InfoZeile(
                    'Winter',
                    '${_formatDate(betrieb.winterStartDatum!)} – ${betrieb.winterEndeDatum != null ? _formatDate(betrieb.winterEndeDatum!) : '?'}'
                  , labelBreite: 120),
                if (betrieb.sommerSaisonAktiv &&
                    betrieb.sommerStartDatum != null)
                  InfoZeile(
                    'Sommer',
                    '${_formatDate(betrieb.sommerStartDatum!)} – ${betrieb.sommerEndeDatum != null ? _formatDate(betrieb.sommerEndeDatum!) : '?'}'
                  , labelBreite: 120),
              ],
            ),

          // Ruhetage & Ferien (für alle Betriebe)
          // Ferien aus der Tabelle `betrieb_ferien` (Analyse R7) — nicht
          // mehr über ferienSlots, das hier (getById, ohne ferienPerioden)
          // die eingefrorenen Altspalten las.
          if (betrieb.ruhetage.isNotEmpty ||
              betrieb.keineBetriebsferien ||
              betrieb.serverId != null)
            DetailKarte(
              titel: 'Ruhetage & Ferien',
              icon: Icons.event_busy,
              kinder: [
                if (betrieb.ruhetage.isNotEmpty)
                  InfoZeile(
                    'Ruhetage',
                    betrieb.ruhetage.contains('keine')
                        ? 'Keine'
                        : betrieb.ruhetage.join(', ')
                  , labelBreite: 120),
                if (betrieb.keineBetriebsferien)
                  const InfoZeile('Betriebsferien', 'Keine', labelBreite: 120),
                if (!betrieb.keineBetriebsferien && betrieb.serverId != null)
                  BetriebFerienListe(
                    betriebId: betrieb.serverId!,
                    bearbeitbar: false,
                  ),
              ],
            ),

          // Öffnungszeiten
          if (_hasOeffnungszeiten(betrieb))
            DetailKarte(
              titel: 'Öffnungszeiten',
              icon: Icons.access_time,
              kinder: _buildOeffnungszeiten(betrieb),
            ),

          // Servicezeiten
          // Beide Zeilen immer zeigen: ein leerer Block heisst «kein Service»,
          // sobald der andere gefüllt ist (Regel Daniel 29.07.2026). Fehlte
          // die Zeile ganz, war das nicht von «noch nicht erfasst» zu
          // unterscheiden.
          if (betrieb.servicezeitMorgenAb != null ||
              betrieb.servicezeitNachmittagAb != null)
            DetailKarte(
              titel: 'Servicezeiten',
              icon: Icons.schedule,
              kinder: [
                InfoZeile(
                  'Morgen',
                  betrieb.servicezeitMorgenAb != null
                      ? '${betrieb.servicezeitMorgenAb} – ${betrieb.servicezeitMorgenBis ?? '?'}'
                      : 'kein Service'
                , labelBreite: 120),
                InfoZeile(
                  'Nachmittag',
                  betrieb.servicezeitNachmittagAb != null
                      ? '${betrieb.servicezeitNachmittagAb} – ${betrieb.servicezeitNachmittagBis ?? '?'}'
                      : 'kein Service'
                , labelBreite: 120),
              ],
            ),

          // Service-Hinweis (erscheint auch beim Reinigungs-Abschluss)
          if ((betrieb.serviceHinweis ?? '').trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withAlpha(120)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.campaign,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      betrieb.serviceHinweis!.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Zugang & Notizen
          if (betrieb.zugangNotizen != null || betrieb.notizen != null)
            DetailKarte(
              titel: 'Notizen',
              icon: Icons.note,
              kinder: [
                if (betrieb.zugangNotizen != null)
                  InfoZeile('Zugang', betrieb.zugangNotizen!, labelBreite: 120),
                if (betrieb.notizen != null)
                  InfoZeile('Notizen', betrieb.notizen!, labelBreite: 120),
              ],
            ),

          // Kontaktpersonen
          if (betrieb.serverId != null) _KontakteSection(betrieb: betrieb),

          // Rechnungsadresse
          if (betrieb.serverId != null)
            _RechnungsadresseSection(betrieb: betrieb),

          // Anlagen
          if (betrieb.serverId != null) _AnlagenSection(betrieb: betrieb),

          // Geplanter Service
          if (betrieb.serverId != null) _ServiceTerminSection(betrieb: betrieb),

          // Reinigungen
          if (betrieb.serverId != null) _ReinigungenSection(betrieb: betrieb),

          // Störungen
          if (betrieb.serverId != null) _StoerungenSection(betrieb: betrieb),

          // Eigenaufträge
          if (betrieb.serverId != null)
            _EigenauftraegeSection(betrieb: betrieb),

          // Sync-Info
          if (!betrieb.isSynced)
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
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Noch nicht synchronisiert',
                    style: TextStyle(color: AppColors.warning),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 80), // Platz für FAB
        ],
      ),
    );
  }

  bool _hasOeffnungszeiten(BetriebLocal b) {
    if (b.oeffnungszeitenJson == null || b.oeffnungszeitenJson!.isEmpty) {
      return false;
    }
    try {
      final map = jsonDecode(b.oeffnungszeitenJson!);
      if (map is! Map) return false;
      return map.values.any((v) => v is List && v.isNotEmpty);
    } catch (_) {
      return false;
    }
  }

  List<Widget> _buildOeffnungszeiten(BetriebLocal b) {
    const tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const tageLabel = {
      'Mo': 'Montag',
      'Di': 'Dienstag',
      'Mi': 'Mittwoch',
      'Do': 'Donnerstag',
      'Fr': 'Freitag',
      'Sa': 'Samstag',
      'So': 'Sonntag',
    };
    final ruhetage = b.ruhetage;
    try {
      final map = jsonDecode(b.oeffnungszeitenJson!) as Map<String, dynamic>;
      final widgets = <Widget>[];
      for (final tag in tage) {
        // Ruhetage überspringen — werden bereits separat angezeigt
        if (ruhetage.contains(tag)) continue;
        final slots = map[tag];
        if (slots is List && slots.isNotEmpty) {
          final slotsStr = slots
              .map((s) => '${s['von']} – ${s['bis']}')
              .join(', ');
          widgets.add(InfoZeile(tageLabel[tag]!, slotsStr, labelBreite: 120));
        }
      }
      return widgets;
    } catch (_) {
      return [const Text('Fehler beim Laden')];
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String? _routeUrl(BetriebLocal betrieb) => googleMapsRouteUrl(
    latitude: betrieb.latitude,
    longitude: betrieb.longitude,
    adresse: [
      betrieb.strasse,
      betrieb.nr,
      betrieb.plz,
      betrieb.ort,
    ].where((s) => s != null && s.isNotEmpty).join(' '),
  );

  String _schliessungsgrundLabel(String? value) {
    switch (value) {
      case 'umnutzung':
        return 'Umnutzung';
      case 'abbruch':
        return 'Abbruch';
      case 'konkurs':
        return 'Konkurs';
      case 'sonstiges':
        return 'Sonstiges';
      default:
        return '–';
    }
  }

  String _rechnungsstellungLabel(String value) {
    switch (value) {
      case 'rechnung_mail':
        return 'Per E-Mail';
      case 'rechnung_post':
        return 'Per Post';
      case 'rechnung_tresen':
        return 'Rechnung Tresen';
      case 'barzahlung':
        return 'Barzahlung';
      case 'jahresrechnung':
        return 'Jahresrechnung';
      case 'heineken':
        return 'Via Heineken';
      default:
        return value;
    }
  }

  /// Kontoauszug des Betriebs (alle Rechnungen + Zahlungen, laufender Saldo)
  /// als PDF öffnen/teilen — Grundlage für Mahn-Gespräche.
  /// Alle Reinigungsprotokolle eines Jahres als ein PDF.
  ///
  /// WARUM je Jahr und nicht alles auf einmal (21.09.2026): Ein Betrieb hat
  /// leicht 50 Protokolle über die Jahre, jedes rund eine Viertelmegabyte.
  /// Ein Bündel über alles wäre unhandlich und dauert. Gefragt wird ohnehin
  /// jahrweise — «schickst du mir die Nachweise für 2026».
  Future<void> _zeigeProtokolle(BuildContext context) async {
    final serverId = betrieb.serverId;
    final messenger = ScaffoldMessenger.of(context);
    if (serverId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Betrieb noch nicht synchronisiert — kein Export.'),
        ),
      );
      return;
    }

    final alle = await ReinigungRepository.getByBetrieb(serverId);
    final mitProtokoll = alle
        .where((r) => (r.protokollFotoPfad ?? '').isNotEmpty)
        .toList();
    if (mitProtokoll.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Für diesen Betrieb ist kein Protokoll hinterlegt.'),
        ),
      );
      return;
    }

    // Jahre mit Anzahl, neueste zuoberst.
    final proJahr = <int, int>{};
    for (final r in mitProtokoll) {
      proJahr[r.datum.year] = (proJahr[r.datum.year] ?? 0) + 1;
    }
    final jahre = proJahr.keys.toList()..sort((a, b) => b.compareTo(a));
    if (!context.mounted) return;

    final jahr = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Protokolle als PDF'),
        children: [
          for (final j in jahre)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, j),
              child: Text(
                '$j  ·  ${proJahr[j]} Protokoll${proJahr[j] == 1 ? '' : 'e'}',
              ),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
    if (jahr == null) return;

    final auswahl = mitProtokoll.where((r) => r.datum.year == jahr).toList()
      ..sort((a, b) => a.datum.compareTo(b.datum));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${auswahl.length} Protokolle werden geladen — das dauert einen '
          'Moment.',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
    try {
      final bilder = await ProtokollePdfService.ladeBilder(auswahl);
      if (bilder.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Keines der Protokolle liess sich laden.'),
          ),
        );
        return;
      }
      final bytes = await ProtokollePdfService.buendel(
        bilder,
        betrieb.name,
        jahr,
      );
      final name = betrieb.name.replaceAll(RegExp(r'[^A-Za-z0-9äöüÄÖÜ]+'), '_');
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Protokolle_${name}_$jahr.pdf',
      );
      // Ehrlich bleiben, wenn nicht alles geladen werden konnte — sonst hält
      // man ein unvollständiges Bündel für vollständig.
      if (bilder.length < auswahl.length) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.warning,
            content: Text(
              '${bilder.length} von ${auswahl.length} Protokollen im PDF — '
              '${auswahl.length - bilder.length} liessen sich nicht laden.',
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Protokolle fehlgeschlagen: ${kurzeFehlermeldung(e)}'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _zeigeKontoauszug(BuildContext context, WidgetRef ref) async {
    final serverId = betrieb.serverId;
    if (serverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Betrieb noch nicht synchronisiert — kein Auszug möglich.',
          ),
        ),
      );
      return;
    }
    try {
      final rechnungen = await RechnungRepository.getByBetrieb(serverId);
      if (rechnungen.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keine Rechnungen für diesen Betrieb.'),
            ),
          );
        }
        return;
      }
      final raLocal = await BetriebRechnungsadresseRepository.getByBetrieb(
        serverId,
      );
      final ra = raLocal == null
          ? null
          : BetriebRechnungsadresseMapper.toDto(raLocal, betriebId: serverId);
      final g = ref.read(geschaeftProvider).valueOrNull;
      final bytes = await KontoauszugPdfService.generate(
        betrieb: betrieb,
        rechnungen: rechnungen,
        rechnungsadresse: ra,
        firmaName: g?.firma,
        firmaStrasse: g?.adresseStrasse,
        firmaPlzOrt: g?.adressePlzOrt,
        firmaMwst: g?.mwstZeile,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'Kontoauszug_${betrieb.name.replaceAll(RegExp(r'[^A-Za-z0-9äöüÄÖÜ]+'), '_')}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kontoauszug-Fehler: ${kurzeFehlermeldung(e)}'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Betrieb löschen'),
        content: Text(
          '«${betrieb.name}» wird gelöscht. Das ist nur möglich, wenn keine verknüpften Daten '
          '(Anlagen, Reinigungen, Rechnungen, Kontakte …) mehr vorhanden sind — sonst wird das '
          'Löschen mit einem Hinweis abgebrochen und nichts entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Abbrechen'),
          ),
          TapKnopf(text: 'Löschen', gefahr: true, onTap: () => ctx.pop(true)),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await BetriebRepository.delete(betrieb.routeId);
        ref.invalidate(betriebeStreamProvider);
        if (context.mounted) context.go('/betriebe');
      } on BetriebLoeschException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Löschen fehlgeschlagen — bitte Internetverbindung prüfen',
              ),
            ),
          );
        }
      }
    }
  }
}

class _KontakteSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _KontakteSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BetriebKontaktLocal>>(
      stream: BetriebKontaktRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final kontakte = snapshot.data ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kontakte (${kontakte.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neuer Kontakt'),
                      onPressed: () => context.push(
                        '/betriebe/${betrieb.routeId}/kontakte/neu',
                      ),
                    ),
                  ],
                ),
                if (kontakte.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...kontakte.map(
                    (k) => _KontaktRow(
                      kontakt: k,
                      betriebRouteId: betrieb.routeId,
                    ),
                  ),
                ],
                if (kontakte.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Kontaktpersonen erfasst',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KontaktRow extends StatelessWidget {
  final BetriebKontaktLocal kontakt;
  final String betriebRouteId;

  const _KontaktRow({required this.kontakt, required this.betriebRouteId});

  @override
  Widget build(BuildContext context) {
    final name = kontakt.nachname != null && kontakt.nachname!.isNotEmpty
        ? '${kontakt.vorname} ${kontakt.nachname}'
        : kontakt.vorname;
    final isGuest = SupabaseService.isGuest;

    return InkWell(
      onTap: () {
        final id = kontakt.serverId ?? kontakt.id.toString();
        context.push('/betriebe/$betriebRouteId/kontakte/$id/bearbeiten');
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.aktiv.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                kontakt.istHauptkontakt ? Icons.star : Icons.person,
                size: 16,
                color: AppColors.aktiv,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      if (kontakt.istHauptkontakt) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.aktiv.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Haupt',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.aktiv,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    [
                      if (kontakt.funktion != null) kontakt.funktion!,
                      if (kontakt.telefon != null) kontakt.telefon!,
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!isGuest)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.textSecondary,
                tooltip: 'Löschen',
                onPressed: () => _confirmDelete(context, name),
              ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kontakt löschen?'),
        content: Text('«$name» wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TapKnopf(
            text: 'Löschen',
            gefahr: true,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final id = kontakt.serverId ?? kontakt.id.toString();
        await BetriebKontaktRepository.delete(id);
        GoogleContactsService.syncImHintergrund(
          onFehler: (f) => zeigeGoogleFehler(messenger, f),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Kontakt gelöscht')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: ${kurzeFehlermeldung(e)}')),
          );
        }
      }
    }
  }
}

class _RechnungsadresseSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _RechnungsadresseSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BetriebRechnungsadresseLocal>>(
      stream: BetriebRechnungsadresseRepository.watchByBetrieb(
        betrieb.serverId!,
      ),
      builder: (context, snapshot) {
        final adressen = snapshot.data ?? [];
        final adresse = adressen.isNotEmpty ? adressen.first : null;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Rechnungsadresse',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: Icon(
                        adresse != null ? Icons.edit : Icons.add,
                        size: 18,
                      ),
                      label: Text(
                        adresse != null ? 'Bearbeiten' : 'Hinzufügen',
                      ),
                      onPressed: () => context.push(
                        '/betriebe/${betrieb.routeId}/rechnungsadresse',
                      ),
                    ),
                  ],
                ),
                if (adresse != null) ...[
                  const SizedBox(height: 8),
                  // Firma fett, restliche Adresszeilen darunter — Aufbau wie
                  // im PDF (core/util/rechnungsadresse_zeilen.dart).
                  if (adresse.firma != null && adresse.firma!.isNotEmpty)
                    Text(
                      adresse.firma!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  Text(
                    adressZeilen(
                      betriebName: adresse.objekt,
                      ra: BetriebRechnungsadresseMapper.toDto(adresse),
                    ).where((z) => z != adresse.firma).join('\n'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (adresse.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      adresse.email!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
                if (adresse == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Keine Rechnungsadresse hinterlegt',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnlagenSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _AnlagenSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnlageLocal>>(
      stream: AnlageRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final anlagen = snapshot.data ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.precision_manufacturing,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Anlagen (${anlagen.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Neue Anlage'),
                      onPressed: () => context.push(
                        '/anlagen/neu?betriebId=${betrieb.serverId}',
                      ),
                    ),
                  ],
                ),
                if (anlagen.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...anlagen.map((a) => _AnlageRow(anlage: a)),
                ],
                if (anlagen.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Anlagen erfasst',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Geplante Service-Termine des Betriebs, mit Knopf zum Setzen.
///
/// **Warum (Daniel, 20.09.2026):** 33 Anlagen laufen «auf Abruf». Für die
/// rechnet die App bewusst kein Fälligkeitsdatum aus — sie tauchen nie von
/// selbst im Tourenplan auf, und ein vereinbarter Termin liess sich nirgends
/// festhalten. Fall Alpina Resort Tschiertschen.
///
/// Gezeigt werden nur die freien Termine (`typ` weder Eröffnungs- noch
/// Endreinigung): Die Saisonreinigungen haben ihren eigenen Weg über die
/// Vorschläge im Tourenplan und gehören nicht hierher.
class _ServiceTerminSection extends ConsumerWidget {
  final BetriebLocal betrieb;

  const _ServiceTerminSection({required this.betrieb});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alle = ref.watch(offeneTermineProvider).valueOrNull ?? const [];
    final meine =
        alle
            .where(
              (t) =>
                  t.betriebId == betrieb.serverId &&
                  t.typ != 'eroeffnungsreinigung' &&
                  t.typ != 'endreinigung',
            )
            .toList()
          ..sort((a, b) => a.datum.compareTo(b.datum));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_available,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Geplanter Service',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Termin setzen'),
                  onPressed: () => _planen(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (meine.isEmpty)
              const Text(
                'Kein Termin gesetzt.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              for (final t in meine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_terminDatum.format(t.datum)} · ${t.titel}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (t.notizen != null && t.notizen!.isNotEmpty)
                              Text(
                                t.notizen!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _erledigen(context, ref, t),
                        child: const Text('Erledigt'),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _planen(BuildContext context, WidgetRef ref) async {
    final sid = betrieb.serverId;
    if (sid == null) return;
    final eingabe = await zeigeServiceTerminDialog(
      context,
      betriebName: betrieb.name,
    );
    if (eingabe == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TerminRepository.anlegen(
        betriebId: sid,
        typ: 'sonstiges',
        datum: eingabe.datum,
        titel: eingabe.titel,
        notizen: eingabe.notizen,
      );
      ref.invalidate(offeneTermineProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Termin am ${_terminDatum.format(eingabe.datum)} gesetzt — '
            'im Kalender und in den Einsätzen.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nicht gesetzt: ${kurzeFehlermeldung(e)}')),
      );
    }
  }

  Future<void> _erledigen(
    BuildContext context,
    WidgetRef ref,
    TerminDto t,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await TerminRepository.erledigen(t.id);
      ref.invalidate(offeneTermineProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Erledigt — der Kalendereintrag verschwindet.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nicht erledigt: ${kurzeFehlermeldung(e)}')),
      );
    }
  }
}

final _terminDatum = DateFormat('dd.MM.yyyy');

class _StoerungenSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _StoerungenSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoerungLocal>>(
      stream: StoerungRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final stoerungen = snapshot.data ?? [];
        final sorted = List<StoerungLocal>.from(stoerungen)
          ..sort((a, b) => b.datum.compareTo(a.datum));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Störungen (${stoerungen.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (!SupabaseService.isGuest)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Neue Störung'),
                        onPressed: () => context.push(
                          '/stoerungen/neu?betriebId=${betrieb.serverId}',
                        ),
                      ),
                  ],
                ),
                if (sorted.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...sorted.take(5).map((s) => _StoerungRow(stoerung: s)),
                  if (sorted.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${sorted.length - 5} weitere',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
                if (stoerungen.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Störungen erfasst',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StoerungRow extends StatelessWidget {
  final StoerungLocal stoerung;

  const _StoerungRow({required this.stoerung});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (stoerung.status) {
      'offen' => AppColors.warning,
      'behoben' => AppColors.success,
      'nicht_behebbar' => AppColors.inaktiv,
      _ => AppColors.textSecondary,
    };

    return InkWell(
      onTap: () => context.push('/stoerungen/${stoerung.routeId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber, size: 16, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stoerung.stoerungsnummer ?? 'Störung',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    [
                      if (stoerung.referenzNr != null)
                        'HN-${stoerung.referenzNr}',
                      _formatDate(stoerung.datum),
                      stoerung.status,
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EigenauftraegeSection extends StatelessWidget {
  final BetriebLocal betrieb;

  const _EigenauftraegeSection({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EigenauftragLocal>>(
      stream: EigenauftragRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final eigenauftraege = snapshot.data ?? [];
        final sorted = List<EigenauftragLocal>.from(eigenauftraege)
          ..sort((a, b) => b.datum.compareTo(a.datum));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.build_circle_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Eigenaufträge (${eigenauftraege.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (!SupabaseService.isGuest)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Neuer Eigenauftrag'),
                        onPressed: () => context.push(
                          '/eigenauftraege/neu?betriebId=${betrieb.serverId}',
                        ),
                      ),
                  ],
                ),
                if (sorted.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...sorted
                      .take(5)
                      .map((e) => _EigenauftragRow(eigenauftrag: e)),
                  if (sorted.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${sorted.length - 5} weitere',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
                if (eigenauftraege.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Eigenaufträge erfasst',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EigenauftragRow extends StatelessWidget {
  final EigenauftragLocal eigenauftrag;

  const _EigenauftragRow({required this.eigenauftrag});

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (eigenauftrag.status) {
      'behoben' => AppColors.success,
      'nicht_behebbar' => AppColors.inaktiv,
      'nachbearbeitung_noetig' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

    return InkWell(
      onTap: () => context.push('/eigenauftraege/${eigenauftrag.routeId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.build_circle_outlined,
                size: 16,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eigenauftrag.stoerungsnummer,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    [
                      _formatDate(eigenauftrag.datum),
                      if (eigenauftrag.pauschale != null)
                        '${eigenauftrag.pauschale!.toStringAsFixed(2)} CHF',
                      eigenauftrag.status,
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnlageRow extends StatelessWidget {
  final AnlageLocal anlage;

  const _AnlageRow({required this.anlage});

  Color get _statusColor {
    switch (anlage.status) {
      case 'aktiv':
        return AppColors.aktiv;
      case 'inaktiv':
        return AppColors.warning;
      case 'stillgelegt':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/anlagen/${anlage.routeId}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.precision_manufacturing,
                size: 16,
                color: _statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anlage.bezeichnung ?? anlage.typAnlage,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${anlage.typAnlage} · ${anlage.anzahlHaehne} Hähne',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReinigungenSection extends StatefulWidget {
  final BetriebLocal betrieb;

  const _ReinigungenSection({required this.betrieb});

  @override
  State<_ReinigungenSection> createState() => _ReinigungenSectionState();
}

class _ReinigungenSectionState extends State<_ReinigungenSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final betrieb = widget.betrieb;
    return StreamBuilder<List<ReinigungLocal>>(
      stream: ReinigungRepository.watchByBetrieb(betrieb.serverId!),
      builder: (context, snapshot) {
        final reinigungen = snapshot.data ?? [];
        reinigungen.sort((a, b) => b.datum.compareTo(a.datum));
        final display = _expanded ? reinigungen : reinigungen.take(5).toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cleaning_services,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Reinigungen',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${reinigungen.length}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    // Kein anlageIds hier: auf der Betriebsseite ist noch nicht
                    // entschieden, welche Anlagen gemeint sind — das Formular
                    // zeigt sie zur Auswahl (bei einer neuen Reinigung sind dort
                    // ohnehin alle Anlagen des Betriebs vorausgewählt). Der
                    // Tourenplan-Block kennt die Bündelung dagegen schon.
                    if (!SupabaseService.isGuest)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Neue Reinigung'),
                        onPressed: () => context.push(
                          '/reinigungen/neu?betriebId=${betrieb.serverId}',
                        ),
                      ),
                  ],
                ),
                if (display.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...display.map(
                    (r) => InkWell(
                      onTap: () => context.push('/reinigungen/${r.routeId}'),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              r.status == 'abgeschlossen'
                                  ? Icons.check_circle
                                  : Icons.hourglass_top,
                              size: 18,
                              color: r.status == 'abgeschlossen'
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${r.datum.day.toString().padLeft(2, '0')}.${r.datum.month.toString().padLeft(2, '0')}.${r.datum.year}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (r.preisBrutto != null)
                              Text(
                                '${r.preisBrutto!.toStringAsFixed(2)} CHF',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (reinigungen.length > 5)
                    InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _expanded
                                  ? 'Weniger anzeigen'
                                  : 'Alle ${reinigungen.length} anzeigen',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (display.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Noch keine Reinigungen',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final BetriebLocal betrieb;

  const _StatusRow({required this.betrieb});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(label: betrieb.status, color: _statusColor(betrieb.status)),
        if (betrieb.istBergkunde)
          _StatusChip(
            label: 'Bergkunde',
            color: AppColors.info,
            icon: Icons.terrain,
          ),
        if (betrieb.istSaisonbetrieb)
          _StatusChip(
            label: 'Saisonbetrieb',
            color: AppColors.saisonpause,
            icon: Icons.calendar_month,
          ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'aktiv':
        return AppColors.aktiv;
      case 'inaktiv':
        return AppColors.inaktiv;
      case 'saisonpause':
        return AppColors.saisonpause;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusChip({required this.label, required this.color, this.icon});

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

class _LinkRow extends StatelessWidget {
  final String label;
  final String text;
  final Uri uri;

  const _LinkRow(this.label, this.text, this.uri);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => launchUrl(uri),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
