/// Zeitachsen-Darstellung des Tagesplans (Spec 2026-07-29, §5).
///
/// Bewusst ohne Riverpod und ohne Datenzugriff: alles Nötige kommt als
/// Parameter herein. So ist die Leiste im Widget-Test auf 360/375/412 px
/// prüfbar, ohne den halben Provider-Baum aufzubauen — und der Screen bleibt
/// der einzige Ort, an dem Warn-Flags und Dauern berechnet werden.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sbs_projer_app/core/theme/app_theme.dart';
import 'package:sbs_projer_app/core/util/touren_anzeige.dart';
import 'package:sbs_projer_app/core/util/zeitplan.dart';
import 'package:sbs_projer_app/presentation/providers/tour_providers.dart';

/// Pixel je Planminute. 1.1 px/min ergibt für einen typischen 30-Minuten-
/// Besuch 33 px — darum greift dort die Mindesthöhe [kBlockMindestHoehe],
/// damit der Block auf dem Handy noch sicher tippbar bleibt.
const double kPxProMinute = 1.1;

/// Mindesthöhe eines Besuchs-Blocks (Tippfläche).
const double kBlockMindestHoehe = 44.0;

/// Breite der linken Zeitspalte.
const double _kZeitSpalte = 36.0;

/// Farbe des Blocks: Fälligkeitsfarbe der Reinigung, sonst typabhängig
/// (Störung rot, Montage/HeiGenie blau) — dasselbe Farbschema wie die
/// bisherigen Tour-Karten.
Color blockFarbe(TourEintrag eintrag) {
  final f = eintrag.faelligkeit;
  if (f != null && eintrag.typ == TourEintragTyp.reinigung) {
    return faelligkeitFarbe(f);
  }
  switch (eintrag.typ) {
    case TourEintragTyp.stoerung:
      return AppColors.error;
    case TourEintragTyp.reinigung:
      return AppColors.success;
    case TourEintragTyp.montage:
    case TourEintragTyp.heigenie:
      return AppColors.info;
  }
}

/// Punktfarbe der Fahrzeit-Quelle: grün = beobachtet (echte Übergänge),
/// blau = geroutet, grau = Heuristik (Luftlinie). So ist ohne Zusatztext
/// sichtbar, wie belastbar eine Fahrzeit ist.
Color _quelleFarbe(String? quelle) {
  switch (quelle) {
    case 'beobachtet':
      return AppColors.success;
    case 'route':
      return AppColors.info;
    default:
      return AppColors.textSecondary;
  }
}

/// Linke Zeitspalte: Startzeit oben, darunter die durchgehende Linie.
class _ZeitSpalte extends StatelessWidget {
  final String? zeit;
  final bool kraeftig;

  const _ZeitSpalte({this.zeit, this.kraeftig = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kZeitSpalte,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (zeit != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                zeit!,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: kraeftig ? FontWeight.w700 : FontWeight.w400,
                  color: kraeftig
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          Expanded(
            child: Center(child: Container(width: 1, color: AppColors.divider)),
          ),
        ],
      ),
    );
  }
}

/// Anfahrt/Heimweg — Randsegmente ohne eigenen Plan-Eintrag.
class RandSegmentZeile extends StatelessWidget {
  final ZeitSegment segment;
  final String label;

