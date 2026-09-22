import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/suche.dart';
import 'package:sbs_projer_app/presentation/providers/suche_provider.dart';
import 'package:sbs_projer_app/presentation/widgets/such_treffer_zeile.dart';
import 'package:sbs_projer_app/services/suche/zuletzt_geoeffnet.dart';

/// Die Suche (v0.133.0) — erreichbar über die Lupe auf Heute und das Feld
/// oben auf Mehr. Spec: docs/superpowers/specs/2026-09-22-suche-design.md
class SucheScreen extends ConsumerStatefulWidget {
  const SucheScreen({super.key});

  @override
  ConsumerState<SucheScreen> createState() => _SucheScreenState();
}

class _SucheScreenState extends ConsumerState<SucheScreen> {
  final _controller = TextEditingController();
  final _fokus = FocusNode();
  Timer? _warte;
  String _text = '';
  List<ZuletztEintrag> _zuletzt = const [];

  static const _gruppenTitel = {
    SuchGruppe.betriebe: 'Betriebe',
    SuchGruppe.personen: 'Personen',
    SuchGruppe.rechnungen: 'Rechnungen',
    SuchGruppe.bereiche: 'Bereiche',
  };

  /// Wohin «alle N anzeigen» führt — die Listen füllen ihr Suchfeld vor.
  static const _listen = {
    SuchGruppe.betriebe: '/betriebe',
    SuchGruppe.personen: '/kontakte',
    SuchGruppe.rechnungen: '/rechnungen',
  };

  @override
  void initState() {
    super.initState();
    _ladeZuletzt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fokus.requestFocus();
    });
  }

  @override
  void dispose() {
    _warte?.cancel();
    _controller.dispose();
    _fokus.dispose();
    super.dispose();
  }

  Future<void> _ladeZuletzt() async {
    try {
      final l = await ZuletztGeoeffnet.lade();
      if (mounted) setState(() => _zuletzt = l);
    } catch (_) {
      // Gesperrter Browser-Speicher darf die Suche nicht stören — dann
      // bleibt «Zuletzt geöffnet» einfach leer.
      if (mounted) setState(() => _zuletzt = const []);
    }
  }

  /// 150 ms nach dem letzten Zeichen rechnen: Bei ~4'000 Rechnungen soll
  /// das Handy nicht bei jedem Buchstaben alles durchgehen.
  void _geaendert(String v) {
    _warte?.cancel();
    _warte = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _text = v);
    });
  }

  void _loeschen() {
    _warte?.cancel();
    _controller.clear();
    setState(() => _text = '');
    _fokus.requestFocus();
  }

  Future<void> _oeffne(String titel, String? untertitel, String route) async {
    // WARUM nicht awaiten: SharedPreferences kann im Browser gesperrt sein
    // (privater Modus, voller Speicher) — das Merken darf das Öffnen der
    // Route nie verzögern oder verhindern. Fehler werden verschluckt, das
    // «Zuletzt geöffnet» ist ein Komfort, kein Muss.
    unawaited(
      ZuletztGeoeffnet.merke(
        ZuletztEintrag(titel: titel, untertitel: untertitel, route: route),
      ).catchError((_) {}),
    );
    await context.push(route);
    _ladeZuletzt();
  }

  Future<void> _anrufen(String telefon) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse('tel:${telefon.replaceAll(' ', '')}'));
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Anruf nicht möglich')));
    }
  }

  Widget _kopf(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _leer() {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Sucht in Betrieben (Name, Ort, Nummer), Personen (Name, '
            'Telefon, Betrieb), Rechnungen (Nummer, Betrieb) und in den '
            'Bereichen der App.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        if (_zuletzt.isNotEmpty) ...[
          _kopf('Zuletzt geöffnet'),
          for (final z in _zuletzt)
            SuchTrefferZeile(
              treffer: SuchTreffer(
                gruppe: SuchGruppe.bereiche,
                titel: z.titel,
                untertitel: z.untertitel,
                route: z.route,
              ),
              suchtext: '',
              onTap: () => _oeffne(z.titel, z.untertitel, z.route),
            ),
        ],
      ],
    );
  }

  Widget _treffer(SuchErgebnis e) {
    if (e.leer) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nichts gefunden für ‹${_text.trim()}›',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView(
      children: [
        for (final g in e.gruppen) ...[
          _kopf(_gruppenTitel[g.gruppe]!),
          for (final t in g.treffer)
            SuchTrefferZeile(
              treffer: t,
              // Ohne führendes «+» vor Ziffern — dieselbe Bereinigung wie in
              // `suche()`, sonst würde «+41 79» nie fett markiert, weil das
              // «+» selbst in keinem Feld vorkommt.
              suchtext: ohneFuehrendesPlus(_text),
              onTap: () => _oeffne(t.titel, t.untertitel, t.route),
              onAnruf: t.telefon == null || t.telefon!.isEmpty
                  ? null
                  : () => _anrufen(t.telefon!),
            ),
          if (g.gesamt > g.treffer.length && _listen[g.gruppe] != null)
            InkWell(
              onTap: () => context.push(
                Uri(
                  path: _listen[g.gruppe],
                  queryParameters: {'suche': _text.trim()},
                ).toString(),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'alle ${g.gesamt} anzeigen',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final eingabe = ref.watch(suchEingabeProvider);
    final aktiv = normalisiere(_text).length >= kSuchMindestLaenge;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _fokus,
          onChanged: _geaendert,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Betrieb, Person, Rechnung, Bereich …',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Suchtext löschen',
            onPressed: _loeschen,
          ),
        ],
      ),
      body: aktiv ? _treffer(suche(eingabe, _text)) : _leer(),
    );
  }
}
