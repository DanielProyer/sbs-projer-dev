import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sbs_projer_app/core/config/bereiche.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/screens/bereich_screen.dart';
import 'package:sbs_projer_app/presentation/screens/einstellungen/stammdaten_screen.dart';
import 'package:sbs_projer_app/presentation/screens/home_screen.dart';
import 'package:sbs_projer_app/presentation/screens/suche/suche_screen.dart';
import 'package:sbs_projer_app/presentation/widgets/bank_waechter_karte.dart';
import 'package:sbs_projer_app/presentation/widgets/camt_erinnerung_karte.dart';
import 'package:sbs_projer_app/presentation/screens/login_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betriebe_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/saison_nachtrag_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/servicezeit_durchsicht_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_rechnungsadresse_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/betriebe/betrieb_vorschlaege_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlagen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlage_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/anlage_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/anlagen/bierleitung_form_screen.dart';
import 'package:sbs_projer_app/core/util/einsatz.dart';
import 'package:sbs_projer_app/presentation/screens/einsaetze/einsaetze_screen.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/reinigungen/reinigung_betrieb_auswahl_screen.dart';
import 'package:sbs_projer_app/presentation/screens/stoerungen/stoerung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/stoerungen/stoerung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/rechnungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/mahnfall_screen.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/mahnlauf_screen.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/offen_pro_betrieb_screen.dart';
import 'package:sbs_projer_app/presentation/screens/rechnungen/rechnung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/materialien_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/material_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/material_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/material_bestellung_screen.dart';
import 'package:sbs_projer_app/presentation/screens/materialien/material_bestellungen_screen.dart';
import 'package:sbs_projer_app/presentation/screens/montagen/montage_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/montagen/montage_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/pikett/pikett_dienst_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/pikett/pikett_dienst_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eigenauftraege/eigenauftrag_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eigenauftraege/eigenauftrag_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eroeffnungsreinigungen/eroeffnungsreinigung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eroeffnungsreinigungen/eroeffnungsreinigung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/heineken/heineken_rechnungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/heineken/heineken_rechnung_generate_screen.dart';
import 'package:sbs_projer_app/presentation/screens/heineken/heineken_rechnung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/heineken/heineken_raster_screen.dart';
import 'package:sbs_projer_app/presentation/screens/aufgaben/aufgaben_screen.dart';
import 'package:sbs_projer_app/presentation/screens/touren/tourenplanung_screen.dart';
import 'package:sbs_projer_app/presentation/screens/auswertungen/arbeitstag_auswertung_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/camt_bankauszug_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eingangsrechnungen/eingangsrechnung_liste_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eingangsrechnungen/eingangsrechnung_upload_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eingangsrechnungen/eingangsrechnung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eingangsrechnungen/kreditor_regeln_screen.dart';
import 'package:sbs_projer_app/presentation/screens/eingangsrechnungen/zahlungsfile_export_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/buchhaltung_dashboard_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/kontenplan_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/buchungen_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/buchung_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/buchung_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/berichte_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/auswertung_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/audit_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/jahrgang_abschreiben_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/monatsabschluss_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/steuern/steuerjahr_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/steuern/steuern_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/mwst_abrechnung_screen.dart';
import 'package:sbs_projer_app/presentation/screens/kontakte/kontakte_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/kontakte/kontakt_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/events/events_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/events/event_lageplan_screen.dart';
import 'package:sbs_projer_app/presentation/screens/bergkundenpauschalen/bergkundenpauschale_list_screen.dart';
import 'package:sbs_projer_app/presentation/screens/bergkundenpauschalen/bergkundenpauschale_detail_screen.dart';
import 'package:sbs_projer_app/presentation/screens/dokumente/dokumente_screen.dart';
import 'package:sbs_projer_app/presentation/screens/einstellungen/einstellungen_screen.dart';
import 'package:sbs_projer_app/presentation/screens/google_kalender/google_termine_screen.dart';
import 'package:sbs_projer_app/presentation/screens/einstellungen/preis_version_form_screen.dart';
import 'package:sbs_projer_app/presentation/screens/einstellungen/biersorten_screen.dart';
import 'package:sbs_projer_app/presentation/screens/einstellungen/regionen_screen.dart';
import 'package:sbs_projer_app/presentation/screens/jahresrechnung/jahresrechnung_generate_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/lohnlauf_screen.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/lohn_einstellungen_screen.dart';
import 'package:sbs_projer_app/presentation/screens/spesen/spesen_scanner_screen.dart';
import 'package:sbs_projer_app/presentation/screens/heineken/heineken_zuweisungen_screen.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart'
    show kSteuerJahrAb;
