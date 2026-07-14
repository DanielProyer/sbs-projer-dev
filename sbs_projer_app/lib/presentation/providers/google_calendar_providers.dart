import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class GoogleCalendarStatus {
  final bool connected;
  final String? email;
  final DateTime? lastSyncAt;
  const GoogleCalendarStatus({
    required this.connected,
    this.email,
    this.lastSyncAt,
  });
}

final googleCalendarStatusProvider =
    FutureProvider<GoogleCalendarStatus>((ref) async {
  final rows = await SupabaseService.client
      .from('google_calendar_status')
      .select()
      .limit(1);
  if (rows.isEmpty) return const GoogleCalendarStatus(connected: false);
  final r = rows.first;
  final lastRaw = r['last_sync_at'] as String?;
  return GoogleCalendarStatus(
    connected: r['connected'] == true,
    email: r['google_email'] as String?,
    lastSyncAt: lastRaw != null ? DateTime.tryParse(lastRaw) : null,
  );
});
