import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sbs_projer_app/core/util/reinigung_entwurf.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lokale Ablage der Entwürfe laufender Reinigungen — einer je Betrieb
/// (V2, siehe [ReinigungEntwurf]).
///
/// `shared_preferences` statt Isar/Supabase: reines Übergangsmaterial, das
/// nur den verworfenen Browser-Tab überbrücken soll. Jeder Zugriff ist in
/// try/catch gekapselt — im Privatmodus oder bei gesperrtem Speicher tut die
/// Ablage so, als gäbe es keinen Entwurf. Das Formular funktioniert dann wie
/// vor V2, nur ohne Netz.
class ReinigungEntwurfSpeicher {
  static const praefix = 'entwurf_reinigung_';

  static String _schluessel(String betriebId) => '$praefix$betriebId';

  static ReinigungEntwurf? _lesen(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return ReinigungEntwurf.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Alle noch gültigen Entwürfe, neueste zuerst (für die Heute-Seite).
  /// Abgelaufene und unlesbare werden dabei gleich entfernt.
  static Future<List<({String betriebId, DateTime gespeichertAm})>>
  alleOffen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jetzt = DateTime.now();
      final offen = <({String betriebId, DateTime gespeichertAm})>[];
      final keys = prefs.getKeys().where((k) => k.startsWith(praefix)).toList();
      for (final key in keys) {
        final e = _lesen(prefs, key);
        if (e == null || e.betriebId.isEmpty || e.istAbgelaufen(jetzt)) {
          await prefs.remove(key);
          continue;
        }
        offen.add((betriebId: e.betriebId, gespeichertAm: e.gespeichertAm));
      }
      offen.sort((a, b) => b.gespeichertAm.compareTo(a.gespeichertAm));
      return offen;
    } catch (e) {
      debugPrint('[Entwurf] alleOffen fehlgeschlagen: $e');
      return const [];
    }
  }

  /// Entwurf für [betriebId] oder null (keiner, abgelaufen, unlesbar).
  /// Ein abgelaufener wird dabei entfernt.
  static Future<ReinigungEntwurf?> laden(String betriebId) async {
    if (betriebId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _schluessel(betriebId);
      final e = _lesen(prefs, key);
      if (e == null) return null;
      if (e.istAbgelaufen(DateTime.now())) {
        await prefs.remove(key);
        return null;
      }
      return e;
    } catch (e) {
      debugPrint('[Entwurf] laden fehlgeschlagen: $e');
      return null;
    }
  }

  /// Überschreibt den Entwurf des Betriebs (letzter Stand gewinnt).
  static Future<void> speichern(ReinigungEntwurf e) async {
    if (e.betriebId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_schluessel(e.betriebId), jsonEncode(e.toJson()));
    } catch (err) {
      debugPrint('[Entwurf] speichern fehlgeschlagen: $err');
    }
  }

  static Future<void> loeschen(String betriebId) async {
    if (betriebId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_schluessel(betriebId));
    } catch (e) {
      debugPrint('[Entwurf] loeschen fehlgeschlagen: $e');
    }
  }
}
