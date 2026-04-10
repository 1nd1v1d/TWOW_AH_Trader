-- ============================================================
-- TWOW AH Trader - Calculator.lua
-- Berechnet Gewinnmargen fuer alle bekannten Rezepte
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
--
-- Formel pro Trank:
--   Einnahme    = Verkaufspreis - AH-Provision (5%) - Einzahlung
--   Gewinn      = Einnahme - Zutatenkosten
--   Marge       = Gewinn / Zutatenkosten * 100
--
-- AH-Provision:  5% des Verkaufspreises (Fraktions-AH)
-- Deposit:       Formel aus aux-addon (24h, Stapel 1, maxStack 5)
--   floor(vendorSellPrice * (1440/120) * (1 + (5-1)*0.05) * 0.025)
--   = floor(vendorSellPrice * 0.36)
-- ============================================================

local AHT = TWOW_AHT

local AH_PROVISION       = 0.05   -- 5% AH-Provision auf den Verkaufspreis

-- Deposit-Konstanten (24h Auktion, Stapelgroesse 1, Traenke stapeln zu 5)
-- Formel aus aux-addon:
--   floor(vendorSellPrice * stackSize * (dauer_min/120) * (1+(maxStack-stackSize)*0.05) * 0.025)
-- Fuer 24h(=1440min), stackSize=1, maxStack=5:
--   durationFactor = 1440/120 = 12
--   stackAdjust    = 1 + 4*0.05 = 1.2
--   => deposit = floor(vendorSellPrice * 12 * 1.2 * 0.025) = floor(vendorSellPrice * 0.36)
local DEPOSIT_MULT         = 0.36
local VENDOR_SELL_ESTIMATE = 0.02  -- Schaetzung: Vendor-VK ca. 2% des AH-Preises

function AHT:CalculateMargins()
    local results = {}

    for _, recipe in ipairs(AHT.recipes) do
        local result = {
            name         = recipe.name,
            link         = recipe.link,
            reagents     = recipe.reagents,
            sellPrice    = AHT.prices[recipe.name],
            ingredCost   = 0,
            depositCost  = 0,
            ahProvision  = 0,
            profit       = nil,
            margin       = nil,
            missingReag  = {},   -- Zutaten ohne AH-Preis
            notOnAH      = false,
            volume       = AHT.listingCounts[recipe.name] or 0,
            avgSellPrice = AHT:GetPriceAverage(recipe.name),
            sellTrend    = AHT:GetPriceTrend(recipe.name),
            isDeal       = AHT:IsDeal(recipe.name),
            hasReagDeal  = false,        }

        -- ── Zutatenkosten berechnen ───────────────────────────
        -- Vendor-Items nutzen feste Preise, AH-Items den gescannten Preis
        -- Detailaufschluesselung fuer Tooltip speichern
        local allFound = true
        local costDetails = {}  -- { {name, count, ppu, total, source} }
        for _, reagent in ipairs(recipe.reagents) do
            local vendorP = AHT.vendorPrices[reagent.name]
            local ahP     = AHT.prices[reagent.name]
            local price   = vendorP or ahP
            if price then
                local total = price * reagent.count
                result.ingredCost = result.ingredCost + total
                tinsert(costDetails, {
                    name   = reagent.name,
                    count  = reagent.count,
                    ppu    = price,
                    total  = total,
                    source = vendorP and "Vendor" or "AH",
                    avgPrice = AHT:GetPriceAverage(reagent.name),
                    isDeal   = AHT:IsDeal(reagent.name),
                })
                if AHT:IsDeal(reagent.name) then
                    result.hasReagDeal = true
                end
            else
                allFound = false
                tinsert(result.missingReag, reagent.name)
                tinsert(costDetails, {
                    name   = reagent.name,
                    count  = reagent.count,
                    ppu    = 0,
                    total  = 0,
                    source = "???",
                })
            end
        end
        result.costDetails = costDetails

        -- ── Aktualisierungszeitpunkt ─────────────────────────
        -- Aeltester Zeitstempel aller Zutaten + Trank = "Frische" der Daten
        local oldestUpdate = AHT.priceUpdated[recipe.name]
        for _, reagent in ipairs(recipe.reagents) do
            if not AHT:IsVendorItem(reagent.name) then
                local ts = AHT.priceUpdated[reagent.name]
                if ts then
                    if not oldestUpdate or ts < oldestUpdate then
                        oldestUpdate = ts
                    end
                else
                    oldestUpdate = nil
                    break
                end
            end
        end
        result.updatedAt = oldestUpdate

        -- ── Verkaufspreis pruefen ─────────────────────────────
        if not result.sellPrice then
            result.notOnAH = true
            tinsert(results, result)

        elseif not allFound then
            -- Zutatendaten unvollstaendig
            tinsert(results, result)

        else
            -- ── AH-Provision ──────────────────────────────────
            result.ahProvision = math.floor(result.sellPrice * AH_PROVISION)

            -- ── Deposit (Einzahlungsgebuehr, 24h) ────────────
            -- Vendor-VK ist in Vanilla nicht per API abfragbar,
            -- daher Schaetzung: ca. 2% des AH-Preises
            local vendorSell = math.floor(result.sellPrice * VENDOR_SELL_ESTIMATE)
            result.depositCost = math.max(1, math.floor(vendorSell * DEPOSIT_MULT))

            -- ── Gewinn ───────────────────────────────────────
            local netIncome   = result.sellPrice - result.ahProvision - result.depositCost
            result.profit     = netIncome - result.ingredCost

            -- ── Marge (ROI auf Zutatenbasis) ──────────────────
            if result.ingredCost > 0 then
                result.margin = (result.profit / result.ingredCost) * 100
            else
                result.margin = 0
            end

            tinsert(results, result)
        end
    end

    AHT.results = results
    AHT:ApplyFilterAndSort()
    return results
