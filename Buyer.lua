-- ============================================================
-- TWOW AH Trader - Buyer.lua
-- Kauft Zutaten aus dem AH fuer einen gewaehlten Trank
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
--
-- Ablauf:
--   1. Spieler waehlt Trank + Anzahl
--   2. Einkaufsliste wird berechnet (Vendor-Items ausgenommen)
--   3. Pro Zutat: AH durchsuchen, anhand gespeichertem ppu filtern,
--      pruefen ob Margin >= 10% bleibt, dann Buyout ausfuehren
--   4. Nach Abschluss: Zusammenfassung im Chat
--
-- PlaceAuctionBid("list", index, buyoutPrice) = Sofortkauf
-- ============================================================

local AHT = TWOW_AHT

local MIN_MARGIN = 0.10   -- 10% Mindestmarge nach Kauf

-- ── Buyer-State ──────────────────────────────────────────────
AHT.buyState        = "idle"    -- idle / searching / buying / done
AHT.buyRecipe       = nil       -- Das Ergebnis-Objekt (aus AHT.results)
AHT.buyCount        = 0         -- Wieviele Traenke hergestellt werden sollen
AHT.buyList         = {}        -- { { name, totalNeeded, bought, maxPPU } }
AHT.buyListIdx      = 0         -- Aktueller Index in buyList
AHT.buyPage         = 0         -- AH-Seite
AHT.buyTimer        = 0
AHT.buyLocked       = false     -- Wird gesetzt waehrend PlaceAuctionBid laeuft
AHT.buyPendingOffer = nil       -- Angebot das gerade gekauft wird (fuer Zaehler-Korrektur)
AHT.buyTotalSpent   = 0         -- Kupfer insgesamt ausgegeben
AHT.buyItemsBought  = 0         -- Stueck insgesamt gekauft
AHT.buySentTimer    = 0
AHT.buyCollecting   = false     -- Phase 1: Alle Seiten scannen ohne zu kaufen
AHT.buyAllOffers    = {}        -- Gesammelte Angebote aus allen Seiten
AHT.buyTargetPPU    = 0         -- Optimaler max PPU (berechnet nach Phase 1)

local BUY_DELAY     = 0.4
local BUY_TIMEOUT   = 12.0
local BUY_WAIT_TIMEOUT = 30.0

-- ── Maximalen Stueckpreis berechnen ──────────────────────────
-- Der Spieler darf nur Items kaufen, deren ppu so ist, dass die
-- Gesamtmarge >= MIN_MARGIN bleibt.
--
-- Formel:  margin = profit / ingredCost >= MIN_MARGIN
-- => profit >= ingredCost * MIN_MARGIN
-- => (sellPrice - ahProv - deposit - ingredCost) >= ingredCost * MIN_MARGIN
-- => sellPrice - ahProv - deposit >= ingredCost * (1 + MIN_MARGIN)
-- => ingredCost <= (sellPrice - ahProv - deposit) / (1 + MIN_MARGIN)
-- => maxIngredCost ist die Obergrenze fuer Gesamtzutaten
-- => maxPPU je Zutat = (maxIngredBudget - KostenAndererZutaten) / benoetigteMenge
--
function AHT:CalcMaxPPU(recipe, reagentName, reagentCount)
    if not recipe or not recipe.sellPrice then return nil end

    local sellPrice   = recipe.sellPrice
    local ahProv      = math.floor(sellPrice * 0.05)
    local vendorSell  = math.floor(sellPrice * 0.02)
    local deposit     = math.max(1, math.floor(vendorSell * 0.36))
    local netIncome   = sellPrice - ahProv - deposit

    -- Maximale Gesamtzutatenkosten bei MIN_MARGIN
    local maxIngredCost = math.floor(netIncome / (1 + MIN_MARGIN))

    -- Kosten aller anderen Zutaten abziehen (festgesetzte oder bereits bekannte)
    local otherCost = 0
    for _, reag in ipairs(recipe.reagents) do
        if reag.name ~= reagentName then
            local price = AHT.vendorPrices[reag.name] or AHT.prices[reag.name]
            if price then
                otherCost = otherCost + price * reag.count
            end
        end
    end

    local budgetForThis = maxIngredCost - otherCost
    if budgetForThis <= 0 then return 0 end

    return math.floor(budgetForThis / reagentCount)
end

