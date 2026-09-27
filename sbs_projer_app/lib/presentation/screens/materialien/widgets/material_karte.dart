import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/data/models/lager.dart';
import 'package:sbs_projer_app/presentation/widgets/tap_knopf.dart';

/// Eine Karte der Swipe-Ansicht auf `/materialien`: Foto, Nummern, Bestand
/// mit ± und Vormerken — das, was man am Fahrzeug mit einer Hand braucht.
/// Alles Weitere (Vollbild-Foto, Verbrauch, Handbuch) liegt hinter
/// «Details».
///
/// Knöpfe aus InkWell + Container statt Material-Buttons (CanvasKit-Falle,
/// CLAUDE.md).
class MaterialKarte extends StatefulWidget {
  final Lager lager;
  final String? kategorieName;

  /// Auf diesem Screen gespeicherter Bestand, den das Neuladen noch nicht
  /// zurückgebracht hat — hat Vorrang vor `lager.bestandAktuell`.
  ///
  /// WARUM: Wird die Karte dazwischen neu aufgebaut (weg- und
  /// zurückgewischt), startete sie sonst beim alten Serverwert, und der
  /// nächste Tipp überschriebe den gespeicherten — ein Tipp ginge verloren.
  final double? bestandVorgabe;

  /// Vom Screen gecacht; `Future.value(null)` ohne Foto.
  final Future<String?> fotoUrl;

  /// false → keine ± und kein Vormerken (Gast).
  final bool bearbeitbar;

  /// Screen speichert; wirft bei Fehler.
  final Future<void> Function(double neuerBestand) onBestand;
  final Future<void> Function(bool vorgemerkt) onVormerken;
  final VoidCallback onDetails;

  const MaterialKarte({
    super.key,
    required this.lager,
    this.bestandVorgabe,
    required this.kategorieName,
    required this.fotoUrl,
    required this.bearbeitbar,
    required this.onBestand,
    required this.onVormerken,
    required this.onDetails,
  });

  @override
  State<MaterialKarte> createState() => _MaterialKarteState();
}

class _MaterialKarteState extends State<MaterialKarte> {
  late double _bestand;
  late bool _vorgemerkt;
  bool _speichert = false;
  bool _merkt = false;

  static double _startwert(MaterialKarte w) =>
      w.bestandVorgabe ?? w.lager.bestandAktuell;

  @override
  void initState() {
    super.initState();
    _bestand = _startwert(widget);
    _vorgemerkt = widget.lager.vorgemerkt;
  }

  @override
  void didUpdateWidget(MaterialKarte alt) {
    super.didUpdateWidget(alt);
    // Während eines Speicherns keinen Serverstand übernehmen: Das kann nur
    // die Antwort eines älteren Neuladens sein (vor dem laufenden Tipp) —
    // sie würde die Anzeige kurz zurückdrehen. Nach dem Speichern lädt der
    // Screen ohnehin neu, und der alte Ladevorgang wird dabei verworfen.
    final neu = _startwert(widget);
    if (!_speichert && neu != _startwert(alt)) {
      _bestand = neu;
    }
    if (!_merkt && widget.lager.vorgemerkt != alt.lager.vorgemerkt) {
      _vorgemerkt = widget.lager.vorgemerkt;
    }
  }

  // Lokal gerechnet, nicht `bestandNiedrig` aus der DB: die Spalte kommt
  // erst mit dem nächsten Neuladen und hinkte dem Tipp sonst hinterher.
  bool get _niedrig => _bestand < widget.lager.bestandMindest;

