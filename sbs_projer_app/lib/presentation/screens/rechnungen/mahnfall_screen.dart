import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sbs_projer_app/core/app_version.dart';
import 'package:sbs_projer_app/core/config/mail_config.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/mahnfall_regeln.dart';
import 'package:sbs_projer_app/data/models/mahnfall.dart';
import 'package:sbs_projer_app/data/models/rechnung.dart';
import 'package:sbs_projer_app/presentation/providers/betrieb_providers.dart';
import 'package:sbs_projer_app/presentation/providers/mahnfall_providers.dart';
import 'package:sbs_projer_app/presentation/providers/mahnlauf_provider.dart';
import 'package:sbs_projer_app/presentation/providers/rechnung_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/rechnung/mahnfall_service.dart';
import 'package:sbs_projer_app/services/storage/protokoll_foto_storage.dart';

/// Arbeitsblatt eines Mahnfalls (Mahnwesen Teil 2, v0.135.0, Spec §5):
/// Heineken-Ergebnis erfassen, Betreibung mit Datenblatt und datierten
/// Schritten begleiten, Fall abschliessen.
///
/// CanvasKit (CLAUDE.md): keine Material-Buttons/ListTile/ExpansionTile —
/// Blöcke aus Container + Column/Row, Aktionen über `TapKnopf`,
/// Unumkehrbares über `TapKnopf(gefahr: true)`.
class MahnfallScreen extends ConsumerStatefulWidget {
  final String id;

  /// Aus dem Mahnlauf: Fall angelegt, Heineken-Mail aber gescheitert —
  /// oben ein roter Hinweis, «Mail erneut senden» steht ohnehin bereit.
  final bool mailFehler;

  const MahnfallScreen({super.key, required this.id, this.mailFehler = false});

  @override
  ConsumerState<MahnfallScreen> createState() => _MahnfallScreenState();
}

class _MahnfallScreenState extends ConsumerState<MahnfallScreen> {
  final _name = TextEditingController();
  final _adresse = TextEditingController();
  final _amt = TextEditingController();
  final _vorschuss = TextEditingController();
  final _notiz = TextEditingController();
  String? _rechtsform;

  /// Schlüssel des Stands, aus dem die Textfelder zuletzt befüllt wurden.
  /// Neu befüllt wird nur, wenn sich Fall oder Status ändert — eine
  /// Datumsaktion darf ungespeicherte Eingaben im Datenblatt nicht löschen.
  String? _befuelltFuer;

  /// Laufende Aktion (sperrt alle Knöpfe, zeigt den Kreis am gedrückten).
  String? _laeuft;
  late bool _mailFehler = widget.mailFehler;

