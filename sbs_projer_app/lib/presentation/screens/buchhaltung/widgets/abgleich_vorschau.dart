import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/data/models/camt_transaction.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/providers/buchung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/widgets/auto_match_tile.dart';
import 'package:sbs_projer_app/services/camt/forderungs_abgleich_service.dart';
import 'package:sbs_projer_app/services/camt/zahlername.dart';

/// Wiederverwendbare Ergebnis-Vorschau für den camt-Forderungsabgleich:
/// Kopf-Übersicht (KPIs) + vier klappbare Gruppen (🟢 Auto / 🟡 Manuell /
/// ⚪ Nicht zugeordnet / 🔴 Keine Zahlung) inkl. aller Verbuchungs- und
/// Zuordnungs-Dialoge. Eingebettet sowohl im Standalone-Abgleich-Screen als
/// auch (später) im Import-Screen.
///
/// Das übergebene [ergebnis] wird beim Verbuchen in-place mutiert (gewollt),
/// ebenso der [alleOffenen]-Pool für die ⚪-Zuordnung.
class AbgleichVorschau extends ConsumerStatefulWidget {
  final AbgleichErgebnis ergebnis; // wird beim Verbuchen in-place mutiert
  final List<Rechnung> alleOffenen; // Pool für die ⚪-Zuordnung
  final Map<String, String> betriebName; // id → Name
  final EdgeInsets padding;

  const AbgleichVorschau({
    super.key,
    required this.ergebnis,
    required this.alleOffenen,
    required this.betriebName,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  });

  @override
  ConsumerState<AbgleichVorschau> createState() => _AbgleichVorschauState();
}

class _AbgleichVorschauState extends ConsumerState<AbgleichVorschau> {
  final _dateFormat = DateFormat('dd.MM.yyyy');

  // Max. gerenderte Zeilen pro Gruppe (verhindert die 1000-Zeilen-Wand).
  static const _maxZeilen = 50;

  @override
  Widget build(BuildContext context) {
    final erg = widget.ergebnis;
    final autoSumme = erg.auto.fold<double>(0, (s, t) => s + t.gutschrift.amount);
    final offenSumme = erg.keineZahlung.fold<double>(0, (s, r) => s + r.betragBrutto);
    final unbekanntSumme =
        erg.unbekannteGutschriften.fold<double>(0, (s, g) => s + g.amount);
    return ListView(
      padding: widget.padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _uebersicht(erg, autoSumme, offenSumme, unbekanntSumme),

        // 🟢 Auto-gematcht
        _GruppeCard(
          emoji: '🟢',
          titel: 'Auto-gematcht',
          anzahl: erg.auto.length,
          summe: erg.auto.isEmpty ? null : autoSumme,
          farbe: AppColors.success,
          initiallyExpanded: true,
          children: [
            if (erg.auto.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _verbucheAlle,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Alle verbuchen'),
                  ),
                ),
              ),
            for (final t in erg.auto) _autoZeile(t),
          ],
        ),

