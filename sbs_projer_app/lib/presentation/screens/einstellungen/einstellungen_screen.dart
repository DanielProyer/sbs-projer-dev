import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/dateigroesse.dart';
import 'package:sbs_projer_app/core/util/google_fehler.dart';
import 'package:sbs_projer_app/core/util/sync_meldung.dart';
import 'package:sbs_projer_app/presentation/widgets/google_fehler_meldung.dart';
import 'package:sbs_projer_app/data/models/buchungs_beleg.dart';
import 'package:sbs_projer_app/data/repositories/buchungs_beleg_repository.dart';
import 'package:sbs_projer_app/presentation/providers/google_calendar_providers.dart';
import 'package:sbs_projer_app/core/util/google_kontakte.dart';
import 'package:sbs_projer_app/services/google/google_contacts_service.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_auth_service.dart';
import 'package:sbs_projer_app/services/google_calendar/google_calendar_sync_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/sync/sync_service_export.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/gefahr_rueckfrage.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';

class EinstellungenScreen extends ConsumerStatefulWidget {
  const EinstellungenScreen({super.key});

  @override
  ConsumerState<EinstellungenScreen> createState() =>
      _EinstellungenScreenState();
}

class _EinstellungenScreenState extends ConsumerState<EinstellungenScreen> {
  // --- Speicher aufräumen (verwaiste Beleg-Dateien, Migration 151) ---
  List<VerwaisterBeleg>? _waisen;
  bool _waisenLaden = false;
  String? _waisenFehler;

  Future<void> _ladeWaisen() async {
    setState(() {
      _waisenLaden = true;
      _waisenFehler = null;
    });
    try {
      final liste = await BuchungsBelegRepository.verwaisteBelege();
      if (!mounted) return;
      setState(() {
        _waisen = liste;
        _waisenLaden = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _waisenFehler = '$e';
        _waisenLaden = false;
      });
    }
  }

  Future<void> _loescheWaisen() async {
    final liste = _waisen;
    if (liste == null || liste.isEmpty) return;
    final bytes = liste.fold<int>(0, (s, w) => s + w.groesse);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dateien löschen?'),
        content: Text(
          '${liste.length} Beleg-Dateien (${formatiereGroesse(bytes)}) werden '
          'endgültig aus dem Speicher entfernt.\n\n'
          'Diese Dateien gehören zu keiner Buchung mehr — die Buchhaltung '
          'bleibt unverändert.',
        ),
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
    if (ok != true) return;

    setState(() => _waisenLaden = true);
    try {
      final anzahl = await BuchungsBelegRepository.loescheVerwaiste(
        liste.map((w) => w.storagePfad).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$anzahl Dateien gelöscht (${formatiereGroesse(bytes)} '
            'freigegeben)',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      await _ladeWaisen();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _waisenFehler = '$e';
        _waisenLaden = false;
      });
    }
  }

