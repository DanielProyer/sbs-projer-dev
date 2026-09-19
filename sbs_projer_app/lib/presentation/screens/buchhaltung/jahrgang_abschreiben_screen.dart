import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/anfrage_bloecke.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/data/models/abschreibung_lauf.dart';
import 'package:sbs_projer_app/data/repositories/abschreibung_lauf_repository.dart';
import 'package:sbs_projer_app/presentation/providers/abschreibung_providers.dart';
import 'package:sbs_projer_app/presentation/providers/buchhaltung_providers.dart';
import 'package:sbs_projer_app/presentation/widgets/filter/app_filter_bar.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/buchhaltung/jahrgang_abschreibung.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart'
    show kSteuerJahrAb;

/// Abschluss-Schritt «Jahrgang abschreiben»: Vorschau der verjährten
/// Kundenrechnungen eines Geschäftsjahres, Freigabe, Lauf mit Rücknahme.
///
/// Erreichbar aus der Abschlussprüfung (Regel «Offene Rechnungen älter als
/// 5 Jahre»). Gebucht wird in der Datenbank in einer Transaktion
/// (`abschreibung_jahrgang_buchen`, Migration 194).
class JahrgangAbschreibenScreen extends ConsumerStatefulWidget {
  final int? jahr;
  const JahrgangAbschreibenScreen({super.key, this.jahr});

  @override
  ConsumerState<JahrgangAbschreibenScreen> createState() =>
      _JahrgangAbschreibenScreenState();
}

