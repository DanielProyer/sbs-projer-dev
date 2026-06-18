// lib/presentation/providers/mwst_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/buchhaltung/mwst_satz_service.dart';

/// MWST-Sätze, neueste zuerst (für die Anzeige in den Einstellungen).
final mwstSaetzeProvider = FutureProvider<List<MwstSatz>>((ref) async {
  final saetze = await MwstSatzService.laden();
  final sorted = [...saetze]..sort((a, b) => b.gueltigAb.compareTo(a.gueltigAb));
  return sorted;
});
