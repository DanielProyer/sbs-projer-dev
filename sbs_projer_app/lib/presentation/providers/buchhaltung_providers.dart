import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Erfolgsrechnung aus DB-View (monatlich/jährlich).
final erfolgsrechnungProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, jahr) async {
  final rows = await SupabaseService.client
      .from('view_erfolgsrechnung')
      .select()
      .eq('geschaeftsjahr', jahr)
      .order('monat');
  return List<Map<String, dynamic>>.from(rows);
});

/// MwSt-Abrechnung aus DB-View (quartalsweise).
final mwstAbrechnungProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, jahr) async {
  final rows = await SupabaseService.client
      .from('view_mwst_abrechnung')
      .select()
      .eq('geschaeftsjahr', jahr)
      .order('quartal');
  return List<Map<String, dynamic>>.from(rows);
});

/// Offene Rechnungen aus DB-View.
final offeneRechnungenViewProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from('view_offene_rechnungen')
      .select()
      .order('faelligkeitsdatum');
  return List<Map<String, dynamic>>.from(rows);
});
