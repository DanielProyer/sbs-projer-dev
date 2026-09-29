# -*- coding: utf-8 -*-
"""Anhang (OR 959c) und Steuerbeilage zur Jahresrechnung der SBS Projer GmbH.

Ergänzt das App-PDF «Bilanz und Erfolgsrechnung» (Mehr → Abschlüsse und
Steuern) um die zwei Seiten, die die Steuererklärung braucht. Die Zahlen
kommen als Argumente — massgebend ist die App-Bilanz, nicht dieses Skript.

Aufruf (Beispiel 2025, Fassung 2 vom 01.10.2026):
  py -3 Datenbank/wartung/jahresrechnung_beilage.py --jahr 2025 \
     --gewinn 15235.70 --vortrag 35060.71 --ek 70296.41 \
     --debitoren 105351.96 --delkredere 5267.60 --rueckstellung 2800 \
     --bank 12202.73 --kasse 6670.24 --bussen 320.00 \
     --abschreibungen "Jahrgang 2019: 29 Rechnungen, 2'235.90; Jahrgang 2020: 76 Rechnungen, 7'216.30" \
     --out "Jahresrechnung 2025 - Anhang und Steuerbeilage.pdf"

WARUM ein Skript statt Handarbeit: Die Fassung 1 vom 02.09.2026 entstand in
einer Sitzung ohne wiederverwendbaren Code; Fassung 2 (Jahrgang 2020 per
31.12.2025) und die Abschlüsse 2026 ff. sollen dieselben Seiten in Minuten
liefern. Schrift: Helvetica (reportlab-Standard, WinAnsi) — Beträge mit
Apostroph ' (ASCII), keine typografischen Zeichen.
"""
import argparse
from datetime import date

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.platypus import (Paragraph, SimpleDocTemplate, Spacer, Table,
                                TableStyle, PageBreak)


def chf(x):
    s = f"{x:,.2f}".replace(",", "'")
    return s


