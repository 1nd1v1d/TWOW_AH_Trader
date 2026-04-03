-- ============================================================
-- TWOW AH Trader - Locales.lua
-- Lokalisierung: Deutsch (Standard) + Englisch
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
--
-- Verwendung: local L = TWOW_AHT.L
--             L["key"]
-- ============================================================

local AHT = TWOW_AHT

-- ── Standard-Sprache: Deutsch ────────────────────────────────
local L = {}
AHT.L = L

-- Core / Allgemein
L["addon_loaded"]           = "v%s geladen. /aht fuer Hilfe."
L["price_data_reset"]       = "Preisdaten zurueckgesetzt."
L["post_hint"]              = "Rechtsklick + Shift auf einen Trank im Ergebnisfenster zum Posten."
L["no_recipes_loaded"]      = "Keine Rezepte geladen. Oeffne das Alchemie-Fenster!"
L["recipes_loaded_count"]   = "%d geladene Alchemie-Rezepte:"
L["recipes_loaded_msg"]     = "%d Alchemie-Rezepte geladen. Oeffne jetzt das AH und klicke 'Trank-Analyse'."
L["recipe_disabled_tag"]    = "[AUS]"

-- Core / Debug
L["debug_version"]          = "Version: %s"
L["debug_recipes"]          = "Rezepte geladen: %d"
L["debug_prices"]           = "Preise gespeichert: %d"
L["debug_vendor"]           = "Vendor-Items: %d"
L["debug_ui"]               = "UI-Frame: %s"
L["debug_scan"]             = "Scan-Status: %s"
L["debug_ui_ok"]            = "OK"
L["debug_ui_error"]         = "|cffff4444FEHLER|r"

-- Core / Slash-Hilfe
L["help_show"]              = "/aht show    - Ergebnisfenster oeffnen"
L["help_scan"]              = "/aht scan    - AH-Scan starten (AH muss offen sein)"
L["help_snipe"]             = "/aht snipe   - Schnaeppchen-Scan (alle bekannten Items)"
L["help_stop"]              = "/aht stop    - Scan, Kauf oder Posting abbrechen"
L["help_reset"]             = "/aht reset   - Gespeicherte Preise loeschen"
L["help_recipes"]           = "/aht rezepte - Geladene Rezepte anzeigen"
L["help_debug"]             = "/aht debug   - Diagnose-Infos anzeigen"
L["help_actions"]           = "Rechtsklick = Zutaten kaufen | Shift+Rechtsklick = Posten"

-- Scanner
L["scan_button"]            = "Trank-Analyse"
L["scan_cancel"]            = "Abbrechen"
L["scan_tooltip_cancel"]    = "Klicken um Scan abzubrechen"
L["scan_tooltip_open"]      = "Oeffnet die Trank-Analyse."
L["scan_tooltip_last"]      = "Zeigt Ergebnisse des letzten Scans."
L["scan_tooltip_no_recipes"] = "|cffff4444Oeffne zuerst das Alchemie-Fenster!|r"
L["scan_tooltip_ready"]     = "|cff00ff00%d Rezepte bereit.|r"
L["scan_no_active"]         = "Kein Scan aktiv."
L["scan_cancelled"]         = "|cffffff00Scan abgebrochen.|r"
L["scan_already_running"]   = "Scan laeuft bereits! /aht stop zum Abbrechen."
L["scan_ah_required"]       = "Das Auktionshaus muss geoeffnet sein!"
L["scan_no_recipes"]        = "Keine Rezepte geladen! Oeffne zuerst das Alchemie-Fenster."
L["scan_no_items"]          = "Keine Items zum Scannen! Waehle mindestens ein Rezept aus."
L["scan_start"]             = "Starte Scan von |cffffd700%d|r Items..."
L["scan_timeout"]           = "|cffff4444Timeout: %s - uebersprungen.|r"
L["scan_complete"]          = "Scan fertig! |cff00ff00%d Preise gefunden|r"
L["scan_missing"]           = ", |cffff4444%d nicht im AH|r."
L["scan_deals_found"]       = "|cffffd700%d Schnaeppchen gefunden:|r"
L["scan_snipe_start"]       = "|cff00ffffSchnaeppchen-Scan:|r Scanne |cffffd700%d|r bekannte Items..."
L["scan_no_history"]        = "Keine Preishistorie vorhanden. Fuehre zuerst einen normalen Scan durch."