        // 🟡 Manuell zuordnen
        _GruppeCard(
          emoji: '🟡',
          titel: 'Manuell zuordnen',
          anzahl: erg.manuell.length,
          summe: null,
          farbe: AppColors.warning,
          initiallyExpanded: true,
          children: [
            for (final f in erg.manuell)
              ListTile(
                title: Text(f.betriebName),
                subtitle: Text(
                  '${f.gutschriften.length} Zahlung(en), '
                  '${f.forderungen.length} offene Forderung(en)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _oeffneManuell(f),
              ),
          ],
        ),

        // ⚪ Nicht zugeordnet (benannte Gutschriften ohne offene Forderung)
        _GruppeCard(
          emoji: '⚪',
          titel: 'Nicht zugeordnet',
          anzahl: erg.unbekannteGutschriften.length,
          summe: erg.unbekannteGutschriften.isEmpty ? null : unbekanntSumme,
          farbe: AppColors.textSecondary,
          initiallyExpanded: true,
          children: [
            for (final g in erg.unbekannteGutschriften)
              ListTile(
                title: Text('${g.amount.toStringAsFixed(2)} CHF — '
                    '${effektiverZahlername(partyName: g.partyName, additionalInfo: g.additionalInfo) ?? '?'}'),
                subtitle: Text(_dateFormat.format(g.bookingDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _ordneZu(g),
              ),
          ],
        ),

        // 🔴 Keine Zahlung gefunden (standardmäßig zugeklappt, Deckel 50 Zeilen)
        _GruppeCard(
          emoji: '🔴',
          titel: 'Keine Zahlung gefunden',
          anzahl: erg.keineZahlung.length,
          summe: erg.keineZahlung.isEmpty ? null : offenSumme,
          farbe: AppColors.error,
          initiallyExpanded: false,
          children: [
            for (final r in erg.keineZahlung.take(_maxZeilen))
              ListTile(
                dense: true,
                title: Text(
                  '${r.rechnungsnummer ?? '?'} — ${r.betragBrutto.toStringAsFixed(2)} CHF',
                ),
              ),
            if (erg.keineZahlung.length > _maxZeilen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  '… und ${erg.keineZahlung.length - _maxZeilen} weitere '
                  '(im Forderungen-Hub)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Kompakte Kopf-Übersicht: vier KPIs (umbrechend auf Smartphone).
  Widget _uebersicht(
    AbgleichErgebnis erg,
    double autoSumme,
    double offenSumme,
    double unbekanntSumme,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Kpi(
                  farbe: AppColors.success,
                  label: 'Auto',
                  anzahl: erg.auto.length,
                  sub: '${chf(autoSumme)} CHF',
                ),
                _Kpi(
                  farbe: AppColors.warning,
                  label: 'Manuell',
                  anzahl: erg.manuell.length,
                ),
                _Kpi(
                  farbe: AppColors.textSecondary,
                  label: 'Nicht zugeordnet',
                  anzahl: erg.unbekannteGutschriften.length,
                  sub: '${chf(unbekanntSumme)} CHF',
                ),
                _Kpi(
                  farbe: AppColors.error,
                  label: 'Keine Zahlung',
                  anzahl: erg.keineZahlung.length,
                  sub: '${chf(offenSumme)} CHF offen',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Baut die Beschreibung + delegiert an das getestete, responsive
  /// [AutoMatchTile] (Betrag/Beschreibung strikt einzeilig).
  Widget _autoZeile(AutoTreffer t) {
    final betrieb = widget.betriebName[t.forderungen.first.betriebId] ?? '';
    final rechnungen = t.forderungen.length == 1
        ? 'Rechnung ${t.forderungen.first.rechnungsnummer ?? '?'}'
        : '${t.forderungen.length} Rechnungen';
    final teile = [
      if (betrieb.isNotEmpty) betrieb,
      rechnungen,
      _dateFormat.format(t.gutschrift.bookingDate),
    ];
    return AutoMatchTile(
      betrag: '${t.gutschrift.amount.toStringAsFixed(2)} CHF',
      beschreibung: teile.join(' · '),
      onVerbuchen: () => _verbuche(t),
    );
  }

  /// Zusatz-Infos zu einer Gutschrift: Zahler-Name, Mitteilung, und bei
  /// Schalter-/Automaten-/Posteinzahlung der rohe Bank-Text (Ort/Datum/Zeit).
  /// Null, wenn keine über Betrag/Datum hinausgehende Info vorhanden ist.
  String? _zahlungInfo(CamtTransaction g) {
    final teile = <String>[];
    final name = effektiverZahlername(
        partyName: g.partyName, additionalInfo: g.additionalInfo);
    if (name != null) teile.add(name);
    final remit = g.remittanceInfo?.trim();
    if (remit != null && remit.isNotEmpty) teile.add(remit);
    // Kein Name extrahierbar (z.B. Schalter-/Automaten-/Posteinzahlung) →
    // rohen AddtlNtryInf-Text zeigen (enthält bei Automaten Ort/Datum/Zeit).
    if (name == null) {
      final addtl = g.additionalInfo?.trim();
      if (addtl != null && addtl.isNotEmpty) teile.add(addtl);
    }
    return teile.isEmpty ? null : teile.join(' · ');
  }

  /// Untertitel-Widget mit [_zahlungInfo] (oder null, wenn nichts vorhanden).
  Widget? _zahlungInfoText(CamtTransaction g) {
    final info = _zahlungInfo(g);
    if (info == null) return null;
    return Text(
      info,
      style: const TextStyle(fontSize: 12),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Future<void> _verbuche(AutoTreffer t) async {
    try {
      await ForderungsAbgleichService.verbuche(
        zahlbetrag: t.gutschrift.amount,
        datum: t.gutschrift.bookingDate,
        forderungen: t.forderungen,
        camtTxKey: t.gutschrift.txKey,
      );
      ref.invalidate(rechnungenStreamProvider);
      ref.invalidate(buchungenStreamProvider);
      if (!mounted) return;
      setState(() {
        widget.ergebnis.auto.remove(t);
        final gebuchteIds = t.forderungen.map((r) => r.id).toSet();
        widget.alleOffenen.removeWhere((r) => gebuchteIds.contains(r.id));
        widget.ergebnis.keineZahlung
            .removeWhere((r) => gebuchteIds.contains(r.id));
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Verbuchungs-Fehler: $e')));
      }
    }
  }

  Future<void> _verbucheAlle() async {
    final treffer = List<AutoTreffer>.from(widget.ergebnis.auto);
    final fehler = <String>[];
    final verbuchteTreffer = <AutoTreffer>[];
    for (final t in treffer) {
      try {
        await ForderungsAbgleichService.verbuche(
          zahlbetrag: t.gutschrift.amount,
          datum: t.gutschrift.bookingDate,
          forderungen: t.forderungen,
          camtTxKey: t.gutschrift.txKey,
        );
        verbuchteTreffer.add(t);
      } catch (e) {
        fehler.add('${t.gutschrift.amount.toStringAsFixed(2)} CHF: $e');
      }
    }
    ref.invalidate(rechnungenStreamProvider);
    ref.invalidate(buchungenStreamProvider);
    if (mounted) {
      setState(() {
        widget.ergebnis.auto.removeWhere((t) => verbuchteTreffer.contains(t));
        final gebuchteIds = verbuchteTreffer
            .expand((t) => t.forderungen)
            .map((r) => r.id)
            .toSet();
        widget.alleOffenen.removeWhere((r) => gebuchteIds.contains(r.id));
        widget.ergebnis.keineZahlung
            .removeWhere((r) => gebuchteIds.contains(r.id));
      });
      final verbucht = treffer.length - fehler.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fehler.isEmpty
            ? '$verbucht Zahlung(en) verbucht.'
            : '$verbucht verbucht, ${fehler.length} fehlgeschlagen: ${fehler.join('; ')}'),
      ));
    }
  }

  Future<void> _oeffneManuell(ManuellFall f) async {
    // Lokale Auswahl-Mengen für den Dialog (Sammelzahlung ↔ mehrere Forderungen).
    final gewaehlteGutschriften = <CamtTransaction>{};
    final gewaehlteForderungen = <Rechnung>{};

    final verbucht = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Live-Summen + 5-Rappen-gerundete Differenz.
            final zahlSumme =
                gewaehlteGutschriften.fold<double>(0, (s, g) => s + g.amount);
            final fordSumme = gewaehlteForderungen.fold<double>(
                0, (s, r) => s + r.betragBrutto);
            final diff = ((zahlSumme - fordSumme) * 20).roundToDouble() / 20;
            final kannVerbuchen = gewaehlteGutschriften.isNotEmpty &&
                gewaehlteForderungen.isNotEmpty;

            return AlertDialog(
              title: Text('Manuelle Zuordnung — ${f.betriebName}'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zahlungseingänge (Gutschriften) als Mehrfachauswahl.
                    const Text('Zahlungseingänge',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final g in f.gutschriften)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: gewaehlteGutschriften.contains(g),
                        title: Text(
                          '${_dateFormat.format(g.bookingDate)} — '
                          '${g.amount.toStringAsFixed(2)} CHF',
                        ),
                        subtitle: _zahlungInfoText(g),
                        onChanged: (sel) => setDialogState(() {
                          if (sel == true) {
                            gewaehlteGutschriften.add(g);
                          } else {
                            gewaehlteGutschriften.remove(g);
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    // Offene Forderungen als Mehrfachauswahl.
                    const Text('Offene Forderungen',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final r in f.forderungen)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: gewaehlteForderungen.contains(r),
                        title: Text(
                          '${_dateFormat.format(r.rechnungsdatum)} — '
                          '${r.betragBrutto.toStringAsFixed(2)} CHF',
                        ),
                        subtitle: Text('Rechnung ${r.rechnungsnummer ?? '?'}'),
                        onChanged: (sel) => setDialogState(() {
                          if (sel == true) {
                            gewaehlteForderungen.add(r);
                          } else {
                            gewaehlteForderungen.remove(r);
                          }
                        }),
                      ),
                    const SizedBox(height: 12),
                    // Summen + Differenz-Hinweis (gespiegelt aus rechnung_detail_screen).
                    Text(
                      'Zahlung: CHF ${zahlSumme.toStringAsFixed(2)}\n'
                      'Forderung: CHF ${fordSumme.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (diff.abs() >= 0.01) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: diff < 0
                              ? AppColors.warning.withAlpha(25)
                              : AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: diff < 0
                                ? AppColors.warning.withAlpha(80)
                                : AppColors.success.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              diff < 0
                                  ? Icons.trending_down
                                  : Icons.trending_up,
                              size: 18,
                              color: diff < 0
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                diff < 0
                                    ? 'Unterzahlung: CHF ${diff.abs().toStringAsFixed(2)}\n'
                                        'Wird als Debitorenverlust (3805) gebucht'
                                    : 'Mehrzahlung: CHF ${diff.toStringAsFixed(2)}\n'
                                        'Wird als a.o. Ertrag (8000) gebucht',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: diff < 0
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
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: kannVerbuchen
                      ? () async {
                          try {
                            await ForderungsAbgleichService.verbuche(
                              zahlbetrag: zahlSumme,
                              datum: gewaehlteGutschriften.first.bookingDate,
                              forderungen: gewaehlteForderungen.toList(),
                              camtTxKey: gewaehlteGutschriften.first.txKey,
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content:
                                      Text('Verbuchungs-Fehler: $e')));
                            }
                          }
                        }
                      : null,
                  child: const Text('Verbuchen'),
                ),
              ],
            );
          },
        );
      },
    );

    if (verbucht != true) return;

    ref.invalidate(rechnungenStreamProvider);
    ref.invalidate(buchungenStreamProvider);
    if (!mounted) return;
    setState(() {
      // Verbuchte Forderungen + konsumierte Gutschriften aus dem Fall entfernen.
      f.forderungen.removeWhere((r) => gewaehlteForderungen.contains(r));
      f.gutschriften.removeWhere((g) => gewaehlteGutschriften.contains(g));
      // Gemeinsamen Pool synchron halten, damit eine bereits hier verbuchte
      // Forderung nicht erneut im ⚪-Dialog (_ordneZu) auswählbar bleibt.
      final gebuchteIds = gewaehlteForderungen.map((r) => r.id).toSet();
      widget.alleOffenen.removeWhere((r) => gebuchteIds.contains(r.id));
      widget.ergebnis.keineZahlung
          .removeWhere((r) => gebuchteIds.contains(r.id));
      // Bleiben keine Forderungen mehr offen, fällt der ganze Fall weg.
      if (f.forderungen.isEmpty) {
        // Übrige (nicht zugeordnete) Gutschriften des Falls sichtbar halten.
        widget.ergebnis.unbekannteGutschriften.addAll(f.gutschriften);
        widget.ergebnis.manuell.remove(f);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
    }
  }

  /// Manuelle Zuordnung einer „nicht zugeordneten" Gutschrift zu einer oder
  /// mehreren offenen Forderungen aus dem Gesamtpool (mit Suche).
  Future<void> _ordneZu(CamtTransaction g) async {
    final gewaehlt = <Rechnung>{};
    var suche = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final gefiltert = widget.alleOffenen.where((r) {
            if (suche.isEmpty) return true;
            final q = suche.toLowerCase();
            final nr = (r.rechnungsnummer ?? '').toLowerCase();
            final betrieb = (widget.betriebName[r.betriebId] ?? '').toLowerCase();
            return nr.contains(q) || betrieb.contains(q);
          }).toList();
          final zahlSumme = g.amount;
          final fordSumme = gewaehlt.fold<double>(0, (s, r) => s + r.betragBrutto);
          final diff = ((zahlSumme - fordSumme) * 20).roundToDouble() / 20;
          return AlertDialog(
            title: Text('Zahlung zuordnen — ${g.amount.toStringAsFixed(2)} CHF'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info zur Zahlung (Datum/Betrag + Zahler/Mitteilung/Schalter-Text).
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_dateFormat.format(g.bookingDate)} — '
                          '${g.amount.toStringAsFixed(2)} CHF',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (_zahlungInfo(g) != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            _zahlungInfo(g)!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Suche (Rechnungsnr. oder Betrieb)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setDialogState(() => suche = v),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final r in gefiltert)
                          CheckboxListTile(
                            dense: true,
                            value: gewaehlt.contains(r),
                            title: Text('${_dateFormat.format(r.rechnungsdatum)} — '
                                '${r.betragBrutto.toStringAsFixed(2)} CHF'),
                            subtitle: Text('Rechnung ${r.rechnungsnummer ?? '?'} · '
                                '${widget.betriebName[r.betriebId] ?? '?'}'),
                            onChanged: (sel) => setDialogState(() {
                              if (sel == true) {
                                gewaehlt.add(r);
                              } else {
                                gewaehlt.remove(r);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (gewaehlt.isNotEmpty && diff.abs() >= 0.01)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (diff < 0 ? AppColors.warning : AppColors.success)
                            .withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(diff < 0 ? Icons.trending_down : Icons.trending_up,
                            color: diff < 0 ? AppColors.warning : AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(diff < 0
                              ? 'Unterzahlung ${diff.abs().toStringAsFixed(2)} CHF — wird als Debitorenverlust (3805) gebucht'
                              : 'Mehrzahlung ${diff.toStringAsFixed(2)} CHF — wird als a.o. Ertrag (8000) gebucht'),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen')),
              FilledButton(
                onPressed: gewaehlt.isEmpty
                    ? null
                    : () async {
                        try {
                          await ForderungsAbgleichService.verbuche(
                            zahlbetrag: g.amount,
                            datum: g.bookingDate,
                            forderungen: gewaehlt.toList(),
                            camtTxKey: g.txKey,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Verbuchungs-Fehler: $e')));
                          }
                        }
                      },
                child: const Text('Verbuchen'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      ref.invalidate(rechnungenStreamProvider);
      ref.invalidate(buchungenStreamProvider);
      if (!mounted) return;
      setState(() {
        widget.ergebnis.unbekannteGutschriften.remove(g);
        final gebuchteIds = gewaehlt.map((r) => r.id).toSet();
        widget.alleOffenen.removeWhere((r) => gebuchteIds.contains(r.id));
        widget.ergebnis.keineZahlung
            .removeWhere((r) => gebuchteIds.contains(r.id));
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Zahlung verbucht.')));
      }
    }
  }
}

/// Klappbare Gruppen-Karte: Header (Emoji · Titel · Anzahl-Badge · CHF-Summe)
/// und darunter die Einträge. Standard-Zustand über [initiallyExpanded].
class _GruppeCard extends StatelessWidget {
  final String emoji;
  final String titel;
  final int anzahl;
  final double? summe;
  final Color farbe;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _GruppeCard({
    required this.emoji,
    required this.titel,
    required this.anzahl,
    required this.summe,
    required this.farbe,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // ExpansionTile zieht sonst Trennlinien über die Kartenkanten.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Text(emoji, style: const TextStyle(fontSize: 20)),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  titel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: farbe.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$anzahl',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: farbe,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          subtitle: summe == null ? null : Text('${chf(summe!)} CHF'),
          childrenPadding: EdgeInsets.zero,
          children: children.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('—',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                ]
              : children,
        ),
      ),
    );
  }
}

/// Kompakte Kennzahl-Kachel in der Kopf-Übersicht (umbruchfähig via Wrap).
class _Kpi extends StatelessWidget {
  final Color farbe;
  final String label;
  final int anzahl;
  final String? sub;

  const _Kpi({
    required this.farbe,
    required this.label,
    required this.anzahl,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: farbe.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: farbe.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: farbe, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$anzahl',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (sub != null)
            Text(
              sub!,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