import 'package:sbs_projer_app/presentation/screens/auswertungen/nutzung_screen.dart';
import 'package:sbs_projer_app/services/nutzung/nutzung_service.dart';
import 'package:sbs_projer_app/services/supabase/supabase_service.dart';

/// Liest die Anlagen-Auswahl aus den Query-Parametern einer Formular-Route.
///
/// `anlageIds=a,b,c` ist der Weg für gebündelte Besuche (ein Betrieb, mehrere
/// Anlagen am selben Tag); das ältere `anlageId=a` bleibt gültig, damit die
/// Betriebsauswahl und bestehende Links unverändert funktionieren.
List<String> anlageIdsAusQuery(Map<String, String> query) {
  final mehrere = query['anlageIds'];
  if (mehrere != null && mehrere.isNotEmpty) {
    return mehrere.split(',').where((s) => s.isNotEmpty).toList();
  }
  final einzeln = query['anlageId'];
  if (einzeln != null && einzeln.isNotEmpty) return [einzeln];
  return const [];
}

/// `?typ=stoerung` auf dem Einsätze-Screen. Unbekannt oder fehlend heisst
/// «alle Typen» — ein Tippfehler in einem Link darf die Liste nicht leeren.
EinsatzTyp? einsatzTypAusQuery(String? wert) {
  if (wert == null || wert.isEmpty) return null;
  for (final t in EinsatzTyp.values) {
    if (t.name == wert) return t;
  }
  return null;
}

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: SupabaseService.authNotifier,
  // Zählt, welche Route geöffnet wird (Punkt 5 der App-Analyse). Der
  // Beobachter sieht das Routen-Muster, nie eine konkrete Datensatz-ID.
  observers: [NutzungBeobachter()],
  redirect: (context, state) {
    final isLoggedIn = SupabaseService.isAuthenticated;
    final isLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginPage) return '/login';
    if (isLoggedIn && isLoginPage) return '/';

    // Gast (Heineken) hat keinen Zugriff auf Buchhaltung und Dokumente
    const gastGesperrt = ['/buchhaltung', '/dokumente'];
    if (SupabaseService.isGuest &&
        gastGesperrt.any(state.matchedLocation.startsWith)) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),

    // Bereiche (v0.131.0) — Aufbau in lib/core/config/bereiche.dart.
    GoRoute(
      path: '/mehr',
      builder: (context, state) => const BereichScreen(bereich: kBereichMehr),
    ),
    GoRoute(
      path: '/suche',
      builder: (context, state) => const SucheScreen(),
    ),
    GoRoute(
      path: '/bank',
      builder: (context, state) => const BereichScreen(
        bereich: kBereichBank,
        kopf: [CamtErinnerungKarte(), _BankWaechterKopf()],
      ),
    ),
    GoRoute(
      path: '/abschluesse',
      builder: (context, state) =>
          const BereichScreen(bereich: kBereichAbschluesse),
    ),
    GoRoute(
      path: '/auswertungen',
      builder: (context, state) =>
          const BereichScreen(bereich: kBereichAuswertungen),
    ),
    GoRoute(
      path: '/stammdaten',
      builder: (context, state) => const StammdatenScreen(),
    ),

    // Tourenplanung
    GoRoute(
      path: '/touren',
      // `?datum=YYYY-MM-DD`: Tag vorwählen (Aufgabe «Arbeitstag ohne Feierabend»).
      builder: (context, state) => TourenplanungScreen(
        startDatum: DateTime.tryParse(state.uri.queryParameters['datum'] ?? ''),
      ),
    ),

    // Auswertung der erfassten Arbeitstage (Zeit, km, Besuche)
    GoRoute(
      path: '/auswertungen/arbeitstage',
      builder: (context, state) => const ArbeitstagAuswertungScreen(),
    ),

    // Nutzungsmessung: welcher Bereich wird tatsächlich geöffnet
    GoRoute(
      path: '/auswertungen/nutzung',
      builder: (context, state) => const NutzungScreen(),
    ),

    // Aufgaben (anstehende Arbeiten chronologisch)
    GoRoute(
      path: '/aufgaben',
      builder: (context, state) => const AufgabenScreen(),
    ),

    // Betriebe
    GoRoute(
      path: '/betriebe',
      builder: (context, state) =>
          BetriebeListScreen(startSuche: state.uri.queryParameters['suche']),
    ),
    GoRoute(
      path: '/betriebe/servicezeiten',
      builder: (context, state) => const ServicezeitDurchsichtScreen(),
    ),
    GoRoute(
      // Saisondaten der gemeldeten Betriebe nachtragen — Ziel beider
      // Saison-Warnungen im Tourenplan.
      path: '/betriebe/saisondaten',
      builder: (context, state) => const SaisonNachtragScreen(),
    ),
    GoRoute(
      path: '/betriebe/neu',
      builder: (context, state) => const BetriebFormScreen(),
    ),
    // VOR "/betriebe/:id", sonst würde "vorschlaege" als Betriebs-Id
    // interpretiert.
    GoRoute(
      path: '/betriebe/vorschlaege',
      builder: (context, state) => const BetriebVorschlaegeScreen(),
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
        return KontaktFormScreen(
          initialKategorie: 'betrieb',
          initialBetriebId: betriebId,
        );
      },
    ),
    GoRoute(
      path: '/betriebe/:id/kontakte/:kid/bearbeiten',
      builder: (context, state) {
        final kontaktId = state.pathParameters['kid']!;
        return KontaktFormScreen(kontaktId: kontaktId);
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
          anlageId: anlageId,
          bierleitungId: bierleitungId,
        );
      },
    ),

    // Einsätze (B2) — eine Liste für alle Typen.
    GoRoute(
      path: '/einsaetze',
      builder: (context, state) => EinsaetzeScreen(
        vorgewaehlterTyp: einsatzTypAusQuery(state.uri.queryParameters['typ']),
        // Aus der Betriebsseite: nur dieser Betrieb (Akte, T10).
        betriebId: state.uri.queryParameters['betrieb'],
      ),
    ),

    // Reinigungen
    GoRoute(
      path: '/reinigungen/neu',
      builder: (context, state) {
        final betriebId = state.uri.queryParameters['betriebId'];
        if (betriebId == null) {
          return const ReinigungBetriebAuswahlScreen();
        }
        final anlageIds = anlageIdsAusQuery(state.uri.queryParameters);
        // `serviceArt` (Saison-Stopp) und `notiz` (Diktat) kommen aus
        // `startRoute` (core/util/einsatz_start.dart); das Formular prüft
        // den Wert selbst gegen sein Dropdown.
        return ReinigungFormScreen(
          betriebId: betriebId,
          anlageId: anlageIds.isNotEmpty ? anlageIds.first : null,
          anlageIds: anlageIds,
          serviceArt: state.uri.queryParameters['serviceArt'],
          notiz: state.uri.queryParameters['notiz'],
        );
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
      path: '/stoerungen/neu',
      builder: (context, state) {
        final anlageId = state.uri.queryParameters['anlageId'];
        final betriebId = state.uri.queryParameters['betriebId'];
        return StoerungFormScreen(anlageId: anlageId, betriebId: betriebId);
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
      path: '/montagen/neu',
      builder: (context, state) {
        final anlageId = state.uri.queryParameters['anlageId'];
        final betriebId = state.uri.queryParameters['betriebId'];
        return MontageFormScreen(anlageId: anlageId, betriebId: betriebId);
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
      path: '/eigenauftraege/neu',
      redirect: (context, state) =>
          SupabaseService.isGuest ? '/einsaetze' : null,
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
          SupabaseService.isGuest ? '/einsaetze' : null,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EigenauftragFormScreen(eigenauftragId: id);
      },
    ),

    // Eröffnungsreinigungen
    GoRoute(
      path: '/eroeffnungsreinigungen/neu',
      redirect: (context, state) =>
          SupabaseService.isGuest ? '/einsaetze' : null,
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
          SupabaseService.isGuest ? '/einsaetze' : null,
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
      path: '/heineken/zuweisungen',
      builder: (context, state) => const HeinekenZuweisungenScreen(),
    ),
    GoRoute(
      path: '/heineken/raster',
      builder: (context, state) => const HeinekenRasterScreen(),
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
      builder: (context, state) => RechnungenListScreen(
        startSuche: state.uri.queryParameters['suche'],
      ),
    ),
    // MUSS vor '/rechnungen/:id' stehen — GoRouter nimmt die erste passende
    // Route, sonst landet 'pro-betrieb' als Rechnungs-ID im Detailscreen.
    GoRoute(
      path: '/rechnungen/pro-betrieb',
      builder: (context, state) => const OffenProBetriebScreen(),
    ),
    // Ebenfalls VOR '/rechnungen/:id' (sonst wäre 'mahnlauf' eine Rechnungs-ID).
    // ?rechnung=<id> = Einzelmahnung aus der Rechnungs-Detailseite.
    GoRoute(
      path: '/rechnungen/mahnlauf',
      builder: (context, state) => MahnlaufScreen(
        rechnungId: state.uri.queryParameters['rechnung'],
      ),
    ),
    // Arbeitsblatt eines Mahnfalls (Mahnwesen Teil 2). ?mailFehler=1 = aus
    // dem Mahnlauf nach gescheiterter Heineken-Mail.
    GoRoute(
      path: '/rechnungen/mahnfall/:id',
      builder: (context, state) => MahnfallScreen(
        id: state.pathParameters['id']!,
        mailFehler: state.uri.queryParameters['mailFehler'] == '1',
      ),
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
      path: '/buchhaltung/auswertung',
      builder: (context, state) => const AuswertungScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/bilanz',
      redirect: (context, state) => '/buchhaltung/berichte',
    ),
    GoRoute(
      path: '/buchhaltung/mwst',
      builder: (context, state) => const MwstAbrechnungScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/monatsabschluss',
      builder: (context, state) => const MonatsabschlussScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/audit',
      // ?jahr= wählt das Prüfjahr vor; der Screen prüft es und fällt bei
      // Unsinn aufs laufende Jahr zurück.
      builder: (context, state) => AuditScreen(
        jahr: int.tryParse(state.uri.queryParameters['jahr'] ?? ''),
      ),
    ),
    GoRoute(
      // Abschluss-Schritt «Jahrgang abschreiben» — aus der Abschlussprüfung
      // heraus (Regel «Offene Rechnungen älter als 5 Jahre»).
      path: '/buchhaltung/abschreibung',
      builder: (context, state) => JahrgangAbschreibenScreen(
        jahr: int.tryParse(state.uri.queryParameters['jahr'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/buchhaltung/steuern',
      builder: (context, state) => const SteuernScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/steuern/:jahr',
      // Unlesbares oder unsinniges Jahr (altes Lesezeichen, vertippte URL)
      // führt zurück auf die Übersicht statt in einen Absturz oder in ein
      // Detail zu einem Jahr, das die App gar nicht führt.
      redirect: (context, state) {
        final j = int.tryParse(state.pathParameters['jahr'] ?? '');
        final ok =
            j != null && j >= kSteuerJahrAb && j <= DateTime.now().year + 1;
        return ok ? null : '/buchhaltung/steuern';
      },
      builder: (context, state) =>
          SteuerjahrScreen(jahr: int.parse(state.pathParameters['jahr']!)),
    ),
    GoRoute(
      path: '/buchhaltung/mahnwesen',
      redirect: (context, state) => '/rechnungen',
    ),
    GoRoute(
      path: '/buchhaltung/debitoren',
      redirect: (context, state) => '/rechnungen',
    ),
    GoRoute(
      path: '/buchhaltung/camt-import',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        final initial = switch (tab) {
          'pruefliste' => 1,
          'regeln' => 2,
          'dateien' => 3,
          _ => 0,
        };
        return CamtBankauszugScreen(initialTab: initial);
      },
    ),
    GoRoute(
      path: '/buchhaltung/camt-pruefliste',
      redirect: (context, state) => '/buchhaltung/camt-import?tab=pruefliste',
    ),
    GoRoute(
      path: '/buchhaltung/camt-regeln',
      redirect: (context, state) => '/buchhaltung/camt-import?tab=regeln',
    ),
    GoRoute(
      path: '/buchhaltung/camt-dateien',
      redirect: (context, state) => '/buchhaltung/camt-import?tab=dateien',
    ),
    GoRoute(
      path: '/buchhaltung/eingangsrechnungen',
      builder: (context, state) => const EingangsrechnungListeScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/eingangsrechnungen/upload',
      builder: (context, state) => const EingangsrechnungUploadScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/eingangsrechnungen/regeln',
      builder: (context, state) => const KreditorRegelnScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/eingangsrechnungen/zahlungsfile',
      builder: (context, state) => const ZahlungsfileExportScreen(),
    ),
    // :id-Route NACH den statischen "upload"-/"regeln"-/"zahlungsfile"-Routen,
    // damit diese nicht als ID interpretiert werden.
    GoRoute(
      path: '/buchhaltung/eingangsrechnungen/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EingangsrechnungDetailScreen(id: id);
      },
    ),
    GoRoute(
      path: '/buchhaltung/lohn',
      builder: (context, state) => const LohnlaufScreen(),
    ),
    GoRoute(
      path: '/buchhaltung/lohn/einstellungen',
      builder: (context, state) => const LohnEinstellungenScreen(),
    ),

    // Materialien
    GoRoute(
      path: '/materialien',
      builder: (context, state) => const MaterialienListScreen(),
    ),
    GoRoute(
      path: '/materialien/bestellen',
      builder: (context, state) => const MaterialBestellungScreen(),
    ),
    GoRoute(
      path: '/materialien/bestellungen',
      builder: (context, state) => const MaterialBestellungenScreen(),
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

    // Kontakte
    GoRoute(
      path: '/kontakte',
      builder: (context, state) =>
          KontakteListScreen(startSuche: state.uri.queryParameters['suche']),
    ),
    GoRoute(
      path: '/kontakte/neu',
      builder: (context, state) {
        final kategorie = state.uri.queryParameters['kategorie'];
        final betriebId = state.uri.queryParameters['betriebId'];
        return KontaktFormScreen(
          initialKategorie: kategorie,
          initialBetriebId: betriebId,
        );
      },
    ),
    GoRoute(
      path: '/kontakte/:id/bearbeiten',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return KontaktFormScreen(kontaktId: id);
      },
    ),

    // Events
    GoRoute(
      path: '/events',
      builder: (context, state) => const EventsListScreen(),
    ),
    GoRoute(
      path: '/events/neu',
      builder: (context, state) => const EventFormScreen(),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) =>
          EventDetailScreen(eventId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/events/:id/bearbeiten',
      builder: (context, state) =>
          EventFormScreen(eventId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/events/:id/lageplan',
      builder: (context, state) =>
          EventLageplanScreen(eventId: state.pathParameters['id']!),
    ),

    // Bergkundenpauschalen
    GoRoute(
      path: '/bergkundenpauschalen',
      builder: (context, state) => const BergkundenpauschaleListScreen(),
    ),
    GoRoute(
      path: '/bergkundenpauschalen/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return BergkundenpauschaleDetailScreen(pauschaleId: id);
      },
    ),

    // Dokumente (Steuern, Versicherungen, Verträge, …)
    GoRoute(
      path: '/dokumente',
      builder: (context, state) => const DokumenteScreen(),
    ),

    // Einstellungen
    GoRoute(
      path: '/einstellungen',
      builder: (context, state) => const EinstellungenScreen(),
    ),
    GoRoute(
      path: '/einstellungen/preise/neu',
      builder: (context, state) => const PreisVersionFormScreen(),
    ),
    GoRoute(
      path: '/einstellungen/preise/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return PreisVersionFormScreen(preisId: id);
      },
    ),
    GoRoute(
      path: '/einstellungen/biersorten',
      builder: (context, state) => const BiersortenScreen(),
    ),
    GoRoute(
      path: '/einstellungen/regionen',
      builder: (context, state) => const RegionenScreen(),
    ),

    // Jahresrechnung
    GoRoute(
      path: '/jahresrechnung',
      builder: (context, state) => const JahresrechnungGenerateScreen(),
    ),

    // Spesen
    GoRoute(
      path: '/spesen',
      builder: (context, state) => const SpesenScannerScreen(),
    ),

    // Google-Kalender: bestehende Termine zuordnen (K2)
    GoRoute(
      path: '/google-termine',
      builder: (context, state) => const GoogleTermineScreen(),
    ),
  ],
);

/// Liest den Bank-Wächter-Stand für die Seite «Bank und Zahlungen».
class _BankWaechterKopf extends ConsumerWidget {
  const _BankWaechterKopf();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BankWaechterKarte(stand: ref.watch(bankWaechterProvider));
}
