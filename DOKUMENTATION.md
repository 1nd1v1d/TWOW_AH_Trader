# TWOW AH Trader – Dokumentation

## Übersicht

WoW-Addon für Turtle WoW (1.12.1 vanilla), das AH-Preise von Alchemie-Tränken und deren Zutaten scannt, die Herstellungsmargen berechnet und eine Empfehlung für den profitabelsten Trank ausspricht. Zusätzlich gibt es eine separate Mats-Analyse für frei definierbare Materialien mit historisch gewichteter Preisbewertung. Optional können Zutaten direkt aus dem AH gekauft werden, wobei eine Mindestmarge von 10 % eingehalten wird.

## Dateistruktur

```
TWOW_AH_Trader/
├── TWOW_AH_Trader.toc   – Addon-Metadaten (Interface: 11200)
├── Core.lua              – Hauptobjekt, Events, Slash-Befehle, Persistenz
├── Locales.lua           – Lokalisierung (Deutsch + Englisch)
├── Recipes.lua           – Liest Alchemie-Rezepte aus dem Berufe-Fenster
├── Scanner.lua           – AH-Scan mit Rate-Limiting und Seitenverarbeitung
├── Calculator.lua        – Margen-Berechnung (Kosten, Provision, Deposit, Gewinn)
├── Buyer.lua             – Automatischer AH-Einkauf mit Margenschutz
├── Poster.lua            – Automatisches AH-Posten von Tränken
├── UI.lua                – Scrollbares Ergebnisfenster + Kaufdialog
├── Mats.lua              – Materialverwaltung + Mats-Analyse UI + Mats-Kaufdialog
└── DOKUMENTATION.md      – Diese Datei
```

## Installation

Ordner `TWOW_AH_Trader` nach `World of Warcraft/Interface/AddOns/` kopieren.

### Lokale Deployment-Notiz (TurtleWoW)

Fuer diese Umgebung wird das Addon nach jeder Umsetzung in folgenden Ordner synchronisiert:

`/home/daos/Games/TurtleWoW/Interface/AddOns/TWOW_AH_Trader/`

Zusatz-Workflow:
- Nach jeder Code-Umsetzung wird diese Dokumentation aktualisiert.
- Danach wird der aktuelle Addon-Stand direkt in den obigen AddOns-Ordner kopiert.

## Benutzung

1. **Alchemie-Fenster öffnen** → Addon lädt automatisch alle bekannten Rezepte.
2. **Auktionshaus öffnen** → Buttons "Trank-Analyse" und "Mats Analyse" erscheinen.
3. **Trank-Analyse öffnen** → gespeicherte Ergebnisse ansehen und Rezepte auswählen.
4. **"Scannen" klicken** → AH-Scan für Tränke/Zutaten starten.
5. **Kostendetails einsehen** → Maus über eine Zeile halten (Tooltip).
6. **Zutaten kaufen** → Rechtsklick auf eine profitable Zeile (Kaufdialog).
7. **Mats verwalten** → `/aht mats` öffnen, Materialien hinzufügen/entfernen.
8. **Mats scannen** → im Mats-Fenster ausgewählte Materialien scannen.
9. **Preisabweichungen nutzen** → aktueller Preis vs. gewichteter Durchschnitt.

## Slash-Befehle

| Befehl              | Funktion                                                  |
|---------------------|-----------------------------------------------------------|
| `/aht`              | Ergebnisfenster öffnen (Alias: `/ahtrader`)               |
| `/aht show`         | Ergebnisfenster öffnen (explizit)                         |
| `/aht scan`         | Scan manuell starten (AH muss offen)                     |
| `/aht stop`         | Laufenden Scan oder Kauf abbrechen (Alias: `/aht cancel`) |
| `/aht rezepte`      | Geladene Rezepte im Chat ausgeben (Alias: `/aht recipes`) |
| `/aht mats`         | Materialien-Management Dialog öffnen                       |
| `/aht reset`        | Gespeicherte Preisdaten löschen                           |
| `/aht snipe`        | Schnäppchen-Scan: Alle bekannten Items auf Deals prüfen   |
| `/aht post`         | Hilfe zum Tränke posten anzeigen                          |
| `/aht debug`        | Diagnose-Infos anzeigen                                   |

## UI-Funktionen

