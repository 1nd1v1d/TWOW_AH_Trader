-- ============================================================
-- TWOW AH Trader - Scanner.lua
-- AH-Scan mit Rate-Limiting und Seitenverarbeitung
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
--
-- Zustandsautomat:
--   "idle"    - kein Scan aktiv
--   "waiting" - wartet auf CanSendAuctionQuery() bevor naechste Anfrage
--   "sent"    - Anfrage gesendet, wartet auf AUCTION_ITEM_LIST_UPDATE
-- ============================================================

local AHT = TWOW_AHT

AHT.scanState    = "idle"
AHT.scanTimer    = 0
AHT.sentTimer    = 0      -- Timeout-Zaehler im "sent"-Zustand
AHT.SCAN_DELAY   = 0.3    -- Sekunden zwischen CanSendAuctionQuery-Checks
AHT.SENT_TIMEOUT = 15.0   -- Sekunden bis ein ausbleibendes Ergebnis als Timeout gilt
AHT.scanRetries  = 0      -- Anzahl Retries fuer aktuelles Item
AHT.MAX_RETRIES  = 2      -- Max Retries pro Item bevor uebersprungen

-- Scan-Queue
AHT.scanQueue    = {}     -- Liste der Item-Namen die gescannt werden sollen
AHT.scanQueueIdx = 0      -- Aktuelle Position in der Queue
AHT.currentItem  = nil    -- Item das gerade gescannt wird
AHT.scanPage     = 0      -- Aktuelle AH-Seite (0-basiert)
AHT.scanMinPrices = {}    -- Temporaer: [itemName] = guenstigster Preis waehrend des Scans
AHT.scanListingCounts = {} -- Temporaer: [itemName] = Anzahl Listings
AHT.lastScanTime = nil    -- GetTime() beim letzten abgeschlossenen Scan

-- ── AH oeffnen ───────────────────────────────────────────────
function AHT:OnAHShow()
    AHT:CreateScanButton()
end

