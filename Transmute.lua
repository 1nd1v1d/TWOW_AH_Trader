-- ============================================================
-- TWOW AH Trader - Transmute.lua
-- Arkanit-Transmute Analyse, UI und Tooltip-Hook
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
-- ============================================================

local AHT = TWOW_AHT

AHT.transmuteScanState = "idle"
AHT.transmuteScanTimer = 0
AHT.transmuteSentTimer = 0
AHT.transmuteScanRetries = 0
AHT.transmuteScanQueue = {}
AHT.transmuteScanQueueIdx = 0
AHT.transmuteCurrentItem = nil
AHT.transmuteCurrentPage = 0
AHT.transmuteScanMinPrices = {}
AHT.transmuteScanListingCounts = {}

local TRANSMUTE_FRAME_W = 560
local TRANSMUTE_FRAME_H = 260

function AHT:GetArcaniteTransmuteNames()
    if GetLocale and GetLocale() == "deDE" then
        return {
            skill = "Transmutieren: Arkanit",
            output = "Arkanitbarren",
            thorium = "Thoriumbarren",
            crystal = "Arkankristall",
        }
    end

    return {
        skill = "Transmute: Arcanite",
        output = "Arcanite Bar",
        thorium = "Thorium Bar",
        crystal = "Arcane Crystal",
    }
end

function AHT:IsArcaniteBarName(itemName)
    local names = AHT:GetArcaniteTransmuteNames()
    return itemName and itemName == names.output
end

function AHT:IsTransmuteScanning()
    return AHT.transmuteScanState ~= "idle"
end

function AHT:CalculateArcaniteTransmuteFee()
    local names = AHT:GetArcaniteTransmuteNames()
    local sellPrice = AHT.prices[names.output]
    local thoriumPrice = AHT.prices[names.thorium]
    local crystalPrice = AHT.prices[names.crystal]
    local missing = {}

    if not sellPrice then tinsert(missing, names.output) end
    if not thoriumPrice then tinsert(missing, names.thorium) end
    if not crystalPrice then tinsert(missing, names.crystal) end

    local updatedAt = nil
    local timestamps = {
        AHT.priceUpdated[names.output],
        AHT.priceUpdated[names.thorium],
        AHT.priceUpdated[names.crystal],
    }

    for _, ts in ipairs(timestamps) do
        if ts then
            if not updatedAt or ts < updatedAt then
                updatedAt = ts
            end
        else
            updatedAt = nil
            break
        end
    end

    local result = {
        skillName = names.skill,
        outputName = names.output,
        thoriumName = names.thorium,
        crystalName = names.crystal,
        sellPrice = sellPrice,
        thoriumPrice = thoriumPrice,
        crystalPrice = crystalPrice,
        materialCost = nil,
        fee = nil,
        updatedAt = updatedAt,
        listingCount = AHT.listingCounts[names.output] or 0,
        missing = missing,
    }

    if sellPrice and thoriumPrice and crystalPrice then
        result.materialCost = thoriumPrice + crystalPrice
        result.fee = sellPrice - result.materialCost
    end

    AHT.transmuteResult = result
    return result
end

