import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_betrag.dart';
import 'package:sbs_projer_app/data/models/buchung.dart';
import 'package:sbs_projer_app/data/models/dokument.dart';
import 'package:sbs_projer_app/data/models/steuerjahr.dart';
import 'package:sbs_projer_app/data/repositories/dokument_repository.dart';
import 'package:sbs_projer_app/data/repositories/steuerjahr_repository.dart';
import 'package:sbs_projer_app/presentation/providers/steuern_providers.dart';
import 'package:sbs_projer_app/presentation/screens/buchhaltung/steuern/steuer_zuordnung_dialog.dart';
import 'package:sbs_projer_app/presentation/widgets/dokumente/dokument_liste.dart';
import 'package:sbs_projer_app/presentation/widgets/dokumente/dokument_upload_dialog.dart';
import 'package:sbs_projer_app/presentation/widgets/steuern/steuer_ampel.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';
import 'package:sbs_projer_app/services/steuern/dokument_pfad.dart';
import 'package:sbs_projer_app/services/steuern/steuerjahr_rechner.dart';

final _chf = NumberFormat('#,##0.00', 'de_CH');
final _df = DateFormat('dd.MM.yyyy');

/// Jahresdetail: Veranlagung erfassen, Soll/Ist, Zahlungen, Dokumente.
class SteuerjahrScreen extends ConsumerStatefulWidget {
  final int jahr;

  const SteuerjahrScreen({super.key, required this.jahr});

  @override
  ConsumerState<SteuerjahrScreen> createState() => _SteuerjahrScreenState();
}

class _SteuerjahrScreenState extends ConsumerState<SteuerjahrScreen> {
  String _status = 'offen';
  DateTime? _eingereicht;
  DateTime? _veranlagt;
  final _c = {
    for (final k in [
      'gewinn',
      'kapital',
      'verlust',
      'bp',
      'bd',
      'kp',
      'kd',
      'notizen',
    ])
      k: TextEditingController(),
  };
  bool _geladen = false;
  bool _speichert = false;

  /// Ungespeicherte Formular-Änderungen. Steuert Rückfrage beim Verlassen
  /// und das Sternchen am Speichern-Knopf.
  bool _geaendert = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _markiereGeaendert() {
    if (!_geaendert) setState(() => _geaendert = true);
  }

  /// Formular einmalig aus dem geladenen Steuerjahr füllen (nicht bei jedem
  /// Rebuild — sonst überschriebe ein Provider-Refresh die Tipparbeit).
  void _fuelle(Steuerjahr s) {
    if (_geladen) return;
    _geladen = true;
    _status = s.status;
    _eingereicht = s.eingereichtAm;
    _veranlagt = s.veranlagtAm;
    String t(double? v) => v == null ? '' : v.toStringAsFixed(2);
    _c['gewinn']!.text = t(s.steuerbarerGewinn);
    _c['kapital']!.text = t(s.steuerbaresKapital);
    _c['verlust']!.text = t(s.verlustvortragVerrechnet);
    _c['bp']!.text = t(s.bundProvisorisch);
    _c['bd']!.text = t(s.bundDefinitiv);
    _c['kp']!.text = t(s.kantonProvisorisch);
    _c['kd']!.text = t(s.kantonDefinitiv);
    _c['notizen']!.text = s.notizen ?? '';
    // Erst nach dem Befüllen horchen — sonst gälte das Laden selbst schon
    // als Änderung und die Rückfrage käme bei jedem Verlassen.
    for (final c in _c.values) {
      c.addListener(_markiereGeaendert);
    }
  }