  @override
  void initState() {
    super.initState();
    // Ausserhalb von build befüllen: Ein Controller-Wechsel mitten im Build
    // löst sonst «setState during build» im TextField aus.
    ref.listenManual<AsyncValue<Mahnfall?>>(
      mahnfallProvider(widget.id),
      (_, next) {
        final f = next.valueOrNull;
        if (f != null) _befuellen(f);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _adresse.dispose();
    _amt.dispose();
    _vorschuss.dispose();
    _notiz.dispose();
    super.dispose();
  }

  void _befuellen(Mahnfall f) {
    final key = '${f.id}:${f.status}:${f.erledigung}';
    if (_befuelltFuer == key) return;
    _befuelltFuer = key;
    _name.text = f.schuldnerName ?? '';
    _adresse.text = f.schuldnerAdresse ?? '';
    _amt.text = f.betreibungsamt ?? '';
    _vorschuss.text = f.kostenVorschuss?.toStringAsFixed(2) ?? '';
    _notiz.text = MahnfallService.notizOhneUebernahme(f.notiz) ?? '';
    _rechtsform = f.rechtsform;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mahnfallProvider(widget.id));
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/rechnungen/mahnlauf'),
        ),
        // Version sichtbar (CLAUDE.md).
        title: const Text('Mahnfall  ·  v$kAppVersion', style: TextStyle(fontSize: 18)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _mitte('Mahnfall nicht ladbar: ${kurzeFehlermeldung(e)}'),
        data: (fall) {
          if (fall == null) {
            return _mitte('Mahnfall nicht gefunden — vielleicht zurückgenommen.');
          }
          final rAsync = ref.watch(mahnfallRechnungenProvider(widget.id));
          final rechnungen = rAsync.valueOrNull ?? const <Rechnung>[];
          return RefreshIndicator(
            onRefresh: () async => _neuLaden(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _kopf(fall),
                const SizedBox(height: 10),
                if (rAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (rAsync.hasError)
                  _kasten(
                    farbe: AppColors.error,
                    child: Text(
                      'Rechnungen nicht ladbar: ${kurzeFehlermeldung(rAsync.error!)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  )
                else
                  _rechnungenBlock(fall, rechnungen),
                if (fall.status == 'heineken' || fall.status == 'heineken_frist') ...[
                  const SizedBox(height: 10),
                  _heinekenBlock(fall),
                ],
                if (fall.status == 'betreibung') ...[
                  const SizedBox(height: 10),
                  _betreibungBlock(fall, rechnungen),
                ],
                if (!fall.offen && fall.heinekenErgebnis == 'konkurs') ...[
                  const SizedBox(height: 10),
                  _kasten(
                    farbe: AppColors.warning,
                    child: const Text(
                      'Kunde in Konkurs — die offenen Rechnungen sind abgeschrieben. '
                      'Die Forderung kann beim Konkursamt angemeldet werden '
                      '(Eingabe innert der publizierten Frist, SHAB).',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                if (fall.erledigung == 'uebernommen') ...[
                  const SizedBox(height: 10),
                  _uebernahmeBlock(fall),
                ],
                const SizedBox(height: 10),
                _notizBlock(fall),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Kopf ───

  Widget _kopf(Mahnfall f) {
    final anzeige = ref.watch(betriebAnzeigeMapProvider)[f.betriebId] ?? '—';
    return _karte(
      titel: anzeige,
      children: [
        _zeile('Status', mahnfallStatusText(f)),
        _zeile('Eröffnet am', _datum(f.eroeffnetAm)),
        if (f.erledigtAm != null) _zeile('Erledigt am', _datum(f.erledigtAm!)),
        if (f.test)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _kasten(
              farbe: AppColors.warning,
              child: const Text(
                'Testfall — im Testmodus eröffnet, die Heineken-Mail ging an '
                '${MailConfig.testEmpfaenger}.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Rechnungen ───

  Widget _rechnungenBlock(Mahnfall f, List<Rechnung> rechnungen) {
    final total = rechnungen.fold(0.0, (s, r) => s + r.zuZahlen);
    final bezahlt = rechnungen.length == f.rechnungIds.length &&
        alleBezahlt(rechnungen.map((r) => r.zahlungsstatus).toList());
    return _karte(
      titel: 'Rechnungen (${rechnungen.length})',
      children: [
        for (final r in rechnungen)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/rechnungen/${r.id}'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.rechnungsnummer ?? '—'} · ${_datum(r.rechnungsdatum)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          _rechnungsStatus(r.zahlungsstatus),
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'CHF ${r.zuZahlen.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(
                'CHF ${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 18),
            ],
          ),
        ),
        if (rechnungen.length != f.rechnungIds.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${f.rechnungIds.length - rechnungen.length} Rechnung(en) des Falls '
              'nicht gefunden.',
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        if (f.offen && bezahlt)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _kasten(
              farbe: AppColors.success,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alle Rechnungen des Falls sind beglichen.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _knopf(
                    'bezahlt',
                    'Fall abschliessen (bezahlt)',
                    icon: Icons.check_circle,
                    onTap: () => _aktion(
                      'bezahlt',
                      () => MahnfallService.erledigen(f, 'bezahlt'),
                      erfolg: 'Fall abgeschlossen (bezahlt).',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ─── Heineken ───

  Widget _heinekenBlock(Mahnfall f) {
    final ohneErgebnis = f.heinekenErgebnis == null;
    return _karte(
      titel: 'Heineken',
      children: [
        if (f.heinekenKontaktAm != null)
          _zeile('Kontakt am', _datum(f.heinekenKontaktAm!)),
        _zeile('Empfänger', f.heinekenEmpfaenger ?? '—'),
        if (_mailFehler)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _kasten(
              farbe: AppColors.error,
              child: const Text(
                'Die Mail an Heineken ist beim Eröffnen fehlgeschlagen — unten '
                '«Mail an Heineken erneut senden».',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (f.status == 'heineken') ...[
          const Text(
            'Was hat Heineken erreicht?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _knopfSpalte([
            _knopf('vermittelt', 'Vermittelt — Kunde zahlt',
                icon: Icons.check,
                onTap: () => _ergebnis(
                      f,
                      'vermittelt',
                      titel: 'Vermittelt?',
                      text: 'Der Kunde hat Zahlung zugesagt. Die App setzt eine Frist '
                          'von $kVermittlungsFristTage Tagen und meldet sich, wenn '
                          'bis dann nichts eingegangen ist.',
                      knopf: 'Vermittelt',
                    )),
            _knopf('uebernommen', 'Heineken übernimmt',
                icon: Icons.business,
                onTap: () => _ergebnis(
                      f,
                      'uebernommen',
                      titel: 'Heineken übernimmt?',
                      text: 'Der Fall wird erledigt. Es wird NICHTS gebucht — die '
                          'Glocke erinnert an «Übernahme verbuchen» (mit Daniel '
                          'prüfen: Buchung und Position auf der Monatsrechnung).',
                      knopf: 'Heineken übernimmt',
                    )),
            _knopf('konkurs', 'Kunde in Konkurs — abschreiben',
                icon: Icons.remove_circle_outline,
                gefahr: true,
                onTap: () => _ergebnis(
                      f,
                      'konkurs',
                      titel: 'Konkurs — abschreiben?',
                      text: 'Alle noch offenen Rechnungen des Falls werden '
                          'abgeschrieben (mit Buchung) und der Fall erledigt.',
                      knopf: 'Abschreiben',
                      gefahr: true,
                    )),
            _knopf('betreibung', 'Betreibung auslösen',
                icon: Icons.gavel,
                onTap: () => _ergebnis(
                      f,
                      'betreibung',
                      titel: 'Betreibung auslösen?',
                      text: 'Der Fall geht in die Betreibung. Das Datenblatt für '
                          'EasyGov wird aus der Rechnungsadresse vorbelegt.',
                      knopf: 'Betreibung',
                    )),
          ]),
        ] else ...[
          Text(
            f.heinekenFristBis != null
                ? 'Kunde zahlt bis ${_datum(f.heinekenFristBis!)}'
                : 'Kunde zahlt (Frist unbekannt)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _knopf('betreibung', 'Keine Zahlung — Betreibung auslösen',
              icon: Icons.gavel,
              onTap: () => _ergebnis(
                    f,
                    'betreibung',
                    titel: 'Betreibung auslösen?',
                    text: 'Trotz Vermittlung keine Zahlung — der Fall geht in die '
                        'Betreibung.',
                    knopf: 'Betreibung',
                  )),
        ],
        if (f.status == 'heineken' && ohneErgebnis) ...[
          const SizedBox(height: 14),
          _knopfSpalte([
            _knopf('mail', 'Mail an Heineken erneut senden',
                icon: Icons.forward_to_inbox,
                primaer: false,
                onTap: () => _mailErneut(f)),
            if (f.test)
              _knopf('zurueck', 'Fall zurücknehmen',
                  icon: Icons.undo, gefahr: true, onTap: () => _zuruecknehmen(f)),
          ]),
        ],
      ],
    );
  }

  Future<void> _ergebnis(
    Mahnfall f,
    String ergebnis, {
    required String titel,
    required String text,
    required String knopf,
    bool gefahr = false,
  }) async {
    if (!await _bestaetigen(titel, text, knopf, gefahr: gefahr)) return;
    await _aktion(ergebnis, () => MahnfallService.ergebnis(f, ergebnis),
        erfolg: 'Ergebnis erfasst.');
  }

  Future<void> _mailErneut(Mahnfall f) async {
    if (!await _bestaetigen(
      'Mail erneut senden?',
      'Die Mail mit Kontoauszug und Rechnungskopien geht nochmals an den '
          'Heineken-Kontakt «Mahnwesen»'
          '${MailConfig.istScharf('mahnwesen') ? '' : ' (Testmodus: an ${MailConfig.testEmpfaenger})'}.',
      'Senden',
    )) {
      return;
    }
    final ok = await _aktion('mail', () => MahnfallService.mailErneutSenden(f),
        erfolg: 'Mail an Heineken gesendet.');
    if (ok && mounted) setState(() => _mailFehler = false);
  }

  Future<void> _zuruecknehmen(Mahnfall f) async {
    if (!await _bestaetigen(
      'Fall zurücknehmen?',
      'Der Testfall wird gelöscht; die Rechnungen erscheinen wieder unter '
          '«Heineken einschalten». Eine schon versandte Mail bleibt versandt.',
      'Zurücknehmen',
      gefahr: true,
    )) {
      return;
    }
    final ok = await _aktion('zurueck', () => MahnfallService.zuruecknehmen(f));
    if (ok && mounted) {
      context.canPop() ? context.pop() : context.go('/rechnungen/mahnlauf');
    }
  }

  // ─── Betreibung ───

  Widget _betreibungBlock(Mahnfall f, List<Rechnung> rechnungen) {
    final offen = rechnungen
        .where((r) => r.zahlungsstatus != 'bezahlt' && r.zahlungsstatus != 'abgeschrieben')
        .toList();
    final summe = offen.fold(0.0, (s, r) => s + r.zuZahlen);
    final fenster = f.zahlungsbefehlAm == null ? null : fortsetzungsFenster(f.zahlungsbefehlAm!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _karte(
          titel: 'Datenblatt zum Abtippen in EasyGov',
          children: [
            _feld('Schuldner (Name/Firma)', _name),
            _feld('Adresse', _adresse, zeilen: 2),
            const SizedBox(height: 4),
            Text('Rechtsform', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _rechtsform,
                hint: const Text('wählen'),
                isExpanded: true,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'einzelfirma', child: Text('Einzelfirma')),
                  DropdownMenuItem(value: 'gmbh', child: Text('GmbH')),
                  DropdownMenuItem(value: 'ag', child: Text('AG')),
                  DropdownMenuItem(value: 'andere', child: Text('andere')),
                ],
                onChanged: (v) => setState(() => _rechtsform = v),
              ),
            ),
            if (_rechtsform == 'einzelfirma')
              _hinweis('Einzelfirma: Wohnsitz des Inhabers angeben (dort wird betrieben).'),
            const SizedBox(height: 8),
            _feld('Betreibungsamt', _amt),
            _hinweis('Zuständig: Amt am Sitz bzw. Wohnsitz des Schuldners.'),
            const SizedBox(height: 8),
            _feld('Kostenvorschuss CHF', _vorschuss, zahl: true),
            _hinweis('Vorbelegt nach GebV SchKG Art. 16 '
                '(CHF ${betreibungsKostenvorschuss(summe).toStringAsFixed(2)} für '
                'CHF ${summe.toStringAsFixed(2)}).'),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _knopf('datenblatt', 'Datenblatt speichern',
                  icon: Icons.save, onTap: () => _datenblattSpeichern(f)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _karte(
          titel: 'Forderung',
          children: [
            // Zins je Forderung ab der Erinnerung DIESER Rechnung (M-1).
            for (final r in offen) ...[
              _zeile(r.rechnungsnummer ?? '—', 'CHF ${r.zuZahlen.toStringAsFixed(2)}'),
              Padding(
                padding: const EdgeInsets.only(left: 110, bottom: 6),
                child: Text(zinsZeile(r),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
            _zeile('Total', 'CHF ${summe.toStringAsFixed(2)}'),
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _easyGovOeffnen,
              child: const Row(
                children: [
                  Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'EasyGov öffnen',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _karte(
          titel: 'Schritte',
          children: [
            _datumSchritt(f, 'Eingereicht am', 'eingereicht_am', f.eingereichtAm),
            _datumSchritt(f, 'Zahlungsbefehl zugestellt am', 'zahlungsbefehl_am',
                f.zahlungsbefehlAm),
            // Fortsetzung nur ohne Rechtsvorschlag (M-6, wie die Glocken-
            // Aufgabe 'fortsetzung'); mit Rechtsvorschlag erst Rechtsöffnung.
            if (fenster != null && f.rechtsvorschlag == false)
              _hinweis('Fortsetzung möglich ab ${_datum(fenster.ab)}, '
                  'spätestens bis ${_datum(fenster.bis)}.'),
            if (fenster != null && f.rechtsvorschlag == true)
              _hinweis('Rechtsvorschlag erhoben — zuerst Rechtsöffnung, erst dann '
                  'Fortsetzung (spätestens bis ${_datum(fenster.bis)}).'),
            const SizedBox(height: 6),
            const Text('Rechtsvorschlag', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                _chip(f, 'Nein', false),
                const SizedBox(width: 8),
                _chip(f, 'Ja', true),
              ],
            ),
            if (f.rechtsvorschlag == true) ...[
              const SizedBox(height: 10),
              _kasten(
                farbe: AppColors.warning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unterschriebene Reinigungsprotokolle helfen, sind aber keine '
                      'Schuldanerkennung — Rechtsöffnung unsicher, ggf. Fachperson '
                      'beiziehen.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    for (final r in offen) _protokollZeile(r),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            _datumSchritt(f, 'Fortsetzungsbegehren am', 'fortsetzung_am', f.fortsetzungAm),
          ],
        ),
        const SizedBox(height: 10),
        _karte(
          titel: 'Abschluss',
          children: [
            _knopfSpalte([
              _knopf('erl_bezahlt', 'Erledigt: bezahlt',
                  icon: Icons.check_circle,
                  onTap: () => _erledigen(
                        f,
                        'bezahlt',
                        'Nur möglich, wenn alle Rechnungen als bezahlt erfasst sind.',
                      )),
              _knopf('erl_abgeschrieben', 'Erledigt: abgeschrieben',
                  icon: Icons.remove_circle_outline,
                  gefahr: true,
                  onTap: () => _erledigen(
                        f,
                        'abgeschrieben',
                        'Alle noch offenen Rechnungen des Falls werden abgeschrieben '
                            '(mit Buchung).',
                        gefahr: true,
                      )),
              _knopf('erl_zurueckgezogen', 'Betreibung zurückgezogen',
                  icon: Icons.undo,
                  primaer: false,
                  onTap: () => _erledigen(
                        f,
                        'zurueckgezogen',
                        'Der Fall wird ohne Buchung abgeschlossen; die Rechnungen '
                            'bleiben, wie sie sind.',
                      )),
            ]),
          ],
        ),
      ],
    );
  }

  Future<void> _datenblattSpeichern(Mahnfall f) async {
    final roh = _vorschuss.text.trim().replaceAll(',', '.');
    final vorschuss = roh.isEmpty ? null : double.tryParse(roh);
    if (roh.isNotEmpty && vorschuss == null) {
      _meldung('Kostenvorschuss: bitte eine Zahl eingeben.');
      return;
    }
    await _aktion(
      'datenblatt',
      () => MahnfallService.betreibungSpeichern(f, {
        'schuldner_name': _name.text,
        'schuldner_adresse': _adresse.text,
        'rechtsform': _rechtsform,
        'betreibungsamt': _amt.text,
        'kosten_vorschuss': vorschuss,
      }),
      erfolg: 'Datenblatt gespeichert.',
    );
  }

  Future<void> _erledigen(Mahnfall f, String erledigung, String text,
      {bool gefahr = false}) async {
    final titel = switch (erledigung) {
      'bezahlt' => 'Erledigt: bezahlt?',
      'abgeschrieben' => 'Erledigt: abschreiben?',
      _ => 'Betreibung zurückgezogen?',
    };
    if (!await _bestaetigen(titel, text, 'Abschliessen', gefahr: gefahr)) return;
    await _aktion('erl_$erledigung', () => MahnfallService.erledigen(f, erledigung),
        erfolg: 'Fall abgeschlossen.');
  }

  Widget _datumSchritt(Mahnfall f, String label, String feld, DateTime? wert) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _laeuft != null ? null : () => _datumWaehlen(f, feld, wert),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      wert != null ? _datum(wert) : 'wählen',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: wert != null ? FontWeight.w600 : null,
                        color: wert != null ? null : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (wert != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _laeuft != null
                    ? null
                    : () => _aktion(feld, () => MahnfallService.betreibungSpeichern(f, {feld: null})),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      );

  Future<void> _datumWaehlen(Mahnfall f, String feld, DateTime? aktuell) async {
    final jetzt = DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: aktuell != null ? DateTime(aktuell.year, aktuell.month, aktuell.day) : jetzt,
      firstDate: DateTime(2020),
      lastDate: DateTime(jetzt.year + 2, 12, 31),
    );
    if (p == null) return;
    await _aktion(feld, () => MahnfallService.betreibungSpeichern(f, {feld: p}));
  }

  Widget _chip(Mahnfall f, String text, bool wert) {
    final an = f.rechtsvorschlag == wert;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _laeuft != null
          ? null
          : () => _aktion('rechtsvorschlag',
              () => MahnfallService.betreibungSpeichern(f, {'rechtsvorschlag': an ? null : wert})),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: an ? AppColors.primary.withAlpha(30) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: an ? AppColors.primary : AppColors.divider),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: an ? FontWeight.w700 : null,
            color: an ? AppColors.primary : null,
          ),
        ),
      ),
    );
  }

  Widget _protokollZeile(Rechnung r) {
    final async = ref.watch(protokollPfadeZuRechnungProvider(r.id));
    final nr = r.rechnungsnummer ?? '—';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: async.when(
        loading: () => Text('$nr: Protokolle werden gesucht …',
            style: const TextStyle(fontSize: 12)),
        error: (e, _) => Text('$nr: Protokolle nicht ladbar (${kurzeFehlermeldung(e)})',
            style: const TextStyle(fontSize: 12, color: AppColors.error)),
        data: (pfade) => Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$nr:', style: const TextStyle(fontSize: 12)),
            if (pfade.isEmpty)
              Text('kein Protokoll',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            for (var i = 0; i < pfade.length; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _protokollOeffnen(pfade[i]),
                child: Text(
                  pfade.length == 1 ? 'Protokoll' : 'Protokoll ${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _protokollOeffnen(String pfad) async {
    try {
      final url = await ProtokollFotoStorage.getSignedUrl(pfad);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _meldung('Protokoll nicht ladbar: ${kurzeFehlermeldung(e)}');
    }
  }

  Future<void> _easyGovOeffnen() async {
    try {
      await launchUrl(Uri.parse('https://www.easygov.swiss'),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      _meldung('EasyGov nicht erreichbar: ${kurzeFehlermeldung(e)}');
    }
  }

  // ─── Übernahme ───

  Widget _uebernahmeBlock(Mahnfall f) {
    final offen = (f.notiz ?? '').contains(MahnfallService.kUebernahmeOffen);
    if (!offen) {
      return _kasten(
        farbe: AppColors.success,
        child: const Text(
          'Heineken hat übernommen — Übernahme ist verbucht.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }
    return _kasten(
      farbe: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Heineken hat übernommen — Buchung und Position auf der '
            'Monatsrechnung mit Daniel prüfen.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _knopf('verbucht', 'Übernahme ist verbucht',
              icon: Icons.done_all,
              onTap: () async {
                if (!await _bestaetigen(
                  'Übernahme verbucht?',
                  'Die Erinnerung in der Glocke verschwindet.',
                  'Ist verbucht',
                )) {
                  return;
                }
                await _aktion('verbucht', () => MahnfallService.uebernahmeVerbucht(f));
              }),
        ],
      ),
    );
  }

  // ─── Notiz ───

  Widget _notizBlock(Mahnfall f) => _karte(
        titel: 'Notiz',
        children: [
          TextField(
            controller: _notiz,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'Telefonate, Absprachen, Aktenzeichen …',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _knopf('notiz', 'Notiz speichern',
                icon: Icons.save,
                primaer: false,
                onTap: () => _aktion('notiz', () => MahnfallService.notizSpeichern(f, _notiz.text),
                    erfolg: 'Notiz gespeichert.')),
          ),
        ],
      );

  // ─── Aktionen ───

  /// Führt eine Aktion aus; `MahnfallFehler` und alles andere als lesbare
  /// Meldung. Danach Fall und Mahnlauf neu laden. `true` bei Erfolg.
  Future<bool> _aktion(String key, Future<Object?> Function() f, {String? erfolg}) async {
    setState(() => _laeuft = key);
    var ok = false;
    try {
      await f();
      ok = true;
      if (erfolg != null) _meldung(erfolg);
    } on MahnfallFehler catch (e) {
      _meldung(e.meldung);
    } catch (e) {
      _meldung(kurzeFehlermeldung(e));
    } finally {
      if (mounted) {
        setState(() => _laeuft = null);
        _neuLaden();
      }
    }
    return ok;
  }

  void _neuLaden() {
    ref.invalidate(mahnfallProvider(widget.id));
    ref.invalidate(mahnfaelleZuRechnungProvider);
    ref.invalidate(mahnlaufProvider);
    ref.invalidate(rechnungenStreamProvider);
  }

  Future<bool> _bestaetigen(String titel, String text, String knopf,
      {bool gefahr = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titel),
        content: Text(text),
        actions: [
          TapKnopf(text: 'Abbrechen', primaer: false, onTap: () => Navigator.pop(ctx, false)),
          TapKnopf(text: knopf, gefahr: gefahr, onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    return ok == true;
  }

  void _meldung(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ─── Bausteine ───

  Widget _knopf(String key, String text,
          {IconData? icon, bool primaer = true, bool gefahr = false, required VoidCallback onTap}) =>
      TapKnopf(
        text: text,
        icon: icon,
        primaer: primaer,
        gefahr: gefahr,
        laeuft: _laeuft == key,
        onTap: _laeuft != null ? null : onTap,
      );

  Widget _knopfSpalte(List<Widget> knoepfe) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < knoepfe.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            knoepfe[i],
          ],
        ],
      );

  Widget _feld(String label, TextEditingController c, {int zeilen = 1, bool zahl = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          minLines: zeilen,
          maxLines: zeilen,
          keyboardType: zahl
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _karte({required String titel, required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _kasten({required Color farbe, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: farbe.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: farbe.withAlpha(90)),
        ),
        child: child,
      );

  Widget _zeile(String label, String wert) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
            Expanded(child: Text(wert, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  Widget _hinweis(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      );

  Widget _mitte(String text) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
      );
}

String _datum(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _rechnungsStatus(String s) => switch (s) {
      'offen' => 'Offen',
      'gesendet' => 'Gesendet',
      'erinnert' => 'Erinnert',
      'mahnung_1' => '1. Mahnung',
      'mahnung_2' => 'Letzte Mahnung',
      'bezahlt' => 'Bezahlt',
      'abgeschrieben' => 'Abgeschrieben',
      _ => s,
    };