### Ergebnisfenster
- **Checkbox** (links): Rezept für den Scan aktivieren/deaktivieren (deaktivierte Rezepte werden gedimmt angezeigt, Daten bleiben sichtbar)
- **Suchfeld** (oben rechts): Filtert die Liste nach Trank-/Elixiername in Echtzeit
- **Sortierbare Spalten**: Klick auf "Gewinn" oder "Marge" sortiert die Tabelle (erneuter Klick kehrt die Richtung um, Pfeil ▲/▼ zeigt Sortierrichtung)
- **Mouseover-Tooltip**: Zeigt detaillierte Kostenaufschlüsselung pro Zutat (mit Durchschnittspreis und Deal-Markierung), Verkaufspreis mit Trend (▲/▼/→), Durchschnittspreis, AH-Listings (Volumen), Provision, Deposit, Gewinn, Marge, Aktualisierung und Inventar-Info
- **Rechtsklick**: Öffnet Kaufdialog für die Zutaten des gewählten Tranks
- **Shift+Rechtsklick**: Postet verfügbare Tränke aus dem Inventar ins AH (mit automatischer Preisberechnung)
- **Deal-Indikator**: Rezepte mit Schnäppchen-Zutaten oder unterbewerteten Tränken werden mit `*` markiert (cyan)
- **"Scannen/Abbrechen"**: Startet oder bricht einen AH-Scan ab
- **"Alle an" / "Alle aus"**: Alle Rezepte aktivieren/deaktivieren
- **Mausrad**: Scrollt durch die Ergebnisliste

### Kaufdialog
- Zeigt alle Zutaten mit Preisen und Quelle (AH/Vendor)
- Eingabefeld für die gewünschte Trank-Anzahl
- Geschätzte Gesamtkosten werden live aktualisiert
- "Kaufen" startet den automatischen AH-Einkauf
- Nach dem Kauf: Zusammenfassung im Chat + Hinweis welche Vendor-Items noch fehlen

### Mats-Analyse Fenster
- Design analog zur Trank-Analyse (gleicher Fensterrahmen, Status-Zeile oben, Buttons unten)
- Status-Zeile oben zeigt Anzahl analysierter Materialien oder Scan-Fortschritt
- Checkbox pro Material für den nächsten Mats-Scan (an/aus)
- Buttons unten: **"Scannen/Abbrechen"** | **"Materialverwaltung"** | **"Alle an"** | **"Alle aus"**
- Scan läuft nur für angehakte Materialien; Scan-Button wechselt auf "Abbrechen" während Scan läuft
- Rechtsklick auf ein Material öffnet den Mats-Kaufdialog
- Spalten: aktueller Preis, gewichteter Durchschnitt, Abweichung, Listings, Scans
- In der Materialspalte wird hinter dem Namen das letzte Scan-Datum mit Uhrzeit angezeigt

### Material-Management Dialog
- Öffnen über `/aht mats`
- Materialname manuell eingeben und hinzufügen
- Kategorie pro Material per Dropdown auswählbar (Waffe, Rüstung, Behaelter, Verbrauchbar, Handwerkswaren, Projektil, Koecher, Rezept, Reagenz, Verschiedenes)
- Wenn keine Kategorie gesetzt ist, scannt das Addon über alle Kategorien
- Materialien per Checkbox markieren und gesammelt entfernen (**Auswahl entfernen**)
- Änderung wird persistent gespeichert
- Änderungen werden sofort im offenen Mats-Fenster sichtbar (kein Neuöffnen nötig)

## Rezepterkennung

Das Addon erkennt den Alchemie-Beruf in folgenden Lokalisierungen:

- **Alchemy** (Englisch / Turtle WoW Standard)
- **Alchemie** (Deutsch)
- **Alchimie** (Französisch)
- **Alchimia** (Italienisch)
- **Alquimia** (Spanisch)

Beim Öffnen des Berufe-Fensters (`TRADE_SKILL_SHOW`) werden alle Nicht-Header-Einträge mit Reagenzien als Rezepte gespeichert. Duplikate werden automatisch gefiltert.

## Berechnungslogik

### Preisermittlung
- Alle Preise basieren auf dem **günstigsten Buyout pro Stück** (Sofortkauf)
- Gestackte Items werden auf den Stückpreis heruntergerechnet: `buyoutPrice / count`
- **Vendor-Items** (Phiolen) nutzen feste Preise, werden nicht im AH gescannt

### Vendor-Preise (fest hinterlegt)

| Phiole                                 | Preis       |
|----------------------------------------|-------------|
| Kristallphiole / Crystal Vial          | 18c         |
| Leere Phiole / Empty Vial              | 1c          |
| Gesprungene Phiole / Leaded Vial       | 1s 80c      |
| Besudelte Phiole / Imbued Vial         | 22s 50c     |
| Geschmolzene Phiole / Enchanted Vial   | 2g 70s      |

### Spalten im Ergebnisfenster

| Spalte            | Berechnung                                                   |
|-------------------|--------------------------------------------------------------|
| **Kosten**        | Summe aller Zutatenpreise (AH + Vendor) pro Stück            |
| **Verkaufspreis** | Günstigster aktueller Buyout des Tranks pro Stück            |
| **AH-Gebühr**    | 5 % AH-Provision + Deposit (24h)                             |
| **Gewinn**        | Verkaufspreis – AH-Gebühr – Zutatenkosten (sortierbar ▲▼)     |
| **Marge**         | Gewinn / Zutatenkosten × 100 % (sortierbar ▲▼)               |
| **Aktualisiert**  | Ältester Zeitstempel aller Zutaten/Trank (DD.MM HH:MM)      |

