// lib/presentation/providers/geschaeft_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/data/models/geschaeft_einstellungen.dart';
import 'package:sbs_projer_app/data/repositories/geschaeft_repository.dart';

final geschaeftProvider = FutureProvider<GeschaeftEinstellungen>((ref) {
  return GeschaeftRepository.get();
});
