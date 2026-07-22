import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sbs_projer_app/services/google_calendar/browser_redirect.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class GoogleCalendarVerbindenResult {
  final bool erfolg;
  final String? info; // E-Mail bei Erfolg, Fehlermeldung sonst
  const GoogleCalendarVerbindenResult(this.erfolg, this.info);
}

class GoogleCalendarAuthService {
  static const _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _scope =
      'https://www.googleapis.com/auth/calendar.events '
      'https://www.googleapis.com/auth/contacts email';

  static String get _clientId => dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ?? '';
  static String get _redirectUri =>
      dotenv.env['GOOGLE_OAUTH_REDIRECT_URI'] ??
      '${Uri.base.origin}${Uri.base.path}';

  /// Startet den Verbinden-Flow (Web): PKCE erzeugen, zu Google navigieren.
  static void verbinden() {
    final verifier = _randomString(64);
    final challenge = _s256(verifier);
    final state = _randomString(24);
    sessionSet('gcal_verifier', verifier);
    sessionSet('gcal_state', state);
    final url = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': _scope,
      'access_type': 'offline',
      'prompt': 'consent',
      'include_granted_scopes': 'true',
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    }).toString();
    navigateTo(url);
  }

  /// Beim App-Start (Web): prüft `?code`, tauscht über die Edge Function.
  /// Gibt null zurück, wenn kein OAuth-Redirect vorliegt.
  static Future<GoogleCalendarVerbindenResult?> verarbeiteRedirect() async {
    if (!kIsWeb) return null;
    final params = Uri.base.queryParameters;
    final code = params['code'];
    final state = params['state'];
    if (code == null || state == null) return null;

    final savedState = sessionGet('gcal_state');
    final verifier = sessionGet('gcal_verifier');
    clearQuery(_redirectUri); // URL immer bereinigen
    if (savedState == null || state != savedState || verifier == null) {
      return const GoogleCalendarVerbindenResult(false, 'Ungültiger State');
    }
    sessionRemove('gcal_state');
    sessionRemove('gcal_verifier');

    try {
      final res = await SupabaseService.client.functions.invoke(
        'google-oauth-exchange',
        body: {
          'code': code,
          'code_verifier': verifier,
          'redirect_uri': _redirectUri,
        },
      );
      final data = res.data;
      if (res.status != 200 || data is! Map || data['connected'] != true) {
        final msg = data is Map ? data['error']?.toString() : null;
        return GoogleCalendarVerbindenResult(false, msg ?? 'Fehler');
      }
      return GoogleCalendarVerbindenResult(true, data['email']?.toString());
    } catch (e) {
      return GoogleCalendarVerbindenResult(false, e.toString());
    }
  }

  static Future<void> trennen() async {
    await SupabaseService.client.functions.invoke('google-calendar-disconnect');
  }

  static String _s256(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String _randomString(int len) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