  /// Material-Buttons rendern unter CanvasKit teils nicht (bestehendes
  /// Projekt-Muster, vgl. material_bestellungen_screen.dart) — deshalb
  /// GestureDetector-Pill. Genau das war der Grund, warum die Karte hier
  /// ohne Knöpfe erschien (Daniel 28.07.2026).
  Widget _tapButton(
    String label,
    VoidCallback? onTap,
    bool primaer, {
    Color? farbe,
  }) {
    final grund = farbe ?? (primaer ? AppColors.primary : Colors.grey.shade600);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade300 : grund,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeicher() {
    if (_waisenLaden) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_waisenFehler != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fehler: $_waisenFehler',
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 8),
            _tapButton('Nochmal versuchen', _ladeWaisen, false),
          ],
        ),
      );
    }
    final liste = _waisen;
    if (liste == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _tapButton('Speicher prüfen', _ladeWaisen, true),
        ),
      );
    }
    if (liste.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('Keine verwaisten Dateien — alles sauber.')),
          ],
        ),
      );
    }

    final bytes = liste.fold<int>(0, (s, w) => s + w.groesse);
    final aeltest = liste.first.hochgeladen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${liste.length} Dateien ohne Buchung · '
          '${formatiereGroesse(bytes)}',
        ),
        const SizedBox(height: 4),
        Text(
          'Älteste vom ${DateFormat('dd.MM.yyyy').format(aeltest)}. '
          'Entstehen, wenn Buchungen gelöscht werden — die Datei bleibt liegen.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _tapButton('Aktualisieren', _ladeWaisen, false),
            const SizedBox(width: 8),
            _tapButton('Löschen', _loescheWaisen, true, farbe: AppColors.error),
          ],
        ),
      ],
    );
  }

  Widget _buildGoogleKalender(GoogleCalendarStatus status) {
    if (status.connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verbunden${status.email != null ? ' · ${status.email}' : ''}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Pikett, Events und Saison-/Ferien-Reinigungen werden automatisch täglich in deinen Google Kalender geschrieben.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (_) {
              final last = status.lastSyncAt?.toLocal();
              if (last == null) {
                return const Text(
                  'Noch nicht abgeglichen — läuft automatisch beim nächsten Öffnen.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                );
              }
              final veraltet = DateTime.now().difference(last).inDays >= 2;
              final farbe = veraltet
                  ? AppColors.warning
                  : AppColors.textSecondary;
              return Row(
                children: [
                  Icon(
                    veraltet ? Icons.warning_amber : Icons.sync,
                    size: 14,
                    color: farbe,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Zuletzt abgeglichen: '
                      '${DateFormat('dd.MM.yyyy, HH:mm').format(last)}'
                      '${veraltet ? ' — Verbindung prüfen' : ''}',
                      style: TextStyle(fontSize: 12, color: farbe),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Jetzt abgleichen'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Kalender wird abgeglichen …')),
                );
                try {
                  final r = await GoogleCalendarSyncService.reconcile();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Abgeglichen: ${r['pushed'] ?? 0} gesendet, ${r['deleted'] ?? 0} entfernt',
                      ),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Fehler: ${kurzeFehlermeldung(e)}')),
                  );
                }
              },
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text('Bestehende Termine zuordnen'),
              onPressed: () => context.push('/google-termine'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            // Trennen ohne Rückfrage kostete bei einem Fehltipp die
            // Kalender-Anbindung samt Neu-Autorisierung (R6, 25.09.2026).
            child: TapKnopf(
              text: 'Trennen',
              icon: Icons.link_off,
              gefahr: true,
              onTap: () async {
                final ok = await gefahrRueckfrage(
                  context,
                  titel: 'Google Kalender trennen?',
                  text:
                      'Die App schreibt danach keine Termine mehr in den '
                      'Kalender. Zum Wiederverbinden musst du den Zugriff '
                      'bei Google neu erteilen.',
                  bestaetigen: 'Trennen',
                );
                if (!ok) return;
                await GoogleCalendarAuthService.trennen();
                ref.invalidate(googleCalendarStatusProvider);
              },
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verbinde deinen Google Kalender, um Erinnerungen und Termin-Sync zu nutzen.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.event_available, size: 18),
            label: const Text('Mit Google Kalender verbinden'),
            onPressed: () => GoogleCalendarAuthService.verbinden(),
          ),
        ),
      ],
    );
  }

  bool _isKontakteSyncing = false;

  Future<void> _kontakteSyncJetzt() async {
    setState(() => _isKontakteSyncing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await GoogleContactsService.syncJetzt();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sync ok: ${r.info} '
            '(${r.created} neu, ${r.updated} geändert, ${r.deleted} gelöscht)',
          ),
        ),
      );
    } catch (e) {
      // Google-Rohmeldungen sind unbrauchbar — übersetzt anzeigen, samt
      // Knopf zur Seite, die das Problem behebt.
      zeigeGoogleFehler(messenger, googleFehler(e));
    } finally {
      if (mounted) setState(() => _isKontakteSyncing = false);
      ref.invalidate(googleCalendarStatusProvider);
    }
  }

  Widget _buildGoogleKontakte(GoogleCalendarStatus status) {
    if (!status.connected) {
      return const Text(
        'Zuerst oben Google Kalender verbinden — der Kontakte-Sync nutzt '
        'dieselbe Google-Verbindung.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }
    if (!hatKontakteScope(status.scope)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Für den Kontakte-Sync fehlt noch die Google-Freigabe. Einmal '
            'erneuern — Google fragt dann nach dem Kontakte-Zugriff.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.sync_lock, size: 18),
              label: const Text('Google-Verbindung erneuern'),
              onPressed: () => GoogleCalendarAuthService.verbinden(),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kontakte und operative Betriebe landen automatisch im Google-'
          'Adressbuch (Label «SBS App») — für die Anrufer-Erkennung auf dem '
          'Handy. Löschungen und Reaktivierungen gleichen sich mit ab.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          kontakteSyncStatusText(
            status.contactsLastSyncAt,
            status.contactsLastSyncInfo,
          ),
          style: TextStyle(
            fontSize: 12,
            color: (status.contactsLastSyncInfo ?? '').startsWith('Fehler')
                ? AppColors.warning
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: _isKontakteSyncing
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
            label: const Text('Jetzt syncen'),
            onPressed: _isKontakteSyncing ? null : _kontakteSyncJetzt,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Google Kalender
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: const Icon(Icons.event, color: AppColors.primary),
              title: const Text(
                'Google Kalender',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Verbindung für Termine & Erinnerungen'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                ref
                    .watch(googleCalendarStatusProvider)
                    .when(
                      data: (status) => _buildGoogleKalender(status),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text(
                        'Fehler: $e',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
              ],
            ),
          ),

          // Google Kontakte
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: const Icon(Icons.contacts, color: AppColors.primary),
              title: const Text(
                'Google Kontakte',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Adressbuch-Sync für Anrufer-Erkennung'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                ref
                    .watch(googleCalendarStatusProvider)
                    .when(
                      data: (status) => _buildGoogleKontakte(status),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text(
                        'Fehler: $e',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
              ],
            ),
          ),

          // Speicher aufräumen
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: const Icon(
                Icons.cleaning_services,
                color: AppColors.primary,
              ),
              title: const Text(
                'Speicher aufräumen',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Beleg-Dateien ohne Buchung finden'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              onExpansionChanged: (offen) {
                if (offen && _waisen == null && !_waisenLaden) _ladeWaisen();
              },
              children: [_buildSpeicher()],
            ),
          ),

          // Abmelden und Sync (bis v0.130.0 auf der Startseite): Das
          // Abmelde-Symbol sass dort neben der Sync-Anzeige — ein Fehltipp
          // meldete unterwegs ab.
          if (!kIsWeb)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TapKnopf(
                text: 'Sync erzwingen',
                icon: Icons.sync,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Synchronisierung gestartet...'),
                    ),
                  );
                  final r = await SyncService.syncAll();
                  final m = syncMeldung(
                    pushed: r.pushed,
                    pulled: r.pulled,
                    fehler: r.errors,
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(m.text),
                      backgroundColor: m.istFehler ? AppColors.offline : null,
                      duration: Duration(seconds: m.istFehler ? 8 : 3),
                    ),
                  );
                },
              ),
            ),
          TapKnopf(
            text: 'Abmelden',
            icon: Icons.logout,
            // Selten gebraucht, soll nicht wie die Hauptaktion aussehen.
            primaer: false,
            onTap: () async {
              if (!kIsWeb) SyncService.stopListening();
              await SupabaseService.client.auth.signOut();
            },
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'SBS Projer v$kAppVersion',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
