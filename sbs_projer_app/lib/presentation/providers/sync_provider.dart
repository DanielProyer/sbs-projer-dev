import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/sync/sync_service.dart';

final syncStateProvider = StreamProvider<SyncState>((ref) {
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
  final state = ref.watch(syncStateProvider).valueOrNull ?? SyncService.state;
  return state == SyncState.syncing;
});
