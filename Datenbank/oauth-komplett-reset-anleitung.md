# Komplett-Reset Google-Secrets & -Tokens — Schritt für Schritt (Stand 29.08.2026)

Drei Clients, drei Projekte (SBS `pltbaqqwpnmdajwgnhpd` · Heineken `dtdcohqjihoiqlaekeiz` · Finanzapp `botsyitkcxxkwpslsssq`).
Abgestimmt am 29.08.2026 mit den Sessions Heineken + Finanzapp (beide einverstanden). Claude (SBS-Session) ist Sammelstelle für alle Grün-Meldungen.

**Drei eiserne Regeln:**
1. Jeden neuen Wert SOFORT in den Passwortmanager — Google zeigt ihn nur einmal.
2. NICHTS löschen, bis Claude «SAMMEL-GRÜN» meldet.
3. Bei jedem 📣 MELDEN kurz in der Claude-Session Bescheid geben — die Prüfungen laufen automatisch (SBS-Probe `google-secret-probe`, Header `x-probe-key` im Transkript der Session vom 29.08.; Heineken: kontakte-Probe + ist_test-Versand; Finanzapp: Refresh-Test).

---

## Phase 1 — Die drei neuen Secrets

### Teil A · Secret F (Client ① — SBS-Kalender + Heineken-Gmail)

1. Öffne https://console.cloud.google.com, angemeldet als **dani.proyer@gmail.com**.
2. Projektwähler oben links → `1040401919292` suchen → Projekt wählen.
3. Menü links: **APIs & Dienste → Anmeldedaten**.
4. Nebenbei unter **OAuth-Zustimmungsbildschirm** den **App-Namen notieren** (für Phase 2/3) und Status prüfen: muss **«In Produktion»** sein. Zurück zu «Anmeldedaten».
5. Client öffnen, dessen ID mit **`1040401919292-cev05`** beginnt.
6. Bereich **Clientschlüssel**. ⚠️ **Korrektur 29.08. (Befund am Gerät):** Es liegen **ZWEI** Schlüssel drin (15.08. und 27.08.), kein Platz frei — die ursprüngliche Annahme «ein Platz frei» stimmte nicht. Also: **den älteren (15.08.) löschen**, dann «+ Schlüssel hinzufügen».
   - *Warum der 15.08.:* Einer der beiden ist Heinekens aktives `GMAIL_CLIENT_SECRET` (Vorher-Beleg 29.08. 12:15 UTC: `gmail_versand` ok/200), der andere ist ein Waisenkind. **Welcher, ist nicht belegbar** — der geglückte Heineken-Versand vom 27.08. 19:54 beweist es NICHT, weil der Fehlversuch um 19:52 ein `403 Gmail API not enabled` war und kein `invalid_client`. SBS' Wert ist keiner von beiden (sonst kein «client secret is invalid»). Der Wertvergleich (Supabase-Secret gegen Konsole/PM) war am Gerät nicht möglich. **Entscheid Daniel:** Restrisiko bewusst tragen — Wochenende ohne Mail/Kalender-Bedarf, Zielmarke Montag. Der ältere ist die schadensminimale Wahl: Waisenkind ⇒ nichts passiert; Heinekens ⇒ Störung nur bis Schritt 11.
   - **AUFGELÖST (Messung, 29.08.):** Heineken-Beleg vorher 12:15:09 UTC `gmail_versand ok/200`, nachher (nach dem Löschen, vor ihrer Umstellung auf F) 12:27:03 UTC **ebenfalls ok/200**. ⇒ Der gelöschte 15.08.-Schlüssel war ein **Waisenkind**; Heinekens `GMAIL_CLIENT_SECRET` ist der **27.08. (= C)**. Kein Ausfall. Damit gilt: **C wird bis Schritt 11 noch gebraucht** und darf erst in Phase 4 weg. Client ① hat nach dem Anlegen von F wieder beide Plätze belegt (C + F) — Rotationsreserve entsteht erst mit dem Löschen von C in Schritt 56.
