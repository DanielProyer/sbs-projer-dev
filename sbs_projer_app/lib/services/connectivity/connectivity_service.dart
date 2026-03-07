import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static bool _isOnline = false;
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  static bool get isOnline => _isOnline;

  static final StreamController<bool> _controller =
      StreamController<bool>.broadcast();
  static Stream<bool> get onConnectivityChanged => _controller.stream;

  static Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = _checkResults(results);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _checkResults(results);
      if (_isOnline != wasOnline) {
        _controller.add(_isOnline);
      }
    });
  }

  static bool _checkResults(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  static void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
