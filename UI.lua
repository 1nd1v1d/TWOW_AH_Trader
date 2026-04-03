-- ============================================================
-- TWOW AH Trader - UI.lua
-- Ergebnisfenster mit scrollbarer Ergebnisliste + Rezeptauswahl
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
-- ============================================================

local AHT = TWOW_AHT

-- ── Layout-Konstanten ────────────────────────────────────────
local FRAME_W  = 780
local FRAME_H  = 480
local ROW_H    = 20
local MAX_ROWS = 14

-- y-Offsets relativ zur Frame-Oberkante
local HEADER_Y   = -72
local FIRST_ROW_Y = -93

-- Spaltendefinitionen (Labels werden in InitLocaleLabels gesetzt)
local COLS = {
    { id="sel",     label="",              w=18,  x=12  },
    { id="rank",    label="#",             w=20,  x=32  },
    { id="name",    label="",              w=175, x=55  },
    { id="cost",    label="",              w=90,  x=233 },
    { id="sell",    label="",              w=90,  x=326 },
    { id="fee",     label="",              w=75,  x=419 },
    { id="profit",  label="",              w=90,  x=497, sortable=true },
    { id="margin",  label="",              w=55,  x=590, sortable=true },
    { id="updated", label="",              w=90,  x=650 },
}

local scrollOffset = 0
local rowFrames    = {}

-- ── Hauptframe ───────────────────────────────────────────────
local mainFrame = CreateFrame("Frame", "TWOW_AHT_UI", UIParent)
mainFrame:SetWidth(FRAME_W)
mainFrame:SetHeight(FRAME_H)
mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
mainFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true, tileSize = 32, edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 },
})
mainFrame:EnableMouse(true)
mainFrame:SetMovable(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function() this:StartMoving() end)
mainFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
mainFrame:SetFrameStrata("DIALOG")
mainFrame:Hide()
TWOW_AHT_UI = mainFrame

-- Mausrad-Scrolling
mainFrame:EnableMouseWheel(true)
mainFrame:SetScript("OnMouseWheel", function()
    if arg1 > 0 then
        if scrollOffset > 0 then
            scrollOffset = scrollOffset - 1
            AHT:RefreshUI()
        end
    else
        if scrollOffset + MAX_ROWS < getn(AHT.displayResults) then
            scrollOffset = scrollOffset + 1
            AHT:RefreshUI()
        end
    end
end)

-- ── Titelleiste ───────────────────────────────────────────────
local titleTex = mainFrame:CreateTexture(nil, "ARTWORK")
titleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
titleTex:SetWidth(320)
titleTex:SetHeight(64)
titleTex:SetPoint("TOP", mainFrame, "TOP", 0, 12)

local titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOP", mainFrame, "TOP", 0, -5)
titleText:SetText("TWOW AH Trader")

-- Spalten-Labels werden spaeter via InitLocaleLabels gesetzt
local colLabelMap = {
    name    = "col_potion",
    cost    = "col_cost",
    sell    = "col_sell",
    fee     = "col_fee",
    profit  = "col_profit",
    margin  = "col_margin",
    updated = "col_updated",
}

local function InitLocaleLabels()
    local L = AHT.L
    for _, col in ipairs(COLS) do
        local key = colLabelMap[col.id]
        if key then col.label = L[key] end
    end
end

local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -5, -5)
closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

-- ── Status & Empfehlungszeile ─────────────────────────────────
local statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -28)
statusText:SetWidth(FRAME_W - 70)
statusText:SetJustifyH("LEFT")
statusText:SetText(AHT.L and AHT.L["status_open_alchemy_first"] or "")

local recText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
recText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -48)
recText:SetWidth(FRAME_W - 70)
recText:SetJustifyH("LEFT")
recText:SetText("")

-- ── Suchfeld ────────────────────────────────────────────────────────
local searchLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
searchLabel:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -175, -50)
searchLabel:SetText(AHT.L and AHT.L["search_label"] or "|cffaaaaaaSuche:|r")

local searchBox = CreateFrame("EditBox", "TWOW_AHT_SearchBox", mainFrame, "InputBoxTemplate")
searchBox:SetWidth(140)
searchBox:SetHeight(20)
searchBox:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -30, -48)
searchBox:SetAutoFocus(false)
searchBox:SetMaxLetters(30)
searchBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
searchBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
searchBox:SetScript("OnTextChanged", function()
    AHT.searchFilter = this:GetText() or ""
    scrollOffset = 0
    AHT:ApplyFilterAndSort()
    AHT:RefreshUI()
end)

-- ── Spalten-Header (sortierbar fuer Gewinn/Marge) ───────────────
local headerBtns = {}
for _, col in ipairs(COLS) do
    if col.id ~= "sel" then
        if col.sortable then
            local btn = CreateFrame("Button", nil, mainFrame)
            btn:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", col.x - 2, HEADER_Y + 2)
            btn:SetWidth(col.w + 4)
            btn:SetHeight(16)
            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetAllPoints(btn)
            fs:SetJustifyH("RIGHT")
            fs:SetText("|cffffff00" .. col.label .. "|r")
            btn._colId = col.id
            btn._label = col.label
            btn._fs    = fs
            btn:SetScript("OnClick", function()
                if AHT.sortMode == this._colId then
                    if AHT.sortDir == "desc" then
                        AHT.sortDir = "asc"
                    else
                        AHT.sortDir = "desc"
                    end
                else
                    AHT.sortMode = this._colId
                    AHT.sortDir  = "desc"
                end
                scrollOffset = 0
                AHT:ApplyFilterAndSort()
                AHT:RefreshUI()
            end)
            btn:SetScript("OnEnter", function()
                GameTooltip:SetOwner(this, "ANCHOR_TOP")
                GameTooltip:AddLine(AHT.L["sort_tooltip"])
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            headerBtns[col.id] = btn
        else
            local fs = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", col.x, HEADER_Y)
            fs:SetWidth(col.w)
            fs:SetJustifyH(col.id == "name" and "LEFT" or "RIGHT")
            fs:SetText("|cffffff00" .. col.label .. "|r")
        end
    end
end
AHT.headerBtns = headerBtns

-- Trennlinie unter dem Header
local sepLine = mainFrame:CreateTexture(nil, "ARTWORK")
sepLine:SetTexture(0.6, 0.6, 0.6, 0.4)
sepLine:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  14,  HEADER_Y - 14)
sepLine:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -14, HEADER_Y - 14)
sepLine:SetHeight(1)

