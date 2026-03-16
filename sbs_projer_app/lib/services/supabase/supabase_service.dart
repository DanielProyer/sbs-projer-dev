import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  static User? get currentUser => client.auth.currentUser;

  static bool get isAuthenticated => currentUser != null;

  static bool get isGuest => currentUser?.email == 'gast@sbsprojer.ch';

  static String get dataUserId {
    if (isGuest) {
      return dotenv.env['DANIEL_USER_ID'] ?? currentUser!.id;
    }
    return currentUser!.id;
  }

  static const _webAppUrl = 'https://danielproyer.github.io/sbs-projer-dev/';

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: _webAppUrl,
    );
  }

  static Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Flag: Passwort-Recovery erkannt (wird in main() gesetzt)
  static bool pendingPasswordRecovery = false;

  static GoRouterRefreshStream? _authNotifier;
  static GoRouterRefreshStream get authNotifier {
    _authNotifier ??= GoRouterRefreshStream(
      client.auth.onAuthStateChange,
    );
    return _authNotifier!;
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;

  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
