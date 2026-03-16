import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.client.auth.onAuthStateChange;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  ref.watch(authStateProvider);
  return SupabaseService.isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return SupabaseService.currentUser;
});