-- ── Datenzeilen ───────────────────────────────────────────────
local function CreateDataRow(rowIndex)
    local yOffset = FIRST_ROW_Y - (rowIndex - 1) * ROW_H

    local row = CreateFrame("Button", nil, mainFrame)
    row:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  10, yOffset)
    row:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, yOffset)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("RightButtonUp", "LeftButtonUp")

    -- Abwechselnder Zeilenhintergrund
    if mod(rowIndex, 2) == 0 then
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(1, 1, 1, 0.04)
        bg:SetAllPoints(row)
    end

    local cells = {}
    for _, col in ipairs(COLS) do
        if col.id == "sel" then
            -- Checkbox fuer Rezeptauswahl
            local cb = CreateFrame("CheckButton", "TWOW_AHT_CB" .. rowIndex, row, "UICheckButtonTemplate")
            cb:SetWidth(18)
            cb:SetHeight(18)
            cb:SetPoint("LEFT", row, "LEFT", col.x - 10, 0)
            cb._rowIndex = rowIndex
            cb:SetScript("OnClick", function()
                local idx = this._rowIndex + scrollOffset
                if idx <= getn(AHT.displayResults) then
                    local rName = AHT.displayResults[idx].name
                    if this:GetChecked() then
                        AHT.selected[rName] = true
                    else
                        AHT.selected[rName] = false
                    end
                    AHT:SaveDB()
                    AHT:RefreshUI()
                end
            end)
            cells[col.id] = cb
        else
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", row, "LEFT", col.x - 10, 0)
            fs:SetWidth(col.w - 2)
            fs:SetJustifyH(col.id == "name" and "LEFT" or "RIGHT")
            fs:SetText("")
            cells[col.id] = fs
        end
    end

    -- Detail-Tooltip beim Ueberfahren der Zeile
    row:EnableMouse(true)
    row._rowIndex = rowIndex
    row:SetScript("OnEnter", function()
        local idx = this._rowIndex + scrollOffset
        if idx > getn(AHT.displayResults) then return end
        local r = AHT.displayResults[idx]
        GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("|cffffd700" .. r.name .. "|r", 1, 1, 1)
        GameTooltip:AddLine(" ")

        -- Kostenaufschluesselung
        if r.costDetails and getn(r.costDetails) > 0 then
            GameTooltip:AddLine(AHT.L["tt_ingred_header"])
            for _, d in ipairs(r.costDetails) do
                if d.source == "???" then
                    GameTooltip:AddDoubleLine(
                        "  " .. d.count .. "x " .. d.name,
                        AHT.L["tt_no_price"], 0.7, 0.7, 0.7)
                else
                    local dealTag = ""
                    if d.isDeal then dealTag = " |cff00ffff[DEAL]|r" end
                    local avgInfo = ""
                    if d.avgPrice then
                        avgInfo = " (Avg: " .. AHT:FormatMoneyPlain(d.avgPrice) .. ")"
                    end
                    GameTooltip:AddDoubleLine(
                        "  " .. d.count .. "x " .. d.name .. " |cff888888(" .. d.source .. ")|r" .. dealTag,
                        AHT:FormatMoneyPlain(d.ppu) .. " x" .. d.count .. " = " .. AHT:FormatMoneyPlain(d.total) .. avgInfo,
                        0.7, 0.7, 0.7, 1, 1, 1)
                end
            end
            GameTooltip:AddLine(" ")
        end

        -- Zusammenfassung
        if r.ingredCost and r.ingredCost > 0 then
            GameTooltip:AddDoubleLine(AHT.L["tt_ingred_total"],
                AHT:FormatMoneyPlain(r.ingredCost), 1, 1, 1, 1, 1, 1)
        end
        if r.sellPrice then
            local trendArrow = ""
            if r.sellTrend == "up" then trendArrow = " |cff00ff00^|r"
            elseif r.sellTrend == "down" then trendArrow = " |cffff5555v|r"
            elseif r.sellTrend == "stable" then trendArrow = " |cffffff00~|r" end
            GameTooltip:AddDoubleLine(AHT.L["tt_sell_price"] .. trendArrow,
                AHT:FormatMoneyPlain(r.sellPrice), 1, 1, 1, 1, 1, 1)
        end
        if r.avgSellPrice then
            GameTooltip:AddDoubleLine(AHT.L["tt_avg_price"],
                AHT:FormatMoneyPlain(r.avgSellPrice), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
        end
        if r.volume and r.volume > 0 then
            GameTooltip:AddDoubleLine(AHT.L["tt_ah_listings"],
                tostring(r.volume), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
        end
        if r.ahProvision and r.ahProvision > 0 then
            GameTooltip:AddDoubleLine(AHT.L["tt_ah_fee"],
                AHT:FormatMoneyPlain(r.ahProvision), 1, 0.5, 0.5, 1, 0.5, 0.5)
        end
        if r.depositCost and r.depositCost > 0 then
            GameTooltip:AddDoubleLine(AHT.L["tt_deposit"],
                AHT:FormatMoneyPlain(r.depositCost), 1, 0.5, 0.5, 1, 0.5, 0.5)
        end
        if r.profit then
            local pr, pg, pb = 0, 1, 0
            if r.profit < 0 then pr, pg, pb = 1, 0.3, 0.3 end
            GameTooltip:AddDoubleLine(AHT.L["tt_profit"],
                AHT:FormatMoneyPlain(r.profit), pr, pg, pb, pr, pg, pb)
        end
        if r.margin then
            GameTooltip:AddDoubleLine(AHT.L["tt_margin"],
                string.format("%.1f%%", r.margin), 1, 1, 0, 1, 1, 0)
        end
        if r.updatedAt then
            GameTooltip:AddDoubleLine(AHT.L["tt_updated"],
                date("%d.%m.%Y %H:%M", r.updatedAt), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
        end

        -- Inventar-Info
        local inBags = AHT:CountItemInBags(r.name)
        if inBags > 0 then
            GameTooltip:AddDoubleLine(AHT.L["tt_in_bags"],
                tostring(inBags), 0, 0.8, 1, 0, 0.8, 1)
        end

        if r.isDeal then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(AHT.L["tt_deal"])
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(AHT.L["tt_rightclick"])
        GameTooltip:AddLine(AHT.L["tt_shift_rightclick"])
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Rechtsklick: Kaufdialog oeffnen / Shift+Rechtsklick: Posten
    row:SetScript("OnClick", function()
        local idx = this._rowIndex + scrollOffset
        if idx > getn(AHT.displayResults) then return end
        local r = AHT.displayResults[idx]

        if arg1 == "RightButton" and IsShiftKeyDown() then
            -- Shift+Rechtsklick: Post-Dialog oeffnen
            local inBags = AHT:CountItemInBags(r.name)
            if inBags > 0 then
                AHT:ShowPostDialog(r.name, r)
            else
                AHT:Print(string.format(AHT.L["click_no_bags"], r.name))
            end
        elseif arg1 == "RightButton" then
            -- Normaler Rechtsklick: Zutaten kaufen
            if r.profit and r.profit > 0 then
                AHT:ShowBuyDialog(r)
            elseif r.notOnAH or getn(r.missingReag) > 0 then
                AHT:Print(string.format(AHT.L["click_no_data"], r.name))
            else
                AHT:Print(string.format(AHT.L["click_not_profitable"], r.name))
            end
        end
    end)

    row.cells = cells
    return row
end

for i = 1, MAX_ROWS do
    rowFrames[i] = CreateDataRow(i)
end

-- ── Scroll-Buttons ────────────────────────────────────────────
local scrollUp = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
scrollUp:SetWidth(24)
scrollUp:SetHeight(16)
scrollUp:SetText("/\\")
scrollUp:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -18, 55)
scrollUp:SetScript("OnClick", function()
    if scrollOffset > 0 then
        scrollOffset = scrollOffset - 1
        AHT:RefreshUI()
    end
end)

local scrollDown = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
scrollDown:SetWidth(24)
scrollDown:SetHeight(16)
scrollDown:SetText("\\/")
scrollDown:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -18, 35)
scrollDown:SetScript("OnClick", function()
    if scrollOffset + MAX_ROWS < getn(AHT.displayResults) then
        scrollOffset = scrollOffset + 1
        AHT:RefreshUI()
    end
end)

-- ── Button-Leiste unten ───────────────────────────────────────
-- Scannen / Abbrechen Button
local scanBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
scanBtn:SetWidth(130)
scanBtn:SetHeight(22)
scanBtn:SetText(AHT.L and AHT.L["btn_scan"] or "Scan")
scanBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 14, 12)
scanBtn:SetScript("OnClick", function()
    if AHT:IsScanning() then
        AHT:CancelScan()
    elseif not AuctionFrame or not AuctionFrame:IsVisible() then
        AHT:Print(AHT.L["scan_ah_required"])
    else
        scrollOffset = 0
        AHT:StartScan()
    end
end)
scanBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    if AHT:IsScanning() then
        GameTooltip:AddLine(AHT.L["scan_cancel_tooltip"])
    else
        GameTooltip:AddLine(AHT.L["scan_start_tooltip"])
        GameTooltip:AddLine(AHT.L["scan_ah_tooltip"], 1, 1, 1)
    end
    GameTooltip:Show()
end)
scanBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
AHT.uiScanBtn = scanBtn