-- ── Kauf starten ─────────────────────────────────────────────
function AHT:StartBuy(recipe, count)
    local L = AHT.L
    if AHT.buyState ~= "idle" then
        AHT:Print(L["buy_already_running"])
        return
    end
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        AHT:Print(L["buy_ah_required"])
        return
    end
    if not recipe.sellPrice or not recipe.profit or recipe.profit <= 0 then
        AHT:Print(string.format(L["buy_no_price"], recipe.name))
        return
    end

    AHT.buyRecipe      = recipe
    AHT.buyCount       = count
    AHT.buyTotalSpent  = 0
    AHT.buyItemsBought = 0

    -- Einkaufsliste aufbauen (nur AH-Items, keine Vendor-Items)
    -- Bereits vorhandene Items in den Taschen abziehen
    local list = {}
    for _, reag in ipairs(recipe.reagents) do
        if not AHT:IsVendorItem(reag.name) then
            local totalNeeded = reag.count * count
            local inBags = AHT:CountItemInBags(reag.name)
            local recipeSession = AHT.sessionBought[AHT.buyRecipe.name] or {}
            local prevBought = recipeSession[reag.name] or 0
            local actualNeeded = totalNeeded - inBags - prevBought
            if actualNeeded > 0 then
                local maxPPU = AHT:CalcMaxPPU(recipe, reag.name, reag.count)
                tinsert(list, {
                    name        = reag.name,
                    totalNeeded = actualNeeded,
                    bought      = 0,
                    maxPPU      = maxPPU or 0,
                    scanPPU     = AHT.prices[reag.name] or 0,
                })
            else
                local haveTotal = inBags + prevBought
                AHT:Print(string.format(L["buy_in_bags_skip"], reag.name, haveTotal, totalNeeded))
            end
        end
    end

    if getn(list) == 0 then
        AHT:Print(L["buy_all_vendor"])
        return
    end

    AHT.buyList    = list
    AHT.buyListIdx = 0

    -- Zusammenfassung anzeigen
    AHT:Print(string.format(L["buy_header"], count, recipe.name))
    for _, item in ipairs(list) do
        AHT:Print(string.format(L["buy_item_max_ppu"], item.totalNeeded, item.name, AHT:FormatMoney(item.maxPPU)))
    end

    AHT:AdvanceBuyQueue()
end

-- ── Buy-Queue vorruecken ─────────────────────────────────────
function AHT:AdvanceBuyQueue()
    AHT.buyListIdx = AHT.buyListIdx + 1

    if AHT.buyListIdx > getn(AHT.buyList) then
        AHT:OnBuyComplete()
        return
    end

    local item = AHT.buyList[AHT.buyListIdx]
    if item.bought >= item.totalNeeded then
        AHT:AdvanceBuyQueue()
        return
    end

    AHT.buyPage       = 0
    AHT.buyState      = "searching"
    AHT.buyTimer      = 0
    AHT.buySentTimer  = 0
    AHT.buyLocked     = false
    AHT.buyCollecting = true
    AHT.buyAllOffers  = {}
    AHT.buyTargetPPU  = 0

    AHT:Print(string.format(AHT.L["buy_searching"], item.name, (item.totalNeeded - item.bought)))
end

-- ── OnUpdate fuer Buy-Zustandsautomat ─────────────────────────
function AHT:OnBuyUpdate(elapsed)
    if AHT.buyState == "idle" or AHT.buyState == "done" then return end

    if AHT.buyState == "searching" then
        AHT.buyTimer = AHT.buyTimer + elapsed
        AHT.buySentTimer = AHT.buySentTimer + elapsed
        -- Globaler Timeout im searching-Zustand
        if AHT.buySentTimer >= BUY_WAIT_TIMEOUT then
            AHT:Print(AHT.L["buy_timeout"])
            AHT:AdvanceBuyQueue()
            return
        end
        if AHT.buyTimer >= BUY_DELAY then
            AHT.buyTimer = 0
            if CanSendAuctionQuery() then
                local item = AHT.buyList[AHT.buyListIdx]
                local invTypeIndex, classIndex, subClassIndex = AHT:GetAuctionQueryFilters(item.name)
                AHT.buySentTimer = 0
                AHT.buyState = "buying"
                QueryAuctionItems(item.name, nil, nil, invTypeIndex, classIndex, subClassIndex, AHT.buyPage, nil, nil)
            end
        end

    elseif AHT.buyState == "buying" then
        AHT.buySentTimer = AHT.buySentTimer + elapsed
        if AHT.buySentTimer >= BUY_TIMEOUT then
            AHT:Print(AHT.L["buy_timeout"])
            AHT:AdvanceBuyQueue()
        end
    end
end

