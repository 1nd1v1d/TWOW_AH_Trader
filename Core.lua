-- ============================================================
-- TWOW AH Trader - Core.lua
-- Hauptobjekt, Initialisierung, Events, Slash-Befehle
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
-- ============================================================

TWOW_AHT = {}
local AHT = TWOW_AHT

AHT.VERSION = "1.5.0"

-- Laufzeit-Daten
AHT.prices    = {}   -- [itemName] = guenstigster Buyout pro Stueck (Kupfer)
AHT.recipes   = {}   -- Array von Rezept-Objekten (aus dem Alchemie-Fenster)
AHT.results   = {}   -- Array von berechneten Ergebnis-Objekten (nach dem Scan)
AHT.selected  = {}   -- [recipeName] = true/false  (welche Rezepte gescannt werden)
AHT.priceUpdated = {}  -- [itemName] = Unix-Timestamp der letzten Preisermittlung
AHT.priceHistory = {}  -- [itemName] = { {t=timestamp, p=price}, ... } letzten N Eintraege
AHT.listingCounts = {} -- [itemName] = Anzahl Listings im AH (letzter Scan)

-- Sortierung & Filter
AHT.sortMode       = "profit"  -- "profit" oder "margin"
AHT.sortDir        = "desc"    -- "asc" oder "desc"
AHT.searchFilter   = ""        -- Namensfilter (Kleinbuchstaben)
AHT.displayResults = {}        -- Gefilterte/sortierte Ergebnisse fuer die Anzeige

-- Konstanten
AHT.MAX_HISTORY    = 20    -- Max Preisverlauf-Eintraege pro Item
AHT.UNDERCUT       = 1     -- Undercut in Kupfer pro Stueck
AHT.DEAL_THRESHOLD = 0.20  -- 20% unter Durchschnitt = Schnaeppchen

-- ── Vendor-Preise (Kupfer) ───────────────────────────────────
-- Items die beim Haendler kaufbar sind werden nicht im AH gescannt
AHT.vendorPrices = {
    -- Deutsche Namen
    ["Kristallphiole"]    = 18,
    ["Gesprungene Phiole"] = 180,
    ["Besudelte Phiole"]  = 2250,
    ["Geschmolzene Phiole"] = 27000,
    -- Englische Namen (Turtle WoW)
    ["Crystal Vial"]      = 18,
    ["Leaded Vial"]       = 180,
    ["Imbued Vial"]       = 2250,
    ["Enchanted Vial"]    = 27000,
    -- Basis-Phiolen
    ["Empty Vial"]        = 1,
    ["Leere Phiole"]      = 1,
}

-- ── Hilfsfunktionen ──────────────────────────────────────────
function AHT:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[AH Trader]|r " .. tostring(msg))
end

-- Formatiert Kupfer-Betrag als farbigen Gold/Silber/Kupfer-String
function AHT:FormatMoney(copper)
    if not copper then return "|cffaaaaaa?|r" end
    local neg = copper < 0
    if neg then copper = -copper end
    local g = math.floor(copper / 10000)
    local s = math.floor(mod(copper, 10000) / 100)
    local c = math.floor(mod(copper, 100))
    local out = ""
    if g > 0 then out = out .. "|cffffd700" .. g .. "g|r " end
    if s > 0 or g > 0 then out = out .. "|cffc7c7cf" .. s .. "s|r " end
    out = out .. "|cffeda55f" .. c .. "c|r"
    if neg then out = "-" .. out end
    return out
end

-- Formatiert Kupfer-Betrag als reinen Text (fuer Tooltips, ohne Color-Codes)
function AHT:FormatMoneyPlain(copper)
    if not copper then return "?" end
    local neg = copper < 0
    if neg then copper = -copper end
    local g = math.floor(copper / 10000)
    local s = math.floor(mod(copper, 10000) / 100)
    local c = math.floor(mod(copper, 100))
    local out = ""
    if g > 0 then out = out .. g .. "g " end
    if s > 0 or g > 0 then out = out .. s .. "s " end
    out = out .. c .. "c"
    if neg then out = "-" .. out end
    return out
end

-- Zaehlt Eintraege in einer Tabelle
function AHT:TableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Prueft ob ein Item ein Vendor-Item ist
function AHT:IsVendorItem(name)
    return AHT.vendorPrices[name] ~= nil
end

-- ── Inventar-Helfer ────────────────────────────────────────
-- Zaehlt wieviele eines Items in den Taschen sind
function AHT:CountItemInBags(itemName)
    local total = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, iName = strfind(link, "%[(.-)%]")
                if iName == itemName then
                    local _, count = GetContainerItemInfo(bag, slot)
                    total = total + (count or 1)
                end
            end
        end
    end
    return total
end

