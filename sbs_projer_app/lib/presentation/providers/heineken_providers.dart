import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/data/repositories/rechnung_repository.dart';

/// Alle Heineken-Monatsrechnungen (rechnungstyp='heineken_monat').
final heinekenRechnungenProvider =
    FutureProvider<List<Rechnung>>((ref) async {
  final all = await RechnungRepository.getAll();
  return all.where((r) => r.rechnungstyp == 'heineken_monat').toList();
});