-- ── AH-Ergebnisse verarbeiten (Kauf-Modus) ───────────────────
-- Zweiphasiger Ansatz:
--   Phase 1 (buyCollecting=true):  Alle Seiten scannen, Angebote sammeln
--   Phase 2 (buyCollecting=false): Guenstigste Angebote (nach Stueckpreis)
--                                   gezielt kaufen
-- Grund: AH sortiert nach Gesamt-Buyout, nicht nach Stueckpreis.
--        Ein 20er-Stack fuer 1g (5s/Stueck) steht auf einer spaeteren
--        Seite als ein Einzel-Item fuer 10s (10s/Stueck).
--        Ohne Vorab-Scan wuerden teure Einzelstuecke zuerst gekauft.
function AHT:OnBuyAuctionListUpdate()
    if AHT.buyState ~= "buying" then return end
    if AHT.buyLocked then return end

    local item = AHT.buyList[AHT.buyListIdx]
    if not item then return end

    local numItems = GetNumAuctionItems("list")

    if AHT.buyCollecting then
        -- ── Phase 1: Angebote sammeln (alle Seiten) ──────────
        for i = 1, numItems do
            local name, texture, count, quality, canUse, level,
                  minBid, minIncrement, buyoutPrice,
                  bidAmount, highBidder, owner = GetAuctionItemInfo("list", i)

            if name == item.name
               and buyoutPrice and buyoutPrice > 0
               and count and count > 0
               and owner ~= UnitName("player") then
                local ppu = math.floor(buyoutPrice / count)
                if ppu <= item.maxPPU then
                    tinsert(AHT.buyAllOffers, {
                        count  = count,
                        buyout = buyoutPrice,
                        ppu    = ppu,
                    })
                end
            end
        end

        if numItems >= 50 then
            -- Weitere Seiten scannen
            AHT.buyPage  = AHT.buyPage + 1
            AHT.buyState = "searching"
            AHT.buyTimer = 0
        else
            -- Alle Seiten gescannt → Angebote auswerten
            table.sort(AHT.buyAllOffers, function(a, b) return a.ppu < b.ppu end)

            if getn(AHT.buyAllOffers) == 0 then
                AHT:Print(string.format(AHT.L["buy_no_offers"], item.name))
                AHT:AdvanceBuyQueue()
                return
            end

            -- Optimalen Maximal-Stueckpreis berechnen:
            -- Nur so viel bezahlen, wie noetig um die Bestellung zu fuellen
            local needed = item.totalNeeded - item.bought
            local cumCount = 0
            AHT.buyTargetPPU = AHT.buyAllOffers[getn(AHT.buyAllOffers)].ppu
            for _, o in ipairs(AHT.buyAllOffers) do
                cumCount = cumCount + o.count
                if cumCount >= needed then
                    AHT.buyTargetPPU = o.ppu
                    break
                end
            end

            local cheapest = AHT.buyAllOffers[1].ppu
            AHT:Print(string.format(AHT.L["buy_offers_found"],
                      getn(AHT.buyAllOffers),
                      AHT:FormatMoney(cheapest),
                      AHT:FormatMoney(AHT.buyTargetPPU)))

            -- Phase 2 starten: ab Seite 0 erneut durchgehen und kaufen
            AHT.buyCollecting = false
            AHT.buyPage       = 0
            AHT.buyState      = "searching"
            AHT.buyTimer      = 0
        end
    else
        -- ── Phase 2: Kaufen (guenstigste zuerst) ─────────────
        local offers = {}
        for i = 1, numItems do
            local name, texture, count, quality, canUse, level,
                  minBid, minIncrement, buyoutPrice,
                  bidAmount, highBidder, owner = GetAuctionItemInfo("list", i)

            if name == item.name
               and buyoutPrice and buyoutPrice > 0
               and count and count > 0
               and owner ~= UnitName("player") then
                local ppu = math.floor(buyoutPrice / count)
                -- Nur Angebote kaufen die <= Ziel-PPU sind
                if ppu <= item.maxPPU and ppu <= AHT.buyTargetPPU then
                    tinsert(offers, {
                        index  = i,
                        count  = count,
                        buyout = buyoutPrice,
                        ppu    = ppu,
                    })
                end
            end
        end

        -- Nach ppu sortieren (guenstigste zuerst)
        table.sort(offers, function(a, b) return a.ppu < b.ppu end)

        -- Versuche zu kaufen
        local stillNeeded = item.totalNeeded - item.bought
        local boughtThisPage = false

        for _, offer in ipairs(offers) do
            if stillNeeded <= 0 then break end

            -- Sicherheitscheck: genug Gold?
            if GetMoney() < offer.buyout then
                AHT:Print(AHT.L["buy_no_gold"])
                AHT:CancelBuy()
                return
            end

            -- Kaufen!
            AHT.buyLocked = true
            AHT.buyPendingOffer = {
                count  = offer.count,
                name   = item.name,
                buyout = offer.buyout,
                ppu    = offer.ppu,
                idx    = AHT.buyListIdx,
            }
            PlaceAuctionBid("list", offer.index, offer.buyout)
            boughtThisPage = true

            break  -- Nur 1 Kauf pro Update-Zyklus (sicher)
        end

        if not boughtThisPage then
            -- Keine passenden Angebote auf dieser Seite
            if numItems >= 50 then
                -- Weitere Seiten pruefen
                AHT.buyPage  = AHT.buyPage + 1
                AHT.buyState = "searching"
                AHT.buyTimer = 0
            else
                -- Keine weiteren Seiten
                if item.bought < item.totalNeeded then
                    AHT:Print(string.format(AHT.L["buy_partial"],
                              item.name, item.bought, item.totalNeeded))
                end
                AHT:AdvanceBuyQueue()
            end
        end
        -- Nach Kauf: Weiter-Logik wird in OnBidPlaced gesteuert
    end
