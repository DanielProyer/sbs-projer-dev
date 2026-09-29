import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/chf_betrag.dart';
import 'package:sbs_projer_app/core/util/chf_format.dart';
import 'package:sbs_projer_app/core/util/steuerrueckstellung.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Was der Dialog zurückgibt: die neue Rückstellung und die Herleitung für
/// die Notiz der Buchung.
typedef RueckstellungEingabe = ({double ziel, String begruendung});

/// Dialog «Steuerrückstellung buchen» (Jahresabschluss Schritt D) — nur
/// Oberfläche, bucht nichts. `null` bei Abbrechen.
Future<RueckstellungEingabe?> zeigeRueckstellungDialog(
  BuildContext context, {
  required int jahr,
  required SteuerrueckstellungLage lage,
}) => showDialog<RueckstellungEingabe>(
  context: context,
  builder: (_) => RueckstellungDialog(jahr: jahr, lage: lage),
);

/// Der Dialog selbst — öffentlich für den Widget-Test.
///
/// Zeigt Gewinn vor Rückstellung, Aufrechnungen, Satz und Vorschlag; der
/// Betrag ist vorbefüllt und editierbar. Solange er nicht von Hand geändert
/// wurde, folgt er dem Vorschlag, wenn Satz oder Aufrechnungen sich ändern.
/// CanvasKit: Knöpfe als `TapKnopf`, «Buchen» rot (`gefahr`), weil die
/// Abschlussbuchung das Jahr als abgeschlossen markiert.
class RueckstellungDialog extends StatefulWidget {
  final int jahr;
  final SteuerrueckstellungLage lage;

  const RueckstellungDialog({
    super.key,
    required this.jahr,
    required this.lage,
  });

  @override
  State<RueckstellungDialog> createState() => _RueckstellungDialogState();
}

class _RueckstellungDialogState extends State<RueckstellungDialog> {
  late final TextEditingController _weitere;
  late final TextEditingController _satz;
  late final TextEditingController _ziel;

  /// Betrag von Hand geändert → folgt dem Vorschlag nicht mehr.
  bool _zielVonHand = false;

  SteuerrueckstellungLage get _lage => widget.lage;

  @override
  void initState() {
    super.initState();
    _weitere = TextEditingController(text: '0');
    _satz = TextEditingController(
      text: (kSteuersatzEffektiv * 100).toStringAsFixed(1),
    );
    _ziel = TextEditingController(text: _vorschlag?.toStringAsFixed(2) ?? '');
  }

  @override
  void dispose() {
    _weitere.dispose();
    _satz.dispose();
    _ziel.dispose();
    super.dispose();
  }

  /// Leeres Feld = 0; unlesbar oder negativ = `null`.
  double? get _weitereWert {
    if (_weitere.text.trim().isEmpty) return 0;
    final v = chfBetragParsen(_weitere.text);
    return v == null || v < 0 ? null : v;
  }

  /// Satz als Faktor (18.2 → 0.182); nur 0 < s < 100 %.
  double? get _satzWert {
    final v = chfBetragParsen(_satz.text);
    return v == null || v <= 0 || v >= 100 ? null : v / 100;
  }

  double? get _aufrechnungen {
    final w = _weitereWert;
    return w == null ? null : _lage.aufrechnungenAuto + w;
  }

  double? get _vorschlag {
    final a = _aufrechnungen;
    final s = _satzWert;
    if (a == null || s == null) return null;
    return rueckstellungVorschlag(
      gewinnVorRueckstellung: _lage.gewinnVorRueckstellung,
      aufrechnungen: a,
      satz: s,
    );
  }

  double? get _zielWert {
    final v = chfBetragParsen(_ziel.text);
    return v == null || v < 0 ? null : v;
  }

  void _grundlageGeaendert() {
    setState(() {
      final v = _vorschlag;
      if (!_zielVonHand && v != null) _ziel.text = v.toStringAsFixed(2);
    });
  }

  void _vorschlagUebernehmen() {
    final v = _vorschlag;
    if (v == null) return;
    setState(() {
      _ziel.text = v.toStringAsFixed(2);
      _zielVonHand = false;
    });
  }