-- Alle auswaehlen
local selAllBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
selAllBtn:SetWidth(90)
selAllBtn:SetHeight(22)
selAllBtn:SetText(AHT.L and AHT.L["btn_select_all"] or "All on")
selAllBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 150, 12)
selAllBtn:SetScript("OnClick", function()
    for _, recipe in ipairs(AHT.recipes) do
        AHT.selected[recipe.name] = true
    end
    AHT:SaveDB()
    AHT:RefreshUI()
end)

-- Alle abwaehlen
local selNoneBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
selNoneBtn:SetWidth(90)
selNoneBtn:SetHeight(22)
selNoneBtn:SetText(AHT.L and AHT.L["btn_deselect_all"] or "All off")
selNoneBtn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 245, 12)
selNoneBtn:SetScript("OnClick", function()
    for _, recipe in ipairs(AHT.recipes) do
        AHT.selected[recipe.name] = false
    end
    AHT:SaveDB()
    AHT:RefreshUI()
end)

-- ── Zeitstempel ───────────────────────────────────────────────
local lastScanLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lastScanLabel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -50, 15)
lastScanLabel:SetJustifyH("RIGHT")
lastScanLabel:SetText("")
AHT.lastScanLabel = lastScanLabel

-- Periodisches Update des Zeitstempels
mainFrame:SetScript("OnUpdate", function()
    if AHT.lastScanTime then
        local elapsed = math.floor(GetTime() - AHT.lastScanTime)
        local mins    = math.floor(elapsed / 60)
        local secs    = mod(elapsed, 60)
        lastScanLabel:SetText(
            string.format(AHT.L["status_last_scan"], mins, secs))
    end
end)