  Future<void> _aendereBestand(double delta) async {
    if (_speichert) return;
    final vorher = _bestand;
    final neu = (vorher + delta).clamp(0, double.infinity).toDouble();
    if (neu == vorher) return;
    // Vor dem await holen: Ist die Karte beim Fehler schon weggewischt,
    // muss die Meldung trotzdem kommen — sonst hielte man den Tipp für
    // gespeichert.
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Optimistisch: sofort zeigen, sperren bis gespeichert — zwei schnelle
    // Tipps schickten sonst zwei Requests mit demselben Ausgangswert.
    setState(() {
      _bestand = neu;
      _speichert = true;
    });
    try {
      await widget.onBestand(neu);
    } catch (e) {
      debugPrint('[MaterialKarte] Bestand nicht gespeichert: $e');
      messenger?.showSnackBar(
        const SnackBar(content: Text('Bestand konnte nicht gespeichert werden')),
      );
      if (mounted) setState(() => _bestand = vorher);
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  Future<void> _schalteVormerken() async {
    if (_merkt) return;
    final vorher = _vorgemerkt;
    final messenger = ScaffoldMessenger.maybeOf(context); // wie oben
    setState(() {
      _vorgemerkt = !vorher;
      _merkt = true;
    });
    try {
      await widget.onVormerken(!vorher);
    } catch (e) {
      debugPrint('[MaterialKarte] Vormerkung nicht gespeichert: $e');
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Vormerkung konnte nicht gespeichert werden'),
        ),
      );
      if (mounted) setState(() => _vorgemerkt = vorher);
    } finally {
      if (mounted) setState(() => _merkt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = widget.lager;
    final nummern = [
      if (l.dboNr != null && l.dboNr!.isNotEmpty) 'DBO ${l.dboNr}',
      if (l.sapNr != null && l.sapNr!.isNotEmpty) 'SAP ${l.sapNr}',
      if (widget.kategorieName != null) widget.kategorieName!,
    ].join(' · ');
    final beschreibung = l.beschreibung?.trim() ?? '';

    // Scrollbar, damit lange Beschreibungen auf kleinen Handys nicht
    // überlaufen; horizontal wischt der PageView darum herum.
    //
    // Reihenfolge: Bestand ± ist die Hauptaktion im Auto und steht deshalb
    // VOR der Beschreibung — auf einem 640er-Handy rutschten die Knöpfe
    // sonst unter den sichtbaren Rand.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _foto(math.min(180, MediaQuery.sizeOf(context).height * 0.22)),
          const SizedBox(height: 12),
          Text(
            l.name,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (nummern.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              nummern,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _bestandBlock(theme),
          if (beschreibung.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              beschreibung,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TapKnopf(
                  text: 'Details',
                  primaer: false,
                  icon: Icons.open_in_new,
                  onTap: widget.onDetails,
                ),
              ),
              // Gast: gar kein Kreis — einer, der wie ein Knopf aussieht und
              // nichts tut, wirkt kaputt.
              if (widget.bearbeitbar) ...[
                const SizedBox(width: 12),
                _vormerkKreis(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// [hoehe]: höchstens 180 px, auf kleinen Handys 22 % der Bildschirmhöhe —
  /// das Foto soll den Bestand nicht aus dem Bild drücken.
  Widget _foto(double hoehe) {
    final platzhalter = Center(
      child: Icon(
        Icons.inventory_2,
        size: 48,
        color: AppColors.textSecondary.withAlpha(120),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: hoehe,
        color: AppColors.divider.withAlpha(60),
        child: FutureBuilder<String?>(
          future: widget.fotoUrl,
          builder: (context, snap) {
            final url = snap.data;
            if (url == null) return platzhalter;
            return Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: hoehe,
              errorBuilder: (_, _, _) => platzhalter,
            );
          },
        ),
      ),
    );
  }

  Widget _bestandBlock(ThemeData theme) {
    final farbe = _niedrig ? AppColors.error : AppColors.success;
    final bearbeitbar = widget.bearbeitbar;
    final minusAktiv = bearbeitbar && !_speichert && _bestand > 0;
    final plusAktiv = bearbeitbar && !_speichert;
    final l = widget.lager;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: farbe.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (bearbeitbar)
                _rundknopf(
                  icon: Icons.remove,
                  semantik: 'Bestand minus eins',
                  fuellung: minusAktiv ? Colors.white : AppColors.divider,
                  iconFarbe: minusAktiv
                      ? AppColors.textPrimary
                      : AppColors.textSecondary.withAlpha(120),
                  rand: AppColors.divider,
                  onTap: minusAktiv ? () => _aendereBestand(-1) : null,
                ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _bestand.toStringAsFixed(0),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: farbe,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l.einheit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mindest ${l.bestandMindest.toStringAsFixed(0)} · '
                      'Optimal ${l.bestandOptimal.toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (bearbeitbar)
                _rundknopf(
                  icon: Icons.add,
                  semantik: 'Bestand plus eins',
                  fuellung: plusAktiv
                      ? AppColors.primary
                      : AppColors.primary.withAlpha(120),
                  iconFarbe: Colors.white,
                  onTap: plusAktiv ? () => _aendereBestand(1) : null,
                ),
            ],
          ),
          if (_niedrig) ...[
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning, size: 16, color: AppColors.error),
                SizedBox(width: 4),
                // Flexible: bei vergrösserter Systemschrift umbrechen statt
                // überlaufen.
                Flexible(
                  child: Text(
                    'Unter Mindestbestand',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Runder Knopf: Container trägt Farbe und Form, InkWell darüber (auf
  /// transparentem Material) — so bleibt die Tipp-Welle über der Füllung
  /// sichtbar. Der Rand liegt in `foregroundDecoration`: in `decoration`
  /// würde er die Tippfläche innen um 2 px verkleinern (44 → 42).
  Widget _rundknopf({
    required IconData icon,
    required String semantik,
    required Color fuellung,
    required Color iconFarbe,
    required VoidCallback? onTap,
    Color? rand,
    double groesse = 52,
  }) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semantik,
      child: Container(
        width: groesse,
        height: groesse,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fuellung),
        foregroundDecoration: rand != null
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rand),
              )
            : null,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: Icon(icon, color: iconFarbe)),
          ),
        ),
      ),
    );
  }

  Widget _vormerkKreis() {
    // Nur bei `bearbeitbar` überhaupt im Baum (Gast sieht keinen Kreis).
    final aktiv = !_merkt;
    return _rundknopf(
      icon: _vorgemerkt ? Icons.bookmark : Icons.bookmark_border,
      semantik: _vorgemerkt ? 'Vormerkung aufheben' : 'Für Bestellung vormerken',
      fuellung: Colors.white,
      iconFarbe: _vorgemerkt ? Colors.orange : AppColors.textSecondary,
      rand: AppColors.divider,
      groesse: 44,
      onTap: aktiv ? _schalteVormerken : null,
    );
  }
}