7. Neuen Wert kopieren = **Secret F** (wird nur einmal angezeigt).
8. https://passwords.google.com → «Passwort hinzufügen»:
   - Website: `console.cloud.google.com`
   - Nutzername: `1040401919292-cev05kfl51rq152du8frk0b50562hcgr.apps.googleusercontent.com`
   - Passwort: F
   - Notiz: `Secret F, 29.08.2026. Konsumenten: SBS-Supabase pltbaqqwpnmdajwgnhpd → GOOGLE_OAUTH_CLIENT_SECRET | Heineken-Supabase dtdcohqjihoiqlaekeiz → GMAIL_CLIENT_SECRET. Rotation: neu anlegen → BEIDE umstellen → verifizieren → erst dann altes löschen.`
9. https://supabase.com/dashboard/project/pltbaqqwpnmdajwgnhpd/functions/secrets (sonst: Edge Functions → Secrets) → Zeile `GOOGLE_OAUTH_CLIENT_SECRET` → Wert = F → Speichern.
10. 📣 MELDEN «F bei SBS drin» → Claude prüft; danach SBS-App → Einstellungen → Google Kalender → «Jetzt abgleichen».
11. https://supabase.com/dashboard/project/dtdcohqjihoiqlaekeiz/functions/secrets → Zeile `GMAIL_CLIENT_SECRET` → Wert = F → Speichern.
12. 📣 MELDEN «F bei Heineken drin» → Heineken-Testversand.

### Teil B · Secret E (Client ② — Finanzapp- + Heineken-Kontakte)

13. Console: Projektwähler → `342011182738` («Finanzapp Kontakte»).
14. APIs & Dienste → Anmeldedaten → Client öffnen (ID beginnt `342011182738-n69h`). App-Namen des Zustimmungsbildschirms notieren.
15. Clientschlüssel: EIN Schlüssel drin (= A, NICHT anfassen — einziger gültiger Finanzapp-Wert!), ein Platz frei. Sind ZWEI drin: STOPP, melden.
16. «+ Schlüssel hinzufügen» → Wert kopieren = **Secret E**.
17. passwords.google.com → neuer Eintrag:
    - Website: `console.cloud.google.com`
    - Nutzername: `342011182738-n69h9dluvj41sscdepcnq77djli9rcai.apps.googleusercontent.com`
    - Passwort: E
    - Notiz: `Secret E, 29.08.2026. Konsumenten: Finanzapp-Supabase botsyitkcxxkwpslsssq → GOOGLE_CLIENT_SECRET | Heineken-Supabase dtdcohqjihoiqlaekeiz → GOOGLE_CLIENT_SECRET. Kontakte-Neuverbindung: STATE-URLs siehe Anleitung Phase 3. Rotation: neu anlegen → BEIDE umstellen → verifizieren → erst dann löschen.`
18. Heineken-Secrets → Zeile `GOOGLE_CLIENT_SECRET` → Wert = E → Speichern. 📣 MELDEN «E bei Heineken drin».
19. https://supabase.com/dashboard/project/botsyitkcxxkwpslsssq/functions/secrets → NUR Zeile `GOOGLE_CLIENT_SECRET` → Wert = E (GOOGLE_CLIENT_ID und GOOGLE_OAUTH_STATE nicht anrühren) → Speichern. 📣 MELDEN «E bei Finanzapp drin».

### Teil C · Secret G (Client ③ — SBS-Rechnungsversand)

20. Console: Projekt `143053064319` öffnen. ⚠️ **Befund 29.08.:** Dieses Projekt gehört **sbs.projer@gmail.com**, nicht dani.proyer@ — als dani.proyer@ kommt «Sie benötigen zusätzliche Zugriffsrechte» (`resourcemanager.projects.get` fehlt). Also **erst Konto wechseln**. Ausserdem findet der Projektwähler nur Namen und Projekt-ID, **nicht die Projektnummer** — direkt über die URL gehen:
    `https://console.cloud.google.com/apis/credentials?project=143053064319&authuser=sbs.projer@gmail.com`
    Gilt genauso für Schritt 35 (Phase 2 Teil E) und Schritt 59 (Phase 4). Clients ① und ② liegen dagegen unter dani.proyer@.
21. OAuth-Zustimmungsbildschirm: App-Namen notieren; steht «Testing» → «App veröffentlichen» klicken.
22. Anmeldedaten → Client `143053064319-3ftn…` öffnen.
23. Clientschlüssel: Platz frei → «+ hinzufügen». Beide voll → das ÄLTERE löschen (Papierkorb), dann «+ hinzufügen». Wert = **Secret G**.
24. passwords.google.com → neuer Eintrag:
    - Website: `console.cloud.google.com`
    - Nutzername: `143053064319-3ftnqsv1g3313d6t9sq2n2mqu4n52tcm.apps.googleusercontent.com`
    - Passwort: G
    - Notiz: `Secret G, 29.08.2026. Konsument: SBS-Supabase pltbaqqwpnmdajwgnhpd → GMAIL_CLIENT_SECRET. Versandkonto sbs.projer@gmail.com. Rotation: neu anlegen → umstellen → verifizieren → erst dann löschen.`
