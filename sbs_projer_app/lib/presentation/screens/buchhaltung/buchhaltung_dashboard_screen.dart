import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/camt_abgleich_providers.dart';

class BuchhaltungDashboardScreen extends ConsumerWidget {
  const BuchhaltungDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final buchungen = ref.watch(buchungenProvider);
    final erfolgsrechnung = ref.watch(erfolgsrechnungProvider(now.year));
    final mwst = ref.watch(mwstAbrechnungProvider(now.year));
    final offeneCount = ref.watch(offeneRechnungenCountProvider);

    // Wochen-Erinnerung: letzte erfasste camt-Periode
    final letzteCamtPeriode = ref.watch(letzteCamtPeriodeProvider).valueOrNull;
    final camtErinnerung = letzteCamtPeriode == null ||
        DateTime.now().difference(letzteCamtPeriode).inDays > 7;

    // Buchungen aktueller Monat
    final buchungenMonat = buchungen.where((b) =>
        b.geschaeftsjahr == now.year && b.monat == now.month).toList();

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
          // Wochen-Erinnerung: neuen camt-Auszug hochladen
          if (camtErinnerung)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upload_file, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(letzteCamtPeriode == null
                        ? 'Noch kein Bankauszug erfasst — camt-Datei hochladen'
                        : 'Letzter Auszug bis ${_fmt(letzteCamtPeriode)} — neuen camt-Auszug hochladen'),
                  ),
                  TextButton(
                    onPressed: () => context.push('/buchhaltung/camt-import'),
                    child: const Text('Hochladen'),
                  ),
                ],
              ),
            ),
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

          const SizedBox(height: 24),

          // Navigation
          Text(
            'Bereiche',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
            icon: Icons.account_balance,
            title: 'MwSt-Abrechnung',
            subtitle: 'Quartals-Abrechnung ESTV',
            onTap: () => context.push('/buchhaltung/mwst'),
          ),
          _NavTile(
            icon: Icons.fact_check,
            title: 'Audit',
            subtitle: 'Verdächtige Buchungen & Salden',
            onTap: () => context.push('/buchhaltung/audit'),
          ),
          _NavTile(
            icon: Icons.receipt_long,
            title: 'Forderungen',
            subtitle: 'Rechnungen, Mahnwesen & Debitoren',
            onTap: () => context.push('/rechnungen'),
          ),
          _NavTile(
            icon: Icons.mark_email_read,
            title: 'Eingangsrechnungen',
            subtitle: 'Lieferantenrechnungen erfassen & buchen',
            onTap: () => context.push('/buchhaltung/eingangsrechnungen'),
          ),
          _NavTile(
            icon: Icons.account_balance,
            title: 'Bankauszug Import',
            subtitle: 'camt.053 Transaktionen importieren',
            onTap: () => context.push('/buchhaltung/camt-import'),
          ),
          _NavTile(
            icon: Icons.fact_check,
            title: 'camt-Prüfliste',
            subtitle: 'Nicht verbuchte Transaktionen prüfen',
            onTap: () => context.push('/buchhaltung/camt-pruefliste'),
          ),
          _NavTile(
            icon: Icons.rule,
            title: 'camt-Regeln',
            subtitle: 'Automatische Zuordnungsregeln verwalten',
            onTap: () => context.push('/buchhaltung/camt-regeln'),
          ),
          _NavTile(
            icon: Icons.folder_open,
            title: 'camt-Dateien',
            subtitle: 'Hochgeladene Bankauszüge verwalten',
            onTap: () => context.push('/buchhaltung/camt-dateien'),
          ),
          _NavTile(
            icon: Icons.payments,
            title: 'Lohnbuchhaltung',
            subtitle: 'Lohnlauf, Abzüge & Lohnausweis',
            onTap: () => context.push('/buchhaltung/lohn'),
          ),
          _NavTile(
            icon: Icons.receipt_long_outlined,
            title: 'Heineken Rechnungen',
            subtitle: 'Heineken-Monatsrechnungen erstellen',
            onTap: () => context.push('/heineken'),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
            ...(List.of(buchungen)
              ..sort((a, b) {
                final cmp = b.datum.compareTo(a.datum);
                if (cmp != 0) return cmp;
                final catA = a.createdAt ?? a.datum;
                final catB = b.createdAt ?? b.datum;
                return catB.compareTo(catA);
              })).take(5).map((b) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: b.istStorniert
                          ? AppColors.error.withAlpha(25)
                          : AppColors.primary.withAlpha(25),
                      radius: 18,
                      child: Icon(
                        b.istStorniert ? Icons.cancel : Icons.swap_horiz,
                        size: 18,
                        color: b.istStorniert ? AppColors.error : AppColors.primary,
                      ),
                    ),
                    title: Text(
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
                    subtitle: Text(
                      '${_formatDateTime(b)} · ${b.sollKonto} → ${b.habenKonto}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      '${b.betragBrutto.toStringAsFixed(2)} CHF',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: b.istStorniert ? AppColors.error : null,
                      ),
                    ),
                    onTap: () => context.push('/buchhaltung/buchungen/${b.id}'),
                  ),
                )),
        ],
      ),
    );
  }

  static double _d(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0;

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _monatName(int m) {
    const namen = [
      '', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
    ];
    return namen[m];
  }

  static String _formatDateTime(Buchung b) {
    final d = b.datum;
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    final c = b.createdAt;
    if (c != null) {
      final time = '${c.hour.toString().padLeft(2, '0')}:${c.minute.toString().padLeft(2, '0')}';
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
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(25),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