-- ── Anzeige aktualisieren ─────────────────────────────────────
function AHT:ShowUI()
    scrollOffset = 0
    InitLocaleLabels()
    -- Update search label
    searchLabel:SetText(AHT.L["search_label"])
    -- Update button labels
    scanBtn:SetText(AHT.L["btn_scan"])
    selAllBtn:SetText(AHT.L["btn_select_all"])
    selNoneBtn:SetText(AHT.L["btn_deselect_all"])
    mainFrame:Show()
    AHT:RefreshUI()
end

function AHT:RefreshUI()
    if not mainFrame:IsVisible() then return end

    local allResults  = AHT.results
    local dispResults = AHT.displayResults

    -- Sortier-Indikatoren in den Headers updaten
    for id, btn in pairs(AHT.headerBtns or {}) do
        local arrow = ""
        if AHT.sortMode == id then
            if AHT.sortDir == "desc" then arrow = " v" else arrow = " ^" end
        end
        btn._fs:SetText("|cffffff00" .. btn._label .. arrow .. "|r")
    end

    -- Scan-Button Text updaten
    if AHT:IsScanning() then
        if AHT.uiScanBtn then
            AHT.uiScanBtn:SetText(AHT.L["btn_cancel_scan"])
        end
        statusText:SetText(string.format(AHT.L["status_scanning"],
                           AHT.scanQueueIdx, getn(AHT.scanQueue),
                           (AHT.currentItem or "...")))
        recText:SetText("")
    else
        if AHT.uiScanBtn then
            AHT.uiScanBtn:SetText(AHT.L["btn_scan"])
        end

        if getn(allResults) == 0 then
            if getn(AHT.recipes) == 0 then
                statusText:SetText(AHT.L["status_open_alchemy"])
            else
                statusText:SetText(string.format(AHT.L["status_recipes_ready"], getn(AHT.recipes)))
            end
            recText:SetText("")
        else
            local totalCount = getn(allResults)
            local dispCount  = getn(dispResults)
            if AHT.searchFilter ~= "" and dispCount < totalCount then
                statusText:SetText(string.format(AHT.L["status_filter_active"], dispCount, totalCount))
            else
                statusText:SetText(string.format(AHT.L["status_analyzed"], totalCount))
            end

            -- Beste profitable Option hervorheben (nur aktivierte)
            local best = nil
            for _, r in ipairs(allResults) do
                if r.profit and r.profit > 0 and AHT.selected[r.name] ~= false then
                    if not best or r.profit > best.profit then
                        best = r
                    end
                end
            end

            if best then
                recText:SetText(string.format(AHT.L["status_recommend"],
                                best.name,
                                AHT:FormatMoney(best.profit),
                                string.format("%.0f%%%%", best.margin)))
            else
                recText:SetText(AHT.L["status_no_profit"])
            end
        end
    end

    -- Datenzeilen befuellen
    for i = 1, MAX_ROWS do
        local idx = i + scrollOffset
        local row = rowFrames[i]

        if idx <= getn(dispResults) then
            local r     = dispResults[idx]
            local cells = row.cells
            row:Show()

            -- Checkbox
            local cb = cells["sel"]
            if AHT.selected[r.name] ~= false then
                cb:SetChecked(true)
            else
                cb:SetChecked(false)
            end

            -- Rang
            cells["rank"]:SetText("|cffaaaaaa" .. idx .. "|r")

            -- Deaktivierte Rezepte werden gedaempft dargestellt
            local isOff = (AHT.selected[r.name] == false)

            -- Itemname (Farbe nach Profitabilitaet)
            local nameColor
            if isOff then
                nameColor = "|cff888888"
            elseif r.notOnAH then
                nameColor = "|cff888888"
            elseif getn(r.missingReag) > 0 then
                nameColor = "|cffaaaaaa"
            elseif r.profit and r.profit >= 0 and r.margin and r.margin >= 20 then
                nameColor = "|cff00ff00"
            elseif r.profit and r.profit >= 0 then
                nameColor = "|cffffff00"
            else
                nameColor = "|cffff5555"
            end
            local dealPrefix = ""
            if r.isDeal or r.hasReagDeal then dealPrefix = "|cff00ffff* |r" end
            cells["name"]:SetText(dealPrefix .. nameColor .. r.name .. "|r")

            -- Zutatenkosten (immer anzeigen, auch wenn deaktiviert)
            if r.ingredCost > 0 then
                if isOff then
                    cells["cost"]:SetText("|cff888888" .. AHT:FormatMoneyPlain(r.ingredCost) .. "|r")
                else
                    cells["cost"]:SetText(AHT:FormatMoney(r.ingredCost))
                end
            elseif getn(r.missingReag) > 0 then
                cells["cost"]:SetText(AHT.L["col_unknown_cost"])
            else
                cells["cost"]:SetText("|cffaaaaaa-|r")
            end

            -- Verkaufspreis
            if r.sellPrice then
                if isOff then
                    cells["sell"]:SetText("|cff888888" .. AHT:FormatMoneyPlain(r.sellPrice) .. "|r")
                else
                    cells["sell"]:SetText(AHT:FormatMoney(r.sellPrice))
                end
            else
                cells["sell"]:SetText(AHT.L["col_not_in_ah"])
            end

            -- AH-Gebuehren
            if r.ahProvision ~= nil then
                local totalFee = (r.ahProvision or 0) + (r.depositCost or 0)
                if isOff then
                    cells["fee"]:SetText("|cff888888" .. AHT:FormatMoneyPlain(totalFee) .. "|r")
                else
                    cells["fee"]:SetText(AHT:FormatMoney(totalFee))
                end
            else
                cells["fee"]:SetText("|cffaaaaaa-|r")
            end

            -- Gewinn
            if r.profit ~= nil then
                if isOff then
                    cells["profit"]:SetText("|cff888888" .. AHT:FormatMoneyPlain(r.profit) .. "|r")
                else
                    local col
                    if r.profit >= 0 then col = "|cff00ff00" else col = "|cffff5555" end
                    cells["profit"]:SetText(col .. AHT:FormatMoney(r.profit) .. "|r")
                end
            elseif r.notOnAH then
                cells["profit"]:SetText("|cffaaaaaa-|r")
            elseif getn(r.missingReag) > 0 then
                cells["profit"]:SetText(AHT.L["col_missing_prefix"] ..
                                        table.concat(r.missingReag, ", ") .. "|r")
            else
                cells["profit"]:SetText("|cffaaaaaa?|r")
            end

            -- Marge
            if r.margin ~= nil then
                local pct = string.format("%.0f%%%%", r.margin)
                local col
                if isOff then
                    col = "|cff888888"
                elseif r.margin >= 20 then
                    col = "|cff00ff00"
                elseif r.margin >= 0 then
                    col = "|cffffff00"
                else
                    col = "|cffff5555"
                end
                cells["margin"]:SetText(col .. pct .. "|r")
            else
                cells["margin"]:SetText("|cffaaaaaa-|r")
            end

            -- Aktualisiert (Datum + Uhrzeit)
            if r.updatedAt then
                cells["updated"]:SetText("|cffaaaaaa" .. date("%d.%m %H:%M", r.updatedAt) .. "|r")
            else
                cells["updated"]:SetText("|cffaaaaaa-|r")
            end

        else
            row:Hide()
        end
    end

    -- Scroll-Buttons aktualisieren
    if scrollOffset > 0 then
        scrollUp:Enable()
    else
        scrollUp:Disable()
    end
    if scrollOffset + MAX_ROWS < getn(dispResults) then
        scrollDown:Enable()
    else
        scrollDown:Disable()
    end
