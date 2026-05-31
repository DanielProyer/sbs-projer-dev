# Termin-Erinnerungen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pro Termin aktivierbare Erinnerungen mit frei wählbarer Vorlaufzeit — auf Android als echte lokale System-Benachrichtigung (auch bei geschlossener App), in der Web-App als Browser-Notification + In-App-Hinweis (solange App offen), ohne Push-Server.

**Architecture:** Neue DB-Felder `erinnerung_aktiv` + `erinnerung_vorlauf_minuten`. Ein `ReminderService` über Conditional Export (native: `flutter_local_notifications`; web: `Timer` + Web Notification API). Repository ruft schedule/cancel bei save/delete. App-Start plant alle zukünftigen Erinnerungen neu (Android) bzw. startet den Web-Scheduler. Reine Zeitpunkt-Berechnung als testbare Funktion.

**Tech Stack:** Flutter, Supabase, Isar (offline-first), Riverpod, `flutter_local_notifications`, `timezone`, `dart:html` (Web Notification API).

**Projekt-Konvention:** Kein durchgängiges TDD. TDD nur für die reine Logik (Task 3). Plattform-/UI-Code wird via `flutter analyze` (0 Errors) + manuellem Test verifiziert. Build/Deploy nach CLAUDE.md. Build-Verzeichnis: `sbs_projer_app`. Flutter-PATH: `export PATH="$PATH:/c/flutter/bin"`.

---

## Task 1: DB-Migration (neue Spalten)

**Files:**
- Create: `Datenbank/migrations/086_termin_erinnerung.sql`

- [ ] **Step 1: Migrationsdatei schreiben**

```sql
-- 086_termin_erinnerung.sql
-- Erinnerungsfunktion für Termine: aktivierbar pro Termin + Vorlaufzeit in Minuten.
ALTER TABLE termine
  ADD COLUMN IF NOT EXISTS erinnerung_aktiv boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS erinnerung_vorlauf_minuten integer NOT NULL DEFAULT 1440;
```

- [ ] **Step 2: Migration auf Prod-DB ausführen**

Via `mcp__supabase__apply_migration` (name: `086_termin_erinnerung`, query = obiger SQL) auf Projekt `pltbaqqwpnmdajwgnhpd`.

- [ ] **Step 3: Verifizieren**

`mcp__supabase__execute_sql`: `SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name='termine' AND column_name LIKE 'erinnerung%';`
Erwartet: `erinnerung_aktiv` (boolean, false), `erinnerung_vorlauf_minuten` (integer, 1440), `erinnerung_tage` (alt, bleibt).

- [ ] **Step 4: Commit**

```bash
git add Datenbank/migrations/086_termin_erinnerung.sql
git commit -m "db: termine erinnerung_aktiv + erinnerung_vorlauf_minuten (Migration 086)"
```

---

## Task 2: Datenmodell erweitern (DTO, Isar, Web-Stub, Mapper)

**Files:**
- Modify: `sbs_projer_app/lib/data/models/termin.dart`
- Modify: `sbs_projer_app/lib/data/local/termin_local.dart`
- Modify: `sbs_projer_app/lib/data/local/web/termin_local_web.dart`
- Modify: `sbs_projer_app/lib/data/mappers/termin_mapper.dart`

- [ ] **Step 1: DTO `termin.dart` um Felder erweitern**

Felder ergänzen (nach `erinnerungTage`):
```dart
  final bool erinnerungAktiv;
  final int erinnerungVorlaufMinuten;
```
Konstruktor-Parameter: `this.erinnerungAktiv = false,` und `this.erinnerungVorlaufMinuten = 1440,`.
`fromJson`: `erinnerungAktiv: json['erinnerung_aktiv'] ?? false,` und `erinnerungVorlaufMinuten: json['erinnerung_vorlauf_minuten'] ?? 1440,`.
`toJson`: `'erinnerung_aktiv': erinnerungAktiv,` und `'erinnerung_vorlauf_minuten': erinnerungVorlaufMinuten,`.

- [ ] **Step 2: Isar-Model `termin_local.dart` erweitern**

Nach `int erinnerungTage = 3;`:
```dart
  bool erinnerungAktiv = false;
  int erinnerungVorlaufMinuten = 1440;
```

- [ ] **Step 3: Web-Stub `termin_local_web.dart` identisch erweitern**