-- Buyer
L["buy_already_running"]    = "Es laeuft bereits ein Kaufvorgang!"
L["buy_ah_required"]        = "Das Auktionshaus muss geoeffnet sein!"
L["buy_no_price"]           = "Kein gueltiger Preis/Gewinn fuer %s"
L["buy_all_vendor"]         = "Alle Zutaten sind Vendor-Items - nichts zu kaufen!"
L["buy_header"]             = "|cffffd700Kaufe Zutaten fuer %dx %s:|r"
L["buy_item_max_ppu"]       = "  %dx %s (max %s/Stueck)"
L["buy_searching"]          = "|cffffff00Suche: %s (%d noch benoetigt)...|r"
L["buy_timeout"]            = "|cffff4444Timeout beim Suchen - naechste Zutat...|r"
L["buy_no_gold"]            = "|cffff4444Nicht genug Gold! Kauf abgebrochen.|r"
L["buy_purchased"]          = "  |cff00ff00Gekauft:|r %dx %s fuer %s (%s/Stueck)"
L["buy_no_offers"]          = "|cffffff00%s: Keine guenstigen Angebote im AH.|r"
L["buy_offers_found"]       = "  |cff888888%d Angebote gefunden, guenstigstes: %s/Stueck, Ziel-PPU: %s/Stueck|r"
L["buy_partial"]            = "|cffffff00%s: %d/%d gekauft (nicht genug guenstige Angebote im AH).|r"
L["buy_item_complete"]      = "  |cff00ff00%s komplett!|r"
L["buy_not_active"]         = "Kein Kaufvorgang aktiv."
L["buy_cancelled"]          = "|cffffff00Kauf abgebrochen.|r"
L["buy_summary_header"]     = "|cffffd700=== Kauf-Zusammenfassung ===|r"
L["buy_summary_recipe"]     = "Trank: %s (x%d)"
L["buy_summary_spent"]      = "Ausgegeben: %s"
L["buy_summary_footer"]     = "|cffffd700========================|r"
L["buy_vendor_hint"]        = "|cffffff00Noch beim Haendler kaufen:|r"
L["buy_in_bags_skip"]       = "  |cff00ff00%s: %d in Taschen (brauche %d) - uebersprungen|r"

-- Poster
L["post_already_running"]   = "Es laeuft bereits ein Posting-Vorgang!"
L["post_ah_required"]       = "Das Auktionshaus muss geoeffnet sein!"
L["post_none_found"]        = "Keine %s in den Taschen gefunden!"
L["post_header"]            = "|cffffd700Poste %dx %s (%d Stacks)|r"
L["post_price"]             = "  Preis: %s/Stueck"
L["post_ah_price"]          = "  AH-Preis: %s/Stueck (Undercut: %dc)"
L["post_wrong_item"]        = "|cffff4444Falsches Item im Sell-Slot: %s - uebersprungen|r"
L["post_no_deposit"]        = "|cffff4444Nicht genug Gold fuer Deposit! (%s)|r"
L["post_posted"]            = "  |cff00ff00Gepostet:|r %dx %s fuer %s (%s/Stueck)"
L["post_not_active"]        = "Kein Posting-Vorgang aktiv."
L["post_cancelled"]         = "|cffffff00Posting abgebrochen.|r"
L["post_summary_header"]    = "|cffffd700=== Posting-Zusammenfassung ===|r"
L["post_summary_line"]      = "%dx %s in %d Auktionen gepostet"
L["post_summary_price"]     = "Preis: %s/Stueck"
L["post_summary_footer"]    = "|cffffd700============================|r"

-- UI / Spalten
L["col_potion"]             = "Trank/Elixier"
L["col_cost"]               = "Kosten"
L["col_sell"]               = "Verkaufspreis"
L["col_fee"]                = "AH-Gebuehr"
L["col_profit"]             = "Gewinn"
L["col_margin"]             = "Marge"
L["col_updated"]            = "Aktualisiert"

-- Datumsformate
L["date_short"]             = "%d.%m %H:%M"
L["date_long"]              = "%d.%m.%Y %H:%M"

