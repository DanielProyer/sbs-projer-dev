# Kontakte-Umzug dani.proyer@ → sbs.projer@ — Schritt-für-Schritt

**Stand 01.09.2026 spätabends. Vorhaben ① des Entflechtungsplans ([oauth-entflechtung-plan.md](oauth-entflechtung-plan.md)).**
Alle Entscheide gefällt. Der Umzug selbst ist Daniels Handarbeit in Google Kontakte — die App-Seiten dürfen keine Anmeldedaten anfassen.

⚠️ **Daniel hat am 01.09. spätabends — NACH den Messungen — beide Konten aufgeräumt** (Zielkonto von 8 auf 3 reduziert, Reto Baumann ins Privatkonto verschoben, Privat-Labels laut Daniel auf «Privat» konsolidiert). Die Nachmittags-Zahlen sind damit teils veraltet. **Deshalb Schritt 0: unmittelbar vor dem Umzug einmal frisch messen** — erst dann sind die Soll-Zahlen verbindlich.

## Zahlenbild — VERBINDLICH (Frisch-Messung 02.09., Schritt 0)

| Grösse | Wert | Anmerkung |
|---|---|---|
| Quellkonto dani.proyer@ gesamt | **767** | Daniel hatte die Obertor-Doublette («Parpan - Obertor» alt) schon selbst gelöscht; «Parpan - Obertor (Rätus Schmid)» besteht |
| Umzugsmenge | **723** | Staging refresht, exakt |
| Nur-Private (bleiben in dani.proyer@) | **44** | inkl. Reto Baumann (Privat+Familie, sauber angekommen) |
| 🔴 Privat-Labels | **weiterhin ALLE SIEBEN** | Privat 45 · Freunde 15 · Bekannte 14 · Familie 11 · Juma 4 · Mexiko 1 · Studium 1 — die beabsichtigte Konsolidierung auf «Privat» ist bei Google NICHT angekommen; Lösch-Schritt deckt alle sieben ab |
| Überlappung Umzügler ∩ Privat-Labels | **2 — Entscheid Daniel 02.09.: beide bleiben PRIVAT** | **Tino Hassler** (arbeitet nicht mehr bei Heineken) und **«Steven (Privat) - Engadin»** ziehen NICHT um — sie werden im Zielkonto beim Label-Löschen bewusst mit entfernt und bleiben in dani.proyer@. Stevens geschäftliche Seite deckt der separate Kontakt «Steven Engadin» ab (geschäftliche Nummer dort ergänzen, falls sie fehlt) |
| Zielkonto sbs.projer@ vorher | **3** | Heineken Urs · Naella. · Your — kein Treffer in den 723, keine Duplikate |
| **Nachher-Soll Zielkonto** | **723** | = 3 + 723 − 1 (Beat-Jörg-Merge, geprüft korrekt: «Beat Jörg» + «Heineken - Beat Jörg - RSL», gleiche Nummer/Mail, kein Dritter teilt die Nummer) − 2 (Tino, Steven-Privat bleiben privat). Beim Staging-Abgleich fehlen zwei Zeilen absichtlich, zwei Beat-Jörg-Zeilen matchen auf einen Kontakt |

Leere Gruppen (gemessen): «SBS Event», «SIM», «Importiert am 15.12.24» — enthalten keinen einzigen Kontakt, spielen keine Rolle.

## Ablauf

**Schritt 0 — Frisch-Messung: ✅ ERLEDIGT 02.09.** (Heineken-Session, rein lesend; Werte in der Tabelle oben). Grünes Licht für den Export.