Dieselben zwei Felder mit Defaults wie in Step 2 (Plain-Dart-Klasse, keine Annotationen).

- [ ] **Step 4: Mapper `termin_mapper.dart` erweitern**

In `fromDto` (Local← DTO): `..erinnerungAktiv = dto.erinnerungAktiv` und `..erinnerungVorlaufMinuten = dto.erinnerungVorlaufMinuten`.
In `toJson`/`toDto` (Local→ DTO/JSON): die beiden Felder durchreichen (analog zu `erinnerungTage`). Beide Map-Keys: `erinnerung_aktiv`, `erinnerung_vorlauf_minuten`.

- [ ] **Step 5: Isar-Code generieren**

```bash
export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && dart run build_runner build --delete-conflicting-outputs
```
Erwartet: `termin_local.g.dart` regeneriert, keine Fehler.

- [ ] **Step 6: Analyze**

`export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze lib/data/models/termin.dart lib/data/local/termin_local.dart lib/data/local/web/termin_local_web.dart lib/data/mappers/termin_mapper.dart`
Erwartet: No issues.

- [ ] **Step 7: Commit**

```bash
git add sbs_projer_app/lib/data/models/termin.dart sbs_projer_app/lib/data/local/termin_local.dart sbs_projer_app/lib/data/local/web/termin_local_web.dart sbs_projer_app/lib/data/mappers/termin_mapper.dart sbs_projer_app/lib/data/local/termin_local.g.dart
git commit -m "model: Termin um erinnerungAktiv + erinnerungVorlaufMinuten erweitern"
```

---

## Task 3: Erinnerungszeitpunkt-Berechnung (reine Funktion, TDD)

Reine Logik, gut testbar. Ergibt den absoluten `DateTime?` der Erinnerung aus Datum, optionaler Uhrzeit und Vorlauf.

**Files:**
- Create: `sbs_projer_app/lib/services/notification/reminder_time.dart`
- Create: `sbs_projer_app/test/reminder_time_test.dart`

- [ ] **Step 1: Failing Test schreiben**

`test/reminder_time_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sbs_projer_app/services/notification/reminder_time.dart';

void main() {
  group('berechneErinnerungszeitpunkt', () {
    test('mit Uhrzeit: Datum+Uhrzeit minus Vorlauf', () {
      final r = berechneErinnerungszeitpunkt(
        datum: DateTime(2026, 6, 10),
        uhrzeitVon: '14:30',
        vorlaufMinuten: 60,
      );
      expect(r, DateTime(2026, 6, 10, 13, 30));
    });

    test('ohne Uhrzeit: 08:00 als Bezug minus Vorlauf', () {
      final r = berechneErinnerungszeitpunkt(
        datum: DateTime(2026, 6, 10),
        uhrzeitVon: null,
        vorlaufMinuten: 1440,
      );
      expect(r, DateTime(2026, 6, 9, 8, 0));
    });

    test('Vorlauf 0: exakt zum Termin', () {
      final r = berechneErinnerungszeitpunkt(
        datum: DateTime(2026, 6, 10),
        uhrzeitVon: '09:15',
        vorlaufMinuten: 0,
      );
      expect(r, DateTime(2026, 6, 10, 9, 15));
    });

    test('ungueltige Uhrzeit faellt auf 08:00 zurueck', () {
      final r = berechneErinnerungszeitpunkt(
        datum: DateTime(2026, 6, 10),
        uhrzeitVon: 'abc',
        vorlaufMinuten: 0,
      );
      expect(r, DateTime(2026, 6, 10, 8, 0));
    });
  });
}
```

- [ ] **Step 2: Test ausführen, Fehlschlag bestätigen**

`export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/reminder_time_test.dart`
Erwartet: FAIL (Funktion/Datei existiert nicht).

- [ ] **Step 3: Implementierung schreiben**