  const RandSegmentZeile({
    super.key,
    required this.segment,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ZeitSpalte(zeit: hhmmAusMinuten(segment.startMin)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
              child: Text(
                '🚗 $label · ${segment.minuten} min',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Verstrichene freie Zeit zwischen letztem erledigtem Ereignis und «jetzt»
/// (Live-Modus des heutigen Tagesplans).
class FreiZeile extends StatelessWidget {
  final ZeitSegment segment;

  const FreiZeile({super.key, required this.segment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ZeitSpalte(zeit: hhmmAusMinuten(segment.startMin)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.warning.withAlpha(60)),
                ),
                child: Text(
                  'frei · ${segment.minuten} min',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rote «Jetzt»-Linie: trennt gemessene Vergangenheit vom Rest-Plan.
class JetztLinie extends StatelessWidget {
  final String zeit;

  const JetztLinie({super.key, required this.zeit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: _kZeitSpalte,
            child: Text(
              zeit,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
          Expanded(child: Container(height: 2, color: AppColors.error)),
        ],
      ),
    );
  }
}

/// Eine Zeile der Zeitachse: optionale Fahrt- und Wartezeit-Zeile, darunter
/// der Besuchs-Block in Dauer-Höhe.
class ZeitplanZeile extends StatelessWidget {
  /// Besuchs-Segment (Start/Ende/Dauer aus `berechneZeitplan`).
  final ZeitSegment segment;

  /// Fahrt zu diesem Besuch (fehlt beim ersten Eintrag des Tages).
  final ZeitSegment? fahrtDavor;

  /// Wartezeit vor diesem Besuch (entsteht durch einen Termin-Anker).
  final ZeitSegment? wartezeitDavor;

  final TourEintrag eintrag;

  /// Anzahl aktiver Anlagen des Betriebs (Nenner im Chip «n von m Anlagen»).
  final int anlagenGesamt;

  /// Dauer ist geschätzt (kein manuelles `dauerMinuten`) → '~' vor der Dauer.
  final bool dauerGeschaetzt;

  /// Betrieb ist am Plantag zu (Ruhetag/Ferien/Saisonpause).
  final bool ruhetagKonflikt;

  /// Ankunft liegt ausserhalb aller Servicefenster des Betriebs.
  final bool servicezeitKonflikt;

  /// 'beobachtet' | 'route' | 'heuristik' — Herkunft der Fahrzeit.
  final String? fahrtQuelle;

  /// Vorschlag «Anker HH:mm?» (Beginn des nächsten Servicefensters).
  final String? ankerVorschlag;
  final VoidCallback? onAnkerVorschlag;

  /// Greif-Griff der ReorderableList (der Screen liefert ihn, damit dieses
  /// Widget ohne ReorderableList testbar bleibt).
  final Widget? dragHandle;

  final VoidCallback? onTap;

  /// Live-Modus: Block wurde heute erledigt — die Segmentzeiten sind die
  /// GEMESSENEN Zeiten (Haken + grüner Akzent, keine Warnbänder mehr).
  final bool erledigt;

  /// Verstrichene freie Zeit VOR diesem Eintrag (Live-Modus).
  final ZeitSegment? freiDavor;

  /// «Jetzt»-Linie vor diesem Eintrag (Live-Modus, 'HH:mm').
  final String? jetztZeit;

  const ZeitplanZeile({
    super.key,
    required this.segment,
    required this.eintrag,
    this.fahrtDavor,
    this.wartezeitDavor,
    this.anlagenGesamt = 0,
    this.dauerGeschaetzt = true,
    this.ruhetagKonflikt = false,
    this.servicezeitKonflikt = false,
    this.fahrtQuelle,
    this.ankerVorschlag,
    this.onAnkerVorschlag,
    this.dragHandle,
    this.onTap,
    this.erledigt = false,
    this.freiDavor,
    this.jetztZeit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reihenfolge im Live-Modus: erst die verstrichene freie Zeit, dann
        // die Jetzt-Linie, dann der (künftige) Fahrt-/Warte-/Besuchsteil.
        if (freiDavor != null) FreiZeile(segment: freiDavor!),
        if (jetztZeit != null) JetztLinie(zeit: jetztZeit!),
        if (fahrtDavor != null) _fahrtZeile(fahrtDavor!),
        if (wartezeitDavor != null) _warteZeile(wartezeitDavor!),
        _blockZeile(),
      ],
    );
  }

  // ─── Fahrt ───

  Widget _fahrtZeile(ZeitSegment fahrt) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
      child: Row(
        children: [
          const SizedBox(width: _kZeitSpalte),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fahrt.ist
                      ? '🚗 ${fahrt.minuten} min gemessen'
                      : '🚗 ${fahrt.minuten} min',
                  style: TextStyle(
                    fontSize: 11,
                    color: fahrt.ist
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: fahrt.ist
                        ? AppColors.success
                        : _quelleFarbe(fahrtQuelle),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Wartezeit ───

  Widget _warteZeile(ZeitSegment warte) {
    // IntrinsicHeight + stretch: nur so bekommt die Zeitspalte eine endliche
    // Höhe für ihre durchgehende Linie (Expanded in einer Column).
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ZeitSpalte(zeit: hhmmAusMinuten(warte.startMin)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⏳ ${warte.minuten} min Wartezeit',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Besuchs-Block ───

  Widget _blockZeile() {
    final hoehe = math.max(kBlockMindestHoehe, segment.minuten * kPxProMinute);
    final farbe = blockFarbe(eintrag);
    final zeigtChipZeile =
        eintrag.typ == TourEintragTyp.reinigung || ankerVorschlag != null;

    final zeitspanne =
        '${hhmmAusMinuten(segment.startMin)}–${hhmmAusMinuten(segment.endMin)}';
    final dauerTxt = '${dauerGeschaetzt ? '~' : ''}${segment.minuten} min';

    final inhalt = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Erledigte Blöcke brauchen keine Warnungen mehr — sie sind Ist.
        if (!erledigt && ruhetagKonflikt)
          _warnband('Betrieb geschlossen', AppColors.error)
        else if (!erledigt && servicezeitKonflikt)
          _warnband('ausserhalb Servicezeit', AppColors.warning),
        Row(
          children: [
            if (erledigt) ...[
              const Icon(
                Icons.check_circle,
                size: 12,
                color: AppColors.success,
              ),
              const SizedBox(width: 3),
            ],
            Expanded(
              child: Text(
                erledigt
                    ? '$zeitspanne · ${segment.minuten} min gemessen'
                    : '$zeitspanne · $dauerTxt',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: erledigt ? FontWeight.w600 : FontWeight.w400,
                  color: erledigt ? AppColors.success : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (eintrag.ankerZeit != null) ...[
              const Icon(Icons.push_pin, size: 11, color: AppColors.info),
              const SizedBox(width: 2),
              Text(
                eintrag.ankerZeit!,
                style: const TextStyle(fontSize: 10, color: AppColors.info),
              ),
            ],
            if (eintrag.uebernommen) ...[
              const SizedBox(width: 4),
              const Text(
                'übernommen',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
        Text(
          eintrag.betriebOrt != null && eintrag.betriebOrt!.isNotEmpty
              ? '${eintrag.betriebName} - ${eintrag.betriebOrt}'
              : eintrag.betriebName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Chip-Zeile IMMER zeigen, auch beim 28-Minuten-Normalfall: der Block
        // hat nur eine Mindesthöhe (keine Fixhöhe) und darf für den Inhalt
        // wachsen. Eine frühere Kompakt-Regel blendete Anlagen-Chip und
        // Anker-Vorschlag bei kurzen Besuchen aus — also fast immer.
        if (zeigtChipZeile)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                if (eintrag.typ == TourEintragTyp.reinigung)
                  Flexible(
                    child: _chip(
                      '${_anlagenZahl(eintrag)} von $anlagenGesamt Anlagen',
                      AppColors.textSecondary,
                    ),
                  ),
                // Der Anker-Vorschlag hängt am Servicefenster des Betriebs —
                // der gilt für Störung und Montage genauso wie für Reinigungen.
                if (ankerVorschlag != null) ...[
                  if (eintrag.typ == TourEintragTyp.reinigung)
                    const SizedBox(width: 6),
                  Flexible(
                    child: GestureDetector(
                      onTap: onAnkerVorschlag,
                      child: _chip('Anker $ankerVorschlag?', AppColors.info),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ZeitSpalte(zeit: hhmmAusMinuten(segment.startMin), kraeftig: true),
          Expanded(
            child: Opacity(
              opacity: eintrag.uebernommen ? 0.55 : 1.0,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  key: ValueKey('block_${eintrag.id}'),
                  margin: const EdgeInsets.only(right: 12, bottom: 4),
                  constraints: BoxConstraints(minHeight: hoehe),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: erledigt
                        ? AppColors.success.withAlpha(10)
                        : farbe.withAlpha(12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: erledigt
                          ? AppColors.success.withAlpha(120)
                          : AppColors.divider,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 4, color: farbe),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: inhalt,
                          ),
                        ),
                      ),
                      if (dragHandle != null) dragHandle!,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warnband(String text, Color farbe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 11, color: farbe),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: farbe,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color farbe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: farbe.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        // In `Flexible` gesetzt: auf schmalen Geräten schrumpft der Chip
        // lieber, als die Zeile überlaufen zu lassen.
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: farbe,
        ),
      ),
    );
  }
}

/// Anzahl Anlagen dieses Besuchs. `anlageIds` ist fachlich führend; solange
/// ein Alt-Eintrag nur das einzelne `anlageId` trägt, zählt genau diese eine.
int _anlagenZahl(TourEintrag e) =>
    e.anlageIds.isNotEmpty ? e.anlageIds.length : (e.anlageId != null ? 1 : 0);
