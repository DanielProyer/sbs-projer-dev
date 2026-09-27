import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

/// Mindesthöhe jeder Zeile — alle gleich hoch, ob mit oder ohne Untertitel
/// und Zähler. Wächst nur mit, wenn die Schrift grösser gestellt ist.
const double kBereichZeileHoehe = 60;

/// Zeichnet Bereichs-Gruppen: kleiner grauer Titel, darunter die Zeilen in
/// einem flachen Rahmen.
///
/// CanvasKit: Zeilen aus `InkWell` + `Container` + `Row`, kein `ListTile` —
/// die Mehr-Seite ist nach der Leiste die meistbenutzte Weiche der App, ein
/// nicht rendernder Eintrag fiele erst auf, wenn man ihn braucht (CLAUDE.md,
/// drei bestätigte Vorfälle).
///
/// Seit 27.09.2026 eine einzige Darstellung (Daniel: «aufgeräumter»): Das
/// Kachel-Raster der Gruppe «Unterwegs» ist weg, jede Gruppe und jede Zeile
/// sieht gleich aus — Symbol im Kreis, Titel, Untertitel, Zähler, Pfeil.
/// Kein Schatten, nur ein Rahmen je Gruppe.
class BereichGruppenListe extends StatelessWidget {
  final List<BereichGruppe> gruppen;
  final String? Function(BereichEintrag) zaehler;
  final ValueChanged<String> onTap;

  const BereichGruppenListe({
    super.key,
    required this.gruppen,
    required this.zaehler,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, g) in gruppen.indexed) ...[
          if (g.titel != null)
            _GruppenTitel(g.titel!, oben: i == 0 ? 8 : 20)
          else if (i > 0)
            const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                for (var j = 0; j < g.eintraege.length; j++)
                  _Zeile(
                    eintrag: g.eintraege[j],
                    zaehler: zaehler(g.eintraege[j]),
                    trennlinie: j < g.eintraege.length - 1,
                    onTap: () => onTap(g.eintraege[j].ziel),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GruppenTitel extends StatelessWidget {
  final String titel;
  final double oben;

  const _GruppenTitel(this.titel, {required this.oben});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, oben, 4, 8),
      child: Text(
        titel,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Breite des Symbol-Kreises; die Trennlinie beginnt erst nach ihm.
const double _kreis = 32;
const double _randLinks = 10;
const double _abstandSymbol = 10;

class _Zeile extends StatelessWidget {
  final BereichEintrag eintrag;
  final String? zaehler;
  final bool trennlinie;
  final VoidCallback onTap;

  const _Zeile({
    required this.eintrag,
    required this.zaehler,
    required this.trennlinie,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zeile = Container(
      constraints: const BoxConstraints(minHeight: kBereichZeileHoehe),
      padding: const EdgeInsets.fromLTRB(_randLinks, 8, 6, 8),
      child: Row(
        children: [
          Container(
            width: _kreis,
            height: _kreis,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(22),
              shape: BoxShape.circle,
            ),
            child: Icon(eintrag.icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: _abstandSymbol),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eintrag.titel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (eintrag.untertitel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      eintrag.untertitel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (zaehler != null)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                zaehler!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      // Die Trennlinie beginnt nach dem Symbol-Kreis — so lesen sich die
      // Zeilen als eine Liste und die Symbole als eine Spalte. Im Stack statt
      // als Rand, damit jede Zeile gleich hoch bleibt.
      child: Stack(
        children: [
          zeile,
          if (trennlinie)
            const Positioned(
              left: _randLinks + _kreis + _abstandSymbol,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 1,
                child: ColoredBox(color: AppColors.divider),
              ),
            ),
        ],
      ),
    );
  }
}
