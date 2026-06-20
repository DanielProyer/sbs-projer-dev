import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/camt_datei.dart';
import 'package:sbs_projer_app/data/repositories/camt_datei_repository.dart';

/// Alle archivierten camt-Dateien (chronologisch nach Zeitraum).
final camtDateienProvider = FutureProvider<List<CamtDatei>>((ref) {
  return CamtDateiRepository.getAll();
});

/// Letzte erfasste Periode (zeitraum_bis der jüngsten Datei) — für die Erinnerung.
final letzteCamtPeriodeProvider = FutureProvider<DateTime?>((ref) async {
  final dateien = await ref.watch(camtDateienProvider.future);
  DateTime? max;
  for (final d in dateien) {
    if (d.zeitraumBis != null && (max == null || d.zeitraumBis!.isAfter(max))) {
      max = d.zeitraumBis;
    }
  }
  return max;
});
