# Kontakte-Umzug dani.proyer@ → sbs.projer@ — Schritt-für-Schritt

**Stand 01.09.2026 spätabends. Vorhaben ① des Entflechtungsplans ([oauth-entflechtung-plan.md](oauth-entflechtung-plan.md)).**
Alle Entscheide gefällt. Der Umzug selbst ist Daniels Handarbeit in Google Kontakte — die App-Seiten dürfen keine Anmeldedaten anfassen.

⚠️ **Daniel hat am 01.09. spätabends — NACH den Messungen — beide Konten aufgeräumt** (Zielkonto von 8 auf 3 reduziert, Reto Baumann ins Privatkonto verschoben, Privat-Labels laut Daniel auf «Privat» konsolidiert). Die Nachmittags-Zahlen sind damit teils veraltet. **Deshalb Schritt 0: unmittelbar vor dem Umzug einmal frisch messen** — erst dann sind die Soll-Zahlen verbindlich.

## Zahlenbild

| Grösse | Nachmittags-Messung | Stand nach Daniels Aufräumen (zu bestätigen in Schritt 0) |
|---|---|---|
| Quellkonto dani.proyer@ gesamt | 768 | voraussichtlich 769 (+ Reto Baumann) |
| Umzugsmenge (5 Geschäftsgruppen ∪ Gruppenlose) | **724** (Staging exakt) | unverändert 724 erwartet |
| Nur-Private (bleiben in dani.proyer@) | 44 | voraussichtlich 45 (+ Reto Baumann); Label-Struktur laut Daniel auf «Privat» konsolidiert — nachmessen |
| Überlappung Umzügler ∩ Privat-Labels | 2 (Tino Hassler · «Steven (Privat) - Engadin») | nachmessen (Labels evtl. geändert) |
| Zielkonto sbs.projer@ vorher | 8 | **3**: Heineken Urs · Naella. · Your (Ervin JANZ, «Heineken - Rolf Petschen» sowie die ALTEN Zeilen «Legna Bar Flims» und «Parpan - Obertor» gelöscht; Reto Baumann verschoben) |
| Duplikate Zielkonto ∩ 724 | 2 | **0** — die beiden Alt-Duplikate hat Daniel gelöscht; Legna und Obertor kommen frisch mit dem Import |
| **Nachher-Soll Zielkonto** | — | **voraussichtlich 726** = 3 + 769 − 45 − 1 (Obertor-Quelldoublette vereinigt); verbindlich nach Schritt 0 |

Leere Gruppen (gemessen): «SBS Event», «SIM», «Importiert am 15.12.24» — enthalten keinen einzigen Kontakt, spielen keine Rolle.

**Quellkonto-interne Doublette:** «Parpan - Obertor» existiert im Privatkonto doppelt — «Parpan - Obertor» (alt) und «Parpan - Obertor (Rätus Schmid)». **Rätus Schmid ist laut Daniel der aktuelle Geschäftskontakt** — beim Vereinigen dessen Daten/Namen behalten.

## Ablauf

**Schritt 0 — Frisch-Messung (Heineken-Session, rein lesend), unmittelbar bevor Daniel startet:**
Daniel meldet «ich lege los» → SBS-Session beauftragt Heineken mit: (a) Quellkonto-Vollbestand + aktuelle Label-Struktur (gibt es nur noch «Privat» oder weiter Familie/Freunde/…?), (b) Zahl der Nur-Privaten, (c) Überlappungsliste Umzügler ∩ Privat-Labels (namentlich), (d) Staging-Refresh (Upsert, idempotent) mit neuer Umzugszahl, (e) Zielkonto-Bestand bestätigen (Soll: 3). **Die Werte aus (a)–(e) ersetzen die Voraussichtlich-Spalte oben und ergeben das verbindliche Nachher-Soll.**