-- ── Scan-Button ──────────────────────────────────────────────
function AHT:CreateScanButton()
    if AHT.scanButton then
        AHT.scanButton:Show()
        return
    end

    local btn = CreateFrame("Button", "TWOW_AHT_ScanBtn", AuctionFrame, "UIPanelButtonTemplate")
    btn:SetWidth(135)
    btn:SetHeight(22)
    btn:SetText(AHT.L["scan_button"])
    btn:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 70, -28)
    btn:SetScript("OnClick", function()
        if AHT:IsScanning() then
            AHT:CancelScan()
        else
            -- Ergebnisse aus gespeicherten Preisen neu berechnen
            if getn(AHT.recipes) > 0 then
                AHT:CalculateMargins()
            end
            AHT:ShowUI()
        end
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine("TWOW AH Trader")
        if AHT:IsScanning() then
            GameTooltip:AddLine(AHT.L["scan_tooltip_cancel"], 1, 0.5, 0.5)
        else
            GameTooltip:AddLine(AHT.L["scan_tooltip_open"], 1, 1, 1)
            GameTooltip:AddLine(AHT.L["scan_tooltip_last"], 0.7, 0.7, 0.7)
            if getn(AHT.recipes) == 0 then
                GameTooltip:AddLine(AHT.L["scan_tooltip_no_recipes"])
            else
                GameTooltip:AddLine(string.format(AHT.L["scan_tooltip_ready"], getn(AHT.recipes)))
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    AHT.scanButton = btn
end

function AHT:IsScanning()
    return AHT.scanState ~= "idle"
end

-- ── Scan abbrechen ───────────────────────────────────────────
function AHT:CancelScan()
    if not AHT:IsScanning() then
        AHT:Print(AHT.L["scan_no_active"])
        return
    end
    AHT:Print(AHT.L["scan_cancelled"])
    AHT.scanState = "idle"
    AHT:SetScanButtonText(AHT.L["scan_button"])
    -- Bereits gesammelte Preise trotzdem uebernehmen
    local now = time()
    for name, price in pairs(AHT.scanMinPrices) do
        AHT.prices[name] = price
        AHT.priceUpdated[name] = now
    end
    -- Bereits abgearbeitete Items ohne Ergebnis: Preis loeschen
    for i = 1, AHT.scanQueueIdx do
        local item = AHT.scanQueue[i]
        if item and not AHT.scanMinPrices[item] and not AHT:IsVendorItem(item) then
            AHT.prices[item] = nil
            AHT.priceUpdated[item] = nil
        end
    end
    AHT:SaveDB()
end

-- ── Scan starten ─────────────────────────────────────────────
function AHT:StartScan()
    if AHT:IsScanning() then
        AHT:Print(AHT.L["scan_already_running"])
        return
    end

    if not AuctionFrame or not AuctionFrame:IsVisible() then
        AHT:Print(AHT.L["scan_ah_required"])
        return
    end

    if getn(AHT.recipes) == 0 then
        AHT:Print(AHT.L["scan_no_recipes"])
        return
    end

    -- Vendor-Preise in die Preistabelle eintragen
    for name, price in pairs(AHT.vendorPrices) do
        AHT.prices[name] = price
    end

    -- Deduplizierte Liste aller zu scannenden Items aufbauen
    -- Vendor-Items und deaktivierte Rezepte ueberspringen
    local seen  = {}
    local queue = {}

    for _, recipe in ipairs(AHT.recipes) do
        -- Nur ausgewaehlte Rezepte scannen
        if AHT.selected[recipe.name] ~= false then
            if not seen[recipe.name] and not AHT:IsVendorItem(recipe.name) then
                tinsert(queue, recipe.name)
                seen[recipe.name] = true
            end
            for _, reagent in ipairs(recipe.reagents) do
                if not seen[reagent.name] and not AHT:IsVendorItem(reagent.name) then
                    tinsert(queue, reagent.name)
                    seen[reagent.name] = true
                end
            end
        end
    end

    if getn(queue) == 0 then
        AHT:Print(AHT.L["scan_no_items"])
        return
    end

    AHT.scanQueue     = queue
    AHT.scanQueueIdx  = 0
    AHT.scanMinPrices = {}
    AHT.scanListingCounts = {}

    AHT:Print(string.format(AHT.L["scan_start"], getn(queue)))
    AHT:SetScanButtonText(AHT.L["scan_cancel"])

    AHT:AdvanceScanQueue()
end

-- ── Queue-Fortschritt ────────────────────────────────────────
function AHT:AdvanceScanQueue()
    AHT.scanQueueIdx = AHT.scanQueueIdx + 1

    if AHT.scanQueueIdx > getn(AHT.scanQueue) then
        AHT:OnScanComplete()
        return
    end

    AHT.currentItem = AHT.scanQueue[AHT.scanQueueIdx]
    AHT.scanPage    = 0
    AHT.scanRetries = 0

    -- In "waiting" uebergehen: wartet auf CanSendAuctionQuery
    AHT.scanState = "waiting"
    AHT.scanTimer = 0
    AHT.sentTimer = 0

    AHT:UpdateScanProgress()
end

-- ── OnUpdate (Timer & Timeout) ────────────────────────────────
function AHT:OnUpdate(elapsed)
    if AHT.scanState == "waiting" then
        AHT.scanTimer = AHT.scanTimer + elapsed
        if AHT.scanTimer >= AHT.SCAN_DELAY then
            AHT.scanTimer = 0
            -- Nur senden wenn AH bereit ist
            if CanSendAuctionQuery() then
                AHT.sentTimer = 0
                AHT.scanState = "sent"
                QueryAuctionItems(AHT.currentItem, nil, nil, nil, nil, nil, AHT.scanPage, nil, nil)
            end
        end

    elseif AHT.scanState == "sent" then
        -- Timeout-Schutz: falls AUCTION_ITEM_LIST_UPDATE ausbleibt
        AHT.sentTimer = AHT.sentTimer + elapsed
        if AHT.sentTimer >= AHT.SENT_TIMEOUT then
            AHT.sentTimer = 0
            AHT.scanRetries = AHT.scanRetries + 1
            if AHT.scanRetries > AHT.MAX_RETRIES then
                AHT:Print(string.format(AHT.L["scan_timeout"], (AHT.currentItem or "?")))
                AHT:AdvanceScanQueue()
            else
                -- Retry: zurueck nach waiting
                AHT.scanState = "waiting"
                AHT.scanTimer = 0
            end
        end
    end
end

-- ── AH-Ergebnis verarbeiten ──────────────────────────────────
function AHT:OnAuctionListUpdate()
    if AHT.scanState ~= "sent" then return end
    AHT.sentTimer = 0

    local numItems = GetNumAuctionItems("list")

    for i = 1, numItems do
        local name, texture, count, quality, canUse, level,
              minBid, minIncrement, buyoutPrice,
              bidAmount, highBidder, owner = GetAuctionItemInfo("list", i)

        -- Nur exakte Namens-Treffer mit gueltigem Buyout beruecksichtigen
        if name == AHT.currentItem
           and buyoutPrice and buyoutPrice > 0
           and count and count > 0 then
            local ppu = math.floor(buyoutPrice / count)
            if not AHT.scanMinPrices[name] or ppu < AHT.scanMinPrices[name] then
                AHT.scanMinPrices[name] = ppu
            end
            -- Listing-Zaehler erhoehen
            AHT.scanListingCounts[name] = (AHT.scanListingCounts[name] or 0) + 1
        end
    end

    if numItems >= 50 then
        -- Moeglicherweise weitere Seiten vorhanden
        AHT.scanPage  = AHT.scanPage + 1
        AHT.scanState = "waiting"
        AHT.scanTimer = 0
    else
        -- Alle Seiten dieses Items gescannt
        AHT:AdvanceScanQueue()
    end
end

-- ── Scan abgeschlossen ───────────────────────────────────────
function AHT:OnScanComplete()
    AHT.scanState    = "idle"
    AHT.lastScanTime = GetTime()

    -- Scan-Ergebnisse in die persistente Preistabelle uebernehmen
    local now = time()
    for name, price in pairs(AHT.scanMinPrices) do
        AHT.prices[name] = price
        AHT.priceUpdated[name] = now
        AHT:AddPriceHistory(name, price)
    end

    -- Listing-Counts aktualisieren
    for name, cnt in pairs(AHT.scanListingCounts) do
        AHT.listingCounts[name] = cnt
    end
    -- Items ohne Listings: Count auf 0 setzen
    for _, item in ipairs(AHT.scanQueue) do
        if not AHT.scanListingCounts[item] then
            AHT.listingCounts[item] = 0
        end
    end

    -- Items die gescannt aber NICHT gefunden wurden: Preis loeschen
    -- (verhindert veraltete Preise fuer Items die nicht mehr im AH sind)
    for _, item in ipairs(AHT.scanQueue) do
        if not AHT.scanMinPrices[item] and not AHT:IsVendorItem(item) then
            AHT.prices[item] = nil
            AHT.priceUpdated[item] = nil
        end
    end
    AHT:SaveDB()

    -- Statistik
    local found, missing = 0, 0
    for _, item in ipairs(AHT.scanQueue) do
        if AHT.prices[item] then found = found + 1 else missing = missing + 1 end
    end

    local resultMsg = string.format(AHT.L["scan_complete"], found)
    if missing > 0 then
        resultMsg = resultMsg .. string.format(AHT.L["scan_missing"], missing)
    else
        resultMsg = resultMsg .. "."
    end
    AHT:Print(resultMsg)

    -- Schnaeppchen-Erkennung
    local deals = {}
    for name, price in pairs(AHT.scanMinPrices) do
        if AHT:IsDeal(name) then
            local avg = AHT:GetPriceAverage(name)
            local pctOff = math.floor((1 - price / avg) * 100)
            tinsert(deals, { name = name, price = price, avg = avg, pct = pctOff })
        end
    end
    if getn(deals) > 0 then
        AHT:Print(string.format(AHT.L["scan_deals_found"], getn(deals)))
        for _, d in ipairs(deals) do
            AHT:Print("  |cff00ffff\226\152\133|r " .. d.name .. ": " ..
                      AHT:FormatMoney(d.price) .. " |cffaaaaaa(Avg: " ..
                      AHT:FormatMoney(d.avg) .. ", -" .. d.pct .. "%%)|r")
        end
    end

    AHT:SetScanButtonText(AHT.L["scan_button"])
    AHT:CalculateMargins()
    AHT:RefreshUI()
end

-- ── Hilfsfunktionen ──────────────────────────────────────────
function AHT:SetScanButtonText(text)
    if AHT.scanButton then
        AHT.scanButton:SetText(text)
    end
end

function AHT:UpdateScanProgress()
    if TWOW_AHT_UI and TWOW_AHT_UI:IsVisible() then
        AHT:RefreshUI()
    end
end

-- ── Schnaeppchen-Scan ────────────────────────────────────────
-- Scannt ALLE bekannten Items (aus priceHistory) um Deals zu finden
function AHT:StartSnipeScan()
    if AHT:IsScanning() then
        AHT:Print(AHT.L["scan_already_running"])
        return
    end

    if not AuctionFrame or not AuctionFrame:IsVisible() then
        AHT:Print(AHT.L["scan_ah_required"])
        return
    end

    -- Alle bekannten Items aus priceHistory als Scan-Queue
    local seen  = {}
    local queue = {}

    for name, _ in pairs(AHT.priceHistory) do
        if not seen[name] and not AHT:IsVendorItem(name) then
            tinsert(queue, name)
            seen[name] = true
        end
    end

    if getn(queue) == 0 then
        AHT:Print(AHT.L["scan_no_history"])
        return
    end

    AHT.scanQueue     = queue
    AHT.scanQueueIdx  = 0
    AHT.scanMinPrices = {}
    AHT.scanListingCounts = {}

    AHT:Print(string.format(AHT.L["scan_snipe_start"], getn(queue)))
    AHT:SetScanButtonText(AHT.L["scan_cancel"])

    AHT:AdvanceScanQueue()
end
