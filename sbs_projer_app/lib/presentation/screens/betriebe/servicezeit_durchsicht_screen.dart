import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/repositories/servicezeit_durchsicht_repository.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/presentation/widgets/zeit_feld.dart';

/// Servicezeiten aller Betriebe durchgehen — einer nach dem anderen.
///
/// **Warum (Daniel, 08.09.2026):** 201 der 305 aktiven Betriebe hatten keine
/// Servicezeit hinterlegt; der Tourenplan konnte dort nicht warnen, wenn ein
/// Besuch ausserhalb liegt. Vorgeschlagen wird, was die Besuche seit 2019
/// hergeben — bestätigen oder korrigieren entscheidet der Mensch.
///
/// Wischen nach rechts übernimmt, was in den Feldern steht. Nach links
/// überspringt: Der Betrieb bekommt keinen Stempel und kommt in der nächsten
/// Runde wieder. Beide Wege gibt es zusätzlich als Knopf — Wischgesten haben
/// auf dem produktiven CanvasKit schon Ärger gemacht.
class ServicezeitDurchsichtScreen extends ConsumerStatefulWidget {
  const ServicezeitDurchsichtScreen({super.key});

  @override
  ConsumerState<ServicezeitDurchsichtScreen> createState() =>
      _ServicezeitDurchsichtScreenState();
}