end

-- ── Filter & Sortierung anwenden ─────────────────────────────
function AHT:ApplyFilterAndSort()
    local filtered = {}
    local filter = strlower(AHT.searchFilter or "")

    for _, r in ipairs(AHT.results) do
        if filter == "" or strfind(strlower(r.name), filter, 1, true) then
            tinsert(filtered, r)
        end
    end

    local mode = AHT.sortMode or "profit"
    local isDesc = (AHT.sortDir or "desc") == "desc"

    table.sort(filtered, function(a, b)
        local va, vb
        if mode == "margin" then
            va = a.margin or -999999
            vb = b.margin or -999999
        else
            va = a.profit or -999999
            vb = b.profit or -999999
        end
        if isDesc then
            return va > vb
        else
            return va < vb
        end
    end)

    AHT.displayResults = filtered
end

-- ══════════════════════════════════════════════════════════════
-- MATERIALS - Neue Berechnung für Material-Analyse
-- ══════════════════════════════════════════════════════════════

-- ── Gewichteter Durchschnitt mit zeitbasiertem Gewicht ────────
-- Scans älter als 60 Tage (2 Monate) sind irrelevant
-- Lineare Gewichtung: Neueste = 1.0, Älteste (60 Tage) = 0.0
function AHT:CalcWeightedMatAverage(matName, currentPrice)
    local hist = AHT.matsHistory[matName]
    if not hist or getn(hist) == 0 then
        return currentPrice or 0
    end

    local now = time()
    local maxAge = 60 * 24 * 3600  -- 60 Tage in Sekunden
    local sumWeightedPrice = 0
    local sumWeight = 0

    -- Alle Eintraege durchlaufen
    for _, entry in ipairs(hist) do
        local ageSeconds = now - entry.t
        local ageDays = math.floor(ageSeconds / (24 * 3600))

        -- Nur Eintraege die älter als MaxAge sind ignorieren
        if ageDays <= 60 then
            -- Lineare Gewichtung: je neuer desto hoher
            local weight = math.max(0, 1 - (ageDays / 60))
            sumWeightedPrice = sumWeightedPrice + (entry.p * weight)
            sumWeight = sumWeight + weight
        end
    end

    if sumWeight > 0 then
        return math.floor(sumWeightedPrice / sumWeight)
    else
        return currentPrice or 0
    end
end

-- ── Mats-Margin Berechnung ──────────────────────────────────
function AHT:CalculateMatsMargins()
    local results = {}

    for matName, _ in pairs(AHT.materials) do
        local currentPrice = AHT.prices[matName] or 0
        local weighted_avg = nil
        local deviation = nil

        if AHT.matsHistory[matName] and getn(AHT.matsHistory[matName]) > 0 then
            -- Hole den letzten gewichteten Durchschnitt
            local lastEntry = AHT.matsHistory[matName][getn(AHT.matsHistory[matName])]
            weighted_avg = lastEntry.weighted_avg or currentPrice

            -- Abweichung vom Durchschnitt berechnen
            if weighted_avg and weighted_avg > 0 then
                if currentPrice > 0 then
                    deviation = ((currentPrice - weighted_avg) / weighted_avg) * 100
                else
                    -- Kein aktueller AH-Preis vorhanden => effektiv 100% unter dem Mittel
                    deviation = -100
                end
            else
                deviation = 0
            end
        else
            weighted_avg = currentPrice
            deviation = 0
        end

        -- Listing Count
        local listingCount = AHT.listingCounts[matName] or 0

        -- Zeitstempel der letzten Aktualisierung (bevorzugt aus Mats-Historie)
        local lastUpdate = AHT.priceUpdated[matName]
        local mHist = AHT.matsHistory[matName]
        if mHist and getn(mHist) > 0 then
            local last = mHist[getn(mHist)]
            if last and last.t then
                lastUpdate = last.t
            end
        end

        tinsert(results, {
            name            = matName,
            currentPrice    = currentPrice or 0,
            weighted_avg    = weighted_avg or 0,
            deviation       = deviation or 0,
            listingCount    = listingCount,
            lastUpdate      = lastUpdate,
            isSelected      = AHT.matsSelected[matName] ~= false,
            historyLength   = getn(AHT.matsHistory[matName] or {}),
        })
    end

    AHT.matsResults = results
    AHT:ApplyMatsFilterAndSort()
    return results
end

-- ── Mats Filter & Sortierung anwenden ────────────────────────
function AHT:ApplyMatsFilterAndSort()
    local filtered = {}
    local filter = strlower(AHT.matsSearchFilter or "")

    for _, r in ipairs(AHT.matsResults) do
        if filter == "" or strfind(strlower(r.name), filter, 1, true) then
            tinsert(filtered, r)
        end
    end

    -- Sortierung
    local mode = AHT.matsSortMode or "deviation"
    local isDesc = (AHT.matsSortDir or "desc") == "desc"

    table.sort(filtered, function(a, b)
        local va, vb
        if mode == "current" then
            va = a.currentPrice
            vb = b.currentPrice
        elseif mode == "weighted_avg" then
            va = a.weighted_avg
            vb = b.weighted_avg
        elseif mode == "deviation" then
            va = a.deviation
            vb = b.deviation
        else  -- "name"
            va = a.name
            vb = b.name
        end

        if isDesc then
            if mode == "name" then return va > vb else return va > vb end
        else
            if mode == "name" then return va < vb else return va < vb end
        end
    end)

    AHT.matsDisplayResults = filtered
end
