import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/connectivity/connectivity_service.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  controller.add(ConnectivityService.isOnline);

  final subscription = ConnectivityService.onConnectivityChanged.listen((online) {
    controller.add(online);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).valueOrNull ?? ConnectivityService.isOnline;
});
