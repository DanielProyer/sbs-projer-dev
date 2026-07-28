import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/aufgaben_sheet.dart';

/// Globales Glocken-Overlay (MaterialApp.builder). Unten links —
/// einhändig erreichbar, kollidiert nicht mit FABs (unten rechts) oder
/// AppBar-Actions (oben). Unsichtbar bei 0 Aufgaben oder ohne Login.
class AufgabenGlocke extends ConsumerWidget {
  final Widget child;
  const AufgabenGlocke({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badge = ref.watch(aufgabenProvider).valueOrNull?.badge ?? 0;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        if (badge > 0)
          Positioned(
            left: 12,
            // Hoch genug, damit die Glocke keine unteren Aktionsleisten
            // überdeckt (Vorfall 26.07.2026: sie lag über dem Buchen-Knopf
            // im Spesen-Scanner).
            bottom: 96,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: GestureDetector(
                onTap: () {
                  // GoRouter erzeugt seinen eigenen Navigator-Key — der
                  // builder-Kontext liegt darüber, das Sheet braucht den
                  // Navigator-Kontext (analog app.dart _triggerPasswordDialog).
                  final ctx = router.routerDelegate.navigatorKey.currentContext;
                  if (ctx != null) zeigeAufgabenSheet(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications,
                          color: Colors.white, size: 22),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$badge',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
