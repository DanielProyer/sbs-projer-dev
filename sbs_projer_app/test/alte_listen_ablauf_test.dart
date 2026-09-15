import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/core/app_version.dart';

/// Die sechs alten Listen-Screens bleiben nach B2 einen Auslieferungszyklus
/// als Rueckfalltuer erreichbar — und danach nicht mehr. Ohne dieses
/// Ablaufdatum blieben sie fuer immer: Niemand raeumt auf, was nicht stoert.
void main() {
  test('alte Listenrouten sind ab v0.106.0 entfernt', () {
    const ablaufAb = '0.106.0';
    if (_versionKleiner(kAppVersion, ablaufAb)) return; // noch Gnadenfrist

    final router = File('lib/core/config/router.dart').readAsStringSync();
    const alteRouten = [
      "path: '/reinigungen',",
      "path: '/stoerungen',",
      "path: '/montagen',",
      "path: '/eigenauftraege',",
      "path: '/eroeffnungsreinigungen',",
      "path: '/pikett',",
    ];
    final noch = alteRouten.where(router.contains).toList();
    expect(
      noch,
      isEmpty,
      reason:
          'Version $kAppVersion — die alten Listen sollten seit $ablaufAb '
          'weg sein. Noch vorhanden: $noch. Screens, Routen und ihre Tests '
          'entfernen; die Kacheln zeigen laengst auf /einsaetze.',
    );
  });
}

bool _versionKleiner(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) return pa[i] < pb[i];
  }
  return false;
}
