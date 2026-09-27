import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/config/router.dart' as app show router;
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/navigation_ziele.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';

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

  /// Zahl im roten Kreis am Symbol eines Ziels; fehlt oder 0 = kein Badge.
  /// Heute nur Material: «N niedrig» (Bestand unter Mindestmenge) stand
  /// bis 27.09.2026 auf der Material-Kachel von Mehr und zog mit in die
  /// Leiste, damit der Hinweis nicht verloren geht.
  final Map<NavZiel, int> zaehler;

  const HauptNavigation({
    super.key,
    required this.aktiv,
    required this.onZiel,
    this.zaehler = const {},
  });

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
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              navIcon(z),
                              size: 22,
                              color: z == aktiv
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            if ((zaehler[z] ?? 0) > 0)
                              Positioned(
                                right: -8,
                                top: -5,
                                child: _ZaehlerPunkt(zaehler[z]!),
                              ),
                          ],
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

/// Roter Zähler am Symbol — derselbe Stil wie die Zahl an der
/// Aufgaben-Glocke (`aufgaben_glocke.dart`), damit «da ist etwas» überall
/// gleich aussieht. Reiner Container + Text, CanvasKit-sicher.
class _ZaehlerPunkt extends StatelessWidget {
  final int anzahl;
  const _ZaehlerPunkt(this.anzahl);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$anzahl',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Angebunden: beobachtet den Router-Delegate, entscheidet über Sichtbarkeit
/// und aktives Ziel und navigiert.
///
/// `GoRouterState.of(context)` gibt es hier oben nicht — deshalb der
/// Delegate als `Listenable` (warum nicht `routeInformationProvider`: siehe
/// `build`). `go` statt `push`: Der Stapel wird ersetzt, damit die Browser-Zurück-
/// Geste eine Seite zurückführt statt durch einen wachsenden Stapel.
class HauptNavigationLeiste extends StatelessWidget {
  /// Standard: der Router der App; Tests geben einen eigenen mit.
  final GoRouter? goRouter;

  const HauptNavigationLeiste({super.key, this.goRouter});

  @override
  Widget build(BuildContext context) {
    final router = goRouter ?? app.router;
    // Der Delegate, nicht `routeInformationProvider`: Eine Weiterleitung
    // meldet dem Provider den neuen Pfad OHNE `notifyListeners()` (go_router
    // 17.5.0, `routerReportsNewRouteInformation`). Die Leiste blieb dadurch
    // auf dem Stand davor — auf dem Anmeldebildschirm stand sie mit
    // «Heute», nach dem Anmelden fehlte sie (Befund 22.09.2026). Der
    // Delegate meldet jede Änderung, auch Weiterleitungen und `pop`.
    // `state.uri` ist die oberste Route, also auch eine per `push` geöffnete
    // — `currentConfiguration.uri` allein übersähe gepushte Formulare.
    final delegate = router.routerDelegate;
    return AnimatedBuilder(
      animation: delegate,
      builder: (context, _) {
        if (delegate.currentConfiguration.isEmpty) {
          return const SizedBox.shrink();
        }
        final pfad = delegate.state.uri.path;
        if (!zeigtNavigation(pfad)) return const SizedBox.shrink();
        // `Consumer` erst hier, nach den Sichtbarkeits-Prüfungen: Auf dem
        // Anmeldebildschirm soll der Materialbestand gar nicht erst geladen
        // werden (ohne Anmeldung liefe die Abfrage ins Leere).
        return Consumer(
          builder: (context, ref, _) => HauptNavigation(
            aktiv: aktivesZiel(pfad),
            onZiel: (z) => router.go(navPfad(z)),
            zaehler: {NavZiel.material: ref.watch(niedrigCountProvider)},
          ),
        );
      },
    );
  }
}
