import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/services/rechnung/mahnwesen_service.dart';
import 'package:sbs_projer_app/services/buchhaltung/zahlungsdifferenz_service.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart' show betriebNameMapProvider;

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

const _statusReihenfolge = [
  'mahnung_2', 'mahnung_1', 'erinnert', 'offen', 'bezahlt', 'abgeschrieben',
];

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
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

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
      if (_statusFilter != 'alle' && r.zahlungsstatus != _statusFilter) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode
            ? '${_selectedIds.length} ausgewählt'
            : 'Rechnungen'),
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectMode = false;
                  _selectedIds.clear();
                }),
              )
            : null,
        actions: [
          if (!_selectMode)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Sammelzahlung',
              onPressed: () => setState(() => _selectMode = true),
            ),
          if (!_selectMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Status-Filter',
              onSelected: (value) => setState(() => _statusFilter = value),
              itemBuilder: (context) => [
                _filterItem('alle', 'Alle'),
                const PopupMenuDivider(),
                _filterItem('offen', 'Offen'),
                _filterItem('erinnert', 'Erinnert'),
                _filterItem('mahnung_1', 'Mahnung 1'),
                _filterItem('mahnung_2', 'Mahnung 2'),
                const PopupMenuDivider(),
                _filterItem('bezahlt', 'Bezahlt'),
                _filterItem('abgeschrieben', 'Abgeschrieben'),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
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
          // Summary Card
          if (_statusFilter == 'alle' || _statusFilter == 'offen' ||
              _statusFilter == 'erinnert' || _statusFilter == 'mahnung_1' ||
              _statusFilter == 'mahnung_2')
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                DropdownButton<int>(
                  value: _selectedYear,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                  items: jahre
                      .map((y) =>
                          DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (y) {
                    if (y != null) setState(() => _selectedYear = y);
                  },
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedMonth,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                  items: [
                    const DropdownMenuItem(
                        value: 0, child: Text('Alle Monate')),
                    for (int m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text(_monatNamen[m])),
                  ],
                  onChanged: (m) {
                    if (m != null) setState(() => _selectedMonth = m);
                  },
                ),
                const Spacer(),
                Text(
                  jahrSumme > 0
                      ? '${filtered.length} – ${jahrSumme.toStringAsFixed(2)} CHF'
                      : '${filtered.length} Rechnungen',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (_statusFilter != 'alle')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    label: Text(_statusLabel(_statusFilter)),
                    onDeleted: () =>
                        setState(() => _statusFilter = 'alle'),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
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
                      final isOffen = entry.zahlungsstatus != 'bezahlt' &&
                          entry.zahlungsstatus != 'abgeschrieben';
                      if (_selectMode) {
                        return _RechnungSelectItem(
                          rechnung: entry,
                          betriebName: entry.betriebId != null
                              ? betriebNames[entry.betriebId]
                              : null,
                          enabled: isOffen,
                          selected: _selectedIds.contains(entry.id),
                          onChanged: isOffen
                              ? (v) => setState(() {
                                    if (v == true) {
                                      _selectedIds.add(entry.id);
                                    } else {
                                      _selectedIds.remove(entry.id);
                                    }
                                  })
                              : null,
                        );
                      }
                      return _RechnungListItem(
                        rechnung: entry,
                        betriebName: entry.betriebId != null
                            ? betriebNames[entry.betriebId]
                            : null,
                        onTap: () =>
                            context.push('/rechnungen/${entry.id}'),
                        onStatusChange: () => _showStatusDialog(entry),
                      );
                    },
                  ),
          ),
          if (_selectMode && _selectedIds.isNotEmpty)
            _buildSammelzahlungBar(rechnungen),
        ],
      ),
    );
  }

  Widget _buildSammelzahlungBar(List<Rechnung> alleRechnungen) {
    final selected = alleRechnungen
        .where((r) => _selectedIds.contains(r.id))
        .toList();
    final summe = selected.fold(
        0.0, (sum, r) => sum + ((r.betragBrutto * 20).roundToDouble() / 20));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${selected.length} Rechnungen',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'Total: CHF ${summe.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.payments, size: 18),
              label: const Text('Sammelzahlung'),
              onPressed: () => _showSammelzahlungDialog(selected, summe),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSammelzahlungDialog(
      List<Rechnung> selected, double summe) async {
    final controller =
        TextEditingController(text: summe.toStringAsFixed(2));

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final eingabe =
                double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
            final differenz =
                ((eingabe - summe) * 20).roundToDouble() / 20;

            return AlertDialog(
              title: const Text('Sammelzahlung'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${selected.length} Rechnungen ausgewählt',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...selected.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.rechnungsnummer ?? 'Entwurf',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                'CHF ${((r.betragBrutto * 20).roundToDouble() / 20).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        )),
                    const Divider(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Rechnungstotal',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          'CHF ${summe.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Eingegangener Betrag (CHF)',
                        prefixText: 'CHF ',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (differenz.abs() >= 0.01) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: differenz < 0
                              ? AppColors.warning.withAlpha(25)
                              : AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: differenz < 0
                                ? AppColors.warning.withAlpha(80)
                                : AppColors.success.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              differenz < 0
                                  ? Icons.trending_down
                                  : Icons.trending_up,
                              size: 18,
                              color: differenz < 0
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                differenz < 0
                                    ? 'Unterzahlung: CHF ${differenz.abs().toStringAsFixed(2)}\n'
                                      'Wird als Debitorenverlust (3805) gebucht'
                                    : 'Mehrzahlung: CHF ${differenz.toStringAsFixed(2)}\n'
                                      'Wird als a.o. Ertrag (8000) gebucht',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: differenz < 0
                                      ? AppColors.warning
                                      : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed:
                      eingabe > 0 ? () => Navigator.pop(ctx, eingabe) : null,
                  child: const Text('Alle bezahlt'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    final zahlungBetrag = (result * 20).roundToDouble() / 20;

    try {
      final datumStr = DateTime.now().toIso8601String().split('T').first;
      for (final r in selected) {
        final brutto = (r.betragBrutto * 20).roundToDouble() / 20;
        await RechnungRepository.update(r.id, {
          'zahlungsstatus': 'bezahlt',
          'zahlung_eingegangen_am': datumStr,
          'zahlung_betrag': brutto,
        });
      }

      await ZahlungsdifferenzService.verbuchenSammel(
        rechnungen: selected,
        zahlungBetrag: zahlungBetrag,
      );

      if (mounted) {
        ref.invalidate(rechnungenStreamProvider);
        ref.invalidate(buchungenStreamProvider);
        setState(() {
          _selectMode = false;
          _selectedIds.clear();
        });

        final differenz = ((zahlungBetrag - summe) * 20).roundToDouble() / 20;
        String snackText =
            '${selected.length} Rechnungen als bezahlt markiert';
        if (differenz.abs() >= 0.01) {
          snackText += differenz < 0
              ? ' (CHF ${differenz.abs().toStringAsFixed(2)} Debitorenverlust)'
              : ' (CHF ${differenz.toStringAsFixed(2)} Mehrzahlung)';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snackText)),
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
        ref.invalidate(mahnwesenDashboardProvider);
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
        ref.invalidate(mahnwesenDashboardProvider);
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

  PopupMenuItem<String> _filterItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_statusFilter == value)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
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
  final VoidCallback onTap;
  final VoidCallback onStatusChange;

  const _RechnungListItem({
    required this.rechnung,
    this.betriebName,
    required this.onTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(rechnung.zahlungsstatus);
    final naechster = _naechsterStatus(rechnung.zahlungsstatus);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(25),
          child: Icon(Icons.receipt_long, color: color, size: 20),
        ),
        title: Text(
          rechnung.rechnungsnummer ?? 'Entwurf',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(_buildSubtitle()),
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
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _RechnungSelectItem extends StatelessWidget {
  final Rechnung rechnung;
  final String? betriebName;
  final bool enabled;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  const _RechnungSelectItem({
    required this.rechnung,
    this.betriebName,
    required this.enabled,
    required this.selected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(rechnung.zahlungsstatus);
    final brutto = (rechnung.betragBrutto * 20).roundToDouble() / 20;
    return Card(
      child: CheckboxListTile(
        value: selected,
        onChanged: onChanged,
        enabled: enabled,
        secondary: CircleAvatar(
          backgroundColor: color.withAlpha(25),
          child: Icon(Icons.receipt_long, color: color, size: 20),
        ),
        title: Text(
          rechnung.rechnungsnummer ?? 'Entwurf',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: enabled ? null : AppColors.textSecondary,
          ),
        ),
        subtitle: Text(
          [
            if (betriebName != null) betriebName!,
            'CHF ${brutto.toStringAsFixed(2)}',
          ].join(' · '),
          style: TextStyle(
            color: enabled ? null : AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
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