### Deposit-Berechnung (24h Auktion)
Formel basierend auf aux-addon:
```
deposit = floor(vendorSellPrice × (1440/120) × (1 + (maxStack-1) × 0.05) × 0.025)
        = floor(vendorSellPrice × 0.36)
```
Da der Vendor-Verkaufspreis nicht per API abfragbar ist, wird er als ~2 % des AH-Preises geschätzt.

### Farbschema

- **Grün**: Marge ≥ 20 % (empfohlen)
- **Gelb**: Marge 0–20 %
- **Rot**: Verlust
- **Cyan `*`**: Deal – aktueller Preis deutlich unter Durchschnitt (≥ 20 % günstiger)
- **Dunkelgrau**: Rezept deaktiviert (Daten werden gedimmt angezeigt)
- **Grau**: Fehlende Daten / nicht im AH

## Automatischer Zutateneinkauf

### Ablauf
1. Rechtsklick auf einen profitablen Trank → Kaufdialog öffnet sich
2. Gewünschte Anzahl Tränke eingeben → "Kaufen" klicken
3. Das Addon durchsucht das AH nacheinander nach jeder Zutat
4. Nur Angebote werden gekauft, bei denen die **Marge ≥ 10 % bleibt**
5. Phiolen und andere Vendor-Items werden übersprungen (beim Händler günstiger)
6. Am Ende: Zusammenfassung im Chat mit gekauften/fehlenden Items

## Material-Analyse (Mats)

Die Material-Analyse ermöglicht es, beliebige Materialien zu überwachen und deren Preisabweichungen vom gewichteten Durchschnitt zu verfolgen.

### Funktionsweise

1. **Materialien hinzufügen**: `/aht mats` öffnet den Management-Dialog.
   - Item-Namen eingeben und "Hinzufügen" klicken.
   - Optional eine Kategorie im Dropdown wählen, um den Scan zu beschleunigen.
   - Materialien können später wieder entfernt werden.

2. **Materialien scannen**: "Mats Analyse" Button im AH-Fenster
   - Nur angehakte Materialien werden gescannt.
   - Preis pro Stück wird erfasst.
   - Mit gesetzter Kategorie wird gezielt in dieser Kategorie gesucht.

3. **Gewichtete Durchschnittsberechnung**:
   - Der historische Mittelwert wird mit zeitbasiertem Gewicht berechnet.
   - **Neuere Scans** haben mehr Einfluss (höheres Gewicht).
   - **Ältere Scans** haben weniger Einfluss.
   - **Scans älter als 60 Tage** werden nicht mehr berücksichtigt.

4. **Abweichungsanzeige**:
   - Zeigt die Differenz zwischen aktuellem Preis und gewichtetem Durchschnitt.
   - **Grün**: -20% oder mehr (günstiges Angebot).
   - **Gelb**: -20% bis +20% (normaler Preis).
   - **Rot**: +20% oder mehr (teuer).
   - Anzeige erfolgt mit Nachkommastelle (z. B. `+0.8%`) statt nur ganzzahlig.
   - Falls aktuell kein AH-Preis vorhanden ist, wird die Abweichung als `-100.0%` dargestellt.

### UI-Spalten

| Spalte | Bedeutung |
|--------|-----------|
| **Material** | Name des Rohstoffs/Materials |
| **Aktuell** | Günstigster Buyout im AH (pro Stück) |
| **Gewicht. Avg** | Gewichteter Durchschnitt der letzten 60 Tage |
| **Abweichung** | +/- Prozentuale Differenz zum Durchschnitt |
| **Listings** | Anzahl Angebote im AH |
| **Scans** | Anzahl erfasster Preispunkte in der Historie |

### Material-Kauf

- **Rechtsklick** auf ein Material öffnet den Kaufdialog (Design analog zum "Zutaten kaufen"-Dialog der Trank-Analyse)
- Gewünschte Menge eingeben
- Optional: **Max. Abweichung (%)** festlegen (negative und positive Werte möglich)
   - Positive Werte: Kaufe bis zu X % unter dem Weighted-Avg (z. B. `10` = `-10%`)
   - Negative Werte: Erlaubt höhere Preise (z. B. `-5` = bis zu `+5%` über Weighted-Avg)
   - Der angezeigte **Max Kaufpreis** aktualisiert sich sofort auf Basis dieser Eingabe
- Anzeige im Dialog:
   - Geschätzte Gesamtkosten
   - **Ø Kaufpreis**
   - **Max Kaufpreis**
- **Veraltete Daten (>10 Minuten)**: Roter Warnhinweis erscheint + "Neu scannen"-Button
   - "Neu scannen" scannt **nur das aktuell ausgewählte Material** (nicht alle)
   - Nach abgeschlossenem Scan wird der Kaufdialog automatisch mit neuen Preisen aktualisiert
   - Während des Scans ist der Button deaktiviert