`lib/services/notification/reminder_time.dart`:
```dart
/// Berechnet den absoluten Zeitpunkt einer Termin-Erinnerung.
///
/// Bei vorhandener [uhrzeitVon] (Format "HH:mm") wird Datum+Uhrzeit als Bezug
/// genommen, sonst 08:00 am Termintag. Davon wird [vorlaufMinuten] abgezogen.
/// Ungueltige Uhrzeit -> 08:00.
DateTime berechneErinnerungszeitpunkt({
  required DateTime datum,
  required String? uhrzeitVon,
  required int vorlaufMinuten,
}) {
  int stunde = 8, minute = 0;
  if (uhrzeitVon != null && uhrzeitVon.contains(':')) {
    final teile = uhrzeitVon.split(':');
    final h = int.tryParse(teile[0]);
    final m = teile.length > 1 ? int.tryParse(teile[1]) : 0;
    if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
      stunde = h;
      minute = m;
    }
  }
  final bezug = DateTime(datum.year, datum.month, datum.day, stunde, minute);
  return bezug.subtract(Duration(minutes: vorlaufMinuten));
}

/// Vordefinierte Vorlauf-Optionen (Minuten -> Label) fuer das UI.
const Map<int, String> erinnerungVorlaufOptionen = {
  0: 'Punktlich',
  15: '15 Minuten vorher',
  30: '30 Minuten vorher',
  60: '1 Stunde vorher',
  120: '2 Stunden vorher',
  1440: '1 Tag vorher',
  2880: '2 Tage vorher',
  4320: '3 Tage vorher',
  10080: '1 Woche vorher',
};
```

- [ ] **Step 4: Test ausführen, Erfolg bestätigen**

`export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter test test/reminder_time_test.dart`
Erwartet: PASS (4 Tests).

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/notification/reminder_time.dart sbs_projer_app/test/reminder_time_test.dart
git commit -m "feat: Erinnerungszeitpunkt-Berechnung + Vorlauf-Optionen (mit Tests)"
```

---

## Task 4: ReminderService-Schnittstelle + Conditional Export

**Files:**
- Create: `sbs_projer_app/lib/services/notification/reminder_service.dart` (native default)
- Create: `sbs_projer_app/lib/services/notification/reminder_service_web.dart`
- Create: `sbs_projer_app/lib/services/notification/reminder_service_export.dart`

Schnittstelle (statische Methoden, analog Projekt-Pattern):
- `Future<void> init()` — initialisiert Plugin (native) / no-op (web)
- `Future<bool> requestPermission()`
- `Future<void> schedule(TerminLocal t)` — plant/aktualisiert; bei `!erinnerungAktiv` oder Vergangenheit → cancel
- `Future<void> cancel(String routeId)`
- `Future<void> rescheduleAll(List<TerminLocal> termine)`

- [ ] **Step 1: Export-Datei erstellen**

`reminder_service_export.dart`:
```dart
export 'reminder_service.dart'
  if (dart.library.html) 'reminder_service_web.dart';
```

- [ ] **Step 2: Native-Grundgerüst (Stub, wird in Task 5 gefüllt)**

`reminder_service.dart` mit Klasse `ReminderService` und allen Methoden als Signaturen, vorerst leere `Future.value()`-Rümpfe + `TODO(Task5)`-Kommentar. (Wird in Task 5 implementiert; hier nur damit Export/Imports kompilieren.)

- [ ] **Step 3: Web-Grundgerüst (Stub, wird in Task 6 gefüllt)**

`reminder_service_web.dart` mit identischer Klassen-Signatur, leere Rümpfe + `TODO(Task6)`.

- [ ] **Step 4: Analyze**

`flutter analyze lib/services/notification/` → No issues.

- [ ] **Step 5: Commit**

```bash
git add sbs_projer_app/lib/services/notification/reminder_service*.dart
git commit -m "feat: ReminderService-Schnittstelle + Conditional Export (Grundgeruest)"
```

---

## Task 5: Native-Implementierung (flutter_local_notifications)

**Files:**
- Modify: `sbs_projer_app/pubspec.yaml` (Pakete)
- Modify: `sbs_projer_app/lib/services/notification/reminder_service.dart`
- Modify: `sbs_projer_app/android/app/src/main/AndroidManifest.xml`
- Modify: `sbs_projer_app/android/app/build.gradle` (falls desugaring nötig)

- [ ] **Step 1: Pakete hinzufügen**

In `pubspec.yaml` unter `dependencies`:
```yaml
  flutter_local_notifications: ^18.0.1
  timezone: ^0.9.4
```
Dann: `export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter pub get`

- [ ] **Step 2: Android-Manifest-Berechtigungen**

In `AndroidManifest.xml` innerhalb `<manifest>` (vor `<application>`):
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```
Innerhalb `<application>` die Receiver von flutter_local_notifications für Boot-Reschedule:
```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

- [ ] **Step 3: Core-Library-Desugaring aktivieren (für flutter_local_notifications v18)**

In `android/app/build.gradle`: `compileOptions { coreLibraryDesugaringEnabled true }` + `dependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4' }`. `minSdk` >= 21 sicherstellen.

