import 'dart:async';

enum SyncState { idle, syncing, error }

class SyncResult {
  final int pushed;
  final int pulled;
  final List<String> errors;

  SyncResult({this.pushed = 0, this.pulled = 0, List<String>? errors})
      : errors = errors ?? [];

  bool get hasErrors => errors.isNotEmpty;
}

class SyncService {
  static final _stateController = StreamController<SyncState>.broadcast();
  static Stream<SyncState> get stateStream => _stateController.stream;
  static SyncState get state => SyncState.idle;

  static void startListening() {}
  static void stopListening() {}
  static Future<SyncResult> syncAll() async => SyncResult();
}