- **Kaufen** startet den Mats-Kauf-Workflow (unabhängig vom Trank-Buyer)
- Kein automatischer Rescan mehr beim Kauf – der Nutzer entscheidet aktiv
- Einkauf erfolgt aus den **günstigsten verfügbaren Angeboten zuerst** (nach Stückpreis)

### Gewichtungsformel

```
weight = max(0, 1 - (alter_in_tagen / 60))
gewichteter_durchschnitt = Sum(preis * gewicht) / Sum(gewicht)
```

Beispiel:
- Scan von heute: Gewicht = 1.0 (voll wirksam)
- Scan von 30 Tagen: Gewicht = 0.5 (halbgewicht)
- Scan von 60+ Tagen: Gewicht = 0.0 (keine Auswirkung)

### Margenschutz
Für jede Zutat wird ein maximaler Stückpreis (`maxPPU`) berechnet:
```
maxIngredCost = floor((sellPrice - ahProvision - deposit) / 1.10)
maxPPU        = (maxIngredCost - kostenAndererZutaten) / benötigteMenge
```
Nur AH-Angebote mit `ppu ≤ maxPPU` werden gekauft. Zu teure Angebote werden übersprungen.

### Sicherheitsfeatures
- Prüfung ob genug Gold vorhanden
- Eigene Auktionen werden nicht gekauft
- Nur 1 Kauf pro AH-Update-Zyklus (verhindert Doppelkäufe)
- Abbruch jederzeit mit `/aht stop` möglich
- Bestätigung via `ERR_AUCTION_BID_PLACED` Event

### Buyer-Zustandsautomat

```
idle → searching → buying → (nächstes Item oder nächste Seite)
           ↑          ↓
           └──────────┘
                ↓
           idle (fertig / abgebrochen)
```

- **idle**: Kein Kaufvorgang aktiv
- **searching**: Wartet auf `CanSendAuctionQuery()` (0,4 s Intervall)
- **buying**: `QueryAuctionItems` gesendet, verarbeitet Angebote
- Timeout nach 12 s → nächste Zutat
- Nur 1 Kauf pro Update-Zyklus (`buyLocked` Schutz)
- Lock wird nach `ERR_AUCTION_BID_PLACED` gelöst
- **Inventar-Check**: Vor dem Kauf wird das Inventar geprüft; bereits vorhandene Zutaten werden abgezogen

## Poster-Zustandsautomat

```
idle → splitting → split_wait → placing → confirming → (nächster Stack) → idle (fertig)
```

- **idle**: Kein Postvorgang aktiv
- **splitting**: Sucht einen passenden Stack in den Taschen. Wenn ein Stack mit exakt der gewünschten Größe existiert, wird er direkt verwendet. Andernfalls wird via `SplitContainerItem(bag, slot, count)` in einen leeren Taschenslot aufgeteilt (Bag-to-Bag-Split nach aux-addon-Muster)
- **split_wait**: Pollt den Ziel-Slot (0,1 s Intervall) bis die korrekte Itemanzahl vorhanden ist (max 3 s Timeout). Erst wenn der Split abgeschlossen ist, wird fortgefahren
- **placing**: Platziert das Item im AH-Sell-Slot nach dem aux-addon-Muster: `ClearCursor → ClickAuctionSellItemButton → ClearCursor → PickupContainerItem(bag, slot) → ClickAuctionSellItemButton → ClearCursor`
- **confirming**: Pollt `GetAuctionSellItemInfo()` (0,2 s Intervall) bis das Item im Sell-Slot erkannt wird (max 3 s Timeout), dann `StartAuction()` aufrufen
- Pro Stack wird ein separater Auktionseintrag erstellt
- Preisberechnung: Aktueller AH-Preis − 1c Undercut, mindestens Zutatenkosten × 1,05, Fallback ohne AH-Preis: Kosten × 1,20
- Deposit wird vor dem Posten geprüft (Goldcheck)
- Abbruch jederzeit mit `/aht stop`

### Post-Dialog

Beim Shift+Rechtsklick auf einen Trank öffnet sich ein Dialog mit:

- **Trankname** und Anzahl in den Taschen
- **Berechneter Preis** pro Stück (Undercut oder Markup)
- **Stackgröße**: Eingabefeld + Preset-Buttons (1, 5, 10, 20)
- **Stacks**: Maximale Anzahl Auktionen (leer = alle)
- **Ergebnis-Vorschau**: Zeigt `→ X Auktionen (Y Stück)` live
- **Preis prüfen**: Scannt den aktuellen AH-Preis des Tranks und zeigt Differenz zum Post-Preis. Wenn der aktuelle AH-Preis günstiger ist, wird der Post-Preis automatisch auf einen neuen Undercut aktualisiert
  - Grün: „X günstiger als AH" (ggf. nach automatischer Preiskorrektur)
  - Gelb: „Gleicher Preis"