- [ ] **Step 4: Native ReminderService implementieren**

`reminder_service.dart`:
```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/services/notification/reminder_time.dart';

class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static int _idFor(String routeId) => routeId.hashCode & 0x7fffffff;

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Zurich'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
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
    await _plugin.cancel(_idFor(routeId));
  }

  static Future<void> schedule(TerminLocal t) async {
    await init();
    await cancel(t.routeId);
    if (!t.erinnerungAktiv) return;
    final when = berechneErinnerungszeitpunkt(
      datum: t.datum, uhrzeitVon: t.uhrzeitVon,
      vorlaufMinuten: t.erinnerungVorlaufMinuten);
    if (when.isBefore(DateTime.now())) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'termine', 'Termin-Erinnerungen',
        channelDescription: 'Erinnerungen an wichtige Termine',
        importance: Importance.max, priority: Priority.high));
    await _plugin.zonedSchedule(
      _idFor(t.routeId),
      t.titel,
      _body(t),
      tz.TZDateTime.from(when, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static String _body(TerminLocal t) {
    final d = '${t.datum.day.toString().padLeft(2,'0')}.${t.datum.month.toString().padLeft(2,'0')}.${t.datum.year}';
    return t.uhrzeitVon != null ? '$d, ${t.uhrzeitVon}' : d;
  }

  static Future<void> rescheduleAll(List<TerminLocal> termine) async {
    await init();
    await _plugin.cancelAll();
    for (final t in termine) {
      if (t.erinnerungAktiv) await schedule(t);
    }
  }
}
```

- [ ] **Step 5: Analyze**

`flutter analyze lib/services/notification/reminder_service.dart` → No issues.

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/pubspec.yaml sbs_projer_app/pubspec.lock sbs_projer_app/lib/services/notification/reminder_service.dart sbs_projer_app/android/
git commit -m "feat: native Termin-Erinnerungen via flutter_local_notifications"
```

---

## Task 6: Web-Implementierung (Notification API + Timer)

**Files:**
- Modify: `sbs_projer_app/lib/services/notification/reminder_service_web.dart`

Ansatz: In-Memory-Liste der aktiven Termine + `Timer.periodic(60s)`. Bei Fälligkeit: Browser-Notification (falls Permission) + Callback für In-App-Hinweis. Ausgelöste IDs in `window.localStorage` (Key `fired_reminders`) gegen Doppelauslösung.

- [ ] **Step 1: Web ReminderService implementieren**

`reminder_service_web.dart`:
```dart
import 'dart:async';
import 'dart:html' as html;
import 'package:sbs_projer_app/data/local/termin_local_export.dart';
import 'package:sbs_projer_app/services/notification/reminder_time.dart';

class ReminderService {
  static final Map<String, _Reminder> _aktiv = {};
  static Timer? _timer;
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
      datum: t.datum, uhrzeitVon: t.uhrzeitVon,
      vorlaufMinuten: t.erinnerungVorlaufMinuten);
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
      if (fired.contains(r.id)) { _aktiv.remove(r.id); continue; }
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
    // begrenzen, damit localStorage nicht unbegrenzt waechst
    final list = s.toList();
    final trimmed = list.length > 500 ? list.sublist(list.length - 500) : list;
    html.window.localStorage['fired_reminders'] = trimmed.join('|');
  }

  static String _body(TerminLocal t) {
    final d = '${t.datum.day.toString().padLeft(2,'0')}.${t.datum.month.toString().padLeft(2,'0')}.${t.datum.year}';
    return t.uhrzeitVon != null ? '$d, ${t.uhrzeitVon}' : d;
  }
}

