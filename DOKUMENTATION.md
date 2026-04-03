# TWOW AH Trader – Dokumentation

## Übersicht

WoW-Addon für Turtle WoW (1.12.1 vanilla), das AH-Preise von Alchemie-Tränken und deren Zutaten scannt, die Herstellungsmargen berechnet und eine Empfehlung für den profitabelsten Trank ausspricht. Optional können Zutaten direkt aus dem AH gekauft werden, wobei eine Mindestmarge von 10 % eingehalten wird.

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
└── DOKUMENTATION.md      – Diese Datei
```

## Installation

Ordner `TWOW_AH_Trader` nach `World of Warcraft/Interface/AddOns/` kopieren.

## Benutzung

1. **Alchemie-Fenster öffnen** → Addon lädt automatisch alle bekannten Rezepte
2. **Auktionshaus öffnen** → Button "Trank-Analyse" erscheint am oberen Rand des AH-Fensters
3. **Button klicken** → Ergebnisfenster öffnet sich (zeigt letzte gespeicherte Preisdaten)
4. **"Scannen" klicken** → AH-Scan startet, aktuelle Preise werden abgefragt
5. **Rezepte auswählen** → Checkboxen in der Ergebnisliste an/aus schalten
6. **Kostendetails einsehen** → Maus über eine Zeile halten (Tooltip)
7. **Zutaten kaufen** → Rechtsklick auf eine profitable Zeile → Kaufdialog
8. Alternativ: `/aht` oder `/ahtrader` im Chat

## Slash-Befehle

| Befehl              | Funktion                                                  |
|---------------------|-----------------------------------------------------------|
| `/aht`              | Ergebnisfenster öffnen (Alias: `/ahtrader`)               |
| `/aht show`         | Ergebnisfenster öffnen (explizit)                         |
| `/aht scan`         | Scan manuell starten (AH muss offen)                     |
| `/aht stop`         | Laufenden Scan oder Kauf abbrechen (Alias: `/aht cancel`) |
| `/aht rezepte`      | Geladene Rezepte im Chat ausgeben (Alias: `/aht recipes`) |
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

## Änderungsprotokoll

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
- **Undurchsichtige Fenster**: Alle drei Frames (Haupt, Kauf, Post) haben jetzt einen schwarzen undurchsichtigen Hintergrund
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