Die Stacks werden via Bag-to-Bag-Split aufgeteilt (nach aux-addon-Muster): `SplitContainerItem` teilt in einen leeren Taschenslot, der Ziel-Slot wird gepollt bis die korrekte Menge vorhanden ist, dann wird der fertige Stack ins AH platziert. Ein 20er-Stack wird z.B. in 4×5er Auktionen gepostet.

## Schnäppchen-Scanner (Sniper)

- Erkennt Items deren aktueller AH-Preis ≥ 20 % unter dem historischen Durchschnitt liegt
- **Passive Erkennung**: Während normaler Scans werden Deals automatisch erkannt und im Chat gemeldet
- **Aktiver Snipe-Scan** (`/aht snipe`): Scannt alle historisch bekannten Items (nicht nur aktive Rezepte)
- Deal-Chat-Meldung zeigt den Rabatt in Prozent: `★ Itemname: Preis (Avg: X, -Y%)`
- In der Ergebnisliste sind Deal-Rezepte mit `*` markiert

## Scanner-Zustandsautomat

```
idle → waiting → sent → (nächstes Item oder nächste Seite)
         ↑        ↓ (Timeout → Retry, max 2×)
         └────────┘
              ↓
         idle (fertig / abgebrochen)
```

- **idle**: Kein Scan aktiv
- **waiting**: Wartet auf `CanSendAuctionQuery()` (0,3 s Intervall)
- **sent**: `QueryAuctionItems` gesendet, wartet auf `AUCTION_ITEM_LIST_UPDATE`
- Timeout nach 15 s → Retry (max 2×), dann übersprungen
- Scan kann jederzeit abgebrochen werden (`/aht stop` oder Button)

## Technische Einschränkungen (vanilla 1.12.1 / Lua 5.0)

- Kein `print()` – stattdessen `DEFAULT_CHAT_FRAME:AddMessage()`
- Kein `#table` Operator – stattdessen `getn(table)` (Lua 5.0)
- Kein `%` Modulo-Operator – stattdessen `mod(a, b)` (Lua 5.0)
- Kein `string.match()` – stattdessen `strfind()` mit Captures
- Kein `string.gmatch()` – stattdessen `string.gfind()`
- `GetItemInfo()` hat nur 10 Rückgabewerte (kein vendorPrice)
- Event-Handler nutzen globale `event`, `arg1`–`arg9` statt Parameter
- In SetScript-Callbacks: `this` statt `self` für den aktuellen Frame
- Globale Aliase bevorzugen: `strlower`, `strfind`, `tinsert`, `getn`, `mod`
- `table.insert` → `tinsert`, `table.remove` → `tremove`
- `RegisterForClicks` / `OnClick` nur auf Button-Frames, nicht auf Frames
- Kein `GetAuctionDeposit()` – Deposit muss manuell berechnet werden

## Lokalisierung

Das Addon unterstützt **Deutsch** und **Englisch**. Die Sprache wird automatisch anhand von `GetLocale()` erkannt:

| Client-Locale | UI-Sprache |
|---------------|------------|
| `deDE`        | Deutsch    |
| alle anderen  | Englisch   |

Alle UI-Strings (Spaltenheader, Buttons, Tooltips, Chat-Nachrichten, Slash-Hilfe, Kaufdialog) sind in `Locales.lua` definiert. Die Kernlogik (Scan, Kauf, Posting) ist sprachunabhängig – Item-Namen kommen dynamisch von der WoW-API.

Zum Hinzufügen einer neuen Sprache: In `Locales.lua` einen weiteren `if locale == "frFR" then ... end` Block ergänzen.

## Persistenz

SavedVariable `TWOW_AHT_DB` speichert:
- `prices` – Tabelle `[itemName] = günstigster Buyout in Kupfer (pro Stück)`
- `recipes` – Array der erkannten Rezepte mit Reagenzien
- `selected` – Tabelle `[recipeName] = true/false` (welche Rezepte aktiv sind)
- `priceUpdated` – Tabelle `[itemName] = Unix-Timestamp` (wann der Preis zuletzt gescannt wurde)
- `priceHistory` – Tabelle `[itemName] = { {t=timestamp, p=price}, ... }` (letzte 20 Preiseinträge pro Item)
- `listingCounts` – Tabelle `[itemName] = Anzahl` (AH-Listings bei letztem Scan)
- `materials` – Tabelle `[itemName] = true` (verwaltete Materialliste)
- `matsSelected` – Tabelle `[itemName] = true/false` (Material im nächsten Mats-Scan aktiv)
- `matsCategories` – Tabelle `[itemName] = categoryId` (optionaler Kategorien-Filter pro Material)
- `matsHistory` – Tabelle `[itemName] = { {t=timestamp, p=price, weighted_avg=...}, ... }` (Mats-Historie)

