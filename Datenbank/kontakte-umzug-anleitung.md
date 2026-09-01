# Kontakte-Umzug dani.proyer@ → sbs.projer@ — Schritt-für-Schritt

**Stand 01.09.2026 abends. Vorhaben ① des Entflechtungsplans ([oauth-entflechtung-plan.md](oauth-entflechtung-plan.md)).**
Alle Entscheide gefällt, alle Messungen gelaufen (Heineken-Session, rein lesend). Der Umzug selbst ist Daniels Handarbeit in Google Kontakte — die App-Seiten dürfen keine Anmeldedaten anfassen.

## Zahlenbild (gemessen, nicht geschätzt)

| Grösse | Wert | Quelle |
|---|---|---|
| Quellkonto dani.proyer@ gesamt | 768 | Vollbestand-Lesung 01.09. |
| Umzugsmenge (5 Geschäftsgruppen ∪ Gruppenlose) | **724** | Staging `kontakt_uebernahme`, exakt |
| Nur-Private (bleiben in dani.proyer@) | 44 | 768 − 724 |
| Überlappung Umzügler ∩ Privat-Labels | **2** | Tino Hassler (Privat+Freunde, auch SBS Heineken) · «Steven (Privat) - Engadin» (Bekannte, auch Geschäftlich) |
| Zielkonto sbs.projer@ vorher | 8 | konto=sbs-Lesung 01.09. |
| Duplikate der 8 in den 724 | **2** | «Legna Bar Flims» (Telefon-Treffer) · «Parpan - Obertor» (trifft im Quellkonto sogar 2 Zeilen: «Parpan - Obertor» + «Parpan - Obertor (Rätus Schmid)») |
| **Nachher-Soll Zielkonto** | **730** | 8 + 724 − 2 zusammengeführte Duplikate; **729**, wenn auch die Obertor-Doublette aus dem Quellbestand vereinigt wird |

Leere Gruppen (gemessen): «SBS Event», «SIM», «Importiert am 15.12.24» — enthalten keinen einzigen Kontakt, spielen keine Rolle.

## Ablauf

**Schritt 0 — Vorbedingung: ✅ ERLEDIGT 01.09. abends.** Duplikat-Abgleich der 8 (Name exakt, Telefon normalisiert, Mail): **2 Duplikate** — «Legna Bar Flims» und «Parpan - Obertor». Die übrigen 6 («Ervin JANZ», «Heineken - Rolf Petschen», «Heineken Urs», «Naella.», «Reto Baumann», «Your») haben keinen Treffer in den 724.

**Schritt 1 — Export (dani.proyer@):**
[contacts.google.com](https://contacts.google.com) → links «Exportieren» → **«Kontakte (alle)»** → Format **Google CSV**.
Warum alle 768: Die 316 Gruppenlosen lassen sich in der Oberfläche nicht auswählen («ohne Label» gibt es als Filter nicht). Die 44 Privaten kommen bewusst mit und werden in Schritt 3 im Zielkonto wieder entfernt.

**Schritt 2 — Import (sbs.projer@):**
contacts.google.com → «Importieren» → die CSV aus Schritt 1. Labels/Gruppen kommen mit.
Danach kurz prüfen: Gesamtzahl = 8 + 768 = 776 (falls Google beim Import schon Duplikate zusammenführt oder «Zusammenführen & korrigieren» vorschlägt: erst NACH der Zählung zusammenführen, sonst ist die Abweichung nicht erklärbar).

Dann die **bekannten Duplikate zusammenführen** («Zusammenführen & korrigieren» oder von Hand):
1. «Legna Bar Flims» — doppelt (Bestand + Import).
2. «Parpan - Obertor» — hier landen **drei** Zeilen nebeneinander: der Bestandskontakt plus «Parpan - Obertor» und «Parpan - Obertor (Rätus Schmid)» aus dem Import (Quellkonto-interne Doublette). Empfehlung: alle drei zu einem Kontakt vereinigen → Nachher-Soll 729.

**Schritt 3 — Die 44 Nur-Privaten im Zielkonto löschen:**
1. **Zuerst die zwei Ausnahmen entschärfen:** «Tino Hassler» öffnen → Labels Privat + Freunde entfernen (SBS Heineken bleibt). «Steven (Privat) - Engadin» öffnen → Label Bekannte entfernen (Geschäftlich bleibt).
2. Dann je Privat-Label (Familie, Privat, Freunde, Bekannte, Juma, Mexiko, Studium): Label öffnen → alle Mitglieder auswählen → löschen. Durch Schritt 3.1 trifft das garantiert nur die 44 Nur-Privaten.
3. Zum Schluss die sieben Privat-Labels selbst löschen (leer, gehören nicht ins Geschäftskonto).

**Schritt 4 — Verifikation (Heineken-Session, rein lesend):**
Zielkonto lesen: Soll = **730** (bzw. **729**, wenn die Obertor-Doublette mit vereinigt wurde — bitte melden, was gemacht wurde). Abgleich gegen die 724 Staging-Zeilen (Name/Nummer/Mail). Jede Abweichung wird geklärt, **bevor** irgendetwas gelöscht wird.

**Schritt 5 — erst nach Grün: Quellkonto aufräumen (dani.proyer@):**
Die 724 Umzügler löschen; die 44 Privaten bleiben. Kein Zeitdruck — bis dahin funktioniert Heinekens `konto=dani`-Lesequelle unverändert weiter. (Das Abklemmen von `konto=dani` selbst ist Vorhaben ③, Schritt 5.)

## Danach (separat, blockiert nichts)

- **Daniels Komplett-Durchsicht** direkt in Google Kontakte unter sbs.projer@ (Web oder Pixel-App): behalten/löschen, umbenennen, Label zuweisen. Kniff: Label «Geprüft» anlegen und anhängen — Fortschritt bleibt messbar (Ziel: Anzahl «Geprüft» = Bestand). Merkposten aus den Messungen: «Steven (Privat) - Engadin» einordnen (heisst «Privat», steht in «Geschäftlich») · 4 Kontakte mit U+2010-Bindestrich vereinheitlichen («Chur ‐ Italy», «Davos ‐ Montana Stube», «Grüsch ‐ Fasan», «Laax ‐ Indy») · Combox und der namenlose Kontakt: löschen oder klären · «Maria Roth Haus Maladerd (Sie)», «Forstamt Arosa Claudio Färber», «Sonnenbräu Monteur» einordnen · «Naella.» und «Your» (Alt-Bestand sbs.projer@) sehen nach Erfassungsresten aus — löschen oder klären.
- Volliste für die Durchsicht liegt strukturiert im Heineken-Staging; bei Bedarf erzeugt die Heineken-Session ein lokales Blatt (bewusst keine Personendaten-Datei im Repo).

## Regeln (aus dem 29.08.)

- Nach jedem Schritt messen, bevor der nächste folgt — Zahlen oben sind das Soll.
- Erst alle Konsumenten umstellen bzw. verifizieren, dann Altes löschen — nie umgekehrt.
- Bei Abweichung: anhalten und klären, nicht «wird schon stimmen».
