import 'dart:async';
import 'dart:html' as html;
import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/services/notification/reminder_time.dart';

/// Termin-Erinnerungen in der Web-App. Ohne Service Worker / Push-Server:
/// ein Timer prueft (solange die App offen ist) faellige Erinnerungen und
/// loest eine Browser-Notification + In-App-Hinweis aus.
class ReminderService {
  static final Map<String, _Reminder> _aktiv = {};
  static Timer? _timer;

  /// Callback fuer den In-App-Hinweis (in main.dart registriert).
  static void Function(String titel, String body)? onInApp;

  static Future<void> init() async {
    _timer ??= Timer.periodic(const Duration(seconds: 60), (_) => _tick());
  }

  static Future<bool> requestPermission() async {
    if (html.Notification.supported) {
      final p = await html.Notification.requestPermission();
      return p == 'granted';
    }
    return false;
  }

  static Future<void> cancel(String routeId) async {
    _aktiv.remove(routeId);
  }

  static Future<void> schedule(TerminLocal t) async {
    await init();
    _aktiv.remove(t.routeId);
    if (!t.erinnerungAktiv) return;
    final when = berechneErinnerungszeitpunkt(
      datum: t.datum,
      uhrzeitVon: t.uhrzeitVon,
      vorlaufMinuten: t.erinnerungVorlaufMinuten,
    );
    if (when.isBefore(DateTime.now())) return;
    _aktiv[t.routeId] = _Reminder(t.routeId, t.titel, _body(t), when);
  }

  static Future<void> rescheduleAll(List<TerminLocal> termine) async {
    await init();
    _aktiv.clear();
    for (final t in termine) {
      if (t.erinnerungAktiv) await schedule(t);
    }
  }

  static void _tick() {
    final now = DateTime.now();
    final fired = _firedSet();
    for (final r in _aktiv.values.toList()) {
      if (r.when.isAfter(now)) continue;
      if (fired.contains(r.id)) {
        _aktiv.remove(r.id);
        continue;
      }
      _fire(r);
      fired.add(r.id);
      _saveFired(fired);
      _aktiv.remove(r.id);
    }
  }

  static void _fire(_Reminder r) {
    if (html.Notification.supported &&
        html.Notification.permission == 'granted') {
      html.Notification(r.titel, body: r.body);
    }
    onInApp?.call(r.titel, r.body);
  }

  static Set<String> _firedSet() {
    final raw = html.window.localStorage['fired_reminders'] ?? '';
    return raw.isEmpty ? <String>{} : raw.split('|').toSet();
  }

  static void _saveFired(Set<String> s) {
    final list = s.toList();
    final trimmed = list.length > 500 ? list.sublist(list.length - 500) : list;
    html.window.localStorage['fired_reminders'] = trimmed.join('|');
  }

  static String _body(TerminLocal t) {
    final d =
        '${t.datum.day.toString().padLeft(2, '0')}.${t.datum.month.toString().padLeft(2, '0')}.${t.datum.year}';
    return t.uhrzeitVon != null ? '$d, ${t.uhrzeitVon}' : d;
  }
}

class _Reminder {
  final String id, titel, body;
  final DateTime when;
  _Reminder(this.id, this.titel, this.body, this.when);
}