function AHT:AppendArcaniteTooltip(tooltip, result)
    local L = AHT.L
    local r = result or AHT:CalculateArcaniteTransmuteFee()

    tooltip:AddLine(" ")
    tooltip:AddLine(L["transmute_tt_header"], 1, 1, 1)

    if not r or getn(r.missing or {}) > 0 then
        if r and getn(r.missing or {}) > 0 then
            tooltip:AddLine(string.format(L["transmute_tt_missing"], table.concat(r.missing, ", ")), 1, 0.3, 0.3)
        else
            tooltip:AddLine(L["transmute_tt_no_data"], 1, 0.3, 0.3)
        end
        tooltip:AddLine(L["transmute_tt_hint"], 0.7, 0.7, 0.7)
        return
    end

    tooltip:AddDoubleLine(L["transmute_tt_sell"], AHT:FormatMoneyPlain(r.sellPrice), 1, 1, 1, 1, 1, 1)
    tooltip:AddDoubleLine(L["transmute_tt_thorium"], AHT:FormatMoneyPlain(r.thoriumPrice), 0.8, 0.8, 0.8, 1, 1, 1)
    tooltip:AddDoubleLine(L["transmute_tt_crystal"], AHT:FormatMoneyPlain(r.crystalPrice), 0.8, 0.8, 0.8, 1, 1, 1)
    tooltip:AddDoubleLine(L["transmute_tt_mats"], AHT:FormatMoneyPlain(r.materialCost), 1, 1, 0, 1, 1, 0)

    local fr, fg, fb = 0, 1, 0
    if r.fee < 0 then
        fr, fg, fb = 1, 0.3, 0.3
    end
    tooltip:AddDoubleLine(L["transmute_tt_fee"], AHT:FormatMoneyPlain(r.fee), fr, fg, fb, fr, fg, fb)

    if r.listingCount and r.listingCount > 0 then
        tooltip:AddDoubleLine(L["transmute_tt_listings"], tostring(r.listingCount), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
    end
    if r.updatedAt then
        tooltip:AddDoubleLine(L["transmute_tt_updated"], date(AHT.L["date_long"], r.updatedAt), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
    end
    tooltip:AddLine(L["transmute_tt_hint"], 0.7, 0.7, 0.7)
end

function AHT:HookTransmuteTooltip()
    if AHT._transmuteTooltipHooked or not GameTooltip then
        return
    end

    local prev = GameTooltip:GetScript("OnTooltipSetItem")
    GameTooltip:SetScript("OnTooltipSetItem", function()
        if prev then
            prev()
        end

        local itemName = nil
        if this.GetItem then
            local _, link = this:GetItem()
            if link then
                local _, _, parsedName = strfind(link, "%[(.-)%]")
                itemName = parsedName
            end
        end
        if not itemName and GameTooltipTextLeft1 and GameTooltipTextLeft1.GetText then
            itemName = GameTooltipTextLeft1:GetText()
        end
        if not AHT:IsArcaniteBarName(itemName) then
            return
        end

        AHT:AppendArcaniteTooltip(this)
        this:Show()
    end)

    AHT._transmuteTooltipHooked = true
end

function AHT:CreateTransmuteButton()
    if AHT.transmuteButton then
        AHT.transmuteButton:Show()
        return
    end

    local btn = CreateFrame("Button", "TWOW_AHT_TransmuteBtn", AuctionFrame, "UIPanelButtonTemplate")
    btn:SetWidth(160)
    btn:SetHeight(22)
    btn:SetText(AHT.L["transmute_button"])
    btn:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 350, -28)
    btn:SetScript("OnClick", function()
        if AHT:IsTransmuteScanning() then
            AHT:CancelTransmuteScan()
        else
            AHT:ShowTransmuteUI()
        end
    end)
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:AddLine(AHT.L["transmute_title"])
        if AHT:IsTransmuteScanning() then
            GameTooltip:AddLine(AHT.L["transmute_tooltip_cancel"], 1, 0.5, 0.5)
        else
            GameTooltip:AddLine(AHT.L["transmute_tooltip_open"], 1, 1, 1)
            GameTooltip:AddLine(AHT.L["transmute_tooltip_last"], 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    AHT.transmuteButton = btn
end

function AHT:StartTransmuteScan()
    local names = AHT:GetArcaniteTransmuteNames()

    if AHT:IsTransmuteScanning() then
        AHT:Print(AHT.L["transmute_scan_already_running"])
        return
    end
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        AHT:Print(AHT.L["scan_ah_required"])
        return
    end

    AHT.transmuteScanQueue = { names.output, names.thorium, names.crystal }
    AHT.transmuteScanQueueIdx = 0
    AHT.transmuteScanMinPrices = {}
    AHT.transmuteScanListingCounts = {}
    AHT.transmuteScanState = "waiting"
    AHT.transmuteScanTimer = 0
    AHT.transmuteSentTimer = 0

    AHT:Print(string.format(AHT.L["transmute_scan_start"], getn(AHT.transmuteScanQueue)))
    AHT:AdvanceTransmuteScanQueue()
    AHT:RefreshTransmuteUI()
end

function AHT:CancelTransmuteScan()
    if not AHT:IsTransmuteScanning() then
        return
    end

    AHT.transmuteScanState = "idle"
    AHT:Print(AHT.L["transmute_scan_cancelled"])
    AHT:RefreshTransmuteUI()
end

function AHT:AdvanceTransmuteScanQueue()
    AHT.transmuteScanQueueIdx = AHT.transmuteScanQueueIdx + 1
    if AHT.transmuteScanQueueIdx > getn(AHT.transmuteScanQueue) then
        AHT:OnTransmuteScanComplete()
        return
    end

    AHT.transmuteCurrentItem = AHT.transmuteScanQueue[AHT.transmuteScanQueueIdx]
    AHT.transmuteCurrentPage = 0
    AHT.transmuteScanRetries = 0
    AHT.transmuteScanState = "waiting"
    AHT.transmuteScanTimer = 0
    AHT.transmuteSentTimer = 0
end

function AHT:OnUpdateTransmute(elapsed)
    if AHT.transmuteScanState == "waiting" then
        AHT.transmuteScanTimer = AHT.transmuteScanTimer + elapsed
        AHT.transmuteSentTimer = AHT.transmuteSentTimer + elapsed

        if AHT.transmuteSentTimer >= AHT.WAIT_TIMEOUT then
            AHT:Print(string.format(AHT.L["scan_timeout"], AHT.transmuteCurrentItem or "?"))
            AHT:AdvanceTransmuteScanQueue()
            return
        end

        if AHT.transmuteScanTimer >= AHT.SCAN_DELAY then
            AHT.transmuteScanTimer = 0
            if CanSendAuctionQuery() then
                local invTypeIndex, classIndex, subClassIndex = AHT:GetAuctionQueryFilters(AHT.transmuteCurrentItem)
                AHT.transmuteSentTimer = 0
                AHT.transmuteScanState = "sent"
                QueryAuctionItems(AHT.transmuteCurrentItem, nil, nil, invTypeIndex, classIndex, subClassIndex, AHT.transmuteCurrentPage, nil, nil)
            end
        end
    elseif AHT.transmuteScanState == "sent" then
        AHT.transmuteSentTimer = AHT.transmuteSentTimer + elapsed
        if AHT.transmuteSentTimer >= AHT.SENT_TIMEOUT then
            AHT.transmuteSentTimer = 0
            AHT.transmuteScanRetries = AHT.transmuteScanRetries + 1
            if AHT.transmuteScanRetries > AHT.MAX_RETRIES then
                AHT:Print(string.format(AHT.L["scan_timeout"], AHT.transmuteCurrentItem or "?"))
                AHT:AdvanceTransmuteScanQueue()
            else
                AHT.transmuteScanState = "waiting"
                AHT.transmuteScanTimer = 0
            end
        end
    end
end

function AHT:OnTransmuteAuctionListUpdate()
    if AHT.transmuteScanState ~= "sent" then return end
    AHT.transmuteSentTimer = 0

    local numItems = GetNumAuctionItems("list")
    local playerName = UnitName("player")

    for i = 1, numItems do
        local name, _, count, _, _, _, _, _, buyoutPrice, _, _, owner = GetAuctionItemInfo("list", i)
        if name == AHT.transmuteCurrentItem
           and buyoutPrice and buyoutPrice > 0
           and count and count > 0
           and owner ~= playerName then
            local ppu = math.floor(buyoutPrice / count)
            if not AHT.transmuteScanMinPrices[name] or ppu < AHT.transmuteScanMinPrices[name] then
                AHT.transmuteScanMinPrices[name] = ppu
            end
            AHT.transmuteScanListingCounts[name] = (AHT.transmuteScanListingCounts[name] or 0) + 1
        end
    end

    if numItems >= 50 then
        AHT.transmuteCurrentPage = AHT.transmuteCurrentPage + 1
        AHT.transmuteScanState = "waiting"
        AHT.transmuteScanTimer = 0
    else
        AHT:AdvanceTransmuteScanQueue()
    end
end

function AHT:OnTransmuteScanComplete()
    local names = AHT:GetArcaniteTransmuteNames()
    local now = time()
    local tracked = { names.output, names.thorium, names.crystal }

    AHT.transmuteScanState = "idle"
    for _, itemName in ipairs(tracked) do
        local price = AHT.transmuteScanMinPrices[itemName]
        if price then
            AHT.prices[itemName] = price
            AHT.priceUpdated[itemName] = now
            AHT:AddPriceHistory(itemName, price)
        else
            AHT.prices[itemName] = nil
            AHT.priceUpdated[itemName] = nil
        end
        AHT.listingCounts[itemName] = AHT.transmuteScanListingCounts[itemName] or 0
    end

    AHT:SaveDB()
    local result = AHT:CalculateArcaniteTransmuteFee()
    AHT:Print(string.format(AHT.L["transmute_scan_complete"], AHT:TableCount(AHT.transmuteScanMinPrices)))
    if result and result.fee then
        AHT:Print(string.format(
            AHT.L["transmute_scan_result"],
            AHT:FormatMoney(result.sellPrice),
            AHT:FormatMoney(result.materialCost),
            AHT:FormatMoney(result.fee)
        ))
    end
    AHT:RefreshTransmuteUI()
end

function AHT:ShowTransmuteUI()
    if not TWOW_AHT_TransmuteUI then
        AHT:CreateTransmuteUI()
    end
    AHT:CalculateArcaniteTransmuteFee()
    TWOW_AHT_TransmuteUI:Show()
    AHT:RefreshTransmuteUI()
end

function AHT:CreateTransmuteUI()
    if TWOW_AHT_TransmuteUI then return end

    local mainFrame = CreateFrame("Frame", "TWOW_AHT_TransmuteUI", UIParent)
    mainFrame:SetWidth(TRANSMUTE_FRAME_W)
    mainFrame:SetHeight(TRANSMUTE_FRAME_H)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    mainFrame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 32,
        insets   = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    mainFrame:SetBackdropColor(0.07, 0.07, 0.07, 1)
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:Hide()

    local titleTex = mainFrame:CreateTexture(nil, "ARTWORK")
    titleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleTex:SetWidth(320)
    titleTex:SetHeight(64)
    titleTex:SetPoint("TOP", mainFrame, "TOP", 0, 12)

    local titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", mainFrame, "TOP", 0, -5)
    titleText:SetText(AHT.L["transmute_title"])

    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() this:GetParent():Hide() end)

    local statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -28)
    statusText:SetWidth(TRANSMUTE_FRAME_W - 70)
    statusText:SetJustifyH("LEFT")
    mainFrame._statusText = statusText

    local missingText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    missingText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -48)
    missingText:SetWidth(TRANSMUTE_FRAME_W - 70)
    missingText:SetJustifyH("LEFT")
    mainFrame._missingText = missingText

    local headerSkill = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerSkill:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -84)
    headerSkill:SetWidth(180)
    headerSkill:SetJustifyH("LEFT")
    headerSkill:SetText("|cffffff00" .. AHT.L["transmute_col_skill"] .. "|r")

    local headerSell = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerSell:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 220, -84)
    headerSell:SetWidth(85)
    headerSell:SetJustifyH("RIGHT")
    headerSell:SetText("|cffffff00" .. AHT.L["transmute_col_sell"] .. "|r")

    local headerCost = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerCost:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 315, -84)
    headerCost:SetWidth(95)
    headerCost:SetJustifyH("RIGHT")
    headerCost:SetText("|cffffff00" .. AHT.L["transmute_col_cost"] .. "|r")

    local headerFee = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerFee:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 420, -84)
    headerFee:SetWidth(85)
    headerFee:SetJustifyH("RIGHT")
    headerFee:SetText("|cffffff00" .. AHT.L["transmute_col_fee"] .. "|r")

    local headerUpdated = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerUpdated:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -142)
    headerUpdated:SetWidth(120)
    headerUpdated:SetJustifyH("LEFT")
    headerUpdated:SetText("|cffffff00" .. AHT.L["transmute_col_updated"] .. "|r")

    local sepLine = mainFrame:CreateTexture(nil, "ARTWORK")
    sepLine:SetTexture(0.6, 0.6, 0.6, 0.4)
    sepLine:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -102)
    sepLine:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -14, -102)
    sepLine:SetHeight(1)

    local skillValue = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    skillValue:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -118)
    skillValue:SetWidth(180)
    skillValue:SetJustifyH("LEFT")
    mainFrame._skillValue = skillValue

    local sellValue = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sellValue:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 220, -118)
    sellValue:SetWidth(85)
    sellValue:SetJustifyH("RIGHT")
    mainFrame._sellValue = sellValue

    local costValue = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    costValue:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 315, -118)
    costValue:SetWidth(95)
    costValue:SetJustifyH("RIGHT")
    mainFrame._costValue = costValue

    local feeValue = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    feeValue:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 420, -118)
    feeValue:SetWidth(85)
    feeValue:SetJustifyH("RIGHT")
    mainFrame._feeValue = feeValue

    local updatedValue = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    updatedValue:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 145, -142)
    updatedValue:SetWidth(170)
    updatedValue:SetJustifyH("LEFT")
    mainFrame._updatedValue = updatedValue

    local listingsLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listingsLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 350, -142)
    listingsLabel:SetWidth(70)
    listingsLabel:SetJustifyH("LEFT")
    listingsLabel:SetText("|cffffff00" .. AHT.L["transmute_tt_listings"] .. "|r")

    local listingsValue = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    listingsValue:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 430, -142)
    listingsValue:SetWidth(60)
    listingsValue:SetJustifyH("LEFT")
    mainFrame._listingsValue = listingsValue

    local hintText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -172)
    hintText:SetWidth(TRANSMUTE_FRAME_W - 36)
    hintText:SetJustifyH("LEFT")
    hintText:SetText(AHT.L["transmute_tt_hint"])

    local scanBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    scanBtn:SetWidth(130)
    scanBtn:SetHeight(22)
    scanBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 14, 12)
    scanBtn:SetScript("OnClick", function()
        if AHT:IsTransmuteScanning() then
            AHT:CancelTransmuteScan()
        elseif not AuctionFrame or not AuctionFrame:IsVisible() then
            AHT:Print(AHT.L["scan_ah_required"])
        else
            AHT:StartTransmuteScan()
        end
    end)
    mainFrame._scanBtn = scanBtn

    local tooltipPreview = CreateFrame("Button", nil, mainFrame)
    tooltipPreview:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 14, -104)
    tooltipPreview:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -14, 46)
    tooltipPreview:EnableMouse(true)
    tooltipPreview:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        AHT:AppendArcaniteTooltip(GameTooltip)
        GameTooltip:Show()
    end)
    tooltipPreview:SetScript("OnLeave", function() GameTooltip:Hide() end)

    TWOW_AHT_TransmuteUI = mainFrame
