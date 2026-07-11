import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class GoogleCalendarStatus {
  final bool connected;
  final String? email;
  const GoogleCalendarStatus({required this.connected, this.email});
}

final googleCalendarStatusProvider =
    FutureProvider<GoogleCalendarStatus>((ref) async {
  final rows = await SupabaseService.client
      .from('google_calendar_status')
      .select()
      .limit(1);
  if (rows.isEmpty) return const GoogleCalendarStatus(connected: false);
  final r = rows.first;
  return GoogleCalendarStatus(
    connected: r['connected'] == true,
    email: r['google_email'] as String?,
  );
});
