import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/presentation/screens/home_screen.dart';
import 'package:sbs_projer_app/presentation/screens/login_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betriebe_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_kontakt_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_rechnungsadresse_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlagen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlage_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlage_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/bierleitung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/stoerungen/stoerungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/stoerungen/stoerung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/stoerungen/stoerung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/rechnungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/rechnung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/materialien_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/material_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/material_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/bestellliste_screen.dart';
import 'package:sbs_projer_app/presentation/screens/montagen/montagen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/montagen/montage_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/montagen/montage_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/pikett/pikett_dienste_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/pikett/pikett_dienst_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/pikett/pikett_dienst_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eigenauftraege/eigenauftrag_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eigenauftraege/eigenauftrag_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eigenauftraege/eigenauftrag_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eroeffnungsreinigungen/eroeffnungsreinigung_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eroeffnungsreinigungen/eroeffnungsreinigung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eroeffnungsreinigungen/eroeffnungsreinigung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/heineken/heineken_rechnungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/heineken/heineken_rechnung_generate_screen.dart';
import 'package:sbs_projer_app/presentation/screens/heineken/heineken_rechnung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/touren/tourenplanung_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/kontenplan_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/buchungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/buchung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/buchung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/berichte_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/mahnwesen_screen.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: SupabaseService.authNotifier,
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

    // Tourenplanung
    GoRoute(
      path: '/touren',
      builder: (context, state) => const TourenplanungScreen(),
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
        final id = state.pathParameters['id']!;
        return BetriebDetailScreen(betriebId: id);
      },
    ),
    GoRoute(
      path: '/betriebe/:id/bearbeiten',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return BetriebFormScreen(betriebId: id);
      },
    ),
    GoRoute(
      path: '/betriebe/:id/kontakte/neu',
      builder: (context, state) {
        final betriebId = state.pathParameters['id']!;
        return BetriebKontaktFormScreen(betriebId: betriebId);
      },
    ),
    GoRoute(
      path: '/betriebe/:id/kontakte/:kid/bearbeiten',
      builder: (context, state) {
        final betriebId = state.pathParameters['id']!;
        final kontaktId = state.pathParameters['kid']!;
        return BetriebKontaktFormScreen(
            betriebId: betriebId, kontaktId: kontaktId);
      },
    ),
    GoRoute(
      path: '/betriebe/:id/rechnungsadresse',
      builder: (context, state) {
        final betriebId = state.pathParameters['id']!;
        return BetriebRechnungsadresseFormScreen(betriebId: betriebId);
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
        final id = state.pathParameters['id']!;
        return AnlageDetailScreen(anlageId: id);
      },
    ),
    GoRoute(
      path: '/anlagen/:id/bearbeiten',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AnlageFormScreen(anlageId: id);
      },
    ),
    GoRoute(
      path: '/anlagen/:id/bierleitungen/neu',
      builder: (context, state) {
        final anlageId = state.pathParameters['id']!;
        return BierleitungFormScreen(anlageId: anlageId);
      },
    ),
    GoRoute(
      path: '/anlagen/:id/bierleitungen/:lid/bearbeiten',
      builder: (context, state) {
        final anlageId = state.pathParameters['id']!;
        final bierleitungId = state.pathParameters['lid']!;
        return BierleitungFormScreen(
            anlageId: anlageId, bierleitungId: bierleitungId);
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
        final id = state.pathParameters['id']!;
        return ReinigungDetailScreen(reinigungId: id);
      },
    ),
    GoRoute(
      path: '/reinigungen/:id/bearbeiten',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
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
        final anlageId = state.uri.queryParameters['anlageId'];
        final betriebId = state.uri.queryParameters['betriebId'];
        return StoerungFormScreen(
            anlageId: anlageId, betriebId: betriebId);
      },
    ),
    GoRoute(
      path: '/stoerungen/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return StoerungDetailScreen(stoerungId: id);
      },
    ),
    GoRoute(
      path: '/stoerungen/:id/bearbeiten',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return StoerungFormScreen(stoerungId: id);
      },
    ),

    // Montagen
    GoRoute(
      path: '/montagen',
      builder: (context, state) => const MontagenListScreen(),
    ),
    GoRoute(
      path: '/montagen/neu',
      builder: (context, state) {
        final anlageId = state.uri.queryParameters['anlageId'];
        final betriebId = state.uri.queryParameters['betriebId'];
        return MontageFormScreen(
            anlageId: anlageId, betriebId: betriebId);
      },
    ),
    GoRoute(
      path: '/montagen/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MontageDetailScreen(montageId: id);
      },
    ),
    GoRoute(
      path: '/montagen/:id/bearbeiten',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MontageFormScreen(montageId: id);
      },
    ),

    // Pikett
    GoRoute(
      path: '/pikett',
      builder: (context, state) => const PikettDiensteListScreen(),
    ),
    GoRoute(
      path: '/pikett/neu',
      builder: (context, state) => const PikettDienstFormScreen(),
    ),
    GoRoute(
      path: '/pikett/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PikettDienstDetailScreen(pikettId: id);
      },
    ),
    GoRoute(
      path: '/pikett/:id/bearbeiten',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PikettDienstFormScreen(pikettId: id);
      },
    ),

    // Eigenaufträge
    GoRoute(
      path: '/eigenauftraege',
      builder: (context, state) => const EigenauftragListScreen(),
    ),
    GoRoute(
      path: '/eigenauftraege/neu',
      redirect: (context, state) =>
          SupabaseService.isGuest ? '/eigenauftraege' : null,
      builder: (context, state) {
        final betriebId = state.uri.queryParameters['betriebId'];
        return EigenauftragFormScreen(betriebId: betriebId);
      },
    ),
    GoRoute(
      path: '/eigenauftraege/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EigenauftragDetailScreen(eigenauftragId: id);
      },
    ),
    GoRoute(
      path: '/eigenauftraege/:id/bearbeiten',
      redirect: (context, state) =>
          SupabaseService.isGuest ? '/eigenauftraege' : null,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EigenauftragFormScreen(eigenauftragId: id);
      },
    ),

    // Eröffnungsreinigungen
    GoRoute(
      path: '/eroeffnungsreinigungen',
      builder: (context, state) => const EroeffnungsreinigungListScreen(),
    ),
    GoRoute(
      path: '/eroeffnungsreinigungen/neu',
      redirect: (context, state) =>
          SupabaseService.isGuest ? '/eroeffnungsreinigungen' : null,
      builder: (context, state) {
        final betriebId = state.uri.queryParameters['betriebId'];
        return EroeffnungsreinigungFormScreen(betriebId: betriebId);
      },
    ),
    GoRoute(
      path: '/eroeffnungsreinigungen/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EroeffnungsreinigungDetailScreen(eroeffnungsreinigungId: id);
      },
    ),
    GoRoute(
      path: '/eroeffnungsreinigungen/:id/bearbeiten',
      redirect: (context, state) =>
          SupabaseService.isGuest ? '/eroeffnungsreinigungen' : null,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EroeffnungsreinigungFormScreen(eroeffnungsreinigungId: id);
      },
    ),

    // Heineken Monatsrechnungen
    GoRoute(
      path: '/heineken',
      builder: (context, state) => const HeinekenRechnungenListScreen(),
    ),
    GoRoute(
      path: '/heineken/neu',
      builder: (context, state) => const HeinekenRechnungGenerateScreen(),
    ),
    GoRoute(
      path: '/heineken/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return HeinekenRechnungDetailScreen(rechnungId: id);
      },
    ),

    // Rechnungen
    GoRoute(
      path: '/rechnungen',
      builder: (context, state) => const RechnungenListScreen(),
    ),
    GoRoute(
      path: '/rechnungen/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return RechnungDetailScreen(rechnungId: id);
      },
    ),

    // Buchhaltung
    GoRoute(
      path: '/buchhaltung',
      builder: (context, state) => const BuchhaltungDashboardScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/konten',
      builder: (context, state) => const KontenplanScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/buchungen',
      builder: (context, state) {
        final filterKonto = state.extra as int?;
        return BuchungenListScreen(filterKontonummer: filterKonto);
      },
    ),
    GoRoute(
      path: '/buchhaltung/buchungen/neu',
      builder: (context, state) => const BuchungFormScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/buchungen/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return BuchungDetailScreen(buchungId: id);
      },
    ),
    GoRoute(
      path: '/buchhaltung/berichte',
      builder: (context, state) => const BerichteScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/mahnwesen',
      builder: (context, state) => const MahnwesenScreen(),
    ),

    // Materialien
    GoRoute(
      path: '/materialien',
      builder: (context, state) => const MaterialienListScreen(),
    ),
    GoRoute(
      path: '/materialien/bestellliste',
      builder: (context, state) => const BestelllisteScreen(),
    ),
    GoRoute(
      path: '/materialien/neu',
      builder: (context, state) => const MaterialFormScreen(),
    ),
    GoRoute(
      path: '/materialien/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MaterialDetailScreen(materialId: id);
      },
    ),
    GoRoute(
      path: '/materialien/:id/bearbeiten',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return MaterialFormScreen(materialId: id);
      },
    ),
  ],
);
