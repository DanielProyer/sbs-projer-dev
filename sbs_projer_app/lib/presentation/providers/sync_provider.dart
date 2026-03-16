import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/sync/sync_service_export.dart';

final syncStateProvider = StreamProvider<SyncState>((ref) {
  if (kIsWeb) return Stream.value(SyncState.idle);

  final controller = StreamController<SyncState>();
  controller.add(SyncService.state);

  final subscription = SyncService.stateStream.listen((state) {
    controller.add(state);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

final isSyncingProvider = Provider<bool>((ref) {
  if (kIsWeb) return false;
  final state = ref.watch(syncStateProvider).valueOrNull ?? SyncService.state;
  return state == SyncState.syncing;
});
