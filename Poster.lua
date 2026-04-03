-- ============================================================
-- TWOW AH Trader - Poster.lua
-- Postet hergestellte Traenke automatisch ins AH
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
--
-- Ablauf:
--   1. Spieler waehlt Trank im Ergebnisfenster (Shift+Rechtsklick)
--   2. Addon findet alle Stacks in den Taschen
--   3. Berechnet Undercut-Preis (1c unter guenstigstem AH-Angebot)
--   4. Postet einen Stack nach dem anderen
--   5. Zusammenfassung im Chat
--
-- API: PickupContainerItem -> ClickAuctionSellItemButton -> StartAuction
-- ============================================================

local AHT = TWOW_AHT

-- ── Poster-State ─────────────────────────────────────────────
AHT.postState       = "idle"    -- idle / splitting / split_wait / placing / confirming / done
AHT.postRecipeName  = nil       -- Name des zu postenden Tranks
AHT.postStacks      = {}        -- { count1, count2, ... } Posting-Plan (Stueckzahlen)
AHT.postStackIdx    = 0         -- Aktueller Plan-Index
AHT.postPrice       = 0         -- Buyout-Preis pro Stueck (Kupfer)
AHT.postTimer       = 0
AHT.postTotalStacks = 0         -- Stacks insgesamt gepostet
AHT.postDuration    = 1440      -- Auktionsdauer in Minuten (24h)
AHT.postStackSize   = 1         -- Gewuenschte Stackgroesse
AHT.postSplitTarget = nil       -- {bag, slot} des Ziel-Slots fuer Split
AHT.postSplitExpect = 0         -- Erwartete Stackgroesse nach Split
AHT.postReadySlot   = nil       -- {bag, slot} des fertig vorbereiteten Stacks

local POST_DELAY    = 0.5       -- Sekunden zwischen Posts
local SPLIT_POLL    = 0.1       -- Sekunden zwischen Split-Polls

-- ── Optimalen Preis berechnen ─────────────────────────────────
-- Undercut: 1c unter dem guenstigsten AH-Preis pro Stueck
-- Minimum: Zutatenkosten * 1.05 (mindestens 5% Aufschlag)
-- Fallback: Zutatenkosten * 1.20 (20% Aufschlag wenn kein AH-Preis)
function AHT:CalcPostPrice(recipe)
    local currentAH = AHT.prices[recipe.name]
    local ingredCost = recipe.ingredCost or 0

    local minPrice = math.floor(ingredCost * 1.05)
    if minPrice < 1 then minPrice = 1 end

    if currentAH and currentAH > 0 then
        local undercut = currentAH - AHT.UNDERCUT
        if undercut >= minPrice then
            return undercut
        else
            return minPrice
        end
    else
        -- Kein AH-Preis bekannt: 20% Aufschlag auf Kosten
        local markup = math.floor(ingredCost * 1.20)
        if markup < minPrice then markup = minPrice end
        return markup
    end
end

-- ── Posting-Plan erstellen ────────────────────────────────────
-- Erstellt eine Liste von Stueckzahlen pro Auktion
-- Gibt zurueck: { count1, count2, ... } wobei jeder Eintrag <= stackSize
function AHT:BuildPostPlan(totalCount, stackSize)
    local plan = {}
    local remaining = totalCount
    while remaining > 0 do
        local take = remaining
        if take > stackSize then take = stackSize end
        tinsert(plan, take)
        remaining = remaining - take
    end
    return plan
end

-- Findet den ersten Stack eines Items in den Taschen
-- Gibt bag, slot, count zurueck (oder nil wenn nicht gefunden)
function AHT:FindFirstBagStack(itemName)
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, iName = strfind(link, "%[(.-)%]")
                if iName == itemName then
                    local _, count = GetContainerItemInfo(bag, slot)
                    return bag, slot, (count or 1)
                end
            end
        end
    end
    return nil, nil, 0
end

-- Findet einen exakten Stack (itemName mit genau exactCount)
function AHT:FindExactBagStack(itemName, exactCount)
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, iName = strfind(link, "%[(.-)%]")
                if iName == itemName then
                    local _, count = GetContainerItemInfo(bag, slot)
                    if (count or 1) == exactCount then
                        return bag, slot
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Findet einen leeren Taschenslot
function AHT:FindEmptyBagSlot()
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            if not GetContainerItemLink(bag, slot) then
                return bag, slot
            end
        end
    end
    return nil, nil
end