class _ServicezeitDurchsichtScreenState
    extends ConsumerState<ServicezeitDurchsichtScreen> {
  List<ServicezeitKandidat> _kandidaten = [];
  int _index = 0;
  bool _laedt = true;
  String? _fehler;
  int _erledigt = 0;

  TimeOfDay? _morgenAb;
  TimeOfDay? _morgenBis;
  TimeOfDay? _nachmittagAb;
  TimeOfDay? _nachmittagBis;
  bool _besucheOffen = false;
  bool _morgenKeinService = false;
  bool _nachmittagKeinService = false;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    try {
      final liste = await ServicezeitDurchsichtRepository.offeneBetriebe();
      if (!mounted) return;
      setState(() {
        _kandidaten = liste;
        _index = 0;
        _laedt = false;
      });
      _feldereBefuellen();
    } catch (e) {
      if (mounted) setState(() => _fehler = '$e');
    }
  }

  ServicezeitKandidat? get _aktuell =>
      _index < _kandidaten.length ? _kandidaten[_index] : null;

  /// Vorbelegung: der Vorschlag, wenn es einen gibt — sonst die bisher
  /// hinterlegten Zeiten. Ohne diesen Rückfall würde ein Wisch bei einem
  /// Betrieb ohne Datenbasis bestehende Zeiten löschen.
  void _feldereBefuellen() {
    final k = _aktuell;
    if (k == null) return;
    final v = k.vorbelegung;
    setState(() {
      _morgenAb = zeitAusText(v.morgenAb);
      _morgenBis = zeitAusText(v.morgenBis);
      _nachmittagAb = zeitAusText(v.nachmittagAb);
      _nachmittagBis = zeitAusText(v.nachmittagBis);
      // Ein gefüllter Block heisst: der andere ist bewusst leer (Regel
      // Daniel 29.07.2026). Genau das zeigt der Schalter an.
      final hatMorgen = _morgenAb != null && _morgenBis != null;
      final hatNachmittag = _nachmittagAb != null && _nachmittagBis != null;
      _morgenKeinService = !hatMorgen && hatNachmittag;
      _nachmittagKeinService = hatMorgen && !hatNachmittag;
    });
  }

  void _weiter() {
    setState(() => _index++);
    _feldereBefuellen();
  }

  Future<void> _uebernehmen() async {
    final k = _aktuell;
    if (k == null) return;
    try {
      await ServicezeitDurchsichtRepository.uebernehmen(
        k.betriebId,
        morgenAb: zeitAlsText(_morgenAb),
        morgenBis: zeitAlsText(_morgenBis),
        nachmittagAb: zeitAlsText(_nachmittagAb),
        nachmittagBis: zeitAlsText(_nachmittagBis),
      );
      ref.invalidate(betriebeStreamProvider);
      if (!mounted) return;
      setState(() => _erledigt++);
      _weiter();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Speichern fehlgeschlagen: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicezeiten durchgehen'),
        actions: [
          if (!_laedt && _kandidaten.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_index + 1} / ${_kandidaten.length}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_fehler != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: Text('Fehler: $_fehler')),
      );
    }
    if (_laedt) return const Center(child: CircularProgressIndicator());
    final k = _aktuell;
    if (k == null) return _fertig();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Dismissible(
              key: ValueKey(k.betriebId),
              background: _wischFlaeche(
                Alignment.centerLeft,
                Icons.check,
                'Übernehmen',
                AppColors.success,
              ),
              secondaryBackground: _wischFlaeche(
                Alignment.centerRight,
                Icons.skip_next,
                'Später',
                AppColors.textSecondary,
              ),
              onDismissed: (richtung) {
                if (richtung == DismissDirection.startToEnd) {
                  _uebernehmen();
                } else {
                  _weiter();
                }
              },
              child: _karte(k),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TapKnopf(
                    text: 'Später',
                    primaer: false,
                    onTap: _weiter,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TapKnopf(text: 'Übernehmen', onTap: _uebernehmen),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _wischFlaeche(
    Alignment richtung,
    IconData icon,
    String text,
    Color farbe,
  ) => Container(
    alignment: richtung,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: farbe.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: farbe, size: 20),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: farbe, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );

  Widget _karte(ServicezeitKandidat k) {
    final v = k.vorschlag;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            v.hatVorschlag
                ? 'Vorschlag aus ${k.besuche} Besuchen seit 2019'
                : k.besuche == 0
                ? 'Keine Besuche mit Uhrzeit erfasst — bitte selbst eintragen'
                : 'Nur ${k.besuche} Besuche — zu wenig für einen Vorschlag',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (k.hatBisherZeiten) ...[
            const SizedBox(height: 6),
            Text(
              'Bisher hinterlegt: ${_bisherText(k)}',
              style: const TextStyle(fontSize: 12, color: AppColors.info),
            ),
          ],
          const Divider(height: 20),
          _blockKopf(
            'Vormittag',
            keinService: _morgenKeinService,
            // Gegenseitig ausschliessend: irgendwann muss Service möglich
            // sein, sonst waere der Betrieb gar nicht bedienbar.
            sperren: _nachmittagKeinService,
            onChanged: (v) => setState(() {
              _morgenKeinService = v;
              if (v) {
                _morgenAb = null;
                _morgenBis = null;
              }
            }),
          ),
          if (!_morgenKeinService)
            Row(
              children: [
                Expanded(
                  child: ZeitFeld(
                    label: 'Morgen von',
                    value: _morgenAb,
                    onChanged: (t) => setState(() => _morgenAb = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZeitFeld(
                    label: 'Morgen bis',
                    value: _morgenBis,
                    onChanged: (t) => setState(() => _morgenBis = t),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          _blockKopf(
            'Nachmittag',
            keinService: _nachmittagKeinService,
            sperren: _morgenKeinService,
            onChanged: (v) => setState(() {
              _nachmittagKeinService = v;
              if (v) {
                _nachmittagAb = null;
                _nachmittagBis = null;
              }
            }),
          ),
          if (!_nachmittagKeinService)
            Row(
              children: [
                Expanded(
                  child: ZeitFeld(
                    label: 'Nachmittag von',
                    value: _nachmittagAb,
                    onChanged: (t) => setState(() => _nachmittagAb = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZeitFeld(
                    label: 'Nachmittag bis',
                    value: _nachmittagBis,
                    onChanged: (t) => setState(() => _nachmittagBis = t),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            _hinweisText(),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (k.besuchsliste.isNotEmpty) _besuche(k),
        ],
      ),
    );
  }

  String _bisherText(ServicezeitKandidat k) {
    final teile = <String>[];
    if (k.bisherMorgenAb != null) {
      teile.add('${k.bisherMorgenAb}–${k.bisherMorgenBis ?? '?'}');
    }
    if (k.bisherNachmittagAb != null) {
      teile.add('${k.bisherNachmittagAb}–${k.bisherNachmittagBis ?? '?'}');
    }
    return teile.join(' · ');
  }

  /// Blocküberschrift mit «kein Service»-Schalter.
  Widget _blockKopf(
    String titel, {
    required bool keinService,
    required bool sperren,
    required ValueChanged<bool> onChanged,
  }) => Row(
    children: [
      Text(
        titel,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      const Spacer(),
      InkWell(
        onTap: sperren ? null : () => onChanged(!keinService),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                keinService
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: sperren
                    ? Colors.grey.shade400
                    : (keinService ? AppColors.error : AppColors.textSecondary),
              ),
              const SizedBox(width: 4),
              Text(
                'kein Service',
                style: TextStyle(
                  fontSize: 12,
                  color: sperren
                      ? Colors.grey.shade400
                      : (keinService
                            ? AppColors.error
                            : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  /// Was beim Übernehmen gespeichert wird — im Klartext, weil «leer» je nach
  /// dem anderen Block zweierlei bedeutet.
  String _hinweisText() {
    final hatMorgen = _morgenAb != null && _morgenBis != null;
    final hatNachmittag = _nachmittagAb != null && _nachmittagBis != null;
    if (!hatMorgen && !hatNachmittag) {
      return 'Nichts erfasst — gilt als «keine Einschränkung bekannt».';
    }
    if (hatMorgen && hatNachmittag) return 'Service vormittags und nachmittags.';
    return hatMorgen
        ? 'Service nur vormittags — nachmittags kein Service.'
        : 'Service nur nachmittags — morgens kein Service.';
  }

  /// Die Besuche, aus denen der Vorschlag stammt — zum Nachprüfen.
  ///
  /// Zugeklappt steht nur die Zusammenfassung da (Spanne und häufigste
  /// Stunde); aufgeklappt alle Besuche, neueste zuoberst. Kein
  /// `ExpansionTile`: das zeichnet auf dem produktiven CanvasKit unzuverlässig.
  Widget _besuche(ServicezeitKandidat k) {
    final u = k.uebersicht;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        InkWell(
          onTap: () => setState(() => _besucheOffen = !_besucheOffen),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bisherige Besuche (${k.besuchsliste.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      if (u != null)
                        Text(
                          'Spanne ${u.spanneVon}–${u.spanneBis} · '
                          'meist ${u.stundenText} (${u.haeufigkeit}×)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  _besucheOffen ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_besucheOffen)
          for (final b in k.besuchsliste)
            Text(
              b.zeile,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
      ],
    );
  }

  Widget _fertig() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
          const SizedBox(height: 12),
          Text(
            _kandidaten.isEmpty
                ? 'Alle Betriebe sind geprüft.'
                : 'Runde durch — $_erledigt von ${_kandidaten.length} übernommen.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (_kandidaten.isNotEmpty &&
              _erledigt < _kandidaten.length) ...[
            const SizedBox(height: 8),
            const Text(
              'Die übersprungenen kommen in der nächsten Runde wieder.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TapKnopf(
              text: 'Nächste Runde',
              onTap: () {
                setState(() {
                  _laedt = true;
                  _erledigt = 0;
                });
                _laden();
              },
            ),
          ],
        ],
      ),
    ),
  );
}