def bauen(a):
    styles = getSampleStyleSheet()
    h1 = ParagraphStyle('h1', parent=styles['Heading1'], fontSize=15, spaceAfter=6)
    h2 = ParagraphStyle('h2', parent=styles['Heading2'], fontSize=12, spaceBefore=10, spaceAfter=4)
    p = ParagraphStyle('p', parent=styles['BodyText'], fontSize=10, leading=13)
    klein = ParagraphStyle('klein', parent=p, fontSize=8.5, leading=11, textColor=colors.grey)

    firma = 'SBS Projer GmbH, Domat/Ems'
    jahr = a.jahr
    steuerbar = a.gewinn + a.bussen

    doc = SimpleDocTemplate(a.out, pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm,
                            topMargin=18 * mm, bottomMargin=18 * mm,
                            title=f'Jahresrechnung {jahr} - Anhang und Steuerbeilage', author=firma)
    el = []

    # ── Seite 1: Anhang OR 959c ────────────────────────────────────────────
    el.append(Paragraph(f'Anhang zur Jahresrechnung {jahr} (Art. 959c OR)', h1))
    el.append(Paragraph(firma, p))
    el.append(Spacer(1, 6))
    punkte = [
        ('Firma, Rechtsform, Sitz', 'SBS Projer GmbH, Gesellschaft mit beschränkter Haftung, Domat/Ems GR. '
                                    'Zapfanlagen-Service (Reinigung, Störungsbehebung, Montage) als Heineken-Franchisenehmerin.'),
        ('Rechnungslegung', 'Nach den Vorschriften des Schweizer Obligationenrechts (Art. 957 ff. OR). '
                            'Die Jahresrechnung wird in Schweizer Franken geführt.'),
        ('Vollzeitstellen', 'Im Jahresdurchschnitt nicht mehr als 10 Vollzeitstellen (eine Person).'),
        ('Forderungen aus Lieferungen und Leistungen',
         f'Nominalwert {chf(a.debitoren)} abzüglich pauschale Wertberichtigung (Delkredere) von 5 %, '
         f'CHF {chf(a.delkredere)}. Verjährte Forderungen (Art. 128 Ziff. 3 OR) werden jahrgangsweise '
         f'im Abschluss des Verjährungsjahres abgeschrieben: {a.abschreibungen}.'),
        ('Rückstellungen', f'Rückstellung für Gewinn- und Kapitalsteuern {jahr}: CHF {chf(a.rueckstellung)}.'),
        ('Flüssige Mittel', f'Bank CHF {chf(a.bank)} (Kontoauszug per 31.12.{jahr}), Kasse CHF {chf(a.kasse)}.'),
        ('Anlagevermögen, Beteiligungen', 'Kein Anlagevermögen, keine Beteiligungen, keine Liegenschaften.'),
        ('Eventualverbindlichkeiten, Leasing', 'Keine Bürgschaften, keine Garantieverpflichtungen, keine Leasingverbindlichkeiten.'),
        ('Ereignisse nach dem Bilanzstichtag',
         a.ereignisse or 'Die Abschreibung der verjährten Jahrgänge wurde nach dem Bilanzstichtag beschlossen '
                         f'und per 31.12.{jahr} verbucht; die Mehrwertsteuer-Rückholung erfolgt in der Periode des Entscheids.'),
    ]
    tabelle = [[Paragraph(f'<b>{k}</b>', p), Paragraph(v, p)] for k, v in punkte]
    t = Table(tabelle, colWidths=[55 * mm, 115 * mm])
    t.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'),
                           ('LINEBELOW', (0, 0), (-1, -1), 0.3, colors.lightgrey),
                           ('BOTTOMPADDING', (0, 0), (-1, -1), 5), ('TOPPADDING', (0, 0), (-1, -1), 5)]))
    el.append(t)
    el.append(Spacer(1, 14))
    el.append(Paragraph(f'Domat/Ems, {a.datum}', p))
    el.append(Spacer(1, 22))
    el.append(Paragraph('______________________________<br/>Daniel Projer, Geschäftsführer', p))
    el.append(PageBreak())

    # ── Seite 2: Steuerbeilage ─────────────────────────────────────────────
    el.append(Paragraph(f'Beilage zur Steuererklärung {jahr} — Kennzahlen', h1))
    el.append(Paragraph(firma, p))
    el.append(Spacer(1, 6))
    zeilen = [
        ['Reingewinn laut Erfolgsrechnung ' + str(jahr), chf(a.gewinn)],
        ['+ Aufrechnung: nicht abzugsfähige Bussen (Konten 6280/8900)', chf(a.bussen)],
        ['= Steuerbarer Reingewinn (Vorschlag)', chf(steuerbar)],
        ['', ''],
        ['Stammkapital', chf(20000.00)],
        ['Gewinnvortrag 01.01.' + str(jahr), chf(a.vortrag)],
        ['Jahresgewinn ' + str(jahr), chf(a.gewinn)],
        ['= Eigenkapital 31.12.' + str(jahr) + ' (steuerbares Kapital)', chf(a.ek)],
        ['', ''],
        ['Rückstellung direkte Steuern (Konto 2208)', chf(a.rueckstellung)],
        ['Delkredere (Konto 1109)', chf(a.delkredere)],
        ['Beteiligungen / Liegenschaften / Anlagevermögen', 'keine'],
        ['Verrechnungssteuer-Ansprüche', 'keine'],
    ]
    t2 = Table(zeilen, colWidths=[125 * mm, 45 * mm])
    t2.setStyle(TableStyle([('ALIGN', (1, 0), (1, -1), 'RIGHT'), ('FONTSIZE', (0, 0), (-1, -1), 10),
                            ('FONTNAME', (0, 2), (-1, 2), 'Helvetica-Bold'),
                            ('FONTNAME', (0, 7), (-1, 7), 'Helvetica-Bold'),
                            ('LINEABOVE', (0, 2), (-1, 2), 0.6, colors.black),
                            ('LINEABOVE', (0, 7), (-1, 7), 0.6, colors.black),
                            ('BOTTOMPADDING', (0, 0), (-1, -1), 4)]))
    el.append(t2)
    el.append(Spacer(1, 10))
    el.append(Paragraph('Beilagen: Bilanz und Erfolgsrechnung per 31.12.' + str(jahr) + ' (App-Ausdruck), '
                        'Anhang, Lohnausweis, Bank-Zins-/Kapitalausweis, Beschluss der Gesellschafterversammlung.', klein))
    el.append(Paragraph(f'Erstellt {a.datum} aus der Buchhaltung der SBS-Projer-App; massgebend ist die App-Bilanz.', klein))
    doc.build(el)
    print('geschrieben:', a.out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--jahr', type=int, required=True)
    ap.add_argument('--gewinn', type=float, required=True)
    ap.add_argument('--vortrag', type=float, required=True)
    ap.add_argument('--ek', type=float, required=True)
    ap.add_argument('--debitoren', type=float, required=True)
    ap.add_argument('--delkredere', type=float, required=True)
    ap.add_argument('--rueckstellung', type=float, required=True)
    ap.add_argument('--bank', type=float, required=True)
    ap.add_argument('--kasse', type=float, required=True)
    ap.add_argument('--bussen', type=float, default=0.0)
    ap.add_argument('--abschreibungen', default='keine')
    ap.add_argument('--ereignisse', default=None)
    ap.add_argument('--datum', default=date.today().strftime('%d.%m.%Y'))
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    if abs(20000.00 + a.vortrag + a.gewinn - a.ek) > 0.02:
        raise SystemExit(f'EK geht nicht auf: 20000 + {a.vortrag} + {a.gewinn} != {a.ek}')
    bauen(a)


if __name__ == '__main__':
    main()