**Schritt 1 — Export (dani.proyer@):**
[contacts.google.com](https://contacts.google.com) → links «Exportieren» → **«Kontakte (alle)»** → Format **Google CSV**.
Warum alle 767: Die Gruppenlosen lassen sich in der Oberfläche nicht auswählen («ohne Label» gibt es als Filter nicht). Die 44 Privaten kommen bewusst mit und werden in Schritt 3 im Zielkonto wieder entfernt.

**Schritt 2 — Import (sbs.projer@):**
contacts.google.com → «Importieren» → die CSV aus Schritt 1. Labels/Gruppen kommen mit.
Danach kurz prüfen: Gesamtzahl = 3 + 767 = **770**. Falls Google «Zusammenführen & korrigieren» vorschlägt: **ignorieren** — es gibt keine erwarteten Duplikate, jede Zusammenführung würde die Abgleich-Zahlen verfälschen.

**Schritt 3 — Die Privaten im Zielkonto löschen (46 Kontakte: 44 Nur-Private + Tino + Steven-Privat):**
1. **Vorher:** Im Kontakt «Steven Engadin» (geschäftlich) prüfen, ob die geschäftliche Nummer drinsteht — falls sie nur in «Steven (Privat) - Engadin» steht, jetzt dorthin kopieren.
2. Dann **alle sieben** Privat-Labels nacheinander (Privat, Freunde, Bekannte, Familie, Juma, Mexiko, Studium): Label öffnen → alle Mitglieder auswählen → löschen. Tino Hassler und «Steven (Privat) - Engadin» fliegen dabei **bewusst** mit raus (Entscheid Daniel: beide bleiben privat).
3. Zum Schluss die sieben Privat-Labels selbst löschen (leer, gehören nicht ins Geschäftskonto).

**Schritt 4 — Verifikation (Heineken-Session, rein lesend):**
Zielkonto lesen: Soll = **exakt 723**. Abgleich gegen die 723 Staging-Zeilen (Name/Nummer/Mail) — erwartete, erklärte Abweichungen: zwei Beat-Jörg-Zeilen matchen auf EINEN Kontakt; Tino Hassler und «Steven (Privat) - Engadin» fehlen absichtlich. Jede andere Abweichung wird geklärt, **bevor** irgendetwas gelöscht wird.

**Schritt 5 — erst nach Grün: Quellkonto aufräumen (dani.proyer@):**
**Zuerst** Tino Hassler das Label «SBS Heineken» und «Steven (Privat) - Engadin» das Label «Geschäftlich» wegnehmen — beide sind damit reine Privatkontakte und **ausdrücklich vom Löschen ausgenommen**. Dann die übrigen 721 Umzügler löschen; die Privaten (inkl. Reto Baumann, Tino, Steven-Privat) bleiben. Kein Zeitdruck — bis dahin funktioniert Heinekens `konto=dani`-Lesequelle unverändert weiter. (Das Abklemmen von `konto=dani` selbst ist Vorhaben ③, Schritt 5.)

## Danach (separat, blockiert nichts)

- **Daniels Komplett-Durchsicht** direkt in Google Kontakte unter sbs.projer@ (Web oder Pixel-App): behalten/löschen, umbenennen, Label zuweisen. Kniff: Label «Geprüft» anlegen und anhängen — Fortschritt bleibt messbar (Ziel: Anzahl «Geprüft» = Bestand). Merkposten aus den Messungen: «Steven (Privat) - Engadin» einordnen (heisst «Privat», steht in «Geschäftlich») · 4 Kontakte mit U+2010-Bindestrich vereinheitlichen («Chur ‐ Italy», «Davos ‐ Montana Stube», «Grüsch ‐ Fasan», «Laax ‐ Indy») · Combox und der namenlose Kontakt: löschen oder klären · «Maria Roth Haus Maladerd (Sie)», «Forstamt Arosa Claudio Färber», «Sonnenbräu Monteur» einordnen · **«Naella.»** = Eventmanagerin Heineken und **«Your»** = Daniels eigene Nummer (geklärt 01.09.) — bei der Durchsicht sauber benennen/labeln; «Heineken Urs» = Heineken-Vertreter, bleibt · **«Steven Engadin» + «Steven (Privat) - Engadin»** — mutmasslich dieselbe Person in zwei Zeilen (Befund 02.09.), zusammenführen · **zusammengeführter Beat Jörg:** Anzeigename «Beat Jörg» behalten, RSL-Rolle in die Notiz — die «Heineken - …»-Präfixe sind die alte Handy-Konvention und auf der Plattform unnötig.
- Volliste für die Durchsicht liegt strukturiert im Heineken-Staging; bei Bedarf erzeugt die Heineken-Session ein lokales Blatt (bewusst keine Personendaten-Datei im Repo).

## Regeln (aus dem 29.08.)

- Nach jedem Schritt messen, bevor der nächste folgt — verbindlich sind die Zahlen aus Schritt 0, nicht die Nachmittags-Messung.
- Erst alle Konsumenten umstellen bzw. verifizieren, dann Altes löschen — nie umgekehrt.
- Bei Abweichung: anhalten und klären, nicht «wird schon stimmen».
