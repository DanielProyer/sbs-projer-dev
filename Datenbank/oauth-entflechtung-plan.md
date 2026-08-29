# Entflechtung Google-OAuth: «1 Client = 1 Verwendung» + Trennung geschäftlich/privat

**Entwurf vom 29.08.2026, freigegeben von Daniel (Reihenfolge A). Umsetzung ab KW 36.**
Vorgeschichte: [oauth-komplett-reset-anleitung.md](oauth-komplett-reset-anleitung.md) — der Reset vom 29.08. hat alle Secrets und Tokens erneuert, aber die geteilte Bauart nicht beseitigt.

---

## Warum

Zwei Clients tragen je zwei Verwendungen. Genau diese Bauart hat am 27.08. den Ausfall verursacht: Beim Anlegen eines neuen Secrets wurde wegen des 2-Secrets-Limits ein altes gelöscht — und damit still ein anderer Konsument gebrochen, der in keiner Liste stand.

Dazu kommt eine zweite Anforderung (Daniel, 29.08.): **klare Trennung geschäftlich (sbs.projer@gmail.com) und privat (dani.proyer@gmail.com)** — und zwar auf beiden Achsen: wem das Cloud-Projekt gehört **und** wessen Daten die App liest. Heute ist beides vermischt: Client ① gehört dem privaten Konto und bedient zwei geschäftliche Verwendungen; Heinekens Kontakte-Anbindung liest die privaten Kontakte mit.

## Ausgangslage (Stand nach dem Reset vom 29.08.)

| Client | Projekt | Inhaber | Verwendungen |
|---|---|---|---|
| `1040401919292-cev05…` | 1040401919292 «SBS Projer» | dani.proyer@ | SBS-Kalender/Kontakte **+ Heineken-Gmail** |
| `342011182738-n69h…` | 342011182738 «Finanzapp Kontakte» | dani.proyer@ | Finanzapp-Kontakte **+ Heineken-Kontakte** |
| `143053064319-3ftn…` | 143053064319 | sbs.projer@ | SBS-Rechnungsversand ✓ bereits sauber |

## Zielbild

**Geschäftlich — sbs.projer@**

| Projekt | Client | Verwendung |
|---|---|---|
| 1040401919292 *(Inhaber umgehängt)* | `…cev05…` | SBS-Kalender + Kontakte |
| 143053064319 *(unverändert)* | `…3ftn…` | SBS-Rechnungsversand |
| **neu: «Heineken Plattform»** | neu | Heineken-Gmail |
| **neu: «Heineken Plattform»** | neu | Heineken-Kontakte |

**Privat — dani.proyer@**

| Projekt | Client | Verwendung |
|---|---|---|
| 342011182738 *(unverändert)* | `…n69h…` | Finanzapp-Kontakte |

Entscheidungen dazu:
- **Ein** Heineken-Projekt mit **zwei** Clients, nicht zwei Projekte. Der Zustimmungsbildschirm hängt am Projekt, beide Heineken-Grants wären also gleich benannt — aber sie sind am Scope unterscheidbar (`gmail.send` vs. `contacts`). Das Problem vom 29.08. (zwei ununterscheidbare «SBS Projer»-Einträge, beide `gmail.send`) entsteht so nicht neu.
- **Die Finanzapp gilt als privat** und bleibt bewusst unter dani.proyer@, inklusive Zugriff auf private Kontakte. Das ist dann Absicht, kein Versehen. **Von der Finanzapp-Session am 29.08. bestätigt — und dort im Code erzwungen, nicht bloss Konvention:** `kontakte-google` akzeptiert ausschliesslich Freigaben von dani.proyer@ und weist das Geschäftskonto aktiv ab; der camt-Import lehnt Firmenkonten der SBS Projer GmbH ab (die App führt bewusst keine Firmenbuchhaltung); Berührungspunkte wie Spesen oder Büromiete behandeln die GmbH nur als Gegenpartei.
- **Eigentümerschaft wird per IAM umgehängt, nicht neu gebaut.** sbs.projer@ als Inhaber hinzufügen, dani.proyer@ entfernen — Clients, Secrets und Tokens bleiben unberührt. Das spart den kompletten Neubau von Client ①.

