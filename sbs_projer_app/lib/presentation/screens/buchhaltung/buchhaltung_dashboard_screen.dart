import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/aufgabe.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_aktionen.dart';
import 'package:sbs_projer_app/presentation/widgets/bank_waechter_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/buero_offen_block.dart';
import 'package:sbs_projer_app/presentation/widgets/camt_erinnerung_karte.dart';

class BuchhaltungDashboardScreen extends ConsumerWidget {
  const BuchhaltungDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final buchungen = ref.watch(buchungenProvider);
    final erfolgsrechnung = ref.watch(erfolgsrechnungProvider(now.year));
    final mwst = ref.watch(mwstAbrechnungProvider(now.year));
    final offeneCount = ref.watch(offeneRechnungenCountProvider);

    // Buchungen aktueller Monat
    final buchungenMonat = buchungen
        .where((b) => b.geschaeftsjahr == now.year && b.monat == now.month)
        .toList();

    // Umsatz aktueller Monat aus Erfolgsrechnung
    double umsatzMonat = 0;
    erfolgsrechnung.whenData((data) {
      for (final row in data) {
        if (row['monat'] == now.month) {
          umsatzMonat = _d(row['ertrag']);
          break;
        }
      }
    });

    // MwSt aktuelles Quartal
    double mwstSchuld = 0;
    final quartal = ((now.month - 1) ~/ 3) + 1;
    mwst.whenData((data) {
      for (final row in data) {
        if (row['quartal'] == quartal) {
          mwstSchuld = _d(row['netto_mwst_schuld']);
          break;
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Buchhaltung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // «Was ist offen?» — der Büro-Ausschnitt der einen Aufgabenliste
          // (B3). Fristen und Vorräte zusammen, ganz oben: Die Seite
          // beantwortet damit zuerst die Frage, mit der man sie öffnet.
          Builder(
            builder: (_) {
              final liste =
                  ref.watch(aufgabenListeProvider).valueOrNull ?? const [];
              final aktionen = AufgabenAktionen(ref);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: BueroOffenBlock(
                  eintraege: liste.where(istBueroAufgabe).toList(),
                  heute: DateTime.now(),
                  onDorthin: (a) => aktionen.dorthin(context, a),
                  onSnooze: (a, t) => aktionen.snooze(context, a, t),
                  onErledigt: (a) => aktionen.erledigt(context, a),
                ),
              );
            },
          ),
          // Wochen-Erinnerung: neuen camt-Auszug hochladen
          const CamtErinnerungKarte(),
          // Kennzahlen
          Row(
            children: [
              Expanded(
                child: _KennzahlCard(
                  label: 'Umsatz ${_monatName(now.month)}',
                  value: '${umsatzMonat.toStringAsFixed(2)} CHF',
                  icon: Icons.trending_up,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KennzahlCard(
                  label: 'Offene Rechnungen',
                  value: '$offeneCount',
                  icon: Icons.receipt_long,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KennzahlCard(
                  label: 'MwSt Q$quartal',
                  value: '${mwstSchuld.toStringAsFixed(2)} CHF',
                  icon: Icons.account_balance,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KennzahlCard(
                  label: 'Buchungen ${_monatName(now.month)}',
                  value: buchungenMonat.length.toString(),
                  icon: Icons.menu_book,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bank-Wächter: Journal vs. letzter Bank-Schlusssaldo +
          // «Tilgung ohne Aufbau» auf Verbindlichkeitskonten.
          BankWaechterKarte(stand: ref.watch(bankWaechterProvider)),

          const SizedBox(height: 24),

          // Navigation — zwei Gruppen statt einer Sammelliste (B3): die 13
          // Ziele lagen sonst auf einer Ebene, Kontenplan neben
          // Bankauszug-Import (Befund 4, App-Analyse 09/2026).
          Text(
            'Laufend',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.account_balance,
            title: 'Bankauszug Import',
            subtitle: 'Import, Prüfliste, Regeln & Dateien',
            onTap: () => context.push('/buchhaltung/camt-import'),
          ),
          _NavTile(
            icon: Icons.mark_email_read,
            title: 'Eingangsrechnungen',
            subtitle: 'Lieferantenrechnungen erfassen & buchen',
            onTap: () => context.push('/buchhaltung/eingangsrechnungen'),
          ),
          _NavTile(
            icon: Icons.receipt_long,
            title: 'Forderungen',
            subtitle: 'Rechnungen, Mahnwesen & Debitoren',
            onTap: () => context.push('/rechnungen'),
          ),
          _NavTile(
            icon: Icons.receipt_long_outlined,
            title: 'Heineken Rechnungen',
            subtitle: 'Heineken-Monatsrechnungen erstellen',
            onTap: () => context.push('/heineken'),
          ),
          _NavTile(
            icon: Icons.payments,
            title: 'Lohnbuchhaltung',
            subtitle: 'Lohnlauf, Abzüge & Lohnausweis',
            onTap: () => context.push('/buchhaltung/lohn'),
          ),

          const SizedBox(height: 16),
          Text(
            'Abschluss & Berichte',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.account_tree,
            title: 'Kontenplan',
            subtitle: '61 Konten nach Schweizer KMU-Standard',
            onTap: () => context.push('/buchhaltung/konten'),
          ),
          _NavTile(
            icon: Icons.menu_book,
            title: 'Journal',
            subtitle: 'Alle Buchungen anzeigen',
            onTap: () => context.push('/buchhaltung/buchungen'),
          ),
          _NavTile(
            icon: Icons.assessment,
            title: 'Bilanz & Erfolgsrechnung',
            subtitle: 'Bilanz & Erfolgsrechnung per Datum',
            onTap: () => context.push('/buchhaltung/berichte'),
          ),
          _NavTile(
            icon: Icons.insights,
            title: 'Auswertung',
            subtitle: 'Umsatz & Arbeiten nach Jahr/Monat',
            onTap: () => context.push('/buchhaltung/auswertung'),
          ),
          // Aus dem Hauptmenü hierher (A6, v0.112.0): Die Arbeitstage-
          // Auswertung gehört neben die Umsatz-Auswertung, nicht auf die
          // Werkstatt-Startseite.
          _NavTile(
            icon: Icons.query_stats,
            title: 'Auswertung Arbeitstage',
            subtitle: 'Arbeitszeit, Fahrten und Einsätze pro Tag',
            onTap: () => context.push('/auswertungen/arbeitstage'),
          ),
          _NavTile(
            icon: Icons.account_balance,
            title: 'MwSt-Abrechnung',
            subtitle: 'Quartals-Abrechnung ESTV',
            onTap: () => context.push('/buchhaltung/mwst'),
          ),
          _NavTile(
            icon: Icons.event_available,
            title: 'Monatsabschluss',
            subtitle: 'Zehn Punkte je Monat: Einsätze, Heineken, Bank, Lohn',
            onTap: () => context.push('/buchhaltung/monatsabschluss'),
          ),
          _NavTile(
            icon: Icons.fact_check,
            title: 'Abschlussprüfung',
            subtitle: 'Jahres-Check: Bank, MWST, Debitoren, Steuern',
            onTap: () => context.push('/buchhaltung/audit'),
          ),
          _NavTile(
            icon: Icons.gavel,
            title: 'Steuern',
            subtitle: 'Veranlagungen, Zahlungen, Unterlagen',
            onTap: () => context.push('/buchhaltung/steuern'),
          ),
          _NavTile(
            icon: Icons.calendar_month,
            title: 'Jahresrechnungen',
            subtitle: 'Sammelrechnungen pro Betrieb erstellen',
            onTap: () => context.push('/jahresrechnung'),
          ),

          const SizedBox(height: 24),

          // Letzte Buchungen
          Text(
            'Letzte Buchungen',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (buchungen.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Noch keine Buchungen vorhanden',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            )
          else
            ...(List.of(buchungen)..sort((a, b) {
                  final cmp = b.datum.compareTo(a.datum);
                  if (cmp != 0) return cmp;
                  final catA = a.createdAt ?? a.datum;
                  final catB = b.createdAt ?? b.datum;
                  return catB.compareTo(catA);
                }))
                .take(5)
                .map(
                  (b) => Card(
                    // CanvasKit: InkWell + Container + Row statt ListTile
                    // (CLAUDE.md, gleiche Begründung wie bei _NavTile).
                    child: InkWell(
                      onTap: () =>
                          context.push('/buchhaltung/buchungen/${b.id}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: b.istStorniert
                                    ? AppColors.error.withAlpha(25)
                                    : AppColors.primary.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                b.istStorniert
                                    ? Icons.cancel
                                    : Icons.swap_horiz,
                                size: 18,
                                color: b.istStorniert
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.beschreibung,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      decoration: b.istStorniert
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_formatDateTime(b)} · ${b.sollKonto} → ${b.habenKonto}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${b.betragBrutto.toStringAsFixed(2)} CHF',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: b.istStorniert ? AppColors.error : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  static double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  static String _monatName(int m) {
    const namen = [
      '',
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    return namen[m];
  }

  static String _formatDateTime(Buchung b) {
    final d = b.datum;
    final date =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    final c = b.createdAt;
    if (c != null) {
      final time =
          '${c.hour.toString().padLeft(2, '0')}:${c.minute.toString().padLeft(2, '0')}';
      return '$date $time';
    }
    return date;
  }
}

class _KennzahlCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KennzahlCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ein Ziel der Büro-Startseite.
///
/// CanvasKit: `InkWell` + `Container` + `Row` statt `ListTile` — es sind 13
/// Navigationsziele, und Material-Komfort-Widgets haben auf dem produktiven
/// CanvasKit-Web dreimal nicht gerendert oder nicht reagiert (CLAUDE.md).
/// Das Aussehen bleibt: Kreis-Symbol, Titel, Untertitel, Pfeil.
///
/// Steht bewusst als letzte Klasse in der Datei: Der Gruppen-Wächter
/// (`buchhaltung_gruppen_waechter_test.dart`) teilt die Datei am Text
/// `_NavTile(`, das auch im eigenen Konstruktor dieser Klasse auftaucht —
/// stünde danach noch eine Klasse mit einem `context.push(...)`, würde der
/// Wächter dessen Ziel-Route fälschlich als 14. Navigationsziel zählen.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