end

-- ══════════════════════════════════════════════════════════════
-- Kaufdialog-Popup
-- ══════════════════════════════════════════════════════════════

local buyFrame = CreateFrame("Frame", "TWOW_AHT_BuyDialog", UIParent)
buyFrame:SetWidth(340)
buyFrame:SetHeight(240)
buyFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
buyFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true, tileSize = 32, edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 },
})
buyFrame:EnableMouse(true)
buyFrame:SetMovable(true)
buyFrame:RegisterForDrag("LeftButton")
buyFrame:SetScript("OnDragStart", function() this:StartMoving() end)
buyFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
buyFrame:SetFrameStrata("FULLSCREEN_DIALOG")
buyFrame:Hide()

-- Titel
local buyTitleTex = buyFrame:CreateTexture(nil, "ARTWORK")
buyTitleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
buyTitleTex:SetWidth(260)
buyTitleTex:SetHeight(64)
buyTitleTex:SetPoint("TOP", buyFrame, "TOP", 0, 12)

local buyTitleText = buyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
buyTitleText:SetPoint("TOP", buyFrame, "TOP", 0, -5)
buyTitleText:SetText(AHT.L and AHT.L["buydlg_title"] or "Buy Reagents")

-- Schliessen
local buyCloseBtn = CreateFrame("Button", nil, buyFrame, "UIPanelCloseButton")
buyCloseBtn:SetPoint("TOPRIGHT", buyFrame, "TOPRIGHT", -5, -5)
buyCloseBtn:SetScript("OnClick", function() buyFrame:Hide() end)

-- Trank-Name
local buyNameLabel = buyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
buyNameLabel:SetPoint("TOPLEFT", buyFrame, "TOPLEFT", 20, -32)
buyNameLabel:SetWidth(300)
buyNameLabel:SetJustifyH("LEFT")

-- Marge-Info
local buyMarginLabel = buyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
buyMarginLabel:SetPoint("TOPLEFT", buyFrame, "TOPLEFT", 20, -52)
buyMarginLabel:SetWidth(300)
buyMarginLabel:SetJustifyH("LEFT")

-- Zutatenliste
local buyReagLabel = buyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
buyReagLabel:SetPoint("TOPLEFT", buyFrame, "TOPLEFT", 20, -75)
buyReagLabel:SetWidth(300)
buyReagLabel:SetJustifyH("LEFT")

-- Anzahl-Label
local buyCountLabel = buyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
buyCountLabel:SetPoint("TOPLEFT", buyFrame, "TOPLEFT", 20, -155)
buyCountLabel:SetText(AHT.L and AHT.L["buydlg_count_label"] or "Number of potions:")