end

-- ── ERR_AUCTION_BID_PLACED Handler ───────────────────────────
function AHT:OnBidPlaced()
    if AHT.IsMatsBuying and AHT:IsMatsBuying() and AHT.OnMatsBidPlaced then
        AHT:OnMatsBidPlaced()
        return
    end

    AHT.buyLocked = false

    -- Zaehler erst nach Bestaetigung aktualisieren
    local pending = AHT.buyPendingOffer
    if pending then
        local item = AHT.buyList[pending.idx]
        if item then
            item.bought = item.bought + pending.count
        end
        AHT.buyTotalSpent = AHT.buyTotalSpent + pending.buyout
        AHT.buyItemsBought = AHT.buyItemsBought + pending.count
        -- Session-Gedaechtnis: merken fuer Neuversuche desselben Rezepts
        local recipeKey = AHT.buyRecipe and AHT.buyRecipe.name or "_unknown_"
        AHT.sessionBought[recipeKey] = AHT.sessionBought[recipeKey] or {}
        AHT.sessionBought[recipeKey][pending.name] = (AHT.sessionBought[recipeKey][pending.name] or 0) + pending.count

        -- Pruefen ob genug gekauft
        if item and item.bought >= item.totalNeeded then
            AHT:Print(string.format(AHT.L["buy_item_complete"], item.name))
            AHT:AdvanceBuyQueue()
        else
            AHT.buyState = "searching"
            AHT.buyTimer = 0
        end
    end
end

-- ── Kauf abbrechen ───────────────────────────────────────────
function AHT:CancelBuy()
    if AHT.buyState == "idle" then
        AHT:Print(AHT.L["buy_not_active"])
        return
    end
    AHT:Print(AHT.L["buy_cancelled"])
    AHT:OnBuyComplete()
end

-- ── Kauf abgeschlossen ───────────────────────────────────────
function AHT:OnBuyComplete()
    AHT.buyState       = "idle"
    AHT.buyLocked      = false
    AHT.buyCollecting  = false
    AHT.buyAllOffers   = {}
    AHT.buyPendingOffer = nil

    local recipe = AHT.buyRecipe
    if not recipe then return end

    -- Zusammenfassung
    local L = AHT.L
    AHT:Print(L["buy_summary_header"])
    AHT:Print(string.format(L["buy_summary_recipe"], recipe.name, AHT.buyCount))
    for _, item in ipairs(AHT.buyList) do
        local color = "|cff00ff00"
        if item.bought < item.totalNeeded then color = "|cffff4444" end
        AHT:Print("  " .. color .. item.bought .. "/" .. item.totalNeeded ..
                  "|r " .. item.name)
    end
    AHT:Print(string.format(L["buy_summary_spent"], AHT:FormatMoney(AHT.buyTotalSpent)))
    AHT:Print(L["buy_summary_footer"])

    -- Fehlende Vendor-Items auflisten
    local vendorList = {}
    for _, reag in ipairs(recipe.reagents) do
        if AHT:IsVendorItem(reag.name) then
            tinsert(vendorList, reag.count * AHT.buyCount .. "x " .. reag.name ..
                    " (" .. AHT:FormatMoney(AHT.vendorPrices[reag.name]) .. "/Stueck)")
        end
    end
    if getn(vendorList) > 0 then
        AHT:Print(L["buy_vendor_hint"])
        for _, v in ipairs(vendorList) do
            AHT:Print("  " .. v)
        end
    end

    AHT.buyRecipe = nil
end

-- ── Prueft ob ein Kaufvorgang laeuft ─────────────────────────
function AHT:IsBuying()
    return AHT.buyState ~= "idle"
end
