import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';

class BereichReiterEintrag {
  final String titel;
  final String pfad;
  const BereichReiterEintrag(this.titel, this.pfad);
}

/// Die Personen sind seit v0.131.0 ein Reiter der Betriebe: Wirte ruft man
/// über ihren Betrieb an (39 Aufrufe Betrieb-Detail am Handy in 14 Tagen,
/// 0 Kontakte-Liste).
const kReiterBetriebe = [
  BereichReiterEintrag('Betriebe', '/betriebe'),
  BereichReiterEintrag('Personen', '/kontakte'),
];

/// Der Rechnungs-Bereich (v0.132.0): vorher hingen die vier Screens einzeln
/// in der Buchhaltung, die Rechnungen zwei Stufen tief.
const kReiterRechnungen = [
  BereichReiterEintrag('Kunden', '/rechnungen'),
  BereichReiterEintrag('Heineken', '/heineken'),
  BereichReiterEintrag('Pro Betrieb', '/rechnungen/pro-betrieb'),
  BereichReiterEintrag('Jährlich', '/jahresrechnung'),
];

/// Umschalter unter der AppBar.
///
/// WARUM kein `TabBar`: Ein TabBar bettet die Reiter-Screens ein — jeder
/// hat aber eine eigene AppBar und eine eigene Route, auf die Mails und
/// Aufgaben zeigen. Hier bleibt jeder Reiter der bestehende Screen unter
/// seiner Route; der Umschalter wechselt nur die Route (`go`, damit «zurück»
/// nicht durch jeden Reiterwechsel führt). Dazu CanvasKit: kein
/// Material-Komfort-Widget in der Navigation (CLAUDE.md).
class BereichReiter extends StatelessWidget implements PreferredSizeWidget {
  final List<BereichReiterEintrag> reiter;
  final String aktiverPfad;

  /// Für Tests; ohne Angabe wird per `context.go` gewechselt.
  final ValueChanged<String>? onWechsel;

  const BereichReiter({
    super.key,
    required this.reiter,
    required this.aktiverPfad,
    this.onWechsel,
  });

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          for (final r in reiter)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: r.pfad == aktiverPfad
                    ? null
                    : () => onWechsel != null
                          ? onWechsel!(r.pfad)
                          : context.go(r.pfad),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: r.pfad == aktiverPfad
                            ? AppColors.primary
                            : AppColors.divider,
                        width: r.pfad == aktiverPfad ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Text(
                    r.titel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: r.pfad == aktiverPfad
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: r.pfad == aktiverPfad
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