-- UI / Buttons
L["btn_scan"]               = "Scannen"
L["btn_cancel_scan"]        = "|cffff4444Abbrechen|r"
L["btn_select_all"]         = "Alle an"
L["btn_deselect_all"]       = "Alle aus"
L["btn_buy"]                = "|cff00ff00Kaufen|r"
L["btn_cancel"]             = "Abbrechen"

-- UI / Tooltip / Suchfeld
L["search_label"]           = "|cffaaaaaaSuche:|r"
L["sort_tooltip"]           = "Klicken zum Sortieren"
L["scan_start_tooltip"]     = "Scan starten"
L["scan_ah_tooltip"]        = "Das Auktionshaus muss geoeffnet sein."
L["scan_cancel_tooltip"]    = "Scan abbrechen"

-- UI / Statuszeile
L["status_open_alchemy"]    = "|cffaaaaaa Oeffne das Alchemie-Fenster, dann starte einen Scan im AH.|r"
L["status_recipes_ready"]   = "|cffaaaaaa%d Rezepte geladen. Starte einen Scan im AH.|r"
L["status_filter_active"]   = "|cffaaaaaa%d/%d Rezepte (Filter aktiv)|r"
L["status_analyzed"]        = "|cffaaaaaa%d Rezepte analysiert.|r"
L["status_scanning"]        = "|cffffff00Scanne %d/%d:  %s|r"
L["status_no_profit"]       = "|cffff6644Kein Trank ist derzeit profitabel.|r"
L["status_recommend"]       = "|cff00ff00Empfehlung: %s | Gewinn: %s | Marge: %s|r"
L["status_last_scan"]       = "|cffaaaaaaLetzter Scan: vor %d:%02d min|r"
L["status_open_alchemy_first"] = "|cffaaaaaa Oeffne das Alchemie-Fenster, dann klicke 'Trank-Analyse' im AH.|r"

-- UI / Tooltip-Details
L["tt_ingred_header"]       = "|cffffff00Zutatenkosten (pro Stueck):|r"
L["tt_no_price"]            = "|cffff4444kein Preis|r"
L["tt_ingred_total"]        = "Zutaten gesamt:"
L["tt_sell_price"]          = "Verkaufspreis (AH):"
L["tt_avg_price"]           = "Durchschnittspreis:"
L["tt_ah_listings"]         = "AH-Listings:"
L["tt_ah_fee"]              = "AH-Provision (5%):"
L["tt_deposit"]             = "Deposit (24h):"
L["tt_profit"]              = "Gewinn:"
L["tt_margin"]              = "Marge:"
L["tt_updated"]             = "Aktualisiert:"
L["tt_in_bags"]             = "In Taschen:"
L["tt_deal"]                = "|cff00ffffSchnaeppchen: Aktueller Preis deutlich unter Durchschnitt!|r"
L["tt_rightclick"]          = "|cff888888Rechtsklick: Zutaten kaufen|r"
L["tt_shift_rightclick"]    = "|cff888888Shift+Rechtsklick: Traenke posten|r"

-- UI / OnClick
L["click_no_bags"]          = "Keine %s in den Taschen."
L["click_no_data"]          = "Nicht genug Preisdaten fuer %s."
L["click_not_profitable"]   = "%s ist nicht profitabel genug zum Kaufen."

-- UI / Kaufdialog
L["buydlg_title"]           = "Zutaten kaufen"
L["buydlg_margin_info"]     = "Marge: %s | Gewinn: %s |cffaaaaaa(min. 10%% wird eingehalten)|r"
L["buydlg_no_margin"]       = "|cffff4444Keine Margeninformation|r"
L["buydlg_count_label"]     = "Anzahl Traenke:"
L["buydlg_est_cost"]        = "|cffaaaaaagesch. Zutatenkosten: %s|r"
L["buydlg_gold_warning"]    = "|cffff4444Nicht genug Gold! (Verfuegbar: %s)|r"
L["buydlg_invalid_count"]   = "Bitte eine gueltige Anzahl eingeben!"

