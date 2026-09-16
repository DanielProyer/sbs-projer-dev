import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/sync_meldung.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/connectivity_provider.dart';
import 'package:sbs_projer_app/presentation/providers/sync_provider.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/event_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/arbeitstag_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_sheet.dart';
import 'package:sbs_projer_app/presentation/widgets/diktat_sheet.dart';
import 'package:sbs_projer_app/presentation/widgets/heute_liste.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/sync/sync_service_export.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Version gleich im Titel: sonst ist im Web nicht feststellbar,
        // welcher Stand geladen ist (Cache-Diagnosen, Daniel 28.07.2026).
        title: const Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('SBS Projer'),
            SizedBox(width: 6),
            Text('(v$kAppVersion)', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: _SyncIndicator(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () async {
              if (!kIsWeb) SyncService.stopListening();
              await SupabaseService.client.auth.signOut();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        children: [
          const _AufgabenKarte(),
          // Arbeitstag direkt auf dem Startbildschirm erfassen (Beginn mit
          // GPS-Position, abends Ende + km) — Daniel 29.07.2026.
          const ArbeitstagKarte(),
          const HeuteListe(),
          const SizedBox(height: 8),
          const _KachelGrid(),
          const SizedBox(height: 16),
          const _WeitereSection(),
        ],
      ),
      // Diktieren als frei schwebender Knopf statt fester Leiste: Daniel
      // braucht ihn vor allem im Auto (einhändig, sofort da) — ein FAB
      // liegt IMMER über dem Inhalt, ohne den seit Task 10 (13.09.2026)
      // bewusst scrollenden Startbildschirm durch zusätzliche Leisten
      // zusätzlich zu verkleinern.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => zeigeDiktatSheet(context),
        icon: const Icon(Icons.mic),
        label: const Text('Diktieren'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _KachelGrid extends ConsumerWidget {
  const _KachelGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kachelzähler = Glocken-Badge — dieselbe Quelle (B6).
    final aufgabenCount = ref.watch(aufgabenBadgeProvider);
    final niedrigCount = ref.watch(niedrigCountProvider);

    // Flachere Kacheln (2.1 statt 1.75) + engere Abstände: ursprünglich
    // sollten alle 10 Kacheln zusammen mit Arbeitstag + Übersicht ohne
    // Scrollen aufs Pixel 9 passen (Daniel 31.07.2026). Diese Regel ist
    // überholt — seit Task 10 (13.09.2026) zeigt die Startseite zusätzlich
    // die Heute-Liste mit dem vollständigen Tagesplan, der je nach
    // Stopp-Zahl beliebig lang wird; die Seite scrollt jetzt bewusst. Das
    // knappe Kachel-Layout bleibt trotzdem so, weil es unabhängig davon
    // gut lesbar ist.
    // Seit v0.107.0 (B1) führt die untere Navigationsleiste zu Heute,
    // Einsätzen, Betrieben und Tour. Hier stehen nur noch die Ziele, die
    // sie nicht abdeckt — und «Weitere» darunter den Rest.
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      childAspectRatio: 2.1,
      children: [
        DashboardTile(
          icon: Icons.contacts,
          label: 'Kontakte',
          count: null,
          color: Colors.teal,
          onTap: () => context.push('/kontakte'),
        ),
        // Events sind seit v0.58.0 unten in der Liste (oberhalb Buchhaltung);
        // an ihrer Stelle die neuen Aufgaben (anstehende Arbeiten) — Daniel
        // 31.07.2026.
        DashboardTile(
          icon: Icons.task_alt,
          label: 'Aufgaben',
          count: aufgabenCount > 0 ? '$aufgabenCount' : null,
          color: Colors.deepOrange,
          onTap: () => context.push('/aufgaben'),
        ),
        DashboardTile(
          icon: Icons.receipt_long,
          label: 'Spesen',
          count: null,
          color: Colors.brown,
          onTap: () => context.push('/spesen'),
        ),
        // Material braucht Daniel auch unterwegs (16.09.2026) — und «N
        // niedrig» ist einer der wenigen Kachelzähler, die eine Handlung
        // verlangen. Stand bis v0.107.0 in «Weitere», dort jetzt entfernt.
        DashboardTile(
          icon: Icons.inventory_2,
          label: 'Material',
          count: niedrigCount > 0 ? '$niedrigCount niedrig' : null,
          color: Colors.blueGrey,
          onTap: () => context.push('/materialien'),
        ),
      ],
    );
  }
}

class _WeitereSection extends ConsumerWidget {
  const _WeitereSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buchungenCount = ref.watch(buchungenCountProvider);
    final eventCount =
        ref
            .watch(eventsProvider)
            .valueOrNull
            ?.where((e) => e.jahr == DateTime.now().year)
            .length ??
        0;

    return Column(
      children: [
        // Events zuoberst (aus dem Kachel-Raster hierher verschoben — Daniel
        // 31.07.2026; die Kachel gehört jetzt den Aufgaben).
        _MenuListTile(
          icon: Icons.festival,
          label: 'Events',
          count: eventCount > 0 ? '$eventCount' : null,
          onTap: () => context.push('/events'),
        ),
        // Buchhaltung für Gast (Heineken) ausgeblendet
        if (!SupabaseService.isGuest)
          _MenuListTile(
            icon: Icons.account_balance,
            label: 'Buchhaltung',
            count: buchungenCount > 0 ? '$buchungenCount' : null,
            onTap: () => context.push('/buchhaltung'),
          ),
        // Dokumentenablage — wie die Buchhaltung nichts für den Gast
        if (!SupabaseService.isGuest)
          _MenuListTile(
            icon: Icons.folder_open,
            label: 'Dokumente',
            onTap: () => context.push('/dokumente'),
          ),
        _MenuListTile(
          icon: Icons.query_stats,
          label: 'Auswertung Arbeitstage',
          onTap: () => context.push('/auswertungen/arbeitstage'),
        ),
        _MenuListTile(
          icon: Icons.nightlight_round,
          label: 'Pikett-Dienste',
          onTap: () => context.push('/einsaetze?typ=pikett'),
        ),
        _MenuListTile(
          icon: Icons.propane_tank_outlined,
          label: 'Anlagen',
          onTap: () => context.push('/anlagen'),
        ),
        _MenuListTile(
          icon: Icons.landscape,
          label: 'Bergkundenpauschalen',
          onTap: () => context.push('/bergkundenpauschalen'),
        ),
        _MenuListTile(
          icon: Icons.settings,
          label: 'Einstellungen',
          onTap: () => context.push('/einstellungen'),
        ),
        if (!kIsWeb)
          _MenuListTile(
            icon: Icons.sync,
            label: 'Sync erzwingen',
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('Synchronisierung gestartet...')),
              );
              // Ergebnis abwarten und melden: Vorher blieb es bei
              // «gestartet», auch wenn einzelne Sätze nicht durchkamen.
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
      ],
    );
  }
}