## Änderungsprotokoll

### v1.6.0 – 2026-04-09
**Mats-Analyse + Materialverwaltung + gewichtete Historie:**
- Neuer AH-Button **Mats Analyse** (separat zur Trank-Analyse)
- Neues Modul **Mats.lua** für Mats-UI, Management-Dialog und Mats-Kaufdialog
- Materialien können über `/aht mats` hinzugefügt/entfernt werden
- Eigene Mats-Liste mit Auswahl pro Material (Checkbox an/aus)
- **Alle an / Alle aus** für Mats-Auswahl ergänzt
- Mats-Scan mit AH-Seitenverarbeitung und Timeout-/Retry-Logik
- Optionaler Kategorien-Filter pro Material (Dropdown im Management-Dialog)
- Ohne Kategorie: Scan über alle Kategorien
- Historischer Mittelwert als **zeitgewichteter Durchschnitt**
- Scans älter als **60 Tage** gehen nicht mehr in den Durchschnitt ein
- Abweichungsanzeige aktueller Preis vs. gewichteter Durchschnitt (farblich markiert)
- Abweichungsanzeige auf Dezimalstellen umgestellt (verhindert dauerhafte `0%` Anzeige bei kleinen Preisänderungen)
- Gewichteter Vergleich ohne Selbst-Beeinflussung durch den aktuellen Preis
- Materialname zeigt letztes Scan-Datum mit Uhrzeit in der Mats-Liste
- Mats-Kaufdialog integriert; Kaufausführung nutzt den bestehenden Buyer-Workflow
- Rechtsklick-Kauf in der Mats-Liste aktiv (Row-RightClick registriert)
- Management-Dialog: Mehrfach-Entfernen per Checkbox ("Auswahl entfernen")
- Persistenz um `materials`, `matsSelected`, `matsCategories`, `matsHistory` erweitert
- Mats-Kauf erweitert:
   - eigener Kauf-State (nicht Trank-Buyer-Reuse)
   - 5-Minuten-Rescan vor Kauf bei veralteten Daten
   - günstigste Angebote zuerst (Stückpreis-Sortierung)
   - Deviation-Limit im Dialog (nie über Weighted-Avg)
   - Dialog zeigt Ø/Max-Kaufpreis für die gewünschte Menge

### v1.5.0 – 2026-04-03
**Robustheit, Performance, UX-Verbesserungen:**
- **AH-Closed-Handler**: Alle laufenden Operationen (Scan, Kauf, Post, Preischeck) werden automatisch abgebrochen wenn das Auktionshaus geschlossen wird
- **Buyer-Zähler nach Bestätigung**: `bought`-Zähler wird erst nach `ERR_AUCTION_BID_PLACED` erhöht (vorher sofort nach `PlaceAuctionBid`, führte zu falschen Zusammenfassungen)
- **Fehlgeschlagene Bids**: `UI_ERROR_MESSAGE` Event gibt `buyLocked` sofort frei (vorher 12s Stall bei Fehlern)
- **Waiting-State-Timeouts**: Scanner und Buyer haben jetzt 30s-Timeouts im `waiting`/`searching`-Zustand (verhindert endloses Polling)
- **Scanner filtert eigene Auktionen**: `owner ~= UnitName("player")` im Scanner (vorher nur im Buyer), verhindert verfälschte Preisdaten
- **`listingCounts` persistiert**: Listing-Zahlen werden jetzt in `SavedVariables` gespeichert und nach Reload wiederhergestellt
- **Rezept-Retry begrenzt**: Max 3 Retry-Versuche für fehlende Reagenzien im Cache (vorher keine Begrenzung)
- **`GetTradeSkillReagentItemLink` gesichert**: API-Aufruf nur wenn Funktion existiert (Kompatibilität mit Servern ohne diese API)
- **Preischeck-Timeout**: 10s Timeout für den AH-Preischeck im Post-Dialog (Button wurde bei verlorenen Queries dauerhaft deaktiviert)
- **OnUpdate optimiert**: Zustandsautomat-Handler werden nur aufgerufen wenn aktiv (vorher jedes Frame ~60x/s)
- **UI-Zeitstempel optimiert**: `lastScanLabel` wird nur 1x/Sekunde aktualisiert statt jeden Frame
- **Lokalisierte Datumsformate**: DD.MM für Deutsch, MM/DD für Englisch (Spalte + Tooltip)
- **Gold-Warnung im Kaufdialog**: Zeigt „Nicht genug Gold!" wenn geschätzte Kosten das verfügbare Gold übersteigen
- **Toter Code entfernt**: `sortKey`-Feld aus Calculator.lua entfernt (wurde nie ausgelesen)
- **Undurchsichtige Fenster**: Alle drei Frames (Haupt, Kauf, Post) nutzen `ChatFrameBackground`-Texture mit solid-schwarzem Hintergrund (0.07 Grau) statt halbtransparentem `UI-DialogBox-Background`
- Version auf 1.5.0 erhöht