**Schritt 1 — Export (dani.proyer@):**
[contacts.google.com](https://contacts.google.com) → links «Exportieren» → **«Kontakte (alle)»** → Format **Google CSV**.
Warum alle: Die 316 Gruppenlosen lassen sich in der Oberfläche nicht auswählen («ohne Label» gibt es als Filter nicht). Die Privaten kommen bewusst mit und werden in Schritt 3 im Zielkonto wieder entfernt.

**Schritt 2 — Import (sbs.projer@):**
contacts.google.com → «Importieren» → die CSV aus Schritt 1. Labels/Gruppen kommen mit.
Danach kurz prüfen: Gesamtzahl = 3 + Quellbestand aus Schritt 0 (voraussichtlich 3 + 769 = 772). Falls Google «Zusammenführen & korrigieren» vorschlägt: erst NACH der Zählung zusammenführen, sonst ist eine Abweichung nicht erklärbar.
Dann die **Obertor-Doublette vereinigen**: «Parpan - Obertor» (alt) + «Parpan - Obertor (Rätus Schmid)» → ein Kontakt, Rätus-Schmid-Stand behalten (−1).

**Schritt 3 — Die Nur-Privaten im Zielkonto löschen:**
1. **Zuerst die Ausnahmen entschärfen** (Liste aus Schritt 0c; bisher bekannt: Tino Hassler — Geschäftslabel SBS Heineken bleibt · «Steven (Privat) - Engadin» — Geschäftlich bleibt): bei diesen Kontakten die Privat-Labels entfernen, NICHT löschen.
2. Dann je Privat-Label aus Schritt 0a (laut Daniel konsolidiert auf «Privat»; falls Alt-Labels wie Familie/Freunde noch existieren, auch diese): Label öffnen → alle Mitglieder auswählen → löschen. Durch Schritt 3.1 trifft das garantiert keine Geschäftskontakte.
3. Zum Schluss die Privat-Labels selbst löschen (leer, gehören nicht ins Geschäftskonto).

**Schritt 4 — Verifikation (Heineken-Session, rein lesend):**
Zielkonto lesen: Soll = Wert aus Schritt 0 (voraussichtlich **726**). Abgleich gegen die Staging-Zeilen (Name/Nummer/Mail). Jede Abweichung wird geklärt, **bevor** irgendetwas gelöscht wird.

**Schritt 5 — erst nach Grün: Quellkonto aufräumen (dani.proyer@):**
Die Umzügler löschen; die Privaten (inkl. Reto Baumann) bleiben. Kein Zeitdruck — bis dahin funktioniert Heinekens `konto=dani`-Lesequelle unverändert weiter. (Das Abklemmen von `konto=dani` selbst ist Vorhaben ③, Schritt 5.)

## Danach (separat, blockiert nichts)

- **Daniels Komplett-Durchsicht** direkt in Google Kontakte unter sbs.projer@ (Web oder Pixel-App): behalten/löschen, umbenennen, Label zuweisen. Kniff: Label «Geprüft» anlegen und anhängen — Fortschritt bleibt messbar (Ziel: Anzahl «Geprüft» = Bestand). Merkposten aus den Messungen: «Steven (Privat) - Engadin» einordnen (heisst «Privat», steht in «Geschäftlich») · 4 Kontakte mit U+2010-Bindestrich vereinheitlichen («Chur ‐ Italy», «Davos ‐ Montana Stube», «Grüsch ‐ Fasan», «Laax ‐ Indy») · Combox und der namenlose Kontakt: löschen oder klären · «Maria Roth Haus Maladerd (Sie)», «Forstamt Arosa Claudio Färber», «Sonnenbräu Monteur» einordnen · **«Naella.»** = Eventmanagerin Heineken und **«Your»** = Daniels eigene Nummer (geklärt 01.09.) — bei der Durchsicht sauber benennen/labeln; «Heineken Urs» = Heineken-Vertreter, bleibt.
- Volliste für die Durchsicht liegt strukturiert im Heineken-Staging; bei Bedarf erzeugt die Heineken-Session ein lokales Blatt (bewusst keine Personendaten-Datei im Repo).

## Regeln (aus dem 29.08.)

- Nach jedem Schritt messen, bevor der nächste folgt — verbindlich sind die Zahlen aus Schritt 0, nicht die Nachmittags-Messung.
- Erst alle Konsumenten umstellen bzw. verifizieren, dann Altes löschen — nie umgekehrt.
- Bei Abweichung: anhalten und klären, nicht «wird schon stimmen».