  /// Rückfrage vor dem Verlassen mit ungespeicherten Änderungen.
  Future<bool> _verwerfenFragen() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Änderungen verwerfen?'),
          content: const Text(
            'Die Veranlagung wurde geändert, aber nicht gespeichert.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Weiter bearbeiten'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Verwerfen'),
            ),
          ],
        ),
      ) ??
      false;

  double? _n(String k) => chfBetragParsen(_c[k]!.text);

  static const _labels = {
    'gewinn': 'Steuerbarer Gewinn',
    'kapital': 'Steuerbares Kapital',
    'verlust': 'Verlust verrechnet',
    'bp': 'Bund provisorisch',
    'bd': 'Bund definitiv',
    'kp': 'Kanton provisorisch',
    'kd': 'Kanton definitiv',
  };
  String _label(String k) => _labels[k] ?? k;

  Future<void> _speichern(Steuerjahr alt) async {
    final messenger = ScaffoldMessenger.of(context);
    // Ungültige Zahl → nicht still als «kein Betrag» verwerfen.
    for (final k in _labels.keys) {
      if (_c[k]!.text.trim().isNotEmpty && _n(k) == null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Ungültiger Betrag im Feld «${_label(k)}»')),
        );
        return;
      }
    }
    setState(() => _speichert = true);
    try {
      await SteuerjahrRepository.upsert(
        alt.copyWith(
          jahr: widget.jahr,
          status: _status,
          eingereichtAm: _eingereicht,
          veranlagtAm: _veranlagt,
          steuerbarerGewinn: _n('gewinn'),
          steuerbaresKapital: _n('kapital'),
          verlustvortragVerrechnet: _n('verlust'),
          bundProvisorisch: _n('bp'),
          bundDefinitiv: _n('bd'),
          kantonProvisorisch: _n('kp'),
          kantonDefinitiv: _n('kd'),
          notizen: _c['notizen']!.text.trim().isEmpty
              ? null
              : _c['notizen']!.text.trim(),
        ),
      );
      // Gespeichert = nicht mehr «offen»; das setState folgt im finally.
      _geaendert = false;
      if (!mounted) return;
      invalidateSteuern(ref);
      messenger.showSnackBar(
        const SnackBar(content: Text('Veranlagung gespeichert')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  Future<void> _loeschen(Dokument d) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DokumentRepository.delete(d);
      if (mounted) invalidateSteuern(ref);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final zeile = ref.watch(steuerjahrZeileProvider(widget.jahr));
    final zahlungen = ref.watch(steuerzahlungenProvider(widget.jahr));
    final offen = ref.watch(nichtZugeordneteSteuerbuchungenProvider);
    final docs = ref.watch(steuerDokumenteProvider(widget.jahr));
    return PopScope(
      canPop: !_geaendert,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final verwerfen = await _verwerfenFragen();
        if (verwerfen && context.mounted) Navigator.pop(context);
      },
      child: _inhalt(zeile, zahlungen, offen, docs),
    );
  }

  Widget _inhalt(
    AsyncValue<SteuerjahrZeile> zeile,
    AsyncValue<List<Buchung>> zahlungen,
    AsyncValue<List<Buchung>> offen,
    AsyncValue<List<Dokument>> docs,
  ) {
    return Scaffold(
      appBar: AppBar(title: Text('Steuern ${widget.jahr}')),
      body: zeile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Fehler: $e'),
              const SizedBox(height: 8),
              TapKnopf(
                text: 'Erneut laden',
                primaer: false,
                onTap: () => invalidateSteuern(ref),
              ),
            ],
          ),
        ),
        data: (z) {
          _fuelle(z.jahr);
          final docList = docs.value ?? const <Dokument>[];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _titel('1 · Veranlagung'),
              _veranlagungForm(z.jahr),
              _titel('2 · Soll / Ist'),
              _sollIstTabelle(z),
              _titel('3 · Zahlungen'),
              zahlungen.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Fehler: $e'),
                data: (l) => l.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Keine zugeordneten Zahlungen.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : Column(
                        children: [
                          // Auch zugeordnete Zeilen sind antippbar — eine
                          // falsche Zuordnung liesse sich sonst nicht mehr
                          // korrigieren.
                          for (final b in l)
                            _zahlungZeile(
                              b,
                              docList.any((d) => d.buchungId == b.id),
                            ),
                        ],
                      ),
              ),
              offen.when(
                loading: () => const SizedBox(),
                error: (e, _) => Text('Fehler: $e'),
                data: (l) => l.isEmpty
                    ? const SizedBox()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 10, bottom: 4),
                            child: Text(
                              // Die Liste ist bewusst nicht jahresgefiltert —
                              // ohne Zuordnung ist ja unbekannt, wohin die
                              // Buchung gehört.
                              'Nicht zugeordnete Steuerbuchungen (alle Jahre)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                          for (final b in l) _zahlungZeile(b, false),
                        ],
                      ),
              ),
              _titel('4 · Dokumente'),
              _dossier(z.dossier),
              docs.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Fehler: $e'),
                data: (l) => DokumentListe(dokumente: l, onLoeschen: _loeschen),
              ),
              const SizedBox(height: 8),
              TapKnopf(
                text: 'Dokument hochladen',
                icon: Icons.upload_file,
                // Solange die Zahlungen laden, böte der Dialog eine leere
                // Verknüpfungs-Liste an — der Beleg landete ohne Zahlung.
                onTap: zahlungen.isLoading
                    ? null
                    : () async {
                        final d = await showDokumentUploadDialog(
                          context,
                          bereich: 'steuern',
                          jahr: widget.jahr,
                          buchungen: zahlungen.value ?? const [],
                        );
                        if (d != null && mounted) invalidateSteuern(ref);
                      },
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _titel(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
    child: Text(
      t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );

  Widget _karte(Widget child) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: child,
  );

  Widget _feld(String key) => Expanded(
    child: TextField(
      controller: _c[key]!,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: _label(key), isDense: true),
    ),
  );

  Widget _datumZeile(String label, DateTime? v, void Function(DateTime?) set) =>
      Row(
        children: [
          Expanded(child: Text('$label: ${v == null ? '—' : _df.format(v)}')),
          TextButton(
            onPressed: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: v ?? DateTime.now(),
                firstDate: DateTime(kSteuerJahrAb),
                lastDate: DateTime(2035),
              );
              if (p != null && mounted) {
                setState(() {
                  set(p);
                  _geaendert = true;
                });
              }
            },
            child: const Text('wählen'),
          ),
          if (v != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 16),
              tooltip: 'löschen',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() {
                set(null);
                _geaendert = true;
              }),
            ),
        ],
      );

  Widget _veranlagungForm(Steuerjahr s) => _karte(
    Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _status,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status', isDense: true),
          items: [
            for (final k in Steuerjahr.statusLabels.keys)
              DropdownMenuItem(
                value: k,
                child: Text(Steuerjahr.statusLabel(k)),
              ),
          ],
          onChanged: (v) => setState(() {
            _status = v!;
            _geaendert = true;
          }),
        ),
        _datumZeile('Eingereicht', _eingereicht, (d) => _eingereicht = d),
        _datumZeile('Veranlagt', _veranlagt, (d) => _veranlagt = d),
        Row(
          children: [
            _feld('gewinn'),
            const SizedBox(width: 8),
            _feld('kapital'),
          ],
        ),
        Row(
          children: [
            _feld('verlust'),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
        Row(children: [_feld('bp'), const SizedBox(width: 8), _feld('bd')]),
        Row(children: [_feld('kp'), const SizedBox(width: 8), _feld('kd')]),
        TextField(
          controller: _c['notizen']!,
          decoration: const InputDecoration(
            labelText: 'Notizen',
            isDense: true,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TapKnopf(
            // Sternchen = ungespeicherte Änderungen.
            text: _geaendert ? 'Speichern*' : 'Speichern',
            laeuft: _speichert,
            onTap: () => _speichern(s),
          ),
        ),
      ],
    ),
  );

  /// Breite einer Zahlenspalte. Fest, damit jede Zeile dieselbe natürliche
  /// Breite hat — nur so skaliert die [FittedBox] alle Zeilen um denselben
  /// Faktor und die Spalten stehen untereinander. Eine FittedBox je Zelle
  /// würde jede Zelle einzeln skalieren: unterschiedlich grosse Schriften
  /// in einer Zeile.
  static const double _spalte = 64;

  Widget _sollIstTabelle(SteuerjahrZeile z) {
    final s = z.sollIst;
    Widget zelle(String t, {bool bold = false, Color? c}) => SizedBox(
      width: _spalte,
      child: Text(
        t,
        textAlign: TextAlign.right,
        softWrap: false,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: c,
        ),
      ),
    );
    // Vier Zahlenspalten als eine Einheit skalieren.
    Widget zahlen(List<Widget> zellen) => Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(mainAxisSize: MainAxisSize.min, children: zellen),
      ),
    );
    Color offenFarbe(double v) => v.abs() <= 0.05
        ? AppColors.success
        : (v > 0 ? AppColors.error : AppColors.info);
    return _karte(
      Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 74),
              zahlen([
                zelle('prov.', bold: true),
                zelle('def.', bold: true),
                zelle('bezahlt', bold: true),
                zelle('offen', bold: true),
              ]),
            ],
          ),
          for (final zl in s.zeilen)
            Row(
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    steuerarten[zl.steuerart] ?? zl.steuerart,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                zahlen([
                  zelle(
                    zl.provisorisch == null
                        ? '—'
                        : _chf.format(zl.provisorisch),
                  ),
                  zelle(zl.definitiv == null ? '—' : _chf.format(zl.definitiv)),
                  zelle(_chf.format(zl.bezahlt)),
                  zelle(_chf.format(zl.offen), c: offenFarbe(zl.offen)),
                ]),
              ],
            ),
          const Divider(),
          Row(
            children: [
              AmpelPunkt(
                farbe: s.sollUnvollstaendig
                    ? AppColors.warning
                    : ampelFarbe(s.ampel),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.sollUnvollstaendig
                      ? 'Veranlagung fehlt — Soll/Ist unvollständig'
                      : 'Gewinn Buchhaltung ${_chf.format(z.buchhaltungsgewinn)}'
                            '${z.jahr.steuerbarerGewinn == null ? '' : ' · steuerbar '
                                      '${_chf.format(z.jahr.steuerbarerGewinn)} · Differenz '
                                      '${_chf.format(z.jahr.steuerbarerGewinn! - z.buchhaltungsgewinn)}'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Eine Zahlungszeile. Tippen öffnet immer den Zuordnungs-Dialog — auch bei
  /// bereits zugeordneten Zeilen, sonst wäre ein Fehlgriff nicht korrigierbar.
  Widget _zahlungZeile(Buchung b, bool hatBeleg) {
    // Rückstellungs-/Umbuchungszeilen (2208 an 8900) tragen ein Steuerjahr,
    // sind aber kein Geldfluss — ohne den Hinweis widersprächen Liste und
    // «bezahlt»-Spalte einander.
    final istGeld =
        b.sollKonto == 1000 ||
        b.sollKonto == 1020 ||
        b.habenKonto == 1000 ||
        b.habenKonto == 1020;
    // Das offene Jahr nur vorschlagen, wenn es zum Buchungsdatum passt —
    // die Liste der nicht zugeordneten Buchungen umfasst alle Jahre, und ein
    // falscher Vorschlag wird beim Durchklicken zu einer falschen Zuordnung.
    final vorschlag =
        (b.datum.year == widget.jahr || b.datum.year - 1 == widget.jahr)
        ? widget.jahr
        : null;
    return InkWell(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          if (await showSteuerZuordnungDialog(
                context,
                b,
                vorschlagJahr: vorschlag,
              ) &&
              mounted) {
            invalidateSteuern(ref);
          }
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Zuordnen fehlgeschlagen: $e')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Text(_df.format(b.datum), style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${b.beschreibung}'
                '${istGeld ? '' : ' (Umbuchung, keine Zahlung)'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (b.steuerart != null)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  steuerarten[b.steuerart] ?? b.steuerart!,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            Text(
              _chf.format(b.betragBrutto),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            if (hatBeleg)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.attach_file, size: 14),
              ),
            // Dezent: das Icon markiert nur die Antippbarkeit, nicht einen
            // Missstand — jede Zeile lässt sich bearbeiten.
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// Pflicht-Dokumente des Jahres als Häkchen-/Fehlt-Chips.
  Widget _dossier(Dossier d) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final p in pflichtTypen(jahr: widget.jahr, heute: DateTime.now()))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: d.fehlend.contains(p)
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${d.fehlend.contains(p) ? '–' : '✓'} ${pflichtTypLabel(p)}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    ),
  );
}