end

function AHT:RefreshTransmuteUI()
    if AHT.CalculateArcaniteTransmuteFee then
        AHT:CalculateArcaniteTransmuteFee()
    end
    if not TWOW_AHT_TransmuteUI or not TWOW_AHT_TransmuteUI:IsVisible() then return end

    local frame = TWOW_AHT_TransmuteUI
    local result = AHT.transmuteResult or AHT:CalculateArcaniteTransmuteFee()

    if frame._scanBtn then
        if AHT:IsTransmuteScanning() then
            frame._scanBtn:SetText(AHT.L["btn_cancel_scan"])
        else
            frame._scanBtn:SetText(AHT.L["btn_scan"])
        end
    end

    if AHT:IsTransmuteScanning() then
        frame._statusText:SetText(string.format(
            AHT.L["transmute_status_scanning"],
            AHT.transmuteScanQueueIdx,
            getn(AHT.transmuteScanQueue),
            AHT.transmuteCurrentItem or "..."
        ))
    elseif result and result.fee then
        frame._statusText:SetText(AHT.L["transmute_status_ready"])
    else
        frame._statusText:SetText(AHT.L["transmute_status_no_data"])
    end

    if result and getn(result.missing or {}) > 0 then
        frame._missingText:SetText(string.format(AHT.L["transmute_missing"], table.concat(result.missing, ", ")))
    else
        frame._missingText:SetText("")
    end

    frame._skillValue:SetText((result and result.skillName) or "-")
    frame._sellValue:SetText(result and result.sellPrice and AHT:FormatMoney(result.sellPrice) or "|cffaaaaaa-|r")
    frame._costValue:SetText(result and result.materialCost and AHT:FormatMoney(result.materialCost) or "|cffaaaaaa-|r")

    if result and result.fee then
        local feeColor = "|cff00ff00"
        if result.fee < 0 then
            feeColor = "|cffff5555"
        end
        frame._feeValue:SetText(feeColor .. AHT:FormatMoney(result.fee) .. "|r")
    else
        frame._feeValue:SetText("|cffaaaaaa-|r")
    end

    frame._updatedValue:SetText(result and result.updatedAt and date(AHT.L["date_short"], result.updatedAt) or "|cffaaaaaa-|r")
    frame._listingsValue:SetText(result and tostring(result.listingCount or 0) or "0")
end

AHT:HookTransmuteTooltip()