### v1.4.0 – 2026-04-03
**Auto-Post, Inventar-Check, Preisverlauf, Volumen, Schnäppchen-Scanner:**
- **Auto-Post (Poster.lua)**: Tränke aus dem Inventar per Shift+Rechtsklick ins AH posten mit automatischer Preisberechnung (Undercut um 1c, Minimum: Kosten × 1,05)
- **Inventar-Check**: Vor dem Zutaten-Kauf werden vorhandene Items in den Taschen geprüft und von der Kaufmenge abgezogen
- **Preisverlauf**: Historische Preise (letzte 20 Scans) werden gespeichert, Durchschnittspreis und Trend (▲ steigend / ▼ fallend / → stabil) berechnet
- **Marktvolumen**: Anzahl der AH-Listings pro Item wird beim Scan erfasst und im Tooltip angezeigt
- **Schnäppchen-Scanner**: Items mit ≥ 20 % Rabatt vs. Durchschnitt werden als Deal erkannt, im Chat gemeldet und in der Liste mit `*` markiert
- **Snipe-Scan** (`/aht snipe`): Scannt alle historisch bekannten Items auf aktuelle Schnäppchen
- Erweiterter Tooltip: Durchschnittspreis, Trendpfeil, Volumen, Inventar-Info, Deal-Indikatoren bei Zutaten
- Slash-Befehle: `/aht snipe` und `/aht post` hinzugefügt
- `priceHistory` und `listingCounts` werden persistent gespeichert
- `NEW_AUCTION_UPDATE` Event für Poster-Modul registriert
- Poster-Zustandsautomat: `idle → splitting → split_wait → placing → confirming → idle` (aux-addon Bag-to-Bag-Split-Muster)
- **Zweiphasen-Kauf**: Buyer scannt erst alle AH-Seiten nach günstigstem Stückpreis, kauft dann gezielt (verhindert überteuerte Einzelstücke vor günstigen Stacks)
- **Lokalisierung (Locales.lua)**: Automatische Spracherkennung via `GetLocale()`, Deutsch (deDE) + Englisch (alle anderen)
- Alle UI-Strings über `AHT.L["key"]` statt hardcoded
- **Bugfix**: `GetAuctionDeposit()` existiert nicht in vanilla 1.12.1 – durch manuelle Berechnung ersetzt
- **Post-Dialog**: Shift+Rechtsklick öffnet Dialog mit Stackgröße (1/5/10/20), Stackanzahl, Preis-Vorschau und Live-AH-Preisabfrage
- **Preis prüfen**: Button im Post-Dialog scannt aktuellen AH-Preis und zeigt Differenz zum berechneten Post-Preis. Bei günstigerem AH-Preis wird der Post-Preis automatisch auf neuen Undercut korrigiert
- **Stack-Splitting**: `SplitContainerItem` für beliebige Stackgrößen beim Posten (Bag-to-Bag nach aux-addon-Muster)
- **Bugfix**: Poster-Confirming nutzt jetzt Polling statt Event-basiert (verhindert verpasste `NEW_AUCTION_UPDATE` Events)
- **Bugfix**: Spaltenüberschriften in englischer Lokalisierung fehlten (FontStrings wurden vor Locale-Init erstellt, jetzt verzögertes Update)
- **Bugfix**: Reagenzien-Erkennung verbessert – Fallback auf `GetTradeSkillReagentItemLink` wenn `GetTradeSkillReagentInfo` keinen Namen liefert (Item-Cache), automatischer Retry nach 1 Sekunde

### v1.3.0 – 2026-04-03
**Suchfeld, Sortierung, Aktualisierungszeitpunkt, Datenanzeige:**
- **Suchfeld**: Echtzeit-Namensfilter im Ergebnisfenster (oben rechts), zeigt "X/Y Rezepte (Filter aktiv)"
- **Sortierbare Spalten**: Klick auf "Gewinn" oder "Marge" Header sortiert die Tabelle, erneuter Klick kehrt die Richtung um (v/^-Indikator)
- **Aktualisiert-Spalte**: Zeigt Datum+Uhrzeit (DD.MM HH:MM) des ältesten Zutatenzeitpunkels pro Rezept
- **Daten immer sichtbar**: Deaktivierte Rezepte zeigen jetzt alle Preisinfos gedimmt statt "-"
- `priceUpdated`-Tabelle in SavedVariables für persistente Zeitstempel
- `ApplyFilterAndSort()` in Calculator.lua für Filter+Sortierung
- `displayResults`-Array trennt Anzeige von Rohdaten
- Frame-Breite auf 780px erhöht für neue Spalte
- Empfehlung sucht jetzt den tatsächlich besten Trank (nicht nur den ersten)
- **Bugfix: Veraltete Preise**: Items die beim Scan nicht mehr im AH sind, werden jetzt korrekt als „nicht im AH" markiert (alter Preis wird gelöscht statt beibehalten)

