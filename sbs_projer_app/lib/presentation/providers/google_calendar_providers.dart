import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

class GoogleCalendarStatus {
  final bool connected;
  final String? email;
  final DateTime? lastSyncAt;
  final String? scope;
  final DateTime? contactsLastSyncAt;
  final String? contactsLastSyncInfo;
  const GoogleCalendarStatus({
    required this.connected,
    this.email,
    this.lastSyncAt,
    this.scope,
    this.contactsLastSyncAt,
    this.contactsLastSyncInfo,
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
  DateTime? ts(String key) {
    final raw = r[key] as String?;
    return raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
  }

  return GoogleCalendarStatus(
    connected: r['connected'] == true,
    email: r['google_email'] as String?,
    lastSyncAt: ts('last_sync_at'),
    scope: r['scope'] as String?,
    contactsLastSyncAt: ts('contacts_last_sync_at'),
    contactsLastSyncInfo: r['contacts_last_sync_info'] as String?,
  );
});
