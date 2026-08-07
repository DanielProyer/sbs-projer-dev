# Zahlernamen aus der Zahlungshistorie gelernt (07.08.2026)

> ## ✅ NACHTRAG (07.08. abends): Internet-Recherche zu den 53 offenen Fällen
>
> Drei Recherche-Agenten (Zefix/Handelsregister, Impressen, Lokalnews) haben
> **49 der 53 Fälle aufgeklärt** — Ergebnis: **52 weitere Aliase auf 42
> Betriebe gesetzt** (u. a. per wörtlichem Impressum-/HR-Beleg), dazu zwei
> Korrekturen:
> - Alias «hotel alpenblick weggis ag» von **Alpenblick [Arosa] entfernt**
>   (HR-Zweck nennt explizit das Hotel in Weggis) → jetzt korrekt auf
>   Hotel Alpenblick [Weggis].
> - Alias «hotel lenzerhorn spa & wellness ag» von **Lenzerhorn entfernt**:
>   das Hotel betreibt AUCH das Haus Spescha → Zwei-Betriebe-Zahler, Zuordnung
>   manuell (wie HR Seehof: Seehof+Chesa · M&M Gastro: Giodavin+Ochsen ·
>   Allegra Vinum: Franziskaner+Fondue Beizli — alle bewusst OHNE Alias).
> - **AlpinTrend-Gruppe (Luzius Bergamin)** erklärt fünf Zahler: Pradaschier→
>   Portal, Luber AG+Posthotel Valbella AG→Posthotel, Gastromagia (=ex
>   Gonglis!)→Löwen Maienfeld, Lupiz→da Elio, Lenzerhorn→(auch) Spescha.
> - Fehlpaarungen erkannt: Alexanderplatz gehört der «Café Alexanderplatz
>   Chur KLG» (Fetz), nicht Pradaschier; «Bahnhof Trübbach (Corca)» war der
>   VORGÄNGER des Steak House (gleiche Adresse, Firma 01/2025 gelöscht);
>   «Traube Senti» war der Alt-Wirt des Don Camillo (heute Blazevic).
>
> **✅ Restfragen von Daniel beantwortet (07.08. spätabends) — ALLE 53 FÄLLE
> ABGESCHLOSSEN:** (1) BARacca ← Florian Pagels bestätigt («F. Pagels
> Erlebnis-Gastronomie BARacca», moneyhouse.ch/…/f-pagels-erlebnis-gastronomie-baracca-10975808571)
> → Alias gesetzt; (2) Weissfluhgipfel ← «racine» bestätigt → gesetzt;
> (3) Weissfluhjoch ← «surselva hospitality ag» bestätigt (Joch im Sommer 2026
> zu, neuer Pächter ab Winter — vgl. Kundenmutations-Mails) → gesetzt.
> Einzig offen als Merkposten: Don Camillo [Quarten] — Alias für den heutigen
> Wirt Ivan Blazevic erst setzen, wenn eine Zahlung von ihm auftaucht.
>
> **Kenntnisnahmen:** Löwen [Sins] hat seit ~04/2026 einen neuen Betreiber
> (Urs Peterhans, Landgasthof Löwen GmbH — Almepa-Alias deckt nur die alten
> Zahlungen); Cresta [Flumserberg] (CFB Gastro) evtl. in Liquidation/Übergabe;
> HH Gastro AG (Alpina Schiers) könnte die Helvetia Bar übernommen haben —
> bisher unbelegt, Helvetia behält ihren Haldi-Alias.
>
> **Stand danach: 120 Betriebe mit 132 Zahler-Aliasen** (vor heute: 25).

**Auftrag Daniel:** «Zahlernamen aus den bereits bezahlten Rechnungen bei den
Reinigungen ermitteln (letzte 4 Zahlungen, falls alle gleich automatisch
Zahlername setzen, sonst nachfragen).»

**Methode:** Alle 1'606 Gutschriften ab 01.01.2024 aus der Voll-Historie-camt
(`MX53D…20260620…941625813.xml`) gegen die bezahlten Kundenrechnungen
gematcht — nur **eindeutige** Paare (genau EINE Gutschrift und genau EINE
Rechnung mit identischem Datum + Betrag; Sammel-/Mehrdeutiges bewusst
ausgeschlossen). Pro Betrieb die letzten ≤4 Matches betrachtet.
Arbeitstabellen bleiben als Beleg in Schema `tmp_zahlername`
(`gutschriften`, `vorschlag` mit Klassifikation je Betrieb).

## Ergebnis (138 Betriebe mit Matches)