-- Anzahl-Editbox
local buyCountBox = CreateFrame("EditBox", "TWOW_AHT_BuyCount", buyFrame, "InputBoxTemplate")
buyCountBox:SetWidth(50)
buyCountBox:SetHeight(20)
buyCountBox:SetPoint("LEFT", buyCountLabel, "RIGHT", 10, 0)
buyCountBox:SetAutoFocus(false)
buyCountBox:SetMaxLetters(4)
buyCountBox:SetNumeric(true)
buyCountBox:SetText("1")
buyCountBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
buyCountBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)

-- Geschaetzte Kosten
local buyEstLabel = buyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
buyEstLabel:SetPoint("TOPLEFT", buyFrame, "TOPLEFT", 20, -180)
buyEstLabel:SetWidth(300)
buyEstLabel:SetJustifyH("LEFT")

-- Aktualisiere Schaetzung wenn Anzahl sich aendert
buyCountBox:SetScript("OnTextChanged", function()
    local count = tonumber(buyCountBox:GetText()) or 0
    if count > 0 and buyFrame._recipe then
        local r = buyFrame._recipe
        local totalCost = r.ingredCost * count
        buyEstLabel:SetText(string.format(AHT.L["buydlg_est_cost"], AHT:FormatMoney(totalCost)))
    else
        buyEstLabel:SetText("")
    end
end)

-- Kaufen-Button
local buyConfirmBtn = CreateFrame("Button", nil, buyFrame, "UIPanelButtonTemplate")
buyConfirmBtn:SetWidth(120)
buyConfirmBtn:SetHeight(24)
buyConfirmBtn:SetText(AHT.L and AHT.L["btn_buy"] or "|cff00ff00Buy|r")
buyConfirmBtn:SetPoint("BOTTOMLEFT", buyFrame, "BOTTOMLEFT", 20, 14)
buyConfirmBtn:SetScript("OnClick", function()
    local count = tonumber(buyCountBox:GetText()) or 0
    if count <= 0 then
        AHT:Print(AHT.L["buydlg_invalid_count"])
        return
    end
    if not buyFrame._recipe then return end
    buyFrame:Hide()
    AHT:StartBuy(buyFrame._recipe, count)
end)

-- Abbrechen-Button
local buyCancelBtn = CreateFrame("Button", nil, buyFrame, "UIPanelButtonTemplate")
buyCancelBtn:SetWidth(120)
buyCancelBtn:SetHeight(24)
buyCancelBtn:SetText(AHT.L and AHT.L["btn_cancel"] or "Cancel")
buyCancelBtn:SetPoint("BOTTOMRIGHT", buyFrame, "BOTTOMRIGHT", -20, 14)
buyCancelBtn:SetScript("OnClick", function() buyFrame:Hide() end)

-- ── Kaufdialog oeffnen ────────────────────────────────────────
function AHT:ShowBuyDialog(recipe)
    buyFrame._recipe = recipe

    buyNameLabel:SetText("|cffffd700" .. recipe.name .. "|r")

    if recipe.margin then
        buyMarginLabel:SetText(string.format(AHT.L["buydlg_margin_info"],
                               string.format("%.1f%%%%", recipe.margin),
                               AHT:FormatMoney(recipe.profit)))
    else
        buyMarginLabel:SetText(AHT.L["buydlg_no_margin"])
    end

    -- Zutaten auflisten
    local lines = {}
    for _, reag in ipairs(recipe.reagents) do
        local price = AHT.vendorPrices[reag.name] or AHT.prices[reag.name]
        local src = AHT:IsVendorItem(reag.name) and "|cff888888(Vendor)|r" or "|cff888888(AH)|r"
        local priceStr = price and AHT:FormatMoney(price) or "|cffff4444?|r"
        tinsert(lines, reag.count .. "x " .. reag.name .. " " .. src .. " " .. priceStr .. "/St.")
    end
    buyReagLabel:SetText(table.concat(lines, "\n"))

    buyCountBox:SetText("1")

    -- Erste Schaetzung
    if recipe.ingredCost and recipe.ingredCost > 0 then
        buyEstLabel:SetText(string.format(AHT.L["buydlg_est_cost"],
                            AHT:FormatMoney(recipe.ingredCost)))
    else
        buyEstLabel:SetText("")
    end

    buyFrame:Show()
end

-- ══════════════════════════════════════════════════════════════
-- Post-Dialog-Popup (Stackgroesse waehlen vor dem Posten)
-- ══════════════════════════════════════════════════════════════

local postFrame = CreateFrame("Frame", "TWOW_AHT_PostDialog", UIParent)
postFrame:SetWidth(300)
postFrame:SetHeight(270)
postFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
postFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile     = true, tileSize = 32, edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 },
})
postFrame:EnableMouse(true)
postFrame:SetMovable(true)
postFrame:RegisterForDrag("LeftButton")
postFrame:SetScript("OnDragStart", function() this:StartMoving() end)
postFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
postFrame:SetFrameStrata("FULLSCREEN_DIALOG")
postFrame:Hide()

-- Titel
local postTitleTex = postFrame:CreateTexture(nil, "ARTWORK")
postTitleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
postTitleTex:SetWidth(260)
postTitleTex:SetHeight(64)
postTitleTex:SetPoint("TOP", postFrame, "TOP", 0, 12)

local postTitleText = postFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
postTitleText:SetPoint("TOP", postFrame, "TOP", 0, -5)
postTitleText:SetText(AHT.L and AHT.L["postdlg_title"] or "Post Potions")

