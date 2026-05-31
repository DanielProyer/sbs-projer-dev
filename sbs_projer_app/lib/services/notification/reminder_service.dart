import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/services/notification/reminder_time.dart';

/// Termin-Erinnerungen auf nativen Plattformen via lokale Benachrichtigungen.
/// Funktioniert auch bei geschlossener App (kein Server).
class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Auf Web ungenutzt; hier nur fuer API-Kompatibilitaet.
  static void Function(String titel, String body)? onInApp;

  static int _idFor(String routeId) => routeId.hashCode & 0x7fffffff;

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Zurich'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? true;
    await android?.requestExactAlarmsPermission();
    return granted;
  }

  static Future<void> cancel(String routeId) async {
    await init();
    await _plugin.cancel(id: _idFor(routeId));
  }

  static Future<void> schedule(TerminLocal t) async {
    await init();
    await cancel(t.routeId);
    if (!t.erinnerungAktiv) return;
    final when = berechneErinnerungszeitpunkt(
      datum: t.datum,
      uhrzeitVon: t.uhrzeitVon,
      vorlaufMinuten: t.erinnerungVorlaufMinuten,
    );
    if (when.isBefore(DateTime.now())) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'termine',
        'Termin-Erinnerungen',
        channelDescription: 'Erinnerungen an wichtige Termine',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _plugin.zonedSchedule(
      id: _idFor(t.routeId),
      title: t.titel,
      body: _body(t),
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> rescheduleAll(List<TerminLocal> termine) async {
    await init();
    await _plugin.cancelAll();
    for (final t in termine) {
      if (t.erinnerungAktiv) await schedule(t);
    }
  }

  static String _body(TerminLocal t) {
    final d =
        '${t.datum.day.toString().padLeft(2, '0')}.${t.datum.month.toString().padLeft(2, '0')}.${t.datum.year}';
    return t.uhrzeitVon != null ? '$d, ${t.uhrzeitVon}' : d;
  }
}