class _SyncIndicator extends ConsumerWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final isSyncing = ref.watch(isSyncingProvider);
    final hatFehler = ref.watch(syncHatFehlerProvider);

    if (isSyncing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // Ein fehlgeschlagener Sync darf nicht als grünes «cloud_done»
    // erscheinen — genau das liess fehlende Daten wie übertragene aussehen.
    if (hatFehler) {
      return Tooltip(
        message: 'Letzter Sync unvollständig — «Sync erzwingen» für Details',
        child: Icon(
          Icons.cloud_off,
          color: AppColors.offline,
          size: 20,
        ),
      );
    }
    return Icon(
      isOnline ? Icons.cloud_done : Icons.cloud_off,
      color: isOnline ? AppColors.online : AppColors.offline,
      size: 20,
    );
  }
}

class DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? count;
  final Color color;
  final VoidCallback onTap;

  const DashboardTile({
    super.key,
    required this.icon,
    required this.label,
    this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Zähler oben neben dem Symbol, Name darunter über die ganze
              // Kachelbreite.
              //
              // WARUM: Solange beide in einer Zeile standen, teilten sie sich
              // die halbe Kachelbreite — und «Reinigungen» wurde zu
              // «Reinigung…» gekürzt, selbst wenn im Chip nur «87» stand
              // (im Browser geprüft, 15.09.2026). Der Zählertext war also gar
              // nicht die Ursache; kürzen allein hätte den Namen nicht
              // gerettet. Oben ist neben dem 20-px-Symbol reichlich Platz.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: color, size: 20),
                  if (count != null) ...[
                    const SizedBox(width: 4),
                    // Flexible ist hier zwingend, nicht nur Kosmetik: ohne
                    // sie bekommt der Container im Row keinerlei Breiten-
                    // grenze und maxLines/overflow am Text greifen nie — das
                    // Ergebnis ist ein RenderFlex-Overflow, kein Ellipsis
                    // (mit einer Probe verifiziert, 13.09.2026). Die neuen
                    // Zähler-Texte ("12 diese Woche") sind deutlich länger
                    // als die alten reinen Zahlen und laufen bei 360 px
                    // (Pixel 9, 2 Spalten) sonst über die Kachel hinaus —
                    // Schriftgrösse bleibt 11 px (Lesbarkeits-Untergrenze),
                    // stattdessen kürzt hier die Ellipse.
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count!,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? count;
  final VoidCallback onTap;

  const _MenuListTile({
    required this.icon,
    required this.label,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  count!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _AufgabenKarte extends ConsumerWidget {
  const _AufgabenKarte();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jetzt = ref.watch(aufgabenJetztProvider);
    if (jetzt.isEmpty) return const SizedBox.shrink();
    final titel = jetzt.map((a) => a.titel).take(3).toList();
    final dringend = jetzt.any((a) => a.dringend);
    final label = jetzt.length == 1 ? '1 Aufgabe offen' : '${jetzt.length} Aufgaben offen';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: dringend
          ? AppColors.error.withValues(alpha: 0.08)
          : AppColors.warning.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () => zeigeAufgabenSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    size: 18,
                    color: dringend ? AppColors.error : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              ...titel.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(left: 26, top: 2),
                  child: Text(
                    '· $t',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