| Klasse | Anzahl | Aktion |
|---|---:|---|
| **auto** (≥2 Zahlungen, alle gleicher Zahler) | **57** | ✅ Alias gesetzt |
| nachfragen: nur 1 Zahlung gefunden | 32 | Liste unten → Daniel |
| nachfragen: verschiedene Zahler in den letzten 4 | 11 | Liste unten → Daniel |
| nachfragen: Konflikt (Name zeigt auf ≥2 Betriebe) | 10 | Liste unten → Daniel |
| übersprungen: Alias schon vorhanden | 15 | — |
| übersprungen: Sammelzahler/technisch (Goodfast, Weisse Arena, DKB, Schalter…) | 11 | — |
| übersprungen: Zahler = exakter Betriebsname | 2 | — |

**Rollback:** Die 57 automatisch gesetzten Aliase stehen in
`tmp_zahlername.vorschlag WHERE klasse='auto'` (`letzter_name_norm`) — per
`array_remove(zahler_aliase, letzter_name_norm)` rückgängig zu machen.
Pflege einzeln: Chip-Editor im Betrieb-Formular.

## ✅ Automatisch gesetzt (57)

Alpenblick[Arosa]←Blick in die Alpen Gastro AG · Alpina Resort[Tschiertschen]←THE ALPINA MANAGEMENT AG · Bahnhöfli[Chur]←Bahnhöfli Chur GmbH · Blockhuus[Davos]←Gehri Gastronomie GmbH · Bolgen Plaza[Davos]←Bolgen Plaza AG · Cafe Bar[Trimmis]←Vita GmbH · Calanda[Chur]←Gastronomia Chur AG · Caluori[Chur]←Franz Josef Caluori · Casa Giovanoli[Tumegl]←BUENDIA GMBH · Clubhaus FC Landquart←Fussballclub Landquart · Conditorei Fischer[Sursee]←Conditorei Fischer AG · Confetti[Chur]←Telegastro AG · El Gusto[Sargans]←El Gusto Restaurant, Milanovic · Foppa[Flims]←Gastro Foppa AG · Fravi[Andeer]←Hotel Fravi AG · Furt[Wangs]←Hotel Furt AG · Garden Lounge[Sempach]←Green Events + More GmbH · Glenner[Vals]←Priora Suisse AG · Grand Hotel Surselva[Flims]←Service Intersociale Belge ASBL · Hemingway[Chur]←Hemingway - Cafe Basfalianu · Hilton Garden Inn[Davos]←Hotelbetriebe Davos GmbH · Hotel Central am See[Weggis]←VWS Gastro AG · Hotel Sport[Klosters]←Meili Hotels AG · Hugos[Davos]←SCHNEIDER'S RESTAURANT AG · Krone[Churwalden]←Sporthotel Krone Churwalden AG · Kulm[Davos]←KESSLER BETRIEBE AG · Kurhaus Omstal←Restaurant Kurhaus GmbH · Marsöl[Chur]←Restaurant Marsoel GmbH · Mastro Alfonso[Cham]←Mastro Alfonso GmbH · Migros Golfpark Oberkirch←Migros-Genossenschafts-Bund · Montana Stübli[Davos]←Vago Gastro GmbH · Music Bar B70[Küssnacht]←B70 GmbH · Ninos[Lenzerheide]←Ninos Bar, Daniel Federspiel · Ochsen 2[Davos Platz]←JEAN PHILIPPE CHARLES · Parsennhütte[Davos]←Parsennhütte AG · Pizolstübli[Wangs]←Klara Maria Thomann · Raben[Cham]←RR Gourmet GmbH · Robinson Club[Arosa]←Clubhotel Schweiz GmbH · Rössli[Cham]←BeMa Gastro GmbH · Seven Alpina[Klosters]←Breuer & Co. · Sil Plaz[Surcuolm]←Sil Plaz GmbH · Skihütte Selfranga[Klosters]←WISO'S-Gastronomie · Sonne[Neuenkirch]←Sonne Neuenkirch GmbH · Sonne Seehotel[Eich]←Sonne Balance AG · Sportrestaurant Obere Au[Chur]←Stadt Chur · Stadtcafé[Sursee]←Stadtcafe Sursee GmbH · Surselva[Disentis]←Pizzeria Surselva GmbH · Surselva[Chur]←Inferno AG · Swissheidi[Maienfeld]←SWISS HEIDI HOTEL AG · Tell's Pub[Küssnacht]←Tell's Pub, Rene Kunz · The Green Wildmann[Davos Platz]←THE GREEN WILDMAN GMBH · Twelve[Chur]←probar GmbH · Valata[Surcuolm]←C Triple G'N Gastro GmbH · Valserstuba[Avers]←Gastro Latina GmbH · Veltlinerhalle[Domat/Ems]←Restaurant Pizzeria Halla Bufano M. · Vereina[Klosters]←Immovalor Invest AG · Vista[Domat/Ems]←Golf Club Domat/Ems

## ❓ Nachfragen — Konflikte (10; ein Name zeigt auf mehrere Betriebe)