class _Reminder {
  final String id, titel, body;
  final DateTime when;
  _Reminder(this.id, this.titel, this.body, this.when);
}
```

Hinweis: `fired`-IDs nutzen `routeId` (serverId auf Web) — über Tage stabil. Damit eine geänderte Erinnerung erneut feuern kann, wird die ID beim Speichern eines Termins NICHT aus `fired` entfernt (v1-Einschränkung: erneut-feuern erst nach Aufgabe der Idempotenz — akzeptiert, da selten).

- [ ] **Step 2: Analyze (auf Web-Lib achten)**

`flutter analyze lib/services/notification/reminder_service_web.dart` → No issues. (`dart:html` ist auf Web ok; analyze läuft generisch.)

- [ ] **Step 3: Commit**

```bash
git add sbs_projer_app/lib/services/notification/reminder_service_web.dart
git commit -m "feat: Web-Termin-Erinnerungen via Notification API + Timer-Scheduler"
```

---

## Task 7: Integration (Repository + App-Start)

**Files:**
- Modify: `sbs_projer_app/lib/data/repositories/termin_repository.dart`
- Modify: `sbs_projer_app/lib/main.dart`

- [ ] **Step 1: Repository — schedule/cancel bei save/delete**

Import ergänzen: `import 'package:sbs_projer_app/services/notification/reminder_service_export.dart';`
In `save(...)` am Ende (nach Persistenz, vor `return`/Funktionsende): `await ReminderService.schedule(termin);`
In `delete(String id)` VOR der Löschung den Termin laden, um `routeId` zu kennen, dann nach dem Löschen `await ReminderService.cancel(routeId);`. Konkret am Anfang von `delete`:
```dart
    final toCancel = await getById(id);
```
und am Ende:
```dart
    if (toCancel != null) await ReminderService.cancel(toCancel.routeId);
```
(Beide Branches web/native abgedeckt, da `getById` beides kann.)

- [ ] **Step 2: App-Start — rescheduleAll + Permission**

In `main.dart`, wo nach Login `SyncService.syncAll()` läuft (Zeile ~44) ergänzen — nach erfolgreichem Laden der Termine:
```dart
      await ReminderService.init();
      final termine = await TerminRepository.getAll();
      await ReminderService.rescheduleAll(termine);
```
Import `TerminRepository` + `ReminderService` + (für Web-In-App-Hinweis) Registrierung von `ReminderService.onInApp` siehe Task 8 Step 3. Permission-Anforderung: einmalig beim ersten Aktivieren einer Erinnerung im Form (Task 8), nicht beim Start erzwingen.

- [ ] **Step 3: Analyze**

`flutter analyze lib/data/repositories/termin_repository.dart lib/main.dart` → No issues.

- [ ] **Step 4: Commit**

```bash
git add sbs_projer_app/lib/data/repositories/termin_repository.dart sbs_projer_app/lib/main.dart
git commit -m "feat: ReminderService an Termin-save/delete + App-Start anbinden"
```

---

## Task 8: UI (Formular-Toggle + Vorlauf-Dropdown, Kalender-Icon, Web-In-App-Hinweis)

**Files:**
- Modify: `sbs_projer_app/lib/presentation/screens/termine/termin_form_screen.dart`
- Modify: `sbs_projer_app/lib/presentation/screens/termine/termine_kalender_screen.dart`
- Modify: `sbs_projer_app/lib/main.dart` (In-App-Hinweis-Callback registrieren)

- [ ] **Step 1: Formular — State + Widgets**

State-Variablen ergänzen: `bool _erinnerungAktiv = false;` `int _erinnerungVorlauf = 1440;`. Beim Laden eines bestehenden Termins aus dem Local-Objekt befüllen. Import `reminder_time.dart` für `erinnerungVorlaufOptionen`.
UI (passend zum bestehenden Form-Stil, z.B. nach Notizen):
```dart
SwitchListTile(
  title: const Text('Erinnerung'),
  value: _erinnerungAktiv,
  onChanged: (v) async {
    if (v) {
      final ok = await ReminderService.requestPermission();
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Benachrichtigungen nicht erlaubt — Erinnerung wird gespeichert, aber evtl. nicht angezeigt.')));
      }
    }
    setState(() => _erinnerungAktiv = v);
  },
),
if (_erinnerungAktiv)
  DropdownButtonFormField<int>(
    initialValue: _erinnerungVorlauf,
    decoration: const InputDecoration(labelText: 'Vorlaufzeit'),
    items: erinnerungVorlaufOptionen.entries
      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
      .toList(),
    onChanged: (v) => setState(() => _erinnerungVorlauf = v ?? 1440),
  ),
```
Import `reminder_service_export.dart` für `ReminderService.requestPermission`.

- [ ] **Step 2: Formular — Speichern**

Beim Erstellen/Aktualisieren des `TerminLocal` vor `TerminRepository.save(...)`:
```dart
  ..erinnerungAktiv = _erinnerungAktiv
  ..erinnerungVorlaufMinuten = _erinnerungVorlauf