25. SBS-Secrets → Zeile `GMAIL_CLIENT_SECRET` → Wert = G → Speichern.
26. 📣 MELDEN «G drin» → Claude prüft Gmail-Refresh per Probe (keine Mail). **Warten auf «Phase 1 grün».**

---

## Phase 2 — Die zwei Gmail-Tokens (beide mit Konto **sbs.projer@gmail.com**)

### Teil D · Heineken-Gmail-Token (Client ①)

27. Console: Projekt `1040401919292` → Client `…cev05…` → «Autorisierte Weiterleitungs-URIs» → «+ URI hinzufügen» → `https://developers.google.com/oauthplayground` → Speichern.
28. https://myaccount.google.com/connections — als **sbs.projer@gmail.com** → App mit dem Namen aus Schritt 4 → **«Zugriff entfernen»**.
    ⚠️ **Befund 29.08.:** Client ① **und** Client ③ haben denselben Zustimmungsbildschirm-Namen **«SBS Projer»** — unter sbs.projer@ stehen also **zwei** gleichnamige Einträge, am Namen nicht unterscheidbar. Beide tragen `gmail.send`, also auch am Scope nicht. **Lösung:** beide entfernen (Client ③ ist in Schritt 36 ohnehin dran), danach beide Playground-Durchläufe (Teil D mit F, Teil E mit G). **Nicht** anfassen: «Finanzapp Kontakte» (Client ②, erst Schritt 49).
29. https://developers.google.com/oauthplayground → Zahnrad → Haken «Use your own OAuth credentials» → Client ID `1040401919292-cev05kfl51rq152du8frk0b50562hcgr.apps.googleusercontent.com` + Secret F → schliessen.
30. Step 1, Feld «Input your own scopes»: `https://www.googleapis.com/auth/gmail.send` → «Authorize APIs».
31. Konto **sbs.projer@** wählen → bei App-Warnung: «Erweitert» → fortfahren → Zulassen.
32. «Exchange authorization code for tokens» → Feld **Refresh token** kopieren.
33. passwords.google.com → neuer Eintrag: Website `console.cloud.google.com` · Nutzername `Token-Heineken-Gmail (sbs.projer@)` · Passwort = Token · Notiz: `Refresh-Token 29.08.2026, Client 1040401919292-cev05…, Scope gmail.send. Konsument: Heineken-Supabase → GMAIL_REFRESH_TOKEN. Neu ausstellbar via OAuth Playground mit Secret F.`
34. Heineken-Secrets → `GMAIL_REFRESH_TOKEN` → Token → Speichern. 📣 MELDEN «Heineken-Token drin» → Heineken-Testversand (ist_test, geht nur an sbs.projer@ selbst).

### Teil E · SBS-Gmail-Token (Client ③)

35. Console: Projekt `143053064319` → Client `…3ftn…` → Weiterleitungs-URI `https://developers.google.com/oauthplayground` hinzufügen → Speichern.
36. myaccount.google.com/connections (sbs.projer@) → App aus Schritt 21 → «Zugriff entfernen».
37. Playground: Zahnrad → Credentials ersetzen: Client-ID `143053064319-3ftnqsv1g3313d6t9sq2n2mqu4n52tcm.apps.googleusercontent.com` + Secret G → schliessen.
38. Scope `https://www.googleapis.com/auth/gmail.send` → «Authorize APIs» → Konto sbs.projer@ → Zulassen → «Exchange authorization code for tokens» → Refresh token kopieren.
39. passwords.google.com → Eintrag: Nutzername `Token-SBS-Gmail (sbs.projer@)` · Passwort = Token · Notiz: `Refresh-Token 29.08.2026, Client 143053064319-3ftn…, Scope gmail.send. Konsument: SBS-Supabase → GMAIL_REFRESH_TOKEN. Neu ausstellbar via OAuth Playground mit Secret G.`
40. SBS-Secrets → `GMAIL_REFRESH_TOKEN` → Token → Speichern. 📣 MELDEN «SBS-Token drin» → Claude-Probe (keine Mail).

