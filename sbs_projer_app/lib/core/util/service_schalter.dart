import 'package:sbs_projer_app/data/local/anlage_local_export.dart';

/// Komponenten einer Anlage, die vor dem Service ausgeschaltet und danach
/// wieder eingeschaltet werden müssen.
///
/// Hintergrund (Daniel, 01.09.2026): Booster und Eissäule müssen während des
/// Service aus, sonst friert Wasser oder Lauge in der Leitung. Bis dahin stand
/// das nirgends in der App — der Booster war zwar am Anlagenblatt erfasst, aber
/// ohne jede Erinnerung im Reinigungsablauf.
class ServiceSchalter {
  static List<String> komponenten({
    required bool booster,
    required bool eissaeule,
  }) {
    return [
      if (booster) 'Booster',
      if (eissaeule) 'Eissäule',
    ];
  }

  /// Wie [komponenten], aber über alle Anlagen einer Reinigung hinweg —
  /// eine Reinigung kann mehrere Anlagen umfassen. Jede Komponente erscheint
  /// höchstens einmal.
  static List<String> komponentenAusAnlagen(Iterable<AnlageLocal> anlagen) {
    return komponenten(
      booster: anlagen.any((a) => a.booster),
      eissaeule: anlagen.any((a) => a.eissaeule),
    );
  }

  /// Hinweis beim Reinigungsbeginn. `null`, wenn nichts betroffen ist.
  static String? hinweisBeginn(List<String> komponenten) {
    if (komponenten.isEmpty) return null;
    return '${_aufzaehlung(komponenten)} vor der Reinigung ausschalten — '
        'sonst friert Wasser oder Lauge in der Leitung.';
  }

  /// Hinweis beim Reinigungsabschluss. `null`, wenn nichts betroffen ist.
  static String? hinweisEnde(List<String> komponenten) {
    if (komponenten.isEmpty) return null;
    return '${_aufzaehlung(komponenten)} wieder einschalten.';
  }

  static String _aufzaehlung(List<String> teile) {
    if (teile.length == 1) return teile.first;
    return '${teile.sublist(0, teile.length - 1).join(', ')} und ${teile.last}';
  }
}
