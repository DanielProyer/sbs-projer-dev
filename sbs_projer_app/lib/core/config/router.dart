import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/presentation/screens/home_screen.dart';
import 'package:sbs_projer_app/presentation/screens/login_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betriebe_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlagen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlage_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlage_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/stoerungen/stoerungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/stoerungen/stoerung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/stoerungen/stoerung_form_screen.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = SupabaseService.isAuthenticated;
    final isLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginPage) return '/login';
    if (isLoggedIn && isLoginPage) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),

    // Betriebe
    GoRoute(
      path: '/betriebe',
      builder: (context, state) => const BetriebeListScreen(),
    ),
    GoRoute(
      path: '/betriebe/neu',
      builder: (context, state) => const BetriebFormScreen(),
    ),
    GoRoute(
      path: '/betriebe/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return BetriebDetailScreen(betriebId: id);
      },
    ),
    GoRoute(
      path: '/betriebe/:id/bearbeiten',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return BetriebFormScreen(betriebId: id);
      },
    ),

    // Anlagen
    GoRoute(
      path: '/anlagen',
      builder: (context, state) => const AnlagenListScreen(),
    ),
    GoRoute(
      path: '/anlagen/neu',
      builder: (context, state) {
        final betriebId = state.uri.queryParameters['betriebId']!;
        return AnlageFormScreen(betriebId: betriebId);
      },
    ),
    GoRoute(
      path: '/anlagen/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return AnlageDetailScreen(anlageId: id);
      },
    ),
    GoRoute(
      path: '/anlagen/:id/bearbeiten',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return AnlageFormScreen(anlageId: id);
      },
    ),

    // Reinigungen
    GoRoute(
      path: '/reinigungen',
      builder: (context, state) => const ReinigungenListScreen(),
    ),
    GoRoute(
      path: '/reinigungen/neu',
      builder: (context, state) {
        final anlageId = state.uri.queryParameters['anlageId']!;
        final betriebId = state.uri.queryParameters['betriebId']!;
        return ReinigungFormScreen(
            anlageId: anlageId, betriebId: betriebId);
      },
    ),
    GoRoute(
      path: '/reinigungen/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ReinigungDetailScreen(reinigungId: id);
      },
    ),
    GoRoute(
      path: '/reinigungen/:id/bearbeiten',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ReinigungFormScreen(reinigungId: id);
      },
    ),

    // Störungen
    GoRoute(
      path: '/stoerungen',
      builder: (context, state) => const StoerungenListScreen(),
    ),
    GoRoute(
      path: '/stoerungen/neu',
      builder: (context, state) {
        final anlageId = state.uri.queryParameters['anlageId']!;
        final betriebId = state.uri.queryParameters['betriebId']!;
        return StoerungFormScreen(
            anlageId: anlageId, betriebId: betriebId);
      },
    ),
    GoRoute(
      path: '/stoerungen/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return StoerungDetailScreen(stoerungId: id);
      },
    ),
    GoRoute(
      path: '/stoerungen/:id/bearbeiten',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return StoerungFormScreen(stoerungId: id);
      },
    ),
  ],
);
