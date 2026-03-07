import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/app.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';
import 'package:sbs_projer_app/services/storage/isar_service.dart';
import 'package:sbs_projer_app/services/connectivity/connectivity_service.dart';
import 'package:sbs_projer_app/services/sync/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await SupabaseService.initialize();
  await IsarService.initialize();
  await ConnectivityService.initialize();

  // Wenn bereits eingeloggt, Sync starten
  if (SupabaseService.isAuthenticated) {
    SyncService.startListening();
    if (ConnectivityService.isOnline) {
      SyncService.syncAll(); // Fire-and-forget, läuft im Hintergrund
    }
  }

  runApp(
    const ProviderScope(
      child: SbsProjerApp(),
    ),
  );
}
