import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sbs_projer_app/app.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/storage/isar_service_export.dart';
import 'package:sbs_projer_app/services/connectivity/connectivity_service.dart';
import 'package:sbs_projer_app/services/sync/sync_service_export.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('de_CH');

  await dotenv.load(fileName: '.env');
  await SupabaseService.initialize();

  // Früh auf Recovery-Event lauschen (bevor runApp)
  SupabaseService.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      SupabaseService.pendingPasswordRecovery = true;
    }
  });

  // Session refreshen (Web + Native)
  if (SupabaseService.isAuthenticated) {
    try {
      await SupabaseService.client.auth.refreshSession();
    } catch (_) {
      await SupabaseService.client.auth.signOut();
    }
  }

  if (!kIsWeb) {
    await IsarService.initialize();
    await ConnectivityService.initialize();

    if (SupabaseService.isAuthenticated) {
      SyncService.startListening();
      if (ConnectivityService.isOnline) {
        SyncService.syncAll();
      }
    }
  }

  runApp(
    const ProviderScope(
      child: SbsProjerApp(),
    ),
  );
}
