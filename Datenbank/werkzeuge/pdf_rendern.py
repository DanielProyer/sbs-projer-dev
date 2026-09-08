# -*- coding: utf-8 -*-
"""Rendert PDF-Seiten und verkleinert Fotos einheitlich zum Lesen."""
import sys, os
from pathlib import Path
import fitz
from PIL import Image

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
HOEHE = 1500

def speichere(img, ziel):
    if img.height > HOEHE:
        b = int(img.width * HOEHE / img.height)
        img = img.resize((b, HOEHE), Image.LANCZOS)
    if img.mode not in ('RGB', 'L'):
        img = img.convert('RGB')
    img.save(ziel, 'JPEG', quality=82)

for pfad in sys.argv[2:]:
    p = Path(pfad)
    stem = ''.join(c if c.isalnum() or c in '-_' else '_' for c in p.stem)[:60]
    if p.suffix.lower() == '.pdf':
        doc = fitz.open(p)
        for i, seite in enumerate(doc, 1):
            pix = seite.get_pixmap(dpi=150)
            img = Image.frombytes('RGB', (pix.width, pix.height), pix.samples)
            speichere(img, OUT / f'{stem}_s{i}.jpg')
        print(f'{p.name}: {len(doc)} Seiten')
        doc.close()
    else:
        speichere(Image.open(p), OUT / f'{stem}.jpg')
        print(f'{p.name}: Bild')

# Warum dieses Skript existiert (08.09.2026):
# Die Scans in 00_Rechnungen/ haben keine Textebene, und ihre PDFs nutzen
# unterschiedliche Bildformate — die Beleg-Scans DCTDecode (JPEG), die
# AXA-Portal-PDFs CCITTFaxDecode (Fax, 1 Bit). Ein selbstgebauter
# JPEG-Extraktor über die PDF-Streams funktioniert nur beim ersten Fall und
# liefert beim zweiten still nichts. PyMuPDF rendert die Seite stattdessen,
# unabhängig vom internen Format — das ist der einzige Weg, der für beide gilt.
# Aufruf: py -3 Datenbank/werkzeuge/pdf_rendern.py <ziel-ordner> <datei> ...
