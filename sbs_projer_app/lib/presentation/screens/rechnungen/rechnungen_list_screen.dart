import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/rechnung_versand_status.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/services/rechnung/mahnwesen_service.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart' show betriebNameMapProvider;
import 'package:sbs_projer_app/services/rechnung/forderung_service.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/widgets/debitoren_header.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_jahr_monat_leiste.dart';

const _monatNamen = [
  '', 'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

String _statusLabel(String status) {
  switch (status) {
    case 'offen': return 'Offen';
    case 'bezahlt': return 'Bezahlt';
    case 'erinnert': return 'Erinnert';
    case 'mahnung_1': return 'Mahnung 1';
    case 'mahnung_2': return 'Mahnung 2';
    case 'abgeschrieben': return 'Abgeschrieben';
    case 'mahnfaellig': return 'Mahnfällig';
    default: return status;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'offen': return AppColors.warning;
    case 'bezahlt': return AppColors.success;
    case 'erinnert': return const Color(0xFFE65100);
    case 'mahnung_1': return AppColors.error;
    case 'mahnung_2': return const Color(0xFF8B0000);
    case 'abgeschrieben': return AppColors.inaktiv;
    default: return AppColors.textSecondary;
  }
}

String? _naechsterStatus(String current) {
  switch (current) {
    case 'offen': return 'erinnert';
    case 'erinnert': return 'mahnung_1';
    case 'mahnung_1': return 'mahnung_2';
    case 'mahnung_2': return 'abgeschrieben';
    default: return null;
  }
}

class RechnungenListScreen extends ConsumerStatefulWidget {
  const RechnungenListScreen({super.key});

  @override
  ConsumerState<RechnungenListScreen> createState() =>
      _RechnungenListScreenState();
}

class _RechnungenListScreenState extends ConsumerState<RechnungenListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'alle';
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = 0;

  @override
  Widget build(BuildContext context) {
    final rechnungen = ref.watch(rechnungenProvider);
    final betriebNames = ref.watch(betriebNameMapProvider);

    // Verfügbare Jahre
    final jahreSet = <int>{};
    for (final r in rechnungen) {
      jahreSet.add(r.rechnungsdatum.year);
    }
    final jahre = jahreSet.toList()..sort((a, b) => b.compareTo(a));
    if (jahre.isEmpty) jahre.add(DateTime.now().year);
    if (!jahre.contains(_selectedYear)) _selectedYear = jahre.first;

    final sorted = List<Rechnung>.from(rechnungen)
      ..sort((a, b) => b.rechnungsdatum.compareTo(a.rechnungsdatum));

    final filtered = sorted.where((r) {
      if (r.rechnungsdatum.year != _selectedYear) return false;
      if (_selectedMonth != 0 && r.rechnungsdatum.month != _selectedMonth) {
        return false;
      }
      if (_statusFilter == 'nicht_versendet') {
        if (!rechnungNichtVersendet(r)) return false;
      } else if (_statusFilter == 'mahnfaellig') {
        if (!ForderungService.istMahnfaellig(r)) return false;
      } else if (_statusFilter != 'alle' && r.zahlungsstatus != _statusFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final betriebName =
            (r.betriebId != null ? betriebNames[r.betriebId] : null)
                    ?.toLowerCase() ??
                '';
        return betriebName.contains(query) ||
            (r.rechnungsnummer?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Monats- und Tagesgruppierung
    final groups = <_MonatsGruppe>[];
    for (final r in filtered) {
      final m = r.rechnungsdatum.month;
      final d = DateTime(
          r.rechnungsdatum.year, r.rechnungsdatum.month, r.rechnungsdatum.day);
      if (groups.isEmpty || groups.last.monat != m) {
        groups.add(_MonatsGruppe(jahr: r.rechnungsdatum.year, monat: m));
      }
      final g = groups.last;
      if (g.tage.isEmpty || g.tage.last.datum != d) {
        g.tage.add(_TagesGruppe(datum: d));
      }
      g.tage.last.eintraege.add(r);
    }

    final jahrSumme =
        filtered.fold(0.0, (sum, r) => sum + r.betragBrutto);

    // Summary für offene Rechnungen
    final offene = rechnungen.where(
        (r) => r.zahlungsstatus != 'bezahlt' && r.zahlungsstatus != 'abgeschrieben');
    final offenSumme = offene.fold(0.0, (sum, r) => sum + r.betragBrutto);
    final ueberfaellige = offene.where(
        (r) => r.faelligkeitsdatum.isBefore(DateTime.now())).length;

    // Erzeugt, aber nie versendet (Versand fehlgeschlagen) — über alle Jahre.
    final nichtVersendetCount = rechnungen.where(rechnungNichtVersendet).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forderungen'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DebitorenHeader(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Rechnung suchen...',
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search, size: 20),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Status-Filter (einheitliche Filter-Leiste statt AppBar-Popup)
          AppFilterBar(
            items: [
              AppFilterDropdown<String>(
                hint: 'Alle Status',
                nullable: false,
                value: _statusFilter,
                options: [
                  const ('alle', 'Alle Status'),
                  const ('mahnfaellig', 'Mahnfällig'),
                  (
                    'nicht_versendet',
                    nichtVersendetCount > 0
                        ? 'Nicht versendet ($nichtVersendetCount)'
                        : 'Nicht versendet'
                  ),
                  const ('offen', 'Offen'),
                  const ('erinnert', 'Erinnert'),
                  const ('mahnung_1', 'Mahnung 1'),
                  const ('mahnung_2', 'Mahnung 2'),
                  const ('bezahlt', 'Bezahlt'),
                  const ('abgeschrieben', 'Abgeschrieben'),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'alle'),
              ),
            ],
          ),
          // Frühwarnung: erzeugte, aber nicht versendete Mail-/Post-Rechnungen
          if (nichtVersendetCount > 0 && _statusFilter != 'nicht_versendet')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () => setState(() => _statusFilter = 'nicht_versendet'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_unread,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$nichtVersendetCount Rechnung(en) erstellt, aber nicht versendet — antippen zum Anzeigen.',
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.error, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          // Summary Card
          if (_statusFilter == 'alle' || _statusFilter == 'offen' ||
              _statusFilter == 'erinnert' || _statusFilter == 'mahnung_1' ||
              _statusFilter == 'mahnung_2' || _statusFilter == 'mahnfaellig')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${offenSumme.toStringAsFixed(2)} CHF',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${offene.length} offene Rechnungen',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (ueberfaellige > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$ueberfaellige',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                              Text(
                                'Überfällig',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          AppJahrMonatLeiste(
            jahre: jahre,
            selectedJahr: _selectedYear,
            onJahrChanged: (y) => setState(() => _selectedYear = y),
            selectedMonat: _selectedMonth,
            onMonatChanged: (m) => setState(() => _selectedMonth = m),
            trailing: Text(
              jahrSumme > 0
                  ? '${filtered.length} – ${jahrSumme.toStringAsFixed(2)} CHF'
                  : '${filtered.length} Rechnungen',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    itemCount: _listItemCount(groups),
                    itemBuilder: (context, index) {
                      final item = _listItemAt(groups, index);
                      if (item is _MonatsGruppe) {
                        return _buildMonatsHeader(context, item);
                      }
                      if (item is _TagesGruppe) {
                        return _buildTagesHeader(context, item);
                      }
                      final entry = item as Rechnung;
                      return _RechnungListItem(
                        rechnung: entry,
                        betriebName: entry.betriebId != null
                            ? betriebNames[entry.betriebId]
                            : null,
                        aktionLabel: _statusFilter == 'mahnfaellig'
                            ? ForderungService.empfohleneAktion(entry)
                            : null,
                        onTap: () =>
                            context.push('/rechnungen/${entry.id}'),
                        onStatusChange: () => _showStatusDialog(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStatusDialog(Rechnung rechnung) async {
    final naechster = _naechsterStatus(rechnung.zahlungsstatus);
    if (naechster == null) return;

    // Für Mahnwesen-Eskalation (erinnert, mahnung_1, mahnung_2)
    if (naechster == 'erinnert' || naechster == 'mahnung_1' || naechster == 'mahnung_2') {
      final stufe = naechster == 'erinnert' ? 0 : naechster == 'mahnung_1' ? 1 : 2;
      final titel = MahnwesenService.titelFuerStufe(stufe);
      final hatEmail = rechnung.versandart == 'rechnung_mail';
      bool? mailSenden = false;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          bool mail = hatEmail;
          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: Text('$titel erstellen?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rechnung.rechnungsnummer ?? 'Rechnung'),
                  const SizedBox(height: 12),
                  const Text('Ein PDF wird generiert und hochgeladen.'),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: mail,
                    onChanged: (v) => setDialogState(() => mail = v ?? false),
                    title: Text(
                      hatEmail ? 'Per E-Mail senden' : 'Per E-Mail senden (keine E-Mail)',
                      style: TextStyle(
                        fontSize: 14,
                        color: hatEmail ? null : AppColors.textSecondary,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () {
                    mailSenden = mail;
                    Navigator.pop(ctx, true);
                  },
                  child: Text('$titel erstellen'),
                ),
              ],
            ),
          );
        },
      );

      if (confirmed != true) return;
      try {
        await MahnwesenService.eskalieren(
          rechnung: rechnung,
          mahnStufe: stufe,
          mailSenden: mailSenden ?? false,
        );
        ref.invalidate(rechnungenStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              '$titel für ${rechnung.rechnungsnummer} erstellt${mailSenden == true ? ' & versendet' : ''}',
            )),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
      return;
    }

    // Für Abschreiben
    if (naechster == 'abgeschrieben') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechnung abschreiben?'),
          content: Text(
            '${rechnung.rechnungsnummer ?? "Rechnung"}\n\n'
            'Eine Buchung auf Konto 3805 (Debitorenverlust) wird erstellt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abschreiben'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await MahnwesenService.abschreiben(rechnung);
        ref.invalidate(rechnungenStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${rechnung.rechnungsnummer} abgeschrieben')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
      return;
    }

    // Einfacher Status-Wechsel (fallback)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Status ändern?'),
        content: Text(
          '${rechnung.rechnungsnummer ?? "Rechnung"}\n\n'
          '${_statusLabel(rechnung.zahlungsstatus)} → ${_statusLabel(naechster)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_statusLabel(naechster)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RechnungRepository.update(rechnung.id, {
          'zahlungsstatus': naechster,
        });
        ref.invalidate(rechnungenStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              '${rechnung.rechnungsnummer}: ${_statusLabel(naechster)}',
            )),
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
  }

  int _listItemCount(List<_MonatsGruppe> groups) {
    int count = 0;
    for (final g in groups) {
      count++;
      for (final t in g.tage) {
        count += 1 + t.eintraege.length;
      }
    }
    return count;
  }

  Object _listItemAt(List<_MonatsGruppe> groups, int index) {
    int pos = 0;
    for (final g in groups) {
      if (index == pos) return g;
      pos++;
      for (final t in g.tage) {
        if (index == pos) return t;
        pos++;
        if (index < pos + t.eintraege.length) {
          return t.eintraege[index - pos];
        }
        pos += t.eintraege.length;
      }
    }
    return groups.last;
  }

  Widget _buildMonatsHeader(BuildContext context, _MonatsGruppe gruppe) {
    final count =
        gruppe.tage.fold(0, (sum, t) => sum + t.eintraege.length);
    final summe = gruppe.tage.fold(
        0.0,
        (sum, t) =>
            sum + t.eintraege.fold(0.0, (s, r) => s + r.betragBrutto));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_monatNamen[gruppe.monat]} ${gruppe.jahr}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          Text('$count St.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          if (summe > 0) ...[
            const SizedBox(width: 8),
            Text('${summe.toStringAsFixed(2)} CHF',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    )),
          ],
        ],
      ),
    );
  }

  Widget _buildTagesHeader(BuildContext context, _TagesGruppe gruppe) {
    final count = gruppe.eintraege.length;
    final summe =
        gruppe.eintraege.fold(0.0, (sum, r) => sum + r.betragBrutto);
    final tag =
        '${gruppe.datum.day.toString().padLeft(2, '0')}.${gruppe.datum.month.toString().padLeft(2, '0')}';
    const wt = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: Text('${wt[gruppe.datum.weekday - 1]} $tag',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    )),
          ),
          Text('$count St.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary, fontSize: 11)),
          if (summe > 0) ...[
            const SizedBox(width: 6),
            Text('${summe.toStringAsFixed(2)} CHF',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    )),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 64, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Keine Ergebnisse'
                : 'Noch keine Rechnungen',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Versuche einen anderen Suchbegriff'
                : 'Rechnungen werden automatisch bei Reinigungsabschluss erstellt',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _MonatsGruppe {
  final int jahr;
  final int monat;
  final List<_TagesGruppe> tage = [];
  _MonatsGruppe({required this.jahr, required this.monat});
}

class _TagesGruppe {
  final DateTime datum;
  final List<Rechnung> eintraege = [];
  _TagesGruppe({required this.datum});
}

class _RechnungListItem extends StatelessWidget {
  final Rechnung rechnung;
  final String? betriebName;
  final String? aktionLabel;
  final VoidCallback onTap;
  final VoidCallback onStatusChange;

  const _RechnungListItem({
    required this.rechnung,
    this.betriebName,
    this.aktionLabel,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(rechnung.zahlungsstatus);
    final naechster = _naechsterStatus(rechnung.zahlungsstatus);
    final nichtVersendet = rechnungNichtVersendet(rechnung);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (nichtVersendet ? AppColors.error : color).withAlpha(25),
          child: Icon(
            nichtVersendet ? Icons.mark_email_unread : Icons.receipt_long,
            color: nichtVersendet ? AppColors.error : color,
            size: 20,
          ),
        ),
        title: Text(
          rechnung.rechnungsnummer ?? 'Entwurf',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_buildSubtitle()),
            if (nichtVersendet)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  '⚠ Nicht versendet',
                  style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (naechster != null && rechnung.rechnungstyp != 'heineken_monat')
              IconButton(
                icon: Icon(
                  _statusUpIcon(rechnung.zahlungsstatus),
                  size: 18,
                  color: _statusColor(naechster),
                ),
                tooltip: _statusLabel(naechster),
                onPressed: onStatusChange,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
              ),
            _StatusChip(status: rechnung.zahlungsstatus),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _statusUpIcon(String status) {
    switch (status) {
      case 'offen': return Icons.notifications;
      case 'erinnert': return Icons.warning_amber;
      case 'mahnung_1': return Icons.gavel;
      case 'mahnung_2': return Icons.block;
      default: return Icons.arrow_forward;
    }
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (betriebName != null) parts.add(betriebName!);
    parts.add(_formatDate(rechnung.rechnungsdatum));
    final brutto = (rechnung.betragBrutto * 20).roundToDouble() / 20;
    parts.add('CHF ${brutto.toStringAsFixed(2)}');
    if (aktionLabel != null && aktionLabel != 'warten') {
      parts.add(_aktionText(aktionLabel!));
    }
    return parts.join(' · ');
  }

  String _aktionText(String aktion) {
    switch (aktion) {
      case 'erinnerung_faellig': return 'Erinnerung fällig';
      case 'mahnung_1_faellig': return 'Mahnung 1 fällig';
      case 'mahnung_2_faellig': return 'Mahnung 2 fällig';
      case 'eskalation': return 'Eskalation';
      default: return aktion;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
