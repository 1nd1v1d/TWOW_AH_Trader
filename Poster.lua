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
AHT.postState       = "idle"    -- idle / placing / confirming / done
AHT.postRecipeName  = nil       -- Name des zu postenden Tranks
AHT.postStacks      = {}        -- { {bag, slot, count}, ... } Posting-Plan
AHT.postStackIdx    = 0         -- Aktueller Plan-Index
AHT.postPrice       = 0         -- Buyout-Preis pro Stueck (Kupfer)
AHT.postTimer       = 0
AHT.postTotalPosted = 0         -- Stueck insgesamt gepostet
AHT.postTotalStacks = 0         -- Stacks insgesamt gepostet
AHT.postDuration    = 1440      -- Auktionsdauer in Minuten (24h)
AHT.postAwaitConfirm = false    -- Wartet auf NEW_AUCTION_UPDATE
AHT.postStackSize   = 1         -- Gewuenschte Stackgroesse

local POST_DELAY    = 0.5       -- Sekunden zwischen Posts

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
-- Erstellt aus den Bag-Stacks einen Plan mit gewuenschter Stackgroesse
-- Gibt zurueck: { {bag, slot, count}, ... } wobei count <= stackSize
function AHT:BuildPostPlan(stacks, stackSize)
    local plan = {}
    for _, s in ipairs(stacks) do
        local remaining = s.count
        while remaining > 0 do
            local take = remaining
            if take > stackSize then take = stackSize end
            tinsert(plan, { bag = s.bag, slot = s.slot, count = take })
            remaining = remaining - take
        end
    end
    return plan
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

    -- Stacks in den Taschen finden
    local stacks = AHT:FindItemInBags(recipeName)
    if getn(stacks) == 0 then
        AHT:Print(string.format(L["post_none_found"], recipeName))
        return
    end

    -- Posting-Plan mit gewuenschter Stackgroesse erstellen
    local plan = AHT:BuildPostPlan(stacks, stackSize or 1)

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
    AHT.postAwaitConfirm = false

    -- Zusammenfassung
    local totalCount = 0
    for _, s in ipairs(stacks) do
        totalCount = totalCount + s.count
    end

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

    AHT.postState = "placing"
    AHT.postTimer = 0
    AHT.postAwaitConfirm = false
end

-- ── OnUpdate fuer Post-Zustandsautomat ────────────────────────
function AHT:OnPostUpdate(elapsed)
    if AHT.postState == "idle" or AHT.postState == "done" then return end

    if AHT.postState == "placing" then
        AHT.postTimer = AHT.postTimer + elapsed
        if AHT.postTimer >= POST_DELAY then
            AHT.postTimer = 0

            local stack = AHT.postStacks[AHT.postStackIdx]
            if not stack then
                AHT:AdvancePostQueue()
                return
            end

            -- Item in die Hand nehmen und in den AH-Sell-Slot legen
            ClearCursor()
            local _, currentCount = GetContainerItemInfo(stack.bag, stack.slot)
            if stack.count < (currentCount or 0) then
                SplitContainerItem(stack.bag, stack.slot, stack.count)
            else
                PickupContainerItem(stack.bag, stack.slot)
            end
            ClickAuctionSellItemButton()

            -- Warten auf NEW_AUCTION_UPDATE
            AHT.postState = "confirming"
            AHT.postAwaitConfirm = true
            AHT.postTimer = 0
        end

    elseif AHT.postState == "confirming" then
        AHT.postTimer = AHT.postTimer + elapsed

        -- Timeout nach 3 Sekunden falls NEW_AUCTION_UPDATE nicht kommt
        if AHT.postTimer >= 3.0 then
            if AHT.postAwaitConfirm then
                -- Versuche trotzdem zu posten (Item koennte schon im Slot sein)
                AHT:DoStartAuction()
            end
        end
    end
end

-- ── NEW_AUCTION_UPDATE: Item ist im Sell-Slot ─────────────────
function AHT:OnNewAuctionUpdate()
    if AHT.postState ~= "confirming" then return end
    if not AHT.postAwaitConfirm then return end

    AHT.postAwaitConfirm = false
    AHT:DoStartAuction()
end

-- ── Auktion starten ──────────────────────────────────────────
function AHT:DoStartAuction()
    local stack = AHT.postStacks[AHT.postStackIdx]
    if not stack then
        AHT:AdvancePostQueue()
        return
    end

    -- Pruefen ob Item im Sell-Slot ist
    local name, texture, count, quality, canUse = GetAuctionSellItemInfo()
    if not name or name ~= AHT.postRecipeName then
        AHT:Print(string.format(AHT.L["post_wrong_item"], (name or "?")))
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