class _JahrgangAbschreibenScreenState
    extends ConsumerState<JahrgangAbschreibenScreen> {
  late int _jahr = _gueltig(widget.jahr) ? widget.jahr! : DateTime.now().year;
  bool _laeuft = false;
  bool _listeOffen = false;

  static bool _gueltig(int? j) =>
      j != null && j >= kSteuerJahrAb && j <= DateTime.now().year;

  @override
  void didUpdateWidget(JahrgangAbschreibenScreen alt) {
    super.didUpdateWidget(alt);
    if (widget.jahr != alt.jahr && _gueltig(widget.jahr)) {
      setState(() => _jahr = widget.jahr!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final laeufe = ref.watch(abschreibungLaeufeProvider);
    final vorschau = ref.watch(jahrgangAbschreibVorschauProvider(_jahr));
    return Scaffold(
      appBar: AppBar(title: const Text('Jahrgang abschreiben')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: AppFilterDropdown<int>(
              hint: 'Geschäftsjahr',
              value: _jahr,
              nullable: false,
              isExpanded: true,
              options: [
                for (var j = DateTime.now().year; j >= kSteuerJahrAb; j--)
                  (j, 'Abschluss $j'),
              ],
              onChanged: (v) => setState(() {
                _jahr = v ?? _jahr;
                _listeOffen = false;
              }),
            ).build(context),
          ),
          Expanded(
            child: laeufe.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _fehler(e),
              data: (alle) => vorschau.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _fehler(e),
                data: (v) {
                  final lauf = alle
                      .where((l) => l.geschaeftsjahr == _jahr && l.gebucht)
                      .firstOrNull;
                  return JahrgangAbschreibenInhalt(
                    vorschau: v,
                    lauf: lauf,
                    heute: DateTime.now(),
                    laeuft: _laeuft,
                    listeOffen: _listeOffen,
                    onListeToggle: () =>
                        setState(() => _listeOffen = !_listeOffen),
                    onBuchen: () => _buchen(v),
                    onZuruecknehmen: lauf == null
                        ? null
                        : () => _zuruecknehmen(lauf),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fehler(Object e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text('Konnte nicht laden: ${kurzeFehlermeldung(e)}'),
    ),
  );

  Future<void> _buchen(AbschreibVorschau v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Jahrgänge ${v.jahrgangText} abschreiben?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${v.total.anzahl} Rechnungen, brutto ${chf(v.total.brutto)}'),
            const SizedBox(height: 8),
            Text('Datiert 31.12.${v.geschaeftsjahr}, je Rechnung:'),
            Text('• 3805 an 1100  netto  ${chf(v.total.netto)}'),
            for (final s in v.saetze)
              Text('• 2200 an 1100  MWST ${s.satz} %  ${chf(s.summe.mwst)}'),
            const SizedBox(height: 8),
            Text(
              'Die Rechnungen gehen auf «abgeschrieben». Die Rückholung '
              'gehört in die MWST-Abrechnung Q4/${v.geschaeftsjahr} '
              'unter Ziff. 235. Der Lauf lässt sich zurücknehmen, solange '
              'keine der Buchungen storniert wurde.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TapKnopf(
            text: 'Abschreiben',
            icon: Icons.check,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _laeuft = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AbschreibungLaufRepository.buchen(
        geschaeftsjahr: v.geschaeftsjahr,
        rechnungIds: v.auswahl.rechnungIds,
      );
      _neuLaden();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Gebucht: ${v.total.anzahl} Rechnungen, '
            'brutto ${chf(v.total.brutto)}, MWST-Rückholung '
            '${chf(v.total.mwst)} → Ziff. 235 Q4/${v.geschaeftsjahr}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Nicht gebucht: ${_meldung(e)}'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  Future<void> _zuruecknehmen(AbschreibungLauf lauf) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lauf ${lauf.geschaeftsjahr} zurücknehmen?'),
        content: Text(
          'Löscht ${lauf.anzahl * 2} Buchungen per '
          '${_datum(lauf.buchungsdatum)} und setzt ${lauf.anzahl} Rechnungen '
          'auf den Status vorher. Eine schon eingereichte MWST-Abrechnung '
          'muss dann korrigiert werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TapKnopf(
            text: 'Zurücknehmen',
            gefahr: true,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _laeuft = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await AbschreibungLaufRepository.zuruecknehmen(lauf.id);
      _neuLaden();
      messenger.showSnackBar(
        SnackBar(content: Text('Zurückgenommen: $n Rechnungen wieder offen')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Nicht zurückgenommen: ${_meldung(e)}'),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  void _neuLaden() {
    ref.invalidate(abschreibungLaeufeProvider);
    ref.invalidate(jahrgangAbschreibVorschauProvider(_jahr));
    ref.invalidate(abschlussPruefungProvider(_jahr));
    ref.invalidate(debitorenUebersichtProvider);
    ref.invalidate(mwstQuartalDetailProvider(_jahr));
  }
}

String _datum(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

/// Die SQL-Funktion meldet auf Deutsch, was nicht geht («Für 2026 gibt es
/// schon einen gebuchten Lauf»). Diese Meldung soll ganz ankommen — nicht
/// hinter «PostgrestException(message: …» auf 80 Zeichen gekappt.
String _meldung(Object e) =>
    e is PostgrestException ? e.message : kurzeFehlermeldung(e);

/// Der Inhalt ohne Provider — damit ein Layout-Test ihn auf 360 px mit
/// grosser Schrift aufbauen kann.
class JahrgangAbschreibenInhalt extends StatelessWidget {
  final AbschreibVorschau vorschau;
  final AbschreibungLauf? lauf;
  final DateTime heute;
  final bool laeuft;
  final bool listeOffen;
  final VoidCallback onListeToggle;
  final VoidCallback? onBuchen;
  final VoidCallback? onZuruecknehmen;

  const JahrgangAbschreibenInhalt({
    super.key,
    required this.vorschau,
    required this.lauf,
    required this.heute,
    required this.laeuft,
    required this.listeOffen,
    required this.onListeToggle,
    required this.onBuchen,
    required this.onZuruecknehmen,
  });

  int get jahr => vorschau.geschaeftsjahr;
  bool get jahrLaeuftNoch => jahr >= heute.year;

  @override
  Widget build(BuildContext context) {
    final v = vorschau;
    final l = lauf;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (l != null) ...[_laufKarte(context, l), const SizedBox(height: 12)],
        _vorschauKarte(context, v),
        if (v.auswahl.ausgeschlossen.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ausgeschlossenKarte(v),
        ],
        if (!v.auswahl.leer) ...[const SizedBox(height: 12), _liste(v)],
        if (l == null && !v.auswahl.leer) ...[
          const SizedBox(height: 16),
          if (jahrLaeuftNoch) _hinweisJahrLaeuft(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TapKnopf(
              text: 'Jahrgänge ${v.jahrgangText} abschreiben',
              icon: Icons.playlist_add_check,
              laeuft: laeuft,
              onTap: onBuchen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bucht ${v.total.anzahl} × (3805 an 1100 netto + 2200 an 1100 '
            'MWST) per 31.12.$jahr in einem Zug, setzt die Rechnungen auf '
            '«abgeschrieben» und merkt Ziff. 235 für Q4/$jahr vor.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _karte({required Widget child, Color? farbe, Color? rand}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: farbe ?? Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: rand ?? AppColors.divider),
        ),
        child: child,
      );

  Widget _titel(String t) =>
      Text(t, style: const TextStyle(fontWeight: FontWeight.w700));

  Widget _zeile(String label, String wert, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          wert,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _laufKarte(BuildContext context, AbschreibungLauf l) => _karte(
    farbe: const Color(0xFFF0FDF4),
    rand: AppColors.success,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: _titel(
                'Gebucht'
                '${l.createdAt == null ? '' : ' am ${_datum(l.createdAt!)}'}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _zeile(
          'Jahrgänge ${l.jahrgaenge.join(', ')} · ${l.anzahl} Rechnungen',
          chf(l.brutto),
          bold: true,
        ),
        _zeile(
          'Debitorenverlust (3805), per ${_datum(l.buchungsdatum)}',
          chf(l.netto),
        ),
        _zeile(
          'MWST-Rückholung ${l.satz} % → Ziff. 235 in Q${l.mwstQuartal}/${l.mwstJahr}',
          chf(l.mwst),
        ),
        if (l.notizen != null && l.notizen!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            l.notizen!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (l.ruecknahmeMoeglich)
          Align(
            alignment: Alignment.centerLeft,
            child: TapKnopf(
              text: 'Lauf zurücknehmen',
              gefahr: true,
              icon: Icons.undo,
              laeuft: laeuft,
              onTap: onZuruecknehmen,
            ),
          )
        else
          const Text(
            'Per SQL gebucht — Rücknahme nur von Hand.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
      ],
    ),
  );

  Widget _vorschauKarte(BuildContext context, AbschreibVorschau v) {
    final grenze = v.auswahl.grenze;
    return _karte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titel('Verjährt per 31.12.$jahr'),
          Text(
            'Jahrgänge bis $grenze — fünf Jahre, Art. 128 OR',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (v.auswahl.leer)
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lauf == null
                        ? 'Keine offene Kundenrechnung bis Jahrgang $grenze.'
                        : 'Alles gebucht — keine offene Rechnung mehr bis '
                              'Jahrgang $grenze.',
                  ),
                ),
              ],
            )
          else ...[
            _zeile('Rechnungen', '${v.total.anzahl}'),
            _zeile('Netto → 3805 Debitorenverluste', chf(v.total.netto)),
            for (final s in v.saetze)
              _zeile(
                'MWST ${s.satz} % → 2200'
                '${s.formularZeile.isEmpty ? '' : ' (${s.formularZeile})'}',
                chf(s.summe.mwst),
              ),
            _zeile('Brutto ab 1100 Debitoren', chf(v.total.brutto), bold: true),
            for (final j in v.jahrgaenge) ...[
              const Divider(height: 16),
              _zeile(
                'Jahrgang ${j.jahrgang} · ${j.total.anzahl} Rechnungen',
                chf(j.total.brutto),
                bold: true,
              ),
              for (final k in AbschreibKategorie.values)
                if ((j.jeKategorie[k]?.anzahl ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _zeile(
                      '${k.label} · ${j.jeKategorie[k]!.anzahl} — ${k.erklaerung}',
                      chf(j.jeKategorie[k]!.brutto),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _ausgeschlossenKarte(AbschreibVorschau v) => _karte(
    farbe: const Color(0xFFFFFBEB),
    rand: AppColors.warning,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titel('Nicht im Lauf (${v.auswahl.ausgeschlossen.length})'),
        const SizedBox(height: 4),
        for (final a in v.auswahl.ausgeschlossen)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _zeile(
                  '${a.nummer} ${a.betrieb} · ${_datum(a.datum)}',
                  chf(a.brutto),
                ),
                Text(
                  a.grund,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _hinweisJahrLaeuft() => _karte(
    farbe: const Color(0xFFFFFBEB),
    rand: AppColors.warning,
    child: Text(
      'Das Jahr $jahr läuft noch. Bis 31.12. kann eine Zahlung eintreffen; '
      'vorgesehen ist dieser Schritt im Januar ${jahr + 1}, vor der '
      'MWST-Abrechnung Q4/$jahr. Buchen geht trotzdem — und lässt sich '
      'per «Lauf zurücknehmen» umkehren.',
      style: const TextStyle(fontSize: 12),
    ),
  );

  Widget _liste(AbschreibVorschau v) => _karte(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onListeToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _titel(
                    listeOffen
                        ? 'Rechnungen ausblenden'
                        : 'Rechnungen anzeigen (${v.total.anzahl})',
                  ),
                ),
                Icon(
                  listeOffen ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (listeOffen)
          for (final p in v.auswahl.positionen)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _zeile('${p.nummer} ${p.betrieb}', chf(p.brutto)),
                  Text(
                    '${_datum(p.datum)} · ${p.kategorie.label}'
                    ' · MWST ${chf(p.mwst)} (${p.satz} %)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}