-- Findet alle Stacks eines Items in den Taschen
-- Gibt zurueck: { {bag=, slot=, count=}, ... }
function AHT:FindItemInBags(itemName)
    local stacks = {}
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, iName = strfind(link, "%[(.-)%]")
                if iName == itemName then
                    local _, count = GetContainerItemInfo(bag, slot)
                    tinsert(stacks, { bag = bag, slot = slot, count = count or 1 })
                end
            end
        end
    end
    return stacks
end

-- ── Preisverlauf-Helfer ────────────────────────────────────
function AHT:AddPriceHistory(itemName, price)
    if not price or price <= 0 then return end
    if not AHT.priceHistory[itemName] then
        AHT.priceHistory[itemName] = {}
    end
    local hist = AHT.priceHistory[itemName]
    tinsert(hist, { t = time(), p = price })
    -- Auf MAX_HISTORY begrenzen
    while getn(hist) > AHT.MAX_HISTORY do
        tremove(hist, 1)
    end
end

function AHT:GetPriceAverage(itemName)
    local hist = AHT.priceHistory[itemName]
    if not hist or getn(hist) == 0 then return nil end
    local sum = 0
    for _, entry in ipairs(hist) do
        sum = sum + entry.p
    end
    return math.floor(sum / getn(hist))
end

function AHT:GetPriceTrend(itemName)
    local hist = AHT.priceHistory[itemName]
    if not hist or getn(hist) < 3 then return nil end
    local avg = AHT:GetPriceAverage(itemName)
    if not avg or avg == 0 then return nil end
    local current = hist[getn(hist)].p
    local pctChange = ((current - avg) / avg) * 100
    if pctChange > 10 then return "up"
    elseif pctChange < -10 then return "down"
    else return "stable" end
end

function AHT:IsDeal(itemName)
    local price = AHT.prices[itemName]
    local avg   = AHT:GetPriceAverage(itemName)
    if not price or not avg or avg == 0 then return false end
    return price < avg * (1 - AHT.DEAL_THRESHOLD)
end

-- ── Slash-Befehle ─────────────────────────────────────────────
SLASH_TWOW_AHT1 = "/aht"
SLASH_TWOW_AHT2 = "/ahtrader"
SlashCmdList["TWOW_AHT"] = function(msg)
    local L = AHT.L
    msg = strlower(msg or "")
    if msg == "" or msg == "show" then
        if getn(AHT.recipes) > 0 then
            AHT:CalculateMargins()
        end
        AHT:ShowUI()
    elseif msg == "scan" then
        AHT:StartScan()
    elseif msg == "stop" or msg == "cancel" then
        if AHT:IsPosting() then
            AHT:CancelPost()
        elseif AHT:IsBuying() then
            AHT:CancelBuy()
        else
            AHT:CancelScan()
        end
    elseif msg == "reset" then
        AHT.prices = {}
        AHT.priceHistory = {}
        AHT.listingCounts = {}
        AHT:SaveDB()
        AHT:Print(L["price_data_reset"])
    elseif msg == "snipe" then
        AHT:StartSnipeScan()
    elseif msg == "post" then
        AHT:Print(L["post_hint"])
    elseif msg == "rezepte" or msg == "recipes" then
        AHT:PrintRecipes()
    elseif msg == "debug" then
        AHT:Print(string.format(L["debug_version"], AHT.VERSION))
        AHT:Print(string.format(L["debug_recipes"], getn(AHT.recipes)))
        AHT:Print(string.format(L["debug_prices"], AHT:TableCount(AHT.prices)))
        AHT:Print(string.format(L["debug_vendor"], AHT:TableCount(AHT.vendorPrices)))
        AHT:Print(string.format(L["debug_ui"], (TWOW_AHT_UI and L["debug_ui_ok"] or L["debug_ui_error"])))
        AHT:Print(string.format(L["debug_scan"], AHT.scanState))
    else
        AHT:Print(L["help_show"])
        AHT:Print(L["help_scan"])
        AHT:Print(L["help_snipe"])
        AHT:Print(L["help_stop"])
        AHT:Print(L["help_reset"])
        AHT:Print(L["help_recipes"])
        AHT:Print(L["help_debug"])
        AHT:Print(L["help_actions"])
    end
end

-- ── Persistenz ───────────────────────────────────────────────
function AHT:OnLoad()
    if TWOW_AHT_DB then
        AHT.prices       = TWOW_AHT_DB.prices       or {}
        AHT.recipes      = TWOW_AHT_DB.recipes      or {}
        AHT.selected     = TWOW_AHT_DB.selected     or {}
        AHT.priceUpdated = TWOW_AHT_DB.priceUpdated or {}
        AHT.priceHistory = TWOW_AHT_DB.priceHistory or {}
        AHT.listingCounts = TWOW_AHT_DB.listingCounts or {}
    end
    -- Vendor-Preise in die Preistabelle eintragen
    for name, price in pairs(AHT.vendorPrices) do
        AHT.prices[name] = price
    end
    AHT:Print(string.format(AHT.L["addon_loaded"], AHT.VERSION))
end