## Zerlegung — drei Vorhaben, Reihenfolge A

### ① Kontakte-Umzug (Voraussetzung für ③)

Geschäftliche Kontakte von dani.proyer@ nach sbs.projer@ übertragen. Rein auf Google-Seite, keine Code- oder OAuth-Arbeit.

**Die Unterscheidung ist bereits gelöst** (Befund der Heineken-Session, 29.08.): In dani.proyer@ existiert die Google-Kontakte-Gruppe **«Geschäftlich» mit 731 Kontakten**. Sie ist die Lesequelle von Heinekens `kontakte-google` — der Weg `konto=dani` ist dort ausdrücklich **nur lesend** angelegt, `konto=sbs` liest und schreibt. Es braucht also keine Heuristik und keinen Abgleich gegen `betriebe`: Die Gruppe ist die Definition.

⚠️ **Diese 731 Kontakte sind bei Heineken noch nie angekommen** — gemessen am 29.08.: Staging-Tabelle `kontakt_uebernahme` = 0, `kontakt_person` mit `google_resource_name` = 0, `kontakt_person` gesamt 117 (aus altapp_import, altapp_nachzug, feld_diktat). Die Übernahme stand seit der Einrichtung als nächster Schritt aus und wurde durch den Ausfall vom 27.08. zusätzlich blockiert.

**Daraus folgt die eigentliche Abhängigkeit, schärfer als zunächst formuliert:** `konto=dani` abzuklemmen heisst, Heineken die Lesequelle der Geschäftskontakte zu nehmen. Das ist nur zulässig, **nachdem** die 731 im Geschäftskonto liegen. Vorhaben ① ist damit nicht nur Vorbedingung für ③, sondern für den Umbau insgesamt.

⚠️ **Vorbehalt zur Definition (Heineken-Session, 29.08.):** Die Gruppe «Geschäftlich» ist die beste verfügbare Definition, aber sie wird **von Hand gepflegt**. Ein geschäftlicher Kontakt, der nie in die Gruppe einsortiert wurde, bleibt beim Umzug liegen und fehlt danach **still** — niemand bemerkt einen Kontakt, der nicht da ist. **Deshalb vor dem Umzug eine Stichprobe:** Kontakte mit einer Firmen-Mailadresse oder einem Firmennamen **ausserhalb** der Gruppe suchen. Findet sich nichts, ist die Gruppe belastbar; findet sich etwas, wird nachsortiert, bevor irgendetwas umzieht.

**Vorher-Zahl festhalten:** Vor dem Umzug die Zahl der Kontakte in der Gruppe «Geschäftlich» notieren (erwartet 731). Heineken vergleicht sie gegen ihre Staging-Zahl. Weichen sie ab, ist die Ursache **vor** dem Umzug zu klären, nicht danach.

**Vorschlag der Heineken-Session, Entscheid liegt bei Daniel (offen, Stand 29.08.):** Die 731 vor dem Umzug einmal per `uebernahme_lesen` ins Staging lesen — rein lesend, ändert bei Google nichts. Begründung: (a) der Umzug wird prüfbar (731 vorher, 731 nachher, statt der Annahme, dass unterwegs nichts verlorengeht), (b) es gibt sonst keine zweite Kopie — die Alt-App kennt diese Kontakte nicht. **Nicht freigegeben, weil es 731 Kontakte aus Daniels privatem Konto in die Heineken-Datenbank schreibt** — diese Entscheidung gehört ihm, nicht der SBS-Session. Kein Zeitdruck: Der `konto=dani`-Zugang bleibt bis Vorhaben ② bestehen.

### ② OAuth-Entflechtung

