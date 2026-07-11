import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/auswertung_providers.dart';
import 'package:sbs_projer_app/services/auswertung/auswertung_aggregat.dart';
import 'package:sbs_projer_app/services/auswertung/auswertung_modell.dart';

enum _Modus { jahr, jahre, monatsvergleich }

const _accent = AppColors.primary; // Heineken-Grün, dezent eingesetzt

const _monatKurz = [
  '', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
  'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
];

const Map<AuswertungKategorie, String> _katLabel = {
  AuswertungKategorie.reinigung: 'Reinigung',
  AuswertungKategorie.reinigungHk: 'Reinigung HK',
  AuswertungKategorie.stoerung: 'Störung',
  AuswertungKategorie.eigenauftrag: 'Eigenauftrag',
  AuswertungKategorie.eroeffnung: 'Eröffnung',
  AuswertungKategorie.montage: 'Montage',
  AuswertungKategorie.pikett: 'Pikett',
  AuswertungKategorie.bkPauschale: 'BK-Pauschale',
};

String _n(num v) {
  final s = v.abs().round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => "'",
      );
  return v < 0 ? '-$s' : s;
}

/// „Schöne" Y-Achse: liefert (maxY, interval) mit runden Schritten (1/2/5×10ⁿ).
(double, double) _achse(double maxV) {
  if (maxV <= 0) return (1, 1);
  final rough = maxV * 1.1 / 4;
  final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  final norm = rough / mag;
  final nice = norm < 1.5
      ? 1.0
      : norm < 3
          ? 2.0
          : norm < 7
              ? 5.0
              : 10.0;
  final interval = nice * mag;
  final maxY = (maxV * 1.05 / interval).ceil() * interval;
  return (maxY, interval);
}

String _achsenLabel(double v) =>
    v >= 1000 ? '${(v / 1000).round()}k' : v.round().toString();

class AuswertungScreen extends ConsumerStatefulWidget {
  const AuswertungScreen({super.key});
  @override
  ConsumerState<AuswertungScreen> createState() => _AuswertungScreenState();
}

class _AuswertungScreenState extends ConsumerState<AuswertungScreen> {
  _Modus _modus = _Modus.jahr;
  late int _jahr;
  int _monat = DateTime.now().month;
  bool _brutto = true;
  int _expand = -1; // Index aufgeklappte Tabellenzeile

  @override
  void initState() {
    super.initState();
    _jahr = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final daten = ref.watch(auswertungProvider);
    final jahre = daten.jahre;
    if (jahre.isNotEmpty && !jahre.contains(_jahr)) _jahr = jahre.last;

    return Scaffold(
      appBar: AppBar(title: const Text('Auswertung')),
      body: jahre.isEmpty
          ? const Center(child: Text('Noch keine Daten für die Auswertung.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _kopf(jahre),
                const SizedBox(height: 14),
                _kpi(daten, jahre),
                const SizedBox(height: 18),
                _chartSektion(daten, jahre),
                const SizedBox(height: 18),
                _tabelle(daten, jahre),
              ],
            ),
    );
  }