-- Schliessen
local postCloseBtn = CreateFrame("Button", nil, postFrame, "UIPanelCloseButton")
postCloseBtn:SetPoint("TOPRIGHT", postFrame, "TOPRIGHT", -5, -5)
postCloseBtn:SetScript("OnClick", function() postFrame:Hide() end)

-- Trankname + Anzahl in Taschen
local postNameLabel = postFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
postNameLabel:SetPoint("TOPLEFT", postFrame, "TOPLEFT", 20, -32)
postNameLabel:SetWidth(260)
postNameLabel:SetJustifyH("LEFT")

local postBagsLabel = postFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
postBagsLabel:SetPoint("TOPLEFT", postFrame, "TOPLEFT", 20, -52)
postBagsLabel:SetWidth(260)
postBagsLabel:SetJustifyH("LEFT")

-- Preis-Info
local postPriceLabel = postFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
postPriceLabel:SetPoint("TOPLEFT", postFrame, "TOPLEFT", 20, -68)
postPriceLabel:SetWidth(260)
postPriceLabel:SetJustifyH("LEFT")

-- Stackgroesse-Label + Eingabefeld
local postStackLabel = postFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
postStackLabel:SetPoint("TOPLEFT", postFrame, "TOPLEFT", 20, -95)
postStackLabel:SetText(AHT.L and AHT.L["postdlg_stack_label"] or "Stack size:")

local postStackBox = CreateFrame("EditBox", "TWOW_AHT_PostStack", postFrame, "InputBoxTemplate")
postStackBox:SetWidth(40)
postStackBox:SetHeight(20)
postStackBox:SetPoint("LEFT", postStackLabel, "RIGHT", 10, 0)
postStackBox:SetAutoFocus(false)
postStackBox:SetMaxLetters(3)
postStackBox:SetNumeric(true)
postStackBox:SetText("1")
postStackBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
postStackBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)

-- Preset-Buttons (1, 5, 10, 20)
local presetSizes = { 1, 5, 10, 20 }
local presetBtns = {}
for i, sz in ipairs(presetSizes) do
    local pbtn = CreateFrame("Button", nil, postFrame, "UIPanelButtonTemplate")
    pbtn:SetWidth(32)
    pbtn:SetHeight(20)
    pbtn:SetText(tostring(sz))
    pbtn:SetPoint("TOPLEFT", postFrame, "TOPLEFT", 20 + (i - 1) * 38, -118)
    pbtn._size = sz
    pbtn:SetScript("OnClick", function()
        postStackBox:SetText(tostring(this._size))
    end)
    presetBtns[i] = pbtn
end

-- Stackanzahl-Label + Eingabefeld
local postCountLabel = postFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
postCountLabel:SetPoint("TOPLEFT", postFrame, "TOPLEFT", 175, -95)
postCountLabel:SetText(AHT.L and AHT.L["postdlg_count_label"] or "Stacks:")

local postCountBox = CreateFrame("EditBox", "TWOW_AHT_PostCount", postFrame, "InputBoxTemplate")
postCountBox:SetWidth(40)
postCountBox:SetHeight(20)
postCountBox:SetPoint("LEFT", postCountLabel, "RIGHT", 10, 0)
postCountBox:SetAutoFocus(false)
postCountBox:SetMaxLetters(4)
postCountBox:SetText("")
postCountBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
postCountBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)

-- Ergebnis-Zeile (Anzahl Auktionen + Stueck)
local postResultLabel = postFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
postResultLabel:SetPoint("TOPLEFT", postFrame, "TOPLEFT", 20, -140)
postResultLabel:SetWidth(260)
postResultLabel:SetJustifyH("LEFT")

-- Helfer: Ergebnis-Zeile aktualisieren
local function UpdatePostResultLabel()
    local sz = tonumber(postStackBox:GetText()) or 0
    local total = postFrame._totalCount or 0
    if sz <= 0 or total <= 0 then
        postResultLabel:SetText("")
        return
    end
    local maxAuctions = math.ceil(total / sz)
    local countText = string.gsub(postCountBox:GetText() or "", "^%s*(.-)%s*$", "%1")
    local wantedStacks = tonumber(countText)
    local auctions = maxAuctions
    if wantedStacks and wantedStacks > 0 and wantedStacks < maxAuctions then
        auctions = wantedStacks
    end
    local units = auctions * sz
    if units > total then units = total end
    postResultLabel:SetText(string.format(AHT.L["postdlg_result_info"], auctions, units))
end

postStackBox:SetScript("OnTextChanged", function() UpdatePostResultLabel() end)
postCountBox:SetScript("OnTextChanged", function() UpdatePostResultLabel() end)

-- Preis-Check: Button + Ergebnis-Labels
local postCheckBtn = CreateFrame("Button", nil, postFrame, "UIPanelButtonTemplate")
postCheckBtn:SetWidth(120)
postCheckBtn:SetHeight(20)
postCheckBtn:SetText(AHT.L and AHT.L["btn_check_price"] or "Check Price")
postCheckBtn:SetPoint("TOPLEFT", postFrame, "TOPLEFT", 20, -160)

local postAHPriceLabel = postFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
postAHPriceLabel:SetPoint("LEFT", postCheckBtn, "RIGHT", 8, 0)
postAHPriceLabel:SetWidth(140)
postAHPriceLabel:SetJustifyH("LEFT")

local postDiffLabel = postFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
postDiffLabel:SetPoint("TOPLEFT", postFrame, "TOPLEFT", 20, -182)
postDiffLabel:SetWidth(260)
postDiffLabel:SetJustifyH("LEFT")

