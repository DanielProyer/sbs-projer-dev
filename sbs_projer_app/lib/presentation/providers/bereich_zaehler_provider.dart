import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/presentation/providers/aufgaben_providers.dart';
import 'package:sbs_projer_app/presentation/providers/material_providers.dart';

/// Zählertext je Bereichs-Eintrag, `null` = kein Zähler.
///
/// Dieselben Quellen wie Glocke und frühere Kacheln (B6): kein Eintrag
/// rechnet selbst aus Einsatz-Providern — sonst zeigen zwei Stellen zwei
/// Zahlen für dasselbe.
final bereichZaehlerProvider = Provider<String? Function(BereichEintrag)>((
  ref,
) {
  final niedrig = ref.watch(niedrigCountProvider);
  final badge = ref.watch(aufgabenBadgeProvider);
  final liste = ref.watch(aufgabenListeProvider).valueOrNull ?? const [];
  final jeBereich = zaehleJeBereich(liste.map((a) => a.route));

  return (e) {
    switch (e.zaehler) {
      case null:
        return null;
      case ZaehlerQuelle.materialNiedrig:
        return niedrig > 0 ? '$niedrig niedrig' : null;
      case ZaehlerQuelle.aufgaben:
        return badge > 0 ? '$badge' : null;
      case ZaehlerQuelle.bereich:
        final id = bereichFuerPfad(e.ziel);
        final n = id == null ? 0 : (jeBereich[id] ?? 0);
        return n > 0 ? '$n offen' : null;
    }
  };
});