-- UI / Post-Dialog
L["postdlg_title"]          = "Traenke posten"
L["postdlg_in_bags"]        = "%d %s in Taschen"
L["postdlg_stack_label"]    = "Stackgroesse:"
L["postdlg_count_label"]    = "Stacks:"
L["postdlg_count_all"]      = "alle"
L["postdlg_result_info"]    = "-> %d Auktionen (%d Stueck)"
L["postdlg_price_info"]     = "Preis: %s pro Stueck"
L["btn_post"]               = "|cff00ff00Posten|r"
L["btn_check_price"]        = "Preis pruefen"
L["postdlg_checking"]       = "|cffffff00Suche...|r"
L["postdlg_ah_price"]       = "AH-Preis: %s/Stueck"
L["postdlg_no_ah_price"]    = "|cffff4444Nicht im AH|r"
L["postdlg_diff_cheaper"]   = "|cff00ff00%s guenstiger als AH|r"
L["postdlg_diff_same"]      = "|cffffff00Gleicher Preis|r"
L["postdlg_diff_more"]      = "|cffff4444%s teurer als AH|r"

-- UI / Datenzeilen
L["col_unknown_cost"]       = "|cffff4444unbekannt|r"
L["col_not_in_ah"]          = "|cffff4444nicht im AH|r"
L["col_missing_prefix"]     = "|cffffff00fehlt: "

-- ── Englische Uebersetzung ───────────────────────────────────
-- Wird geladen wenn GetLocale() ~= "deDE"
-- (Turtle WoW verwendet Englisch als Standard-Client)

local locale = GetLocale and GetLocale() or "enUS"
if locale ~= "deDE" then

-- Core / Allgemein
L["addon_loaded"]           = "v%s loaded. /aht for help."
L["price_data_reset"]       = "Price data reset."
L["post_hint"]              = "Shift+Right-click a potion in the results to post."
L["no_recipes_loaded"]      = "No recipes loaded. Open the Alchemy window first!"
L["recipes_loaded_count"]   = "%d loaded alchemy recipes:"
L["recipes_loaded_msg"]     = "%d alchemy recipes loaded. Open the AH and click 'Potion Analysis'."
L["recipe_disabled_tag"]    = "[OFF]"

-- Core / Debug
L["debug_version"]          = "Version: %s"
L["debug_recipes"]          = "Recipes loaded: %d"
L["debug_prices"]           = "Prices saved: %d"
L["debug_vendor"]           = "Vendor items: %d"
L["debug_ui"]               = "UI frame: %s"
L["debug_scan"]             = "Scan status: %s"
L["debug_ui_ok"]            = "OK"
L["debug_ui_error"]         = "|cffff4444ERROR|r"

-- Core / Slash-Hilfe
L["help_show"]              = "/aht show    - Open results window"
L["help_scan"]              = "/aht scan    - Start AH scan (AH must be open)"
L["help_snipe"]             = "/aht snipe   - Snipe scan (all known items)"
L["help_stop"]              = "/aht stop    - Cancel scan, buy, or posting"
L["help_reset"]             = "/aht reset   - Delete saved prices"
L["help_recipes"]           = "/aht recipes - Show loaded recipes"
L["help_debug"]             = "/aht debug   - Show debug info"
L["help_actions"]           = "Right-click = Buy reagents | Shift+Right-click = Post"

-- Scanner
L["scan_button"]            = "Potion Analysis"
L["scan_cancel"]            = "Cancel"
L["scan_tooltip_cancel"]    = "Click to cancel scan"
L["scan_tooltip_open"]      = "Opens the Potion Analysis."
L["scan_tooltip_last"]      = "Shows results from the last scan."
L["scan_tooltip_no_recipes"] = "|cffff4444Open the Alchemy window first!|r"
L["scan_tooltip_ready"]     = "|cff00ff00%d recipes ready.|r"
L["scan_no_active"]         = "No scan active."
L["scan_cancelled"]         = "|cffffff00Scan cancelled.|r"
L["scan_already_running"]   = "Scan already running! /aht stop to cancel."
L["scan_ah_required"]       = "The Auction House must be open!"
L["scan_no_recipes"]        = "No recipes loaded! Open the Alchemy window first."
L["scan_no_items"]          = "No items to scan! Select at least one recipe."
L["scan_start"]             = "Starting scan of |cffffd700%d|r items..."
L["scan_timeout"]           = "|cffff4444Timeout: %s - skipped.|r"
L["scan_complete"]          = "Scan complete! |cff00ff00%d prices found|r"
L["scan_missing"]           = ", |cffff4444%d not in AH|r."
L["scan_deals_found"]       = "|cffffd700%d deals found:|r"
L["scan_snipe_start"]       = "|cff00ffffSnipe Scan:|r Scanning |cffffd700%d|r known items..."
L["scan_no_history"]        = "No price history available. Run a normal scan first."