### v1.2.0 – 2026-04-03
**Automatischer Zutateneinkauf + Kostendetails:**
- **Neues Modul Buyer.lua**: Kauf-Zustandsautomat für automatischen AH-Einkauf
- **Margenschutz**: Mindestmarge von 10 % wird eingehalten (maxPPU-Berechnung)
- **Detail-Tooltip**: Mouseover zeigt Kostenaufschlüsselung pro Zutat (Name, Stückpreis, Quelle, Gesamt)
- **Rechtsklick-Kaufdialog**: Trank auswählen, Anzahl eingeben, automatisch kaufen
- **Vendor-Items werden übersprungen** beim Kauf (Phiolen beim Händler günstiger)
- **Zusammenfassung nach Kauf** im Chat: gekaufte Items + fehlende Vendor-Items
- `FormatMoneyPlain()` für Tooltip-Texte ohne Color-Codes
- `costDetails`-Array in Calculator für Zutatenaufschlüsselung
- `CHAT_MSG_SYSTEM` Event für Kaufbestätigung (`ERR_AUCTION_BID_PLACED`)
- `/aht stop` bricht jetzt auch laufende Käufe ab
- Zeilen sind jetzt Button-Frames (für Rechtsklick-Support)

### v1.1.0 – 2026-04-03
**Rezeptauswahl, Scan-Abbruch, Vendor-Preise, Timeout-Fix:**
- **Rezeptauswahl**: Checkboxen pro Rezept (an/aus), "Alle an"/"Alle aus"-Buttons
- **Scan-Abbruch**: "Scannen"/"Abbrechen"-Toggle-Button + `/aht stop`
- **Vendor-Preise**: Phiolen mit festen Preisen hinterlegt (DE+EN), werden nicht gescannt
- **CanSendAuctionQuery()**: Prüft ob AH bereit ist bevor Query gesendet wird (behebt Timeouts)
- **Retry-Logik**: Max 2 Retries pro Item, 15 s Timeout
- **Deposit-Berechnung**: Einzahlungsgebühr basierend auf aux-addon Formel (24h, Stack 1, maxStack 5)
- **Empfehlung** berücksichtigt nur aktive (ausgewählte) Rezepte
- Deaktivierte Rezepte werden ausgegraut dargestellt
- Persistenz speichert jetzt auch `selected`-Tabelle

### v1.0.3 – 2026-04-03
**Crash-Fix beim Öffnen des Alchemie-Fensters:**
- `TRADE_SKILL_UPDATE` Event entfernt (feuert dutzende Male beim Öffnen → Crash)
- `GetTradeSkillItemLink()` durch `GetTradeSkillInfo()` skillName ersetzt (Batch-Aufruf von ItemLink über alle Skills überlastet den Client)
- Re-Entry-Guard in `LearnRecipes()` hinzugefügt
- Nur `TRADE_SKILL_SHOW` wird noch verwendet (feuert einmal beim Öffnen)

### v1.0.2 – 2026-04-03
**Komplette Lua 5.0 Kompatibilität (basierend auf aux-addon Analyse):**
- Alle `#table` Operatoren → `getn(table)` (25 Stellen, `#` existiert nicht in Lua 5.0 = Parse-Fehler)
- Alle `%` Modulo-Operatoren → `mod(a, b)` (4 Stellen, `%` als Arithmetik-Op existiert nicht in Lua 5.0)
- `string.lower()` → `strlower()`, `string.find()` → `strfind()` (vanilla Globals)
- `table.insert()` → `tinsert()` (vanilla Global)
- Upvalue-Referenzen in SetScript → `this` (vanilla Pattern für Frame-Referenz)
- Inline `and/or` Ternary-Ketten aufgelöst (Lua 5.0 Kompatibilität)
- Version auf 1.0.1 erhöht

### v1.0.1 – 2026-04-03
**Bugfixes für Turtle WoW Kompatibilität:**
- `Interface: 11900` → `11200` (vanilla 1.12.1 korrekt)
- Alle `print()` Aufrufe entfernt (existiert nicht in vanilla Lua)
- `string.match()` → `string.find()` in Recipes.lua (Lua 5.0)
- `GetItemInfo()` vendorPrice-Zugriff entfernt (nur 10 Rückgabewerte in vanilla)
- Nil-Guard für OnUpdate Handler hinzugefügt
- Leeres Author-Feld in TOC gefüllt

### v1.0.0 – Erstversion
- AH-Scan für Tränke und Zutaten
- Margen-Berechnung mit AH-Provision
- Scrollbares Ergebnisfenster mit Empfehlung
- Rezept-Erkennung aus dem Alchemie-Fenster
- Persistente Preisspeicherung via SavedVariables
