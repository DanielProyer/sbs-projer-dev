import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';

/// Die untere Navigationsleiste (B1) — reine Darstellung, ohne
/// Router-Wissen.
///
/// CanvasKit: `InkWell` + `Container` + `Row`, **kein** `NavigationBar`.
/// Auf dem produktiv genutzten CanvasKit-Web haben Material-Komfort-Widgets
/// dreimal nicht gerendert oder nicht reagiert (CLAUDE.md) — bei der
/// globalen Navigation wäre das der grösste denkbare Ausfall.
class HauptNavigation extends StatelessWidget {
  final NavZiel? aktiv;
  final ValueChanged<NavZiel> onZiel;

  const HauptNavigation({super.key, required this.aktiv, required this.onZiel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0x1F000000))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kNavigationHoehe,
          child: Row(
            children: [
              for (final z in NavZiel.values)
                Expanded(
                  child: InkWell(
                    onTap: () => onZiel(z),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          navIcon(z),
                          size: 22,
                          color: z == aktiv
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          navLabel(z),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: z == aktiv
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: z == aktiv
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
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

/// Angebunden: beobachtet den Router, entscheidet über Sichtbarkeit und
/// aktives Ziel und navigiert.
///
/// `router.routeInformationProvider` ist ein `Listenable` und meldet jeden
/// Routenwechsel — `GoRouterState.of(context)` gibt es hier oben nicht.
/// `go` statt `push`: Der Stapel wird ersetzt, damit die Browser-Zurück-
/// Geste eine Seite zurückführt statt durch einen wachsenden Stapel.
class HauptNavigationLeiste extends StatelessWidget {
  const HauptNavigationLeiste({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: router.routeInformationProvider,
      builder: (context, _) {
        final pfad = router.routeInformationProvider.value.uri.path;
        if (!zeigtNavigation(pfad)) return const SizedBox.shrink();
        return HauptNavigation(
          aktiv: aktivesZiel(pfad),
          onZiel: (z) => router.go(navPfad(z)),
        );
      },
    );
  }
}