-- Buyer
L["buy_already_running"]    = "A purchase is already in progress!"
L["buy_ah_required"]        = "The Auction House must be open!"
L["buy_no_price"]           = "No valid price/profit for %s"
L["buy_all_vendor"]         = "All reagents are vendor items - nothing to buy!"
L["buy_header"]             = "|cffffd700Buying reagents for %dx %s:|r"
L["buy_item_max_ppu"]       = "  %dx %s (max %s/each)"
L["buy_searching"]          = "|cffffff00Searching: %s (%d still needed)...|r"
L["buy_timeout"]            = "|cffff4444Search timeout - next reagent...|r"
L["buy_no_gold"]            = "|cffff4444Not enough gold! Purchase cancelled.|r"
L["buy_purchased"]          = "  |cff00ff00Purchased:|r %dx %s for %s (%s/each)"
L["buy_no_offers"]          = "|cffffff00%s: No cheap offers in the AH.|r"
L["buy_offers_found"]       = "  |cff888888%d offers found, cheapest: %s/each, target PPU: %s/each|r"
L["buy_partial"]            = "|cffffff00%s: %d/%d bought (not enough cheap offers in AH).|r"
L["buy_item_complete"]      = "  |cff00ff00%s complete!|r"
L["buy_not_active"]         = "No purchase in progress."
L["buy_cancelled"]          = "|cffffff00Purchase cancelled.|r"
L["buy_summary_header"]     = "|cffffd700=== Purchase Summary ===|r"
L["buy_summary_recipe"]     = "Potion: %s (x%d)"
L["buy_summary_spent"]      = "Spent: %s"
L["buy_summary_footer"]     = "|cffffd700========================|r"
L["buy_vendor_hint"]        = "|cffffff00Still buy from vendor:|r"
L["buy_in_bags_skip"]       = "  |cff00ff00%s: %d in bags (need %d) - skipped|r"

-- Poster
L["post_already_running"]   = "A posting is already in progress!"
L["post_ah_required"]       = "The Auction House must be open!"
L["post_none_found"]        = "No %s found in bags!"
L["post_header"]            = "|cffffd700Posting %dx %s (%d stacks)|r"
L["post_price"]             = "  Price: %s/each"
L["post_ah_price"]          = "  AH price: %s/each (undercut: %dc)"
L["post_wrong_item"]        = "|cffff4444Wrong item in sell slot: %s - skipped|r"
L["post_no_deposit"]        = "|cffff4444Not enough gold for deposit! (%s)|r"
L["post_posted"]            = "  |cff00ff00Posted:|r %dx %s for %s (%s/each)"
L["post_not_active"]        = "No posting in progress."
L["post_cancelled"]         = "|cffffff00Posting cancelled.|r"
L["post_summary_header"]    = "|cffffd700=== Posting Summary ===|r"
L["post_summary_line"]      = "%dx %s in %d auctions posted"
L["post_summary_price"]     = "Price: %s/each"
L["post_summary_footer"]    = "|cffffd700============================|r"

-- UI / Spalten
L["col_potion"]             = "Potion/Elixir"
L["col_cost"]               = "Cost"
L["col_sell"]               = "Sell Price"
L["col_fee"]                = "AH Fee"
L["col_profit"]             = "Profit"
L["col_margin"]             = "Margin"
L["col_updated"]            = "Updated"

-- Date formats
L["date_short"]             = "%m/%d %H:%M"
L["date_long"]              = "%m/%d/%Y %H:%M"

-- UI / Buttons
L["btn_scan"]               = "Scan"
L["btn_cancel_scan"]        = "|cffff4444Cancel|r"
L["btn_select_all"]         = "All on"
L["btn_deselect_all"]       = "All off"
L["btn_buy"]                = "|cff00ff00Buy|r"
L["btn_cancel"]             = "Cancel"

-- UI / Tooltip / Suchfeld
L["search_label"]           = "|cffaaaaaaSearch:|r"
L["sort_tooltip"]           = "Click to sort"
L["scan_start_tooltip"]     = "Start scan"
L["scan_ah_tooltip"]        = "The Auction House must be open."
L["scan_cancel_tooltip"]    = "Cancel scan"