  // ─── Kopf: Modus + Kontext + netto/brutto ───
  Widget _kopf(List<int> jahre) {
    return Column(
      children: [
        SegmentedButton<_Modus>(
          segments: const [
            ButtonSegment(value: _Modus.jahr, label: Text('Jahr')),
            ButtonSegment(value: _Modus.jahre, label: Text('Jahre')),
            ButtonSegment(
                value: _Modus.monatsvergleich, label: Text('Monatsvgl.')),
          ],
          selected: {_modus},
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onSelectionChanged: (s) => setState(() {
            _modus = s.first;
            _expand = -1;
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_modus == _Modus.jahr)
              _dropdown<int>(
                value: _jahr,
                items: [for (final j in jahre.reversed) (j, '$j')],
                onChanged: (v) => setState(() {
                  _jahr = v;
                  _expand = -1;
                }),
              )
            else if (_modus == _Modus.monatsvergleich)
              _dropdown<int>(
                value: _monat,
                items: [for (int m = 1; m <= 12; m++) (m, _monatKurz[m])],
                onChanged: (v) => setState(() {
                  _monat = v;
                  _expand = -1;
                }),
              )
            else
              const SizedBox(),
            const Spacer(),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Netto')),
                ButtonSegment(value: true, label: Text('Brutto')),
              ],
              selected: {_brutto},
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
              ),
              onSelectionChanged: (s) => setState(() => _brutto = s.first),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(9),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        isDense: true,
        borderRadius: BorderRadius.circular(8),
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary),
        items: [
          for (final (v, l) in items)
            DropdownMenuItem(value: v, child: Text(l)),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );
  }

  // ─── KPI-Kopf ───
  Widget _kpi(AuswertungDaten daten, List<int> jahre) {
    // Bezugswert je Modus.
    late final MonatsWerte cur;
    late final MonatsWerte? prev;
    late final String titel;
    if (_modus == _Modus.monatsvergleich) {
      final vglJahre = daten.monatsvergleich(_monat).keys.toList()..sort();
      final bez = vglJahre.isNotEmpty ? vglJahre.last : _jahr;
      cur = daten.monat(bez, _monat) ?? MonatsWerte(bez, _monat, const {});
      prev = daten.monat(bez - 1, _monat);
      titel = '${_monatKurz[_monat]} $bez';
    } else {
      final bezugsJahr = _modus == _Modus.jahr ? _jahr : jahre.last;
      cur = daten.jahresWerte(bezugsJahr);
      prev = jahre.contains(bezugsJahr - 1)
          ? daten.jahresWerte(bezugsJahr - 1)
          : null;
      titel = 'Umsatz $bezugsJahr';
    }
    final total = cur.total(_brutto);
    final delta = (prev != null && prev.total(_brutto) != 0)
        ? (total - prev.total(_brutto)) / prev.total(_brutto) * 100
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              border: const Border(
                left: BorderSide(color: _accent, width: 3),
                top: BorderSide(color: AppColors.divider),
                right: BorderSide(color: AppColors.divider),
                bottom: BorderSide(color: AppColors.divider),
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titel.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: .4,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(_n(total),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5)),
                if (delta != null)
                  Text(
                    '${delta >= 0 ? '▲' : '▼'} ${delta.abs().toStringAsFixed(1)} % ggü. Vorjahr',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            delta >= 0 ? AppColors.success : AppColors.error),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _miniKpi('Kunde', cur.reinigungKunde(_brutto)),
              const SizedBox(height: 8),
              _miniKpi('Heineken', cur.rechnungHk(_brutto)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniKpi(String label, double wert) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
          Text(_n(wert),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ─── Charts ───
  Widget _chartSektion(AuswertungDaten daten, List<int> jahre) {
    final String titel;
    final Widget chart;
    switch (_modus) {
      case _Modus.jahr:
        titel = 'Verlauf $_jahr${jahre.contains(_jahr - 1) ? ' vs. ${_jahr - 1}' : ''}';
        chart = _lineChart(daten, jahre);
      case _Modus.jahre:
        titel = 'Umsatz je Jahr';
        chart = _barChart(
          [for (final j in jahre) (('$j'), daten.jahresWerte(j).total(_brutto))],
          highlightLast: true,
        );
      case _Modus.monatsvergleich:
        titel = 'Monatsvergleich · ${_monatKurz[_monat]}';
        final vgl = daten.monatsvergleich(_monat);
        chart = _barChart(
          [for (final e in vgl.entries) (('${e.key}'), e.value.total(_brutto))],
          highlightLast: true,
        );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(titel,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        SizedBox(height: 180, width: double.infinity, child: chart),
      ],
    );
  }

  FlTitlesData _titles(double interval, List<String> unten,
      {double bottomInterval = 1}) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: interval,
          getTitlesWidget: (v, meta) => Text(_achsenLabel(v),
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textSecondary)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 20,
          interval: bottomInterval,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= unten.length) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(unten[i],
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary)),
            );
          },
        ),
      ),
    );
  }

  FlGridData _grid(double interval) => FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (v) =>
            const FlLine(color: AppColors.divider, strokeWidth: 1, dashArray: [2, 4]),
      );

  List<FlSpot> _spots(AuswertungDaten d, int jahr) {
    final monate = d.monateVon(jahr);
    int last = 0;
    for (int i = 0; i < 12; i++) {
      if (monate[i].anzahlGesamt > 0) last = i + 1;
    }
    return [for (int i = 0; i < last; i++) FlSpot(i.toDouble(), monate[i].total(_brutto))];
  }

  Widget _lineChart(AuswertungDaten daten, List<int> jahre) {
    final cur = _spots(daten, _jahr);
    final prev = jahre.contains(_jahr - 1) ? _spots(daten, _jahr - 1) : <FlSpot>[];
    final maxV = [
      ...cur.map((e) => e.y),
      ...prev.map((e) => e.y),
      1.0,
    ].reduce((a, b) => a > b ? a : b);
    final (maxY, interval) = _achse(maxV);
    return LineChart(LineChartData(
      minX: 0,
      maxX: 11,
      minY: 0,
      maxY: maxY,
      gridData: _grid(interval),
      borderData: FlBorderData(show: false),
      titlesData: _titles(interval, [for (int m = 1; m <= 12; m++) _monatKurz[m][0]]),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots
              .map((s) => LineTooltipItem(
                  _n(s.y), const TextStyle(color: Colors.white, fontSize: 11)))
              .toList(),
        ),
      ),
      lineBarsData: [
        if (prev.isNotEmpty)
          LineChartBarData(
            spots: prev,
            isCurved: false,
            color: AppColors.textSecondary.withAlpha(120),
            barWidth: 1.5,
            dashArray: const [4, 3],
            dotData: const FlDotData(show: false),
          ),
        LineChartBarData(
          spots: cur,
          isCurved: false,
          color: _accent,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (s, p, b, i) =>
                FlDotCirclePainter(radius: 2.2, color: _accent),
          ),
          belowBarData: BarAreaData(show: true, color: _accent.withAlpha(20)),
        ),
      ],
    ));
  }

  Widget _barChart(List<(String, double)> daten, {bool highlightLast = false}) {
    final maxV = [...daten.map((e) => e.$2), 1.0].reduce((a, b) => a > b ? a : b);
    final (maxY, interval) = _achse(maxV);
    return BarChart(BarChartData(
      maxY: maxY,
      gridData: _grid(interval),
      borderData: FlBorderData(show: false),
      titlesData: _titles(interval, [for (final d in daten) d.$1]),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
              _n(r.toY), const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      ),
      barGroups: [
        for (int i = 0; i < daten.length; i++)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: daten[i].$2,
              width: 16,
              color: (highlightLast && i == daten.length - 1)
                  ? _accent
                  : _accent.withAlpha(70),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ]),
      ],
    ));
  }

  // ─── Tabelle ───
  Widget _tabelle(AuswertungDaten daten, List<int> jahre) {
    final List<(String, MonatsWerte, bool)> zeilen; // label, werte, aufklappbar
    final String titel;
    MonatsWerte summe;
    if (_modus == _Modus.jahr) {
      titel = 'Monatsübersicht $_jahr';
      final monate = daten.monateVon(_jahr);
      zeilen = [
        for (int i = 0; i < 12; i++) (_monatKurz[i + 1], monate[i], true),
      ];
      summe = daten.jahresWerte(_jahr);
    } else if (_modus == _Modus.jahre) {
      titel = 'Jahresübersicht';
      zeilen = [for (final j in jahre) ('$j', daten.jahresWerte(j), true)];
      summe = _summe(zeilen.map((z) => z.$2));
    } else {
      titel = '${_monatKurz[_monat]} · Jahresvergleich';
      final vgl = daten.monatsvergleich(_monat);
      zeilen = [for (final e in vgl.entries) ('${e.key}', e.value, true)];
      summe = _summe(zeilen.map((z) => z.$2));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(titel,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _kopfzeile(),
              for (int i = 0; i < zeilen.length; i++)
                _zeile(i, zeilen[i].$1, zeilen[i].$2, zeilen[i].$3),
              _summenzeile(summe),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8, left: 2),
          child: Text('Zeile antippen → alle Kategorien',
              style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  MonatsWerte _summe(Iterable<MonatsWerte> werte) {
    final acc = <AuswertungKategorie, KategorieWert>{};
    for (final w in werte) {
      w.kategorien.forEach((k, v) {
        final cur = acc[k] ?? KategorieWert.leer;
        acc[k] = KategorieWert(
            cur.anzahl + v.anzahl, cur.netto + v.netto, cur.brutto + v.brutto);
      });
    }
    return MonatsWerte(0, 0, acc);
  }

  TextStyle get _th => const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary);

  Widget _kopfzeile() => Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text('MONAT', style: _th)),
            Expanded(
                flex: 2,
                child: Text('ANZ.', style: _th, textAlign: TextAlign.right)),
            Expanded(
                flex: 3,
                child: Text('KUNDE', style: _th, textAlign: TextAlign.right)),
            Expanded(
                flex: 3,
                child:
                    Text('HEINEKEN', style: _th, textAlign: TextAlign.right)),
            Expanded(
                flex: 3,
                child: Text('TOTAL', style: _th, textAlign: TextAlign.right)),
          ],
        ),
      );

  Widget _zeile(int i, String label, MonatsWerte w, bool aufklappbar) {
    final offen = _expand == i;
    final leer = w.anzahlGesamt == 0;
    return Column(
      children: [
        InkWell(
          onTap: aufklappbar && !leer
              ? () => setState(() => _expand = offen ? -1 : i)
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: i.isOdd ? AppColors.surface.withAlpha(120) : null,
              border: const Border(
                  top: BorderSide(color: AppColors.divider, width: .6)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 2,
                    child: Text(leer ? '–' : '${w.anzahlGesamt}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary))),
                Expanded(
                    flex: 3,
                    child: Text(_n(w.reinigungKunde(_brutto)),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12))),
                Expanded(
                    flex: 3,
                    child: Text(_n(w.rechnungHk(_brutto)),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12))),
                Expanded(
                    flex: 3,
                    child: Text(_n(w.total(_brutto)),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        ),
        if (offen && !leer) _breakdown(w),
      ],
    );
  }

  Widget _breakdown(MonatsWerte w) {
    final eintraege = [
      for (final k in AuswertungKategorie.values)
        if (w.kat(k).anzahl > 0) (k, w.kat(k)),
    ];
    return Container(
      color: _accent.withAlpha(12),
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
      child: Column(
        children: [
          for (final (k, v) in eintraege)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                      flex: 5,
                      child: Text('${_katLabel[k]}',
                          style: const TextStyle(fontSize: 11.5))),
                  Expanded(
                      flex: 2,
                      child: Text('${v.anzahl}×',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary))),
                  Expanded(
                      flex: 3,
                      child: Text(_n(_brutto ? v.brutto : v.netto),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summenzeile(MonatsWerte s) => Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider, width: 1.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            const Expanded(
                flex: 3,
                child: Text('Total',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w800))),
            Expanded(
                flex: 2,
                child: Text('${s.anzahlGesamt}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700))),
            Expanded(
                flex: 3,
                child: Text(_n(s.reinigungKunde(_brutto)),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700))),
            Expanded(
                flex: 3,
                child: Text(_n(s.rechnungHk(_brutto)),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700))),
            Expanded(
                flex: 3,
                child: Text(_n(s.total(_brutto)),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _accent))),
          ],
        ),
      );
}