function AHT:SaveDB()
    TWOW_AHT_DB = TWOW_AHT_DB or {}
    TWOW_AHT_DB.prices       = AHT.prices
    TWOW_AHT_DB.recipes      = AHT.recipes
    TWOW_AHT_DB.selected     = AHT.selected
    TWOW_AHT_DB.priceUpdated = AHT.priceUpdated
    TWOW_AHT_DB.priceHistory = AHT.priceHistory
    TWOW_AHT_DB.listingCounts = AHT.listingCounts
end

-- ── Debug-Ausgabe ────────────────────────────────────────────
function AHT:PrintRecipes()
    local L = AHT.L
    if getn(AHT.recipes) == 0 then
        AHT:Print(L["no_recipes_loaded"])
        return
    end
    AHT:Print("|cffffd700" .. string.format(L["recipes_loaded_count"], getn(AHT.recipes)) .. "|r")
    for _, recipe in ipairs(AHT.recipes) do
        local parts = {}
        for _, ing in ipairs(recipe.reagents) do
            tinsert(parts, ing.count .. "x " .. ing.name)
        end
        local sel = ""
        if AHT.selected[recipe.name] == false then
            sel = "|cff888888" .. L["recipe_disabled_tag"] .. "|r "
        end
        AHT:Print("  " .. sel .. "|cff00ff00" .. recipe.name .. "|r: " .. table.concat(parts, ", "))
    end
end

-- ── Event-Frame ───────────────────────────────────────────────
local evtFrame = CreateFrame("Frame", "TWOW_AHT_EventFrame")
evtFrame:RegisterEvent("VARIABLES_LOADED")
evtFrame:RegisterEvent("TRADE_SKILL_SHOW")
evtFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
evtFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
evtFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
evtFrame:RegisterEvent("CHAT_MSG_SYSTEM")
evtFrame:RegisterEvent("NEW_AUCTION_UPDATE")
evtFrame:RegisterEvent("UI_ERROR_MESSAGE")

evtFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        AHT:OnLoad()
    elseif event == "TRADE_SKILL_SHOW" then
        AHT:LearnRecipes()
    elseif event == "AUCTION_HOUSE_SHOW" then
        AHT:OnAHShow()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        AHT:OnAHClosed()
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        if AHT.postPriceCheck and AHT.postPriceCheck.state == "sent" then
            AHT:OnPostPriceCheckResult()
        elseif AHT:IsPosting() then
            -- Poster ignoriert AUCTION_ITEM_LIST_UPDATE
        elseif AHT:IsBuying() then
            AHT:OnBuyAuctionListUpdate()
        else
            AHT:OnAuctionListUpdate()
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        if arg1 and arg1 == ERR_AUCTION_BID_PLACED then
            AHT:OnBidPlaced()
        end
    elseif event == "UI_ERROR_MESSAGE" then
        -- Fehlgeschlagene Bids: buyLocked sofort freigeben
        if AHT.buyLocked and arg1 then
            AHT.buyLocked = false
        end
    elseif event == "NEW_AUCTION_UPDATE" then
        if AHT:IsPosting() then
            AHT:OnNewAuctionUpdate()
        end
    end
end)

evtFrame:SetScript("OnUpdate", function()
    local dt = arg1
    -- Nur aktive Zustandsautomaten aufrufen
    if AHT.scanState ~= "idle" then
        AHT:OnUpdate(dt)
    end
    if AHT.buyState ~= "idle" then
        AHT:OnBuyUpdate(dt)
    end
    if AHT.postState ~= "idle" then
        AHT:OnPostUpdate(dt)
    end
    -- Price-Check Timer fuer Post-Dialog
    local pc = AHT.postPriceCheck
    if pc and pc.state == "waiting" then
        pc.timer = pc.timer + dt
        if pc.timer >= 0.3 then
            pc.timer = 0
            if CanSendAuctionQuery() then
                pc.state = "sent"
                pc.sentTimer = 0
                QueryAuctionItems(pc.name, nil, nil, nil, nil, nil, pc.page, nil, nil)
            end
        end
    elseif pc and pc.state == "sent" then
        pc.sentTimer = (pc.sentTimer or 0) + dt
        if pc.sentTimer >= 10.0 then
            -- Timeout: Preis-Check abbrechen
            pc.state = "done"
            AHT:ShowPriceCheckResult()
        end
    end
    -- Recipe-Retry Timer (bei fehlenden Reagenzien im Cache)
    if AHT._recipeRetryPending then
        AHT:OnRecipeRetryUpdate(dt)
    end
end)

-- ── AH geschlossen: alle laufenden Operationen abbrechen ─────
function AHT:OnAHClosed()
    if AHT:IsScanning() then
        AHT:CancelScan()
    end
    if AHT:IsBuying() then
        AHT:CancelBuy()
    end
    if AHT:IsPosting() then
        AHT:CancelPost()
    end
    if AHT.postPriceCheck and AHT.postPriceCheck.state ~= "done" then
        AHT.postPriceCheck = nil
    end
end