-- ── Posting starten ──────────────────────────────────────────
function AHT:StartPost(recipeName, recipe, stackSize, maxStacks)
    local L = AHT.L
    if AHT.postState ~= "idle" then
        AHT:Print(L["post_already_running"])
        return
    end
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        AHT:Print(L["post_ah_required"])
        return
    end

    -- Gesamtanzahl in den Taschen ermitteln
    local totalCount = AHT:CountItemInBags(recipeName)
    if totalCount == 0 then
        AHT:Print(string.format(L["post_none_found"], recipeName))
        return
    end

    -- Posting-Plan erstellen (nur Stueckzahlen)
    local plan = AHT:BuildPostPlan(totalCount, stackSize or 1)

    -- Auf gewuenschte Stackanzahl begrenzen
    if maxStacks and maxStacks > 0 and getn(plan) > maxStacks then
        local limited = {}
        for i = 1, maxStacks do
            tinsert(limited, plan[i])
        end
        plan = limited
    end

    -- Preis berechnen
    local price = AHT:CalcPostPrice(recipe)

    AHT.postRecipeName  = recipeName
    AHT.postStacks      = plan
    AHT.postStackIdx    = 0
    AHT.postPrice       = price
    AHT.postStackSize   = stackSize or 1
    AHT.postTotalPosted = 0
    AHT.postTotalStacks = 0
    AHT.postTimer       = 0

    AHT:Print(string.format(L["post_header"], totalCount, recipeName, getn(plan)))
    AHT:Print(string.format(L["post_price"], AHT:FormatMoney(price)))

    local currentAH = AHT.prices[recipeName]
    if currentAH then
        AHT:Print(string.format(L["post_ah_price"], AHT:FormatMoney(currentAH), AHT.UNDERCUT))
    end

    AHT:AdvancePostQueue()
end

-- ── Post-Queue vorruecken ────────────────────────────────────
function AHT:AdvancePostQueue()
    AHT.postStackIdx = AHT.postStackIdx + 1

    if AHT.postStackIdx > getn(AHT.postStacks) then
        AHT:OnPostComplete()
        return
    end

    AHT.postReadySlot   = nil
    AHT.postSplitTarget = nil
    AHT.postSplitExpect = 0
    AHT.postState       = "splitting"
    AHT.postTimer       = 0
end

-- ── OnUpdate fuer Post-Zustandsautomat ────────────────────────
-- Ablauf nach aux-addon Muster:
--   splitting  -> Split Bag-zu-Bag (oder Skip wenn Stack schon passt)
--   split_wait -> Warten bis Ziel-Slot die korrekte Stackgroesse hat
--   placing    -> Item mit PickupContainerItem aufnehmen + in AH-Slot legen
--   confirming -> Warten auf ERR_AUCTION_STARTED, dann StartAuction
function AHT:OnPostUpdate(elapsed)
    if AHT.postState == "idle" or AHT.postState == "done" then return end

    if AHT.postState == "splitting" then
        AHT.postTimer = AHT.postTimer + elapsed
        if AHT.postTimer < POST_DELAY then return end
        AHT.postTimer = 0

        local wantCount = AHT.postStacks[AHT.postStackIdx]
        if not wantCount then
            AHT:AdvancePostQueue()
            return
        end

        -- Suche ob ein Stack mit exakter Groesse schon existiert
        local eBag, eSlot = AHT:FindExactBagStack(AHT.postRecipeName, wantCount)
        if eBag then
            -- Perfekter Stack gefunden, direkt posten
            AHT.postReadySlot = { eBag, eSlot }
            AHT.postState = "placing"
            AHT.postTimer = 0
            return
        end

        -- Suche einen Stack der groesser ist und gesplittet werden kann
        local bag, slot, currentCount = AHT:FindFirstBagStack(AHT.postRecipeName)
        if not bag then
            AHT:AdvancePostQueue()
            return
        end

        if currentCount == wantCount then
            -- Passt schon
            AHT.postReadySlot = { bag, slot }
            AHT.postState = "placing"
            AHT.postTimer = 0
            return
        end

        -- Brauche einen leeren Slot fuer den Split
        local emptyBag, emptySlot = AHT:FindEmptyBagSlot()
        if not emptyBag then
            -- Kein leerer Slot: Stack trotzdem komplett posten
            AHT.postReadySlot = { bag, slot }
            AHT.postState = "placing"
            AHT.postTimer = 0
            return
        end

        -- Split: Gewuenschte Menge vom Quell-Stack in den leeren Slot
        ClearCursor()
        SplitContainerItem(bag, slot, wantCount)
        PickupContainerItem(emptyBag, emptySlot)
        ClearCursor()

        AHT.postSplitTarget = { emptyBag, emptySlot }
        AHT.postSplitExpect = wantCount
        AHT.postState = "split_wait"
        AHT.postTimer = 0
        AHT.postSplitTimeout = 0

    elseif AHT.postState == "split_wait" then
        AHT.postTimer = AHT.postTimer + elapsed
        AHT.postSplitTimeout = AHT.postSplitTimeout + elapsed
        -- Pollen bis der Ziel-Slot die erwartete Groesse hat
        if AHT.postTimer >= SPLIT_POLL then
            AHT.postTimer = 0
            local tBag   = AHT.postSplitTarget[1]
            local tSlot  = AHT.postSplitTarget[2]
            local _, count = GetContainerItemInfo(tBag, tSlot)
            if count and count == AHT.postSplitExpect then
                -- Split fertig
                AHT.postReadySlot = { tBag, tSlot }
                AHT.postState = "placing"
                AHT.postTimer = 0
            elseif AHT.postSplitTimeout > 3.0 then
                -- Timeout: trotzdem weiter
                if count and count > 0 then
                    AHT.postReadySlot = { tBag, tSlot }
                    AHT.postState = "placing"
                    AHT.postTimer = 0
                else
                    AHT:AdvancePostQueue()
                end
            end
        end

    elseif AHT.postState == "placing" then
        -- Item mit aux-Muster in den AH-Sell-Slot legen
        local rBag  = AHT.postReadySlot[1]
        local rSlot = AHT.postReadySlot[2]

        ClearCursor()
        ClickAuctionSellItemButton()
        ClearCursor()
        PickupContainerItem(rBag, rSlot)
        ClickAuctionSellItemButton()
        ClearCursor()

        -- Warten bis Item im Sell-Slot erkannt wird (Polling)
        AHT.postState = "confirming"
        AHT.postTimer = 0

    elseif AHT.postState == "confirming" then
        AHT.postTimer = AHT.postTimer + elapsed
        if AHT.postTimer < 0.2 then return end  -- kurze Wartezeit fuer Sell-Slot Update

        -- Pollen ob Item im Sell-Slot ist
        local name = GetAuctionSellItemInfo()
        if name and name == AHT.postRecipeName then
            AHT:DoStartAuction()
            return
        end

        -- Timeout nach 3 Sekunden
        if AHT.postTimer >= 3.0 then
            AHT:Print(string.format(AHT.L["post_wrong_item"], (name or "?")))
            ClearCursor()
            AHT:AdvancePostQueue()
        end
    end