postCheckBtn:SetScript("OnClick", function()
    if not postFrame._recipeName then return end
    if AHT:IsScanning() or AHT:IsBuying() then return end
    if not AuctionFrame or not AuctionFrame:IsVisible() then
        AHT:Print(AHT.L["scan_ah_required"])
        return
    end
    -- Start price check
    AHT.postPriceCheck = {
        name     = postFrame._recipeName,
        minPPU   = nil,
        page     = 0,
        state    = "waiting",
        timer    = 0,
    }
    postAHPriceLabel:SetText(AHT.L["postdlg_checking"])
    postDiffLabel:SetText("")
    postCheckBtn:Disable()
end)

-- Posten-Button
local postConfirmBtn = CreateFrame("Button", nil, postFrame, "UIPanelButtonTemplate")
postConfirmBtn:SetWidth(120)
postConfirmBtn:SetHeight(24)
postConfirmBtn:SetText(AHT.L and AHT.L["btn_post"] or "|cff00ff00Post|r")
postConfirmBtn:SetPoint("BOTTOMLEFT", postFrame, "BOTTOMLEFT", 20, 14)
postConfirmBtn:SetScript("OnClick", function()
    local sz = tonumber(postStackBox:GetText()) or 0
    if sz <= 0 then
        AHT:Print(AHT.L["buydlg_invalid_count"])
        return
    end
    if not postFrame._recipe then return end
    local countText = string.gsub(postCountBox:GetText() or "", "^%s*(.-)%s*$", "%1")
    local maxStacks = tonumber(countText) or 0
    if maxStacks <= 0 then maxStacks = nil end
    postFrame:Hide()
    AHT:StartPost(postFrame._recipeName, postFrame._recipe, sz, maxStacks)
end)

-- Abbrechen-Button
local postCancelBtn = CreateFrame("Button", nil, postFrame, "UIPanelButtonTemplate")
postCancelBtn:SetWidth(120)
postCancelBtn:SetHeight(24)
postCancelBtn:SetText(AHT.L and AHT.L["btn_cancel"] or "Cancel")
postCancelBtn:SetPoint("BOTTOMRIGHT", postFrame, "BOTTOMRIGHT", -20, 14)
postCancelBtn:SetScript("OnClick", function() postFrame:Hide() end)

-- ── Post-Dialog oeffnen ───────────────────────────────────────
function AHT:ShowPostDialog(recipeName, recipe)
    local L = AHT.L
    postFrame._recipeName = recipeName
    postFrame._recipe     = recipe

    local totalCount = AHT:CountItemInBags(recipeName)
    postFrame._totalCount = totalCount

    postTitleText:SetText(L["postdlg_title"])
    postNameLabel:SetText("|cffffd700" .. recipeName .. "|r")
    postBagsLabel:SetText(string.format(L["postdlg_in_bags"], totalCount, recipeName))

    local price = AHT:CalcPostPrice(recipe)
    postPriceLabel:SetText(string.format(L["postdlg_price_info"], AHT:FormatMoney(price)))

    postStackLabel:SetText(L["postdlg_stack_label"])
    postConfirmBtn:SetText(L["btn_post"])
    postCancelBtn:SetText(L["btn_cancel"])

    postStackBox:SetText("1")
    postCountBox:SetText("")
    postCountLabel:SetText(L["postdlg_count_label"])

    -- Price-Check zuruecksetzen
    AHT.postPriceCheck = nil
    postAHPriceLabel:SetText("")
    postDiffLabel:SetText("")
    postCheckBtn:Enable()
    postCheckBtn:SetText(L["btn_check_price"])

    -- Auktionsanzahl initial berechnen
    UpdatePostResultLabel()

    postFrame:Show()
end

-- ── Preis-Check: AH-Ergebnis verarbeiten ──────────────────────
function AHT:OnPostPriceCheckResult()
    local pc = AHT.postPriceCheck
    if not pc or pc.state ~= "sent" then return end

    local numItems = GetNumAuctionItems("list")
    for i = 1, numItems do
        local name, _, count, _, _, _,
              _, _, buyoutPrice = GetAuctionItemInfo("list", i)
        if name == pc.name and buyoutPrice and buyoutPrice > 0 and count and count > 0 then
            local ppu = math.floor(buyoutPrice / count)
            if not pc.minPPU or ppu < pc.minPPU then
                pc.minPPU = ppu
            end
        end
    end

    if numItems >= 50 then
        -- Weitere Seiten
        pc.page  = pc.page + 1
        pc.state = "waiting"
        pc.timer = 0
    else
        -- Fertig: Ergebnis anzeigen
        AHT:ShowPriceCheckResult()
    end
end

function AHT:ShowPriceCheckResult()
    local pc = AHT.postPriceCheck
    if not pc then return end
    local L = AHT.L

    if not pc.minPPU then
        postAHPriceLabel:SetText(L["postdlg_no_ah_price"])
        postDiffLabel:SetText("")
    else
        postAHPriceLabel:SetText(string.format(L["postdlg_ah_price"], AHT:FormatMoney(pc.minPPU)))

        local myPrice = postFrame._recipe and AHT:CalcPostPrice(postFrame._recipe) or 0
        local diff = pc.minPPU - myPrice
        if diff > 0 then
            postDiffLabel:SetText(string.format(L["postdlg_diff_cheaper"], AHT:FormatMoney(diff)))
        elseif diff < 0 then
            postDiffLabel:SetText(string.format(L["postdlg_diff_more"], AHT:FormatMoney(-diff)))
        else
            postDiffLabel:SetText(L["postdlg_diff_same"])
        end
    end

    pc.state = "done"
    postCheckBtn:Enable()
end