-- UI / Statuszeile
L["status_open_alchemy"]    = "|cffaaaaaa Open the Alchemy window, then start a scan at the AH.|r"
L["status_recipes_ready"]   = "|cffaaaaaa%d recipes loaded. Start a scan at the AH.|r"
L["status_filter_active"]   = "|cffaaaaaa%d/%d recipes (filter active)|r"
L["status_analyzed"]        = "|cffaaaaaa%d recipes analyzed.|r"
L["status_scanning"]        = "|cffffff00Scanning %d/%d:  %s|r"
L["status_no_profit"]       = "|cffff6644No potion is currently profitable.|r"
L["status_recommend"]       = "|cff00ff00Recommendation: %s | Profit: %s | Margin: %s|r"
L["status_last_scan"]       = "|cffaaaaaaLast scan: %d:%02d min ago|r"
L["status_open_alchemy_first"] = "|cffaaaaaa Open the Alchemy window, then click 'Potion Analysis' at the AH.|r"

-- UI / Tooltip-Details
L["tt_ingred_header"]       = "|cffffff00Reagent costs (per unit):|r"
L["tt_no_price"]            = "|cffff4444no price|r"
L["tt_ingred_total"]        = "Reagents total:"
L["tt_sell_price"]          = "Sell price (AH):"
L["tt_avg_price"]           = "Average price:"
L["tt_ah_listings"]         = "AH listings:"
L["tt_ah_fee"]              = "AH cut (5%):"
L["tt_deposit"]             = "Deposit (24h):"
L["tt_profit"]              = "Profit:"
L["tt_margin"]              = "Margin:"
L["tt_updated"]             = "Updated:"
L["tt_in_bags"]             = "In bags:"
L["tt_deal"]                = "|cff00ffffDeal: Current price well below average!|r"
L["tt_rightclick"]          = "|cff888888Right-click: Buy reagents|r"
L["tt_shift_rightclick"]    = "|cff888888Shift+Right-click: Post potions|r"

-- UI / OnClick
L["click_no_bags"]          = "No %s in bags."
L["click_no_data"]          = "Not enough price data for %s."
L["click_not_profitable"]   = "%s is not profitable enough to buy."

-- UI / Kaufdialog
L["buydlg_title"]           = "Buy Reagents"
L["buydlg_margin_info"]     = "Margin: %s | Profit: %s |cffaaaaaa(min. 10%% enforced)|r"
L["buydlg_no_margin"]       = "|cffff4444No margin information|r"
L["buydlg_count_label"]     = "Number of potions:"
L["buydlg_est_cost"]        = "|cffaaaaaaest. reagent cost: %s|r"
L["buydlg_gold_warning"]    = "|cffff4444Not enough gold! (Available: %s)|r"
L["buydlg_invalid_count"]   = "Please enter a valid number!"

-- UI / Post-Dialog
L["postdlg_title"]          = "Post Potions"
L["postdlg_in_bags"]        = "%d %s in bags"
L["postdlg_stack_label"]    = "Stack size:"
L["postdlg_count_label"]    = "Stacks:"
L["postdlg_count_all"]      = "all"
L["postdlg_result_info"]    = "-> %d auctions (%d units)"
L["postdlg_price_info"]     = "Price: %s per unit"
L["btn_post"]               = "|cff00ff00Post|r"
L["btn_check_price"]        = "Check Price"
L["postdlg_checking"]       = "|cffffff00Searching...|r"
L["postdlg_ah_price"]       = "AH price: %s/unit"
L["postdlg_no_ah_price"]    = "|cffff4444Not in AH|r"
L["postdlg_diff_cheaper"]   = "|cff00ff00%s cheaper than AH|r"
L["postdlg_diff_same"]      = "|cffffff00Same price|r"
L["postdlg_diff_more"]      = "|cffff4444%s more expensive than AH|r"

-- UI / Datenzeilen
L["col_unknown_cost"]       = "|cffff4444unknown|r"
L["col_not_in_ah"]          = "|cffff4444not in AH|r"
L["col_missing_prefix"]     = "|cffffff00missing: "

end -- locale ~= "deDE"