1. Neues GCP-Projekt «Heineken Plattform» **unter sbs.projer@** anlegen, Zustimmungsbildschirm einrichten, auf «In Produktion» veröffentlichen, Gmail- und People-API freischalten.
2. Zwei Clients anlegen, je ein Secret, je ein Passwortmanager-Eintrag mit Konsumenten-Liste.
3. Heineken-Session stellt `GMAIL_CLIENT_ID`/`GMAIL_CLIENT_SECRET` und `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` um. **Achtung: diesmal ändern sich auch die Client-IDs**, nicht nur die Secrets — beim Reset am 29.08. blieben die IDs gleich.
4. Neues Gmail-Refresh-Token via OAuth Playground (Konto sbs.projer@), Kontakte-Flows neu autorisieren.
5. Nach Grün-Meldung: Heinekens Verwendungen aus Client ① und ② entfernen (alte Freigaben unter myaccount widerrufen).
6. **Der Finanzapp-Session Bescheid geben, sobald Heinekens Kopie von Secret E stillgelegt ist** (Bitte von dort, 29.08.). Sie streichen Heineken dann aus ihrer Konsumenten-Liste — in der Doku und im Passwortmanager-Eintrag von E. Ohne diesen Zuruf bliebe eine Konsumenten-Liste stehen, die einen Verbraucher nennt, den es nicht mehr gibt — genau die Sorte veraltete Landkarte, die den Ausfall vom 27.08. mitverursacht hat.
7. Projekt 1040401919292 per IAM auf sbs.projer@ umhängen.

### ③ Kalender-Umzug

1. SBS-App von dani.proyer@ trennen, mit sbs.projer@ neu verbinden.
2. Kalender aus der Datenbank neu aufbauen — die App erzeugt alle Einträge selbst (sechs Typen, täglicher Auto-Reconcile), einzelne Termine müssen also **nicht** umgezogen werden.
3. Kalender von sbs.projer@ für dani.proyer@ freigeben, damit die Termine auf dem Handy neben dem privaten Kalender erscheinen (einblendbar, farblich getrennt).
4. Alt-Termine im privaten Kalender aufräumen.
5. Heinekens `kontakte-google` auf `konto=sbs` reduzieren, `konto=dani` abklemmen (setzt ① voraus).

## Regeln für die Umsetzung (aus dem 29.08. gelernt)

- **Nach jedem Eingriff messen, bevor der nächste folgt.** Am 29.08. sind drei plausible Ableitungen an einer Messung zerbrochen.
- **Erst alle Konsumenten umstellen, dann Altes löschen** — nie umgekehrt.
- **Ein grüner Refresh beweist nur, dass irgendein gültiges Token wirkt.** Dass es das neue ist, zeigt erst der Schreibzeitstempel der Token-Zeile.
- **Fehler-Merkregeln:** `invalid_client` + «was not found» ⇒ Wert in der ID-Zeile · `invalid_client` + «secret is invalid» ⇒ falscher Wert · `invalid_grant` (400) ⇒ Token widerrufen.
- **Konsole-Fallen:** Der Projektwähler findet die Projektnummer nicht (nur Name und Projekt-ID) → URL `console.cloud.google.com/apis/credentials?project=<nr>&authuser=<konto>`. Und aufs richtige Konto achten.
- **Koordination:** Die Heineken-Session verifiziert ihre Wege selbst; SBS bleibt Sammelstelle. Secret-Werte gehen **nicht** durch den Nachrichtenkanal.
- **«Geprüft» heisst: am ausgerollten Stand, nicht am Repo.** Am 29.08. stand der `Content-Type`-Header in Heinekens Repo-Datei seit je korrekt — draussen lief trotzdem eine ältere Fassung, sichtbar an rohen `<h2>`-Tags und «fÃ¼r». Ein Blick in den Quelltext hätte «alles in Ordnung» ergeben. Bei projektübergreifenden Prüfungen also **die laufende Function befragen**, nicht die Datei lesen — dieselbe Logik wie die Regel «Version muss in der Oberfläche sichtbar sein».

## Was dieser Plan bewusst nicht umfasst

- Kein Umzug der Finanzapp (privat, bleibt wie sie ist).
- Keine Änderung am SBS-Rechnungsversand (Client ③ ist bereits sauber).
- Keine Anpassung von Heinekens `kontakte-google`-Code ausser der Konten-Reduktion — der offene `Content-Type`-Fehler ihrer Erfolgsseite gehört in ihr eigenes Repo.