---

## Phase 3 — Kalender- & Kontakte-Verbindungen neu

### Teil F · SBS-Kalender + Kontakte (Konto **dani.proyer@**)

41. myaccount.google.com/connections — als **dani.proyer@** → App aus Schritt 4 («SBS Projer») → «Zugriff entfernen».
42. SBS-App https://danielproyer.github.io/sbs-projer-dev/ → Einstellungen → Google Kalender.
43. Steht «Verbunden»: «Trennen» klicken (Fehlermeldung dabei egal).
44. «Verbinden» → Google-Dialog → **dani.proyer@** → Zulassen.
45. «Jetzt abgleichen» — muss ohne Fehler laufen.
46. Bereich Google Kontakte: Sync einmal anstossen — ohne Fehler.
47. 📣 MELDEN «SBS Kalender+Kontakte neu verbunden».

### Teil G · Kontakte-Flows Client ② (3 Freigaben)

48. myaccount.google.com/connections als **dani.proyer@** → App «Finanzapp Kontakte» → «Zugriff entfernen».
49. Kontowechsel **sbs.projer@** → erscheint «Finanzapp Kontakte» → ebenfalls entfernen (fehlt sie: weiter).
50. Heineken-`GOOGLE_OAUTH_STATE` besorgen: zuerst Passwortmanager (Einrichtung 14.08.), sonst Heineken-Secrets-Zeile `GOOGLE_OAUTH_STATE` aufdecken.
51. Browser (als dani.proyer@), STATE ersetzen und öffnen:
    `https://dtdcohqjihoiqlaekeiz.supabase.co/functions/v1/kontakte-google?s=STATE&konto=dani`
    → Konto dani.proyer@ wählen → «Freigabe für … erteilt».
52. Gleiche URL mit `&konto=sbs` → Konto **sbs.projer@** wählen → «Freigabe erteilt». (Falsches Konto = speichert nichts; einfach nochmal.)
53. Finanzapp-`GOOGLE_OAUTH_STATE` aus deren Secrets kopieren.
54. Browser (als dani.proyer@), STATE ersetzen:
    `https://botsyitkcxxkwpslsssq.supabase.co/functions/v1/kontakte-google?s=STATE`
    → dani.proyer@ wählen → «Freigabe erteilt. Dieses Fenster kann zu.»
55. 📣 MELDEN «Kontakte-Flows fertig» → Heineken- + Finanzapp-Proben.

---

## Phase 4 — Aufräumen (**erst nach Claudes «SAMMEL-GRÜN»**)

56. Projekt `1040401919292` → Client `…cev05…` → Schlüssel mit Erstellungsdatum **27.08.** (= C) löschen. Nur F bleibt.
57. Gleicher Client: Playground-Weiterleitungs-URI wieder entfernen → Speichern.
58. Projekt `342011182738` → Client → das ÄLTERE Secret (A) löschen. Nur E bleibt.
59. Projekt `143053064319` → Client → falls noch ein zweites, älteres Secret: löschen (nur G bleibt) → Playground-URI entfernen → Speichern.
60. 📣 MELDEN «aufgeräumt» → Schluss-Verifikation aller vier Wege; Sessions legen Probe-Functions still (410-Rumpf; endgültige Löschung im Dashboard); ToDo + Memory werden nachgeführt.

---

**Hinweis DB-Tokens (Kalender/Kontakte):** Werte werden bei jedem Neu-Verbinden überschrieben — ihr Backup ist der Wiederherstellungsweg (App neu verbinden bzw. STATE-URL, je 1 Minute), dokumentiert in den PM-Notizen der Einträge 1+2. Optional zusätzlich Werte ablegen: SBS Table Editor `google_calendar_tokens.refresh_token` · Heineken Tabelle `google_token` (je Konto) · Finanzapp `google_tokens` (dani.proyer@) — mit Datum in der Notiz (Schnappschuss).

**Offene Punkte nach dem Reset (auf Zuruf):** Entflechtung «1 Client = 1 Verwendung» (eigene Clients für Heineken-Gmail und Heineken-Kontakte, dann Vereinheitlichung der Secrets); SBS-Probe-Function `google-secret-probe` im Dashboard endgültig löschen.