- **HH Gastro AG** → Alpina [Schiers] (4/4) UND Helvetia [Chur] (gemischt) — wem gehört der Zahler?
- **HOTELS BY HR SEEHOF GMBH** → Chesa [Davos Dorf] UND Seehof [Davos] (Sammelzahler für beide? → dann in die Sammelzahler-Liste)
- **Pradaschier AG Top** → Portal [Churwalden] (2/2) UND Cafe Alexanderplatz [Chur] (1)
- **M.M Gastro GmbH** → Giodavin [Davos Platz] UND Steakhouse Ochsen [Davos] (je gemischt)
- **Hotel Alpenblick Weggis AG** → Hotel Alpenblick [Weggis] (4/4) — ⚠️ der Alias liegt aber auf **Alpenblick [Arosa]** (gelernt 15.07.)! Vermutlich falsch gelernt → Alias umhängen?
- **Hotel Lenzerhorn Spa & Wellness AG** → Spescha [Lenzerheide] (4/4) — Alias liegt auf **Lenzerhorn [Lenzerheide]**. Zahlt das Hotel für beide? → Sammelzahler?

## ❓ Nachfragen — verschiedene Zahler in den letzten 4 (11)

Chalet Güggel [Davos] (zuletzt CHALET GUEGGEL AG) · Cresta [Flumserberg] (CFB Gastro GmbH) · Dancing Zur Zinne [Sargans] (Namensvarianten «…Ruparaj»/«…Ru» — wohl gleicher Zahler, gekürzt) · Don Camillo [Quarten] (Restaurant Pizzeria Traube Senti) · Grotto da Elio [Lenzerheide] (Lupiz AG) · Löwen [Maienfeld] (Gastromagia AG) · Obertor [Parpan] («Obertor Bar & Grill»/«Bar . Grill» — Schreibvarianten) · Posthotel [Valbella] (Posthotel Valbella AG) · Steak House [Trübbach] (Renar Gastro GmbH) · Vieri Bar [Cham] (4i Bar / Wanda Elisabeth Andres) · Vincenz [Breil/Brigels] (Hotel Vincenz SA)

*Hinweis: Bei mehreren davon sind es nur Schreibvarianten desselben Zahlers
(Kürzungen der Bank). Wenn Daniel sie bestätigt, setzen wir beide Varianten
als Aliase.*

## ❓ Nachfragen — nur eine Zahlung gefunden (32)

Alpsu←Hotel Alpsu AG · BARacca[Vella]←Florian Pagels · Bernina[Thusis]←Pizzeria Bernina AG · Clubhaus FC Flums←Fussballclub Flums · **Concordia[Davos]←Hotel Edelweiss Davos AG** · Edelweiss[Vals]←M. Gartmann Gastro · Eisstadion Davos←Hockey Club Davos AG · Fondue Beizli[Chur]←ALLEGRA VINUM SA · Frosch Sportclub←Frosch Sportreisen Touristik AG · Gasthaus Löwen[Sins]←Almepa Waser · Gasthaus Michaelskreuz[Root]←Gasthaus Michaelskreuz GmbH · Gentiana[Davos]←STAU DAVOS AG · Getränke Candreja[Ilanz]←Candreja Weine + Getränke AG · Hotel Sportcenter Fünf Dörfer←Hotel Sportcenter Fuenf Doerfer AG · Kaffee und Tee[Küssnacht]←Lüthold Kaffee & Tee GmbH · Kulm[Arosa]←Arosa Kulm-Hotel AG · Milez[Rueras]←Andermatt-Sedrun Sport AG · Pizzeria Tennishalle[Vaduz]←Fratelli Del Vecchio · Protos[Oberkirch]←BENGU GASTRO GmbH · Rätia[Ilanz]←motion GmbH · Schützenhaus[Chur]←Restaurant Schützenhaus Cancarevic · Seeblick[Sufers]←Sophie Bevernage · Sezner←Gipfelrestaurant Sezner Balazs Fojtyik · Silvia Kaufmann's Schlagerbar←Silvia Kaufmann · Tankstelle[Flims]←Flims Gastro GmbH · Tödi[Ilanz]←Calic Josip · Triel[Vella]←Berggastronomie Cebov · Türmli[Sempach]←AO Gastro AG · Villaggio[Root]←DMU VILLAGGIO GMBH · Waldhaus[Valbella]←AG Hotel Waldhaus Valbella · Weissfluhgipfel[Davos]←Racine · Weissfluhjoch[Davos]←Surselva Hospitality AG

*Diese 32 sehen fast alle plausibel aus (Zahler enthält oft den Betriebsnamen
— dann findet sie auch das unscharfe Matching als Vorschlag). Auf Zuruf
Daniel: einzelne oder alle als Alias übernehmen.*
