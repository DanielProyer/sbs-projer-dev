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
- **Die Finanzapp gilt als privat** und bleibt bewusst unter dani.proyer@, inklusive Zugriff auf private Kontakte. Das ist dann Absicht, kein Versehen.
- **Eigentümerschaft wird per IAM umgehängt, nicht neu gebaut.** sbs.projer@ als Inhaber hinzufügen, dani.proyer@ entfernen — Clients, Secrets und Tokens bleiben unberührt. Das spart den kompletten Neubau von Client ①.

## Zerlegung — drei Vorhaben, Reihenfolge A

### ① Kontakte-Umzug (Voraussetzung für ③)

Geschäftliche Kontakte von dani.proyer@ nach sbs.projer@ übertragen. Rein auf Google-Seite, keine Code- oder OAuth-Arbeit.

**Offen und vor Beginn zu klären:** Wie werden geschäftliche Kontakte von privaten unterschieden? Kandidaten: Label/Gruppe in Google Kontakte, Abgleich gegen die `betriebe`-Tabelle (Name/Telefon/Adresse), oder manuelle Durchsicht. Vor dem Umzug erst **zählen**, wie viele Kontakte in beiden Konten liegen und wie stark sie sich überschneiden — Entscheid auf Zahlen, nicht auf Gefühl.

### ② OAuth-Entflechtung

1. Neues GCP-Projekt «Heineken Plattform» **unter sbs.projer@** anlegen, Zustimmungsbildschirm einrichten, auf «In Produktion» veröffentlichen, Gmail- und People-API freischalten.
2. Zwei Clients anlegen, je ein Secret, je ein Passwortmanager-Eintrag mit Konsumenten-Liste.
3. Heineken-Session stellt `GMAIL_CLIENT_ID`/`GMAIL_CLIENT_SECRET` und `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` um. **Achtung: diesmal ändern sich auch die Client-IDs**, nicht nur die Secrets — beim Reset am 29.08. blieben die IDs gleich.
4. Neues Gmail-Refresh-Token via OAuth Playground (Konto sbs.projer@), Kontakte-Flows neu autorisieren.
5. Nach Grün-Meldung: Heinekens Verwendungen aus Client ① und ② entfernen (alte Freigaben unter myaccount widerrufen).
6. Projekt 1040401919292 per IAM auf sbs.projer@ umhängen.

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

## Was dieser Plan bewusst nicht umfasst

- Kein Umzug der Finanzapp (privat, bleibt wie sie ist).
- Keine Änderung am SBS-Rechnungsversand (Client ③ ist bereits sauber).
- Keine Anpassung von Heinekens `kontakte-google`-Code ausser der Konten-Reduktion — der offene `Content-Type`-Fehler ihrer Erfolgsseite gehört in ihr eigenes Repo.