  void _buchen(double ziel) {
    final satz = (_satzWert! * 100).toStringAsFixed(1);
    final w = _weitereWert!;
    final begruendung =
        'Gewinn vor Rückstellung ${chf(_lage.gewinnVorRueckstellung)}, '
        'Aufrechnungen ${chf(_aufrechnungen!)} (Bussen '
        '${chf(_lage.aufrechnungenAuto)}'
        '${w > 0 ? ' + weitere ${chf(w)}' : ''}), Satz $satz % → Vorschlag '
        '${chf(_vorschlag!)}; bisher ${chf(_lage.gebucht)}, neu ${chf(ziel)}';
    Navigator.pop<RueckstellungEingabe>(context, (
      ziel: ziel,
      begruendung: begruendung,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final vorschlag = _vorschlag;
    final ziel = _zielWert;
    final aufrechnungen = _aufrechnungen;
    final buchung = ziel == null
        ? null
        : rueckstellungBuchung(ziel: ziel, gebucht: _lage.gebucht);
    final zuBuchen = buchung == null
        ? '—'
        : buchung.betrag < 0.01
        ? 'nichts (unverändert)'
        : '${chf(buchung.betrag)} · '
              '${buchung.aufbau ? '8900 an 2208' : '2208 an 8900'}';
    final steuerbar = ziel == null || aufrechnungen == null
        ? null
        : steuerbarerGewinn(
            gewinnNachRueckstellung: _lage.gewinnVorRueckstellung - ziel,
            aufrechnungen: aufrechnungen,
          );
    final kannBuchen =
        vorschlag != null && buchung != null && buchung.betrag >= 0.01;

    return AlertDialog(
      title: Text('Steuerrückstellung ${widget.jahr}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buchung per 31.12.${widget.jahr} gegen 8900 (Direkte '
                'Steuern).',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _zeile(
                'Gewinn vor Rückstellung',
                chf(_lage.gewinnVorRueckstellung),
              ),
              _zeile(
                'Bussen 6280/6281 (nicht abzugsfähig)',
                chf(_lage.aufrechnungenAuto),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const Key('rueckstellung_weitere'),
                controller: _weitere,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Weitere Aufrechnungen (CHF)',
                  helperText: 'z. B. Bussen auf 8900',
                  errorText: _weitereWert == null ? 'Betrag ≥ 0' : null,
                ),
                onChanged: (_) => _grundlageGeaendert(),
              ),
              TextField(
                key: const Key('rueckstellung_satz'),
                controller: _satz,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Steuersatz effektiv (%)',
                  helperText: 'an der letzten Veranlagung prüfen',
                  errorText: _satzWert == null
                      ? 'Satz zwischen 0 und 100'
                      : null,
                ),
                onChanged: (_) => _grundlageGeaendert(),
              ),
              const SizedBox(height: 8),
              _zeile(
                'Vorschlag',
                vorschlag == null ? '—' : chf(vorschlag),
                wertKey: const Key('rueckstellung_vorschlag'),
                fett: true,
              ),
              TextField(
                key: const Key('rueckstellung_ziel'),
                controller: _ziel,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Rückstellung (CHF)',
                  errorText: ziel == null ? 'Betrag ≥ 0' : null,
                ),
                onChanged: (_) => setState(() => _zielVonHand = true),
              ),
              if (_zielVonHand && vorschlag != null && ziel != vorschlag)
                InkWell(
                  key: const Key('rueckstellung_vorschlag_uebernehmen'),
                  onTap: _vorschlagUebernehmen,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Vorschlag übernehmen',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _zeile('Bisher gebucht', chf(_lage.gebucht)),
              _zeile(
                'Zu buchen',
                zuBuchen,
                wertKey: const Key('rueckstellung_differenz'),
                fett: true,
              ),
              _zeile(
                'Steuerbarer Gewinn danach',
                steuerbar == null ? '—' : chf(steuerbar),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TapKnopf(
          text: 'Abbrechen',
          primaer: false,
          onTap: () => Navigator.pop(context),
        ),
        TapKnopf(
          key: const Key('rueckstellung_buchen'),
          text: 'Buchen',
          gefahr: true,
          onTap: kannBuchen ? () => _buchen(ziel!) : null,
        ),
      ],
    );
  }

  Widget _zeile(String label, String wert, {Key? wertKey, bool fett = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            // Flexible statt fester Breite: «2'208.00 · 2208 an 8900» passt
            // bei 360 px nicht neben ein langes Label und bricht dann um.
            Flexible(
              child: Text(
                wert,
                key: wertKey,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: fett ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      );
}