end

-- ── NEW_AUCTION_UPDATE: nicht mehr fuer Confirm benoetigt ─────
function AHT:OnNewAuctionUpdate()
    -- Platzhalter, Confirm nutzt jetzt Polling
end

-- ── Auktion starten ──────────────────────────────────────────
function AHT:DoStartAuction()
    local wantCount = AHT.postStacks[AHT.postStackIdx]
    if not wantCount then
        AHT:AdvancePostQueue()
        return
    end

    -- Pruefen ob Item im Sell-Slot ist
    local name, texture, count, quality, canUse = GetAuctionSellItemInfo()
    if not name or name ~= AHT.postRecipeName then
        AHT:Print(string.format(AHT.L["post_wrong_item"], (name or "?")))
        ClearCursor()
        AHT:AdvancePostQueue()
        return
    end

    -- Deposit pruefen
    -- GetAuctionDeposit existiert nicht in vanilla 1.12.1
    -- Deposit = floor(vendorSellPrice * duration/120 * 0.05) * count
    -- vendorSellPrice ~ 2% des AH-Preises (nicht per API abfragbar)
    local startPrice = AHT.postPrice * count
    local buyout     = AHT.postPrice * count
    local estVendor  = math.floor(AHT.postPrice * 0.02)
    local deposit    = math.max(1, math.floor(estVendor * 0.36)) * count

    -- Genug Gold fuer Deposit?
    if deposit > GetMoney() then
        AHT:Print(string.format(AHT.L["post_no_deposit"], AHT:FormatMoney(deposit)))
        ClearCursor()
        AHT:CancelPost()
        return
    end

    -- Posten!
    StartAuction(startPrice, buyout, AHT.postDuration)

    AHT.postTotalPosted = AHT.postTotalPosted + count
    AHT.postTotalStacks = AHT.postTotalStacks + 1

    AHT:Print(string.format(AHT.L["post_posted"],
              count, AHT.postRecipeName,
              AHT:FormatMoney(buyout),
              AHT:FormatMoney(AHT.postPrice)))

    -- Naechster Stack
    AHT:AdvancePostQueue()
end

-- ── Posting abbrechen ────────────────────────────────────────
function AHT:CancelPost()
    if AHT.postState == "idle" then
        AHT:Print(AHT.L["post_not_active"])
        return
    end
    AHT:Print(AHT.L["post_cancelled"])
    AHT:OnPostComplete()
end

-- ── Posting abgeschlossen ────────────────────────────────────
function AHT:OnPostComplete()
    AHT.postState = "idle"
    ClearCursor()

    if AHT.postTotalStacks > 0 then
        local L = AHT.L
        AHT:Print(L["post_summary_header"])
        AHT:Print(string.format(L["post_summary_line"],
                  AHT.postTotalPosted, (AHT.postRecipeName or "?"), AHT.postTotalStacks))
        AHT:Print(string.format(L["post_summary_price"], AHT:FormatMoney(AHT.postPrice)))
        AHT:Print(L["post_summary_footer"])
    end

    AHT.postRecipeName = nil
end

-- ── Prueft ob ein Posting laeuft ─────────────────────────────
function AHT:IsPosting()
    return AHT.postState ~= "idle"
end
