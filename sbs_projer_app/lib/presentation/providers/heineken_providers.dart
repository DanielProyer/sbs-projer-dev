import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/heineken_monats_daten.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';
import 'package:sbs_projer_app/services/rechnung/heineken_rechnung_service.dart';

/// Alle Heineken-Monatsrechnungen (rechnungstyp='heineken_monat').
final heinekenRechnungenProvider =
    FutureProvider<List<Rechnung>>((ref) async {
  final all = await RechnungRepository.getAll();
  return all.where((r) => r.rechnungstyp == 'heineken_monat').toList();
});

/// Anzahl Heineken-Rechnungen.
final heinekenRechnungCountProvider = FutureProvider<int>((ref) async {
  final list = await ref.watch(heinekenRechnungenProvider.future);
  return list.length;
});

/// Monatsdaten für die Generierung einer Heineken-Rechnung.
final heinekenMonatsDatenProvider =
    FutureProvider.family<HeinekenMonatsDaten, DateTime>((ref, monat) async {
  return HeinekenRechnungService.sammleMonatsDaten(monat);
});