```
(save ruft intern bereits `ReminderService.schedule` auf — Task 7.)

- [ ] **Step 3: Web-In-App-Hinweis-Callback in main.dart**

In `main.dart` nach `ReminderService.init()` (Task 7) bzw. im App-Widget einen globalen Callback registrieren, der ein SnackBar/Dialog via globalem `ScaffoldMessengerKey` zeigt:
```dart
  ReminderService.onInApp = (titel, body) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('Erinnerung: $titel ($body)'),
        duration: const Duration(seconds: 10)));
  };
```
`rootScaffoldMessengerKey` (GlobalKey<ScaffoldMessengerState>) anlegen und der `MaterialApp.scaffoldMessengerKey` zuweisen. (Auf native ist `onInApp` ungenutzt — schadet nicht.)

- [ ] **Step 4: Kalender — Glocken-Icon**

In `termine_kalender_screen.dart` bei der Termin-Listenzeile: wenn `termin.erinnerungAktiv`, ein `Icon(Icons.notifications_active, size: 16)` neben dem Titel anzeigen.

- [ ] **Step 5: Analyze**

`flutter analyze lib/presentation/screens/termine/ lib/main.dart` → No issues.

- [ ] **Step 6: Commit**

```bash
git add sbs_projer_app/lib/presentation/screens/termine/ sbs_projer_app/lib/main.dart
git commit -m "feat: UI fuer Termin-Erinnerungen (Toggle, Vorlauf, Kalender-Icon, Web-Hinweis)"
```

---

## Task 9: Sync-Felder prüfen, Gesamt-Analyze, Build & Deploy

**Files:**
- Review: `sbs_projer_app/lib/services/sync/sync_service.dart`
- Modify: `sbs_projer_app/pubspec.yaml` (Version-Bump)

- [ ] **Step 1: Sync prüfen**

Sicherstellen, dass der Termin-Push/Pull die neuen Felder mitführt. Da Sync über `TerminMapper.toJson`/`fromDto` läuft (Task 2), sollte das automatisch erfolgen. Falls der SyncService Termine über explizite Feldlisten serialisiert: `erinnerung_aktiv`, `erinnerung_vorlauf_minuten` ergänzen. Grep: `grep -n "erinnerung\|termin" lib/services/sync/sync_service.dart`.

- [ ] **Step 2: Gesamt-Analyze (vollständig, nicht `| tail`)**

`export PATH="$PATH:/c/flutter/bin" && cd sbs_projer_app && flutter analyze 2>&1 | grep -E "error -" | head -50` → keine Ausgabe (0 Errors). Zusätzlich `flutter test test/reminder_time_test.dart` → PASS.

- [ ] **Step 3: Version-Bump**

In `pubspec.yaml` Zeile 4: Version + Build-Nummer erhöhen (z.B. `0.10.106+388`).

- [ ] **Step 4: Manueller Test (Web)**

`flutter run -d edge` → Termin anlegen, Erinnerung aktivieren, Vorlauf „Pünktlich", Datum/Uhrzeit ~2 Min in der Zukunft. Browser-Notification-Erlaubnis bestätigen. Warten → Browser-Notification + In-App-SnackBar erscheinen. Glocken-Icon im Kalender sichtbar.

- [ ] **Step 5: Build + Deploy (nach CLAUDE.md)**

Web-Build (`--pwa-strategy=none`), Cache-Bust, gh-pages-Deploy, beide Branches pushen. Commit-Message: `deploy vX.Y.Z — Termin-Erinnerungen`.

- [ ] **Step 6: Commit (Version-Bump, falls nicht im Deploy enthalten)**

```bash
git add sbs_projer_app/pubspec.yaml
git commit -m "chore: Version-Bump fuer Termin-Erinnerungen"
```

---

## Hinweise zur Ausführung

- **Android-Test** erfordert ein echtes Gerät/Emulator; falls nicht verfügbar, native Funktion nur via `flutter analyze` + Code-Review absichern und Android-Verhalten beim nächsten APK-Build prüfen.
- **Web `dart:html`**: Deprecation-Warnungen möglich (package:web ist neuer). Für Konsistenz mit bestehendem Code (der bereits `dart:html` nutzt, z.B. camt-Import) bleibt `dart:html` ok.
- **Zeitzone**: fix `Europe/Zurich` (Projekt ist CH-spezifisch).
