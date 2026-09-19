import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Wochenwechsel und Tageswahl in **einer** Zeile (B5, v0.113.0).
///
/// WARUM: Bis v0.112.0 standen hier zwei Zeilen — ein Wochen-Navigator
/// (Pfeil, «KW 38 · 14.–19. Sep», Pfeil) und darunter die sechs Tages-Chips.
/// Zusammen rund 130 px; auf einem 360-px-Handy fast ein Fünftel der
/// Zeitachse, um die es auf diesem Screen eigentlich geht. Die Woche steht
/// jetzt im AppBar-Titel, die Pfeile rücken neben die Chips.
///
/// Der Tourenplan verdient den Platz: 28 Aufrufe an 8 Tagen (09.–18.09.2026).
/// Die frühere Messung «an keinem Arbeitstag geöffnet» stammte aus zwei Tagen
/// und war überholt.
///
/// Die Chips teilen sich den Rest über `Expanded`, statt feste 52 px zu
/// nehmen. Mit festen Breiten kämen sechs Chips plus zwei Pfeile auf 408 px
/// und passten nicht auf 360 — der Wochenwechsel wäre unerreichbar geworden.
class WochenLeiste extends StatelessWidget {
  /// Montag der angezeigten Woche.
  final DateTime weekStart;
  final DateTime selectedDate;

  /// Einträge je Tag, Montag bis Samstag.
  final List<int> counts;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final void Function(DateTime) onSelect;

  const WochenLeiste({
    super.key,
    required this.weekStart,
    required this.selectedDate,
    required this.counts,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  static const _tage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    final heute = DateTime.now();
    final heuteDatum = DateTime(heute.year, heute.month, heute.day);

    return Container(
      color: AppColors.primary.withAlpha(15),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _Pfeil(
            icon: Icons.chevron_left,
            tooltip: 'Vorherige Woche',
            onTap: onPrevious,
          ),
          for (var i = 0; i < 6; i++)
            Expanded(
              child: _Tag(
                tag: weekStart.add(Duration(days: i)),
                kuerzel: _tage[i],
                anzahl: i < counts.length ? counts[i] : 0,
                gewaehlt: gleicherTag(
                  weekStart.add(Duration(days: i)),
                  selectedDate,
                ),
                istHeute: gleicherTag(
                  weekStart.add(Duration(days: i)),
                  heuteDatum,
                ),
                onTap: () => onSelect(weekStart.add(Duration(days: i))),
              ),
            ),
          _Pfeil(
            icon: Icons.chevron_right,
            tooltip: 'Nächste Woche',
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

/// Gleicher Kalendertag, ohne Rücksicht auf die Uhrzeit.
bool gleicherTag(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Die Beschriftung der Woche für den AppBar-Titel, z. B. «KW 38 · Sep 2026».
///
/// WARUM ohne Tagesspanne: «KW 38 · 14.–19. Sep 2026» wurde in der Titelzeile
/// abgeschnitten, sobald rechts drei Knöpfe stehen — und die Tage 14 bis 19
/// stehen ohnehin in den Chips direkt darunter. Der Titel ergänzt nur, was
/// die Chips nicht zeigen: Monat und Jahr.
///
/// Reine Funktion, damit sie prüfbar bleibt.
String wochenTitel(DateTime weekStart) {
  const monate = [
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
  final ende = weekStart.add(const Duration(days: 5));
  // Läuft die Woche über einen Monatswechsel, stehen beide Monate da —
  // sonst wüsste man bei «Mo 28 … Sa 3» nicht, wohin die 3 gehört.
  final monat = weekStart.month == ende.month
      ? monate[ende.month]
      : '${monate[weekStart.month]}/${monate[ende.month]}';
  return 'KW ${kalenderwoche(weekStart)} · $monat ${ende.year}';
}

/// Kalenderwoche nach ISO 8601 (Woche 1 enthält den ersten Donnerstag).
///
/// Die frühere Rechnung im Screen zählte ab dem 1. Januar und lag deshalb am
/// Jahreswechsel daneben.
int kalenderwoche(DateTime datum) {
  // In UTC rechnen. `difference().inDays` auf lokalen Daten verliert über
  // einen Sommerzeit-Wechsel eine Stunde und damit einen ganzen Tag: Vom
  // 1. Januar zum 17. September 2026 ergäbe das 258 statt 259 Tage — und
  // damit KW 37 statt 38. Der Fehler zeigt sich nur im Sommerhalbjahr.
  final tag = DateTime.utc(datum.year, datum.month, datum.day);
  // Donnerstag derselben Woche: Montag (1) + 3, Sonntag (7) − 3.
  final donnerstag = tag.add(Duration(days: 4 - tag.weekday));
  final jahresbeginn = DateTime.utc(donnerstag.year, 1, 1);
  return (donnerstag.difference(jahresbeginn).inDays / 7).floor() + 1;
}

/// Schmale Tap-Fläche für den Wochenwechsel — ein voller `IconButton`
/// (48 px) nähme den Chips zu viel Breite.
class _Pfeil extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _Pfeil({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 32,
        height: 44,
        child: Icon(icon, size: 22, color: AppColors.primary),
      ),
    ),
  );
}

/// Ein Tag. Aus `InkWell` + `Container` gebaut, nicht aus einem
/// Material-Komfort-Widget — auf CanvasKit-Web sind solche schon dreimal
/// unsichtbar geblieben oder ohne Klick-Reaktion (siehe CLAUDE.md).
class _Tag extends StatelessWidget {
  final DateTime tag;
  final String kuerzel;
  final int anzahl;
  final bool gewaehlt;
  final bool istHeute;
  final VoidCallback onTap;

  const _Tag({
    required this.tag,
    required this.kuerzel,
    required this.anzahl,
    required this.gewaehlt,
    required this.istHeute,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: gewaehlt
              ? AppColors.primary
              : istHeute
              ? AppColors.primary.withAlpha(25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: istHeute && !gewaehlt
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kuerzel,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: gewaehlt ? Colors.white : AppColors.textSecondary,
              ),
            ),
            Text(
              '${tag.day}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: gewaehlt ? Colors.white : AppColors.textPrimary,
              ),
            ),
            // Feste Höhe, damit die Zeile nicht springt, wenn ein Tag einen
            // Zähler bekommt und der nächste keinen.
            SizedBox(
              height: 14,
              child: anzahl == 0
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: gewaehlt
                            ? Colors.white.withAlpha(50)
                            : AppColors.info.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$anzahl',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: gewaehlt ? Colors.white : AppColors.info,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
