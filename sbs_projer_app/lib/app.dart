import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sbs_projer_app/core/config/router.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/repositories/termin_repository.dart';
import 'package:sbs_projer_app/services/notification/reminder_service_export.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Globaler Messenger-Key, damit Termin-Erinnerungen (Web) einen In-App-Hinweis
/// anzeigen koennen, ohne einen konkreten BuildContext zu kennen.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SbsProjerApp extends StatefulWidget {
  const SbsProjerApp({super.key});

  @override
  State<SbsProjerApp> createState() => _SbsProjerAppState();
}

class _SbsProjerAppState extends State<SbsProjerApp> {
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();

    // Listener für zukünftige Recovery-Events
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _triggerPasswordDialog();
      }
    });

    // Flag prüfen (Event kam schon vor runApp)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SupabaseService.pendingPasswordRecovery) {
        SupabaseService.pendingPasswordRecovery = false;
        _triggerPasswordDialog();
      }
    });

    _initReminders();
  }

  /// Termin-Erinnerungen beim App-Start neu planen.
  /// Web: In-App-Hinweis ueber den globalen Messenger. Native: System-Notifications.
  Future<void> _initReminders() async {
    if (!SupabaseService.isAuthenticated) return;
    ReminderService.onInApp = (titel, body) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Erinnerung: $titel ($body)'),
          duration: const Duration(seconds: 10),
        ),
      );
    };
    try {
      await ReminderService.init();
      final termine = await TerminRepository.getAll();
      await ReminderService.rescheduleAll(termine);
    } catch (e) {
      debugPrint('[ReminderService] rescheduleAll fehlgeschlagen: $e');
    }
  }

  void _triggerPasswordDialog() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final ctx = router.routerDelegate.navigatorKey.currentContext;
      if (ctx != null) _showUpdatePasswordDialog(ctx);
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _showUpdatePasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Neues Passwort setzen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Neues Passwort',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outlined),
              ),
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                labelText: 'Passwort bestätigen',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outlined),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwort muss mindestens 6 Zeichen haben')),
                );
                return;
              }
              if (passwordController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwörter stimmen nicht überein')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.updatePassword(passwordController.text);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwort erfolgreich geändert')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }

    passwordController.dispose();
    confirmController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SBS Projer',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
