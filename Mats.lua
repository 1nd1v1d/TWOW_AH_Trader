-- ============================================================
-- TWOW AH Trader - Mats.lua
-- Materials Analysis UI und Dialog-Fenster
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
--
-- Bietet:
-- 1. Material Management Dialog (Add/Remove)
-- 2. Materials Analysis Fenster (Preis-Abweichung + Historie)
-- 3. Material Kauf-Dialog
-- ============================================================

local AHT = TWOW_AHT

-- ── Globale UI-Variablen für Mats ─────────────────────────────
local MATS_FRAME_W  = 780
local MATS_FRAME_H  = 480
local MATS_ROW_H    = 20
local MATS_MAX_ROWS = 14

local function Trim(s)
    if not s then return "" end
    return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

-- Parst eine Preisangabe (z.B. "5g 20s 10c" oder rohe Kupferzahl) in Kupfer
local function ParseMoney(s)
    if not s or s == "" then return 0 end
    s = string.lower(s)
    local total = 0
    local hasUnit = false
    local _, _, g = string.find(s, "(%d+)%s*g")
    if g then total = total + tonumber(g) * 10000; hasUnit = true end
    local _, _, sv = string.find(s, "(%d+)%s*s")
    if sv then total = total + tonumber(sv) * 100; hasUnit = true end
    local _, _, cp = string.find(s, "(%d+)%s*c")
    if cp then total = total + tonumber(cp); hasUnit = true end
    if not hasUnit then total = tonumber(s) or 0 end
    return math.floor(total)
end

-- Formatiert Kupfer als lesbaren Text für Eingabefelder (keine Farb-Codes)
local function FormatMoneyInput(copper)
    copper = math.floor(copper or 0)
    if copper <= 0 then return "0c" end
    local g = math.floor(copper / 10000)
    local s = math.floor(mod(copper, 10000) / 100)
    local c = mod(copper, 100)
    if g > 0 then
        return string.format("%dg %ds %dc", g, s, c)
    elseif s > 0 then
        return string.format("%ds %dc", s, c)
    else
        return string.format("%dc", c)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- MATERIALS MANAGEMENT DIALOG
-- ═══════════════════════════════════════════════════════════════

function AHT:ShowMatsDialog()
    local existing = AHT:CreateMatsManagementDialog()
    existing:Show()
end

function AHT:CreateMatsManagementDialog()
    if AHT.matsManagementDialog then
        return AHT.matsManagementDialog
    end

    local dlg = CreateFrame("Frame", "TWOW_AHT_MatsManagementDialog", UIParent)
    dlg:SetWidth(420)
    dlg:SetHeight(500)
    dlg:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dlg:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 16,
        insets   = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    dlg:SetBackdropColor(0.07, 0.07, 0.07, 1)
    dlg:EnableMouse(true)
    dlg:SetMovable(true)
    dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", function() this:StartMoving() end)
    dlg:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    dlg:SetFrameStrata("DIALOG")
    dlg:Hide()

    -- Innerer Vollflaechen-Hintergrund, damit der Rahmen optisch komplett gefuellt ist
    local innerBg = dlg:CreateTexture(nil, "BACKGROUND")
    innerBg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    innerBg:SetPoint("TOPLEFT", dlg, "TOPLEFT", 11, -12)
    innerBg:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -12, 11)
    innerBg:SetVertexColor(0.04, 0.04, 0.04, 1)

    -- Titelleiste
    local titleTex = dlg:CreateTexture(nil, "ARTWORK")
    titleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleTex:SetWidth(256)
    titleTex:SetHeight(64)
    titleTex:SetPoint("TOP", dlg, "TOP", 0, 12)

    local titleText = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", dlg, "TOP", 0, -5)
    titleText:SetText(AHT.L["mats_dialog_title"])

    local closeBtn = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() this:GetParent():Hide() end)

    -- Input für neues Material
    local labelAdd = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelAdd:SetPoint("TOPLEFT", dlg, "TOPLEFT", 15, -40)
    labelAdd:SetText(AHT.L["mats_dialog_add"])

    local inputBoxFrame = CreateFrame("Frame", nil, dlg)
    local inputBox = CreateFrame("EditBox", "TWOW_AHT_MatsInput", inputBoxFrame, "InputBoxTemplate")
    inputBox:SetParent(dlg)
    inputBox:SetWidth(230)
    inputBox:SetHeight(20)
    inputBox:SetPoint("TOPLEFT", dlg, "TOPLEFT", 15, -58)
    inputBox:SetAutoFocus(false)
    inputBox:SetMaxLetters(50)
    inputBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    local btnAdd = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    btnAdd:SetWidth(90)
    btnAdd:SetHeight(22)
    btnAdd:SetText(AHT.L["mats_dialog_add_btn"])
    btnAdd:SetPoint("TOPLEFT", dlg, "TOPLEFT", 255, -54)
    btnAdd:SetScript("OnClick", function()
        local matName = Trim(inputBox:GetText())
        if matName and matName ~= "" then
            local catId = dlg.currentCategoryId
            if catId and catId <= 0 then catId = nil end
            AHT:AddMaterial(matName, catId)
            inputBox:SetText("")
            AHT:RefreshMatsDialogList(dlg)
            AHT:CalculateMatsMargins()
            AHT:RefreshMatsUI()
        end
    end)

    local catLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    catLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 15, -82)
    catLabel:SetText(AHT.L["mats_category_label"])

    local catDD = CreateFrame("Frame", "TWOW_AHT_MatsCategoryDD", dlg, "UIDropDownMenuTemplate")
    catDD:SetPoint("TOPLEFT", dlg, "TOPLEFT", 110, -73)
    UIDropDownMenu_SetWidth(155, catDD)

    local function SetDialogCategory(catId)
        dlg.currentCategoryId = catId or 0
        UIDropDownMenu_SetSelectedValue(catDD, dlg.currentCategoryId)
    end

    UIDropDownMenu_Initialize(catDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = AHT.L["mats_category_all"]
        info.value = 0
        info.func = function()
            SetDialogCategory(this.value)
            if dlg.selectedMat then
                AHT:SetMatCategory(dlg.selectedMat, nil)
                AHT:RefreshMatsDialogList(dlg)
                AHT:CalculateMatsMargins()
                AHT:RefreshMatsUI()
            end
        end
        UIDropDownMenu_AddButton(info)

        for _, cat in ipairs(AHT.MAT_CATEGORY_IDS) do
            local info2 = UIDropDownMenu_CreateInfo()
            info2.text = AHT:GetMatCategoryLabel(cat.id)
            info2.value = cat.id
            info2.func = function()
                SetDialogCategory(this.value)
                if dlg.selectedMat then
                    AHT:SetMatCategory(dlg.selectedMat, this.value)
                    AHT:RefreshMatsDialogList(dlg)
                    AHT:CalculateMatsMargins()
                    AHT:RefreshMatsUI()
                end
            end
            UIDropDownMenu_AddButton(info2)
        end
    end)

    SetDialogCategory(0)
    dlg.catDropdown = catDD

    -- Liste aktueller Materialien
    local labelCurrent = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelCurrent:SetPoint("TOPLEFT", dlg, "TOPLEFT", 15, -120)
    labelCurrent:SetText(AHT.L["mats_dialog_current"])

    -- Listenbereich fuellt den Dialog sichtbar aus
    local listPanel = CreateFrame("Frame", nil, dlg)
    listPanel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 12, -140)
    listPanel:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -28, 52)
    listPanel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listPanel:SetBackdropColor(0.10, 0.10, 0.10, 0.95)

    -- ScrollFrame fuer MaterialienListe
    local scrollFrame = CreateFrame("ScrollFrame", "TWOW_AHT_MatsScrollFrame", listPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -24, 6)

    local listBox = CreateFrame("Frame", nil, scrollFrame)
    listBox:SetWidth(340)
    listBox:SetHeight(1)  -- wird dynamisch gesetzt
    scrollFrame:SetScrollChild(listBox)

    dlg.listBox = listBox
    dlg.listPanel = listPanel
    dlg.scrollFrame = scrollFrame
    dlg.inputBox = inputBox
    dlg.removeMarked = {}

    local btnRemove = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    btnRemove:SetWidth(150)
    btnRemove:SetHeight(22)
    btnRemove:SetText(AHT.L["mats_dialog_remove_btn"])
    btnRemove:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -14, 14)
    btnRemove:SetScript("OnClick", function()
        local removed = 0
        for matName, marked in pairs(dlg.removeMarked) do
            if marked and AHT.materials[matName] then
                AHT:RemoveMaterial(matName)
                removed = removed + 1
            end
        end

        -- Fallback: falls nichts markiert wurde, aktuelles selektiertes Material entfernen
        if removed == 0 and dlg.selectedMat and AHT.materials[dlg.selectedMat] then
            AHT:RemoveMaterial(dlg.selectedMat)
            removed = 1
        end

        dlg.removeMarked = {}
        if dlg.selectedMat and not AHT.materials[dlg.selectedMat] then
            dlg.selectedMat = nil
        end
        AHT:RefreshMatsDialogList(dlg)
        AHT:CalculateMatsMargins()
        AHT:RefreshMatsUI()
    end)

    local btnClose = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    btnClose:SetWidth(120)
    btnClose:SetHeight(22)
    btnClose:SetText(AHT.L["mats_dialog_close"])
    btnClose:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 14, 14)
    btnClose:SetScript("OnClick", function()
        dlg:Hide()
    end)

    dlg.btnRemove = btnRemove
    AHT.matsManagementDialog = dlg
    AHT:RefreshMatsDialogList(dlg)

    return dlg
end

function AHT:RefreshMatsDialogList(dlg)
    if not dlg or not dlg.listBox then return end

    -- Clear existing buttons
    local children = { dlg.listBox:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
    end

    local list = AHT:GetMaterialsList()
    local rowHeight = 0

    for i, matName in ipairs(list) do
        local matKey = matName
        local btn = CreateFrame("Button", nil, dlg.listBox)
        btn:SetWidth(334)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", dlg.listBox, "TOPLEFT", 3, -(i-1)*20)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SlateButton",
            edgeFile = "Interface\\Buttons\\UI-Highlight",
            edgeSize = 2,
        })
        btn:SetBackdropColor(0.2, 0.2, 0.2, 0.3)

        local cb = CreateFrame("CheckButton", nil, btn, "UICheckButtonTemplate")
        cb:SetWidth(18)
        cb:SetHeight(18)
        cb:SetPoint("LEFT", btn, "LEFT", 2, 0)
        cb:SetChecked(dlg.removeMarked[matKey] and 1 or nil)
        cb:SetScript("OnClick", function()
            if this:GetChecked() then
                dlg.removeMarked[matKey] = true
            else
                dlg.removeMarked[matKey] = nil
            end
        end)

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", btn, "LEFT", 24, 0)
        fs:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
        fs:SetJustifyH("LEFT")
        local catLabel = AHT:GetMatCategoryLabel(AHT:GetMatCategoryId(matKey))
        fs:SetText(matKey .. " |cff888888[" .. catLabel .. "]|r")

        btn:SetScript("OnClick", function()
            dlg.selectedMat = matKey
            local catId = AHT:GetMatCategoryId(matKey) or 0
            dlg.currentCategoryId = catId
            if dlg.catDropdown then
                UIDropDownMenu_SetSelectedValue(dlg.catDropdown, catId)
            end
            AHT:RefreshMatsDialogList(dlg)  -- Refresh für Highlight
        end)

        btn:SetScript("OnEnter", function()
            this:SetBackdropColor(0.3, 0.3, 0.6, 0.4)
        end)

        btn:SetScript("OnLeave", function()
            if dlg.selectedMat == matKey then
                this:SetBackdropColor(0.1, 0.3, 0.7, 0.5)
            else
                this:SetBackdropColor(0.2, 0.2, 0.2, 0.3)
            end
        end)

        -- Highlight selected
        if dlg.selectedMat == matKey then
            btn:SetBackdropColor(0.1, 0.3, 0.7, 0.5)
        end

        rowHeight = rowHeight + 20
    end

    dlg.listBox:SetHeight(math.max(20, rowHeight))
end

-- ═══════════════════════════════════════════════════════════════
-- MATERIALS ANALYSIS WINDOW
-- ═══════════════════════════════════════════════════════════════

function AHT:ShowMatsUI()
    if not TWOW_AHT_MatsUI then
        AHT:CreateMatsUI()
    end

    -- Immer neu berechnen, damit das Fenster auch ohne Materialien leer aber korrekt oeffnet.
    AHT:CalculateMatsMargins()

    TWOW_AHT_MatsUI:Show()
    AHT:RefreshMatsUI()
end

function AHT:CreateMatsUI()
    if TWOW_AHT_MatsUI then return end

    local mainFrame = CreateFrame("Frame", "TWOW_AHT_MatsUI", UIParent)
    mainFrame:SetWidth(MATS_FRAME_W)
    mainFrame:SetHeight(MATS_FRAME_H)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 300, 50)
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
    mainFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    mainFrame:SetFrameStrata("DIALOG")
    mainFrame:Hide()

    -- Title
    local titleTex = mainFrame:CreateTexture(nil, "ARTWORK")
    titleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleTex:SetWidth(320)
    titleTex:SetHeight(64)
    titleTex:SetPoint("TOP", mainFrame, "TOP", 0, 12)

    local titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", mainFrame, "TOP", 0, -5)
    titleText:SetText("TWOW AH Trader - Mats")

    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() this:GetParent():Hide() end)

    -- Status-Zeile (wie Trank-Analyse)
    local statusText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -28)
    statusText:SetWidth(MATS_FRAME_W - 70)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("")
    mainFrame._statusText = statusText

    local infoText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -48)
    infoText:SetWidth(MATS_FRAME_W - 70)
    infoText:SetJustifyH("LEFT")
    infoText:SetText("")
    mainFrame._infoText = infoText

    -- Header im Fenster
    local COLS = {
        { id="sel",    label="",              w=18,  x=12  },
        { id="name",   label=AHT.L["mats_col_name"],    w=150, x=35  },
        { id="current", label=AHT.L["mats_col_current"], w=90,  x=190 },
        { id="weighted", label=AHT.L["mats_col_weighted_avg"], w=90, x=283 },
        { id="dev", label=AHT.L["mats_col_deviation"], w=80,  x=376 },
        { id="listings", label=AHT.L["mats_col_listings"], w=70, x=459 },
        { id="history", label=AHT.L["mats_col_history"], w=70, x=532 },
    }

    local headerBtns = {}
    for _, col in ipairs(COLS) do
        if col.id ~= "sel" then
            local fs = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", col.x, -72)
            fs:SetWidth(col.w)
            fs:SetJustifyH("RIGHT")
            fs:SetText("|cffffff00" .. col.label .. "|r")
            headerBtns[col.id] = fs
        end
    end

    -- Trennlinie
    local sepLine = mainFrame:CreateTexture(nil, "ARTWORK")
    sepLine:SetTexture(0.6, 0.6, 0.6, 0.4)
    sepLine:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  14,  -90)
    sepLine:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -14, -90)
    sepLine:SetHeight(1)

    -- Data Rows
    local scrollOffset = 0
    local rowFrames = {}

    local function UpdateMatssDisplay()
        for i = 1, MATS_MAX_ROWS do
            local idx = i + scrollOffset
            if idx <= getn(AHT.matsDisplayResults) then
                local r = AHT.matsDisplayResults[idx]
                local row = rowFrames[i]

                -- Checkbox
                local cb = row.cells.sel
                cb._rowIndex = i
                cb._matName = r.name
                cb:SetChecked(AHT.matsSelected[r.name] ~= false)
                cb:SetScript("OnClick", function()
                    local matName = this._matName
                    if this:GetChecked() then
                        AHT.matsSelected[matName] = true
                    else
                        AHT.matsSelected[matName] = false
                    end
                    AHT:SaveDB()
                    AHT:CalculateMatsMargins()
                    UpdateMatssDisplay()
                end)

                -- Text cells
                local nameCell = row.cells.name
                if r.lastUpdate then
                    nameCell:SetText(r.name .. " |cff888888(" .. date(AHT.L["date_short"], r.lastUpdate) .. ")|r")
                else
                    nameCell:SetText(r.name)
                end

                local currentCell = row.cells.current
                currentCell:SetText(AHT:FormatMoneyPlain(r.currentPrice))

                local weightedCell = row.cells.weighted
                weightedCell:SetText(AHT:FormatMoneyPlain(r.weighted_avg))

                -- Deviation mit Farbe
                local devCell = row.cells.deviation
                local devValue = r.deviation or 0
                local devText = string.format("%+0.1f%%", devValue)
                local devR, devG, devB = 1, 1, 0
                if devValue < -20 then devR, devG, devB = 0, 1, 0  -- Green - cheap
                elseif devValue > 20 then devR, devG, devB = 1, 0, 0  -- Red - expensive
                end
                local r8 = math.floor(devR * 255)
                local g8 = math.floor(devG * 255)
                local b8 = math.floor(devB * 255)
                devCell:SetText("|c" .. string.format("ff%02x%02x%02x", r8, g8, b8) .. devText .. "|r")

                local listCell = row.cells.listings
                listCell:SetText(tostring(r.listingCount))

                local histCell = row.cells.history
                histCell:SetText(tostring(r.historyLength))

                row:Show()
            else
                rowFrames[i]:Hide()
            end
        end
    end

    local function CreateDataRow(rowIndex)
        local yOffset = -93 - (rowIndex - 1) * MATS_ROW_H

        local row = CreateFrame("Button", nil, mainFrame)
        row:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  10, yOffset)
        row:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, yOffset)
        row:SetHeight(MATS_ROW_H)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Zeilenhintergrund
        if mod(rowIndex, 2) == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetTexture(1, 1, 1, 0.04)
            bg:SetAllPoints(row)
        end

        local cells = {}

        -- Checkbox
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetWidth(18)
        cb:SetHeight(18)
        cb:SetPoint("LEFT", row, "LEFT", 12, 0)
        cells.sel = cb

        -- Name
        local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFs:SetPoint("LEFT", row, "LEFT", 35, 0)
        nameFs:SetWidth(150)
        nameFs:SetJustifyH("LEFT")
        cells.name = nameFs

        -- Current Price
        local currentFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        currentFs:SetPoint("LEFT", row, "LEFT", 190, 0)
        currentFs:SetWidth(85)
        currentFs:SetJustifyH("RIGHT")
        cells.current = currentFs

        -- Weighted Avg
        local weightedFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        weightedFs:SetPoint("LEFT", row, "LEFT", 283, 0)
        weightedFs:SetWidth(85)
        weightedFs:SetJustifyH("RIGHT")
        cells.weighted = weightedFs

        -- Deviation
        local devFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        devFs:SetPoint("LEFT", row, "LEFT", 376, 0)
        devFs:SetWidth(75)
        devFs:SetJustifyH("RIGHT")
        cells.deviation = devFs

        -- Listings
        local listFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        listFs:SetPoint("LEFT", row, "LEFT", 459, 0)
        listFs:SetWidth(65)
        listFs:SetJustifyH("RIGHT")
        cells.listings = listFs

        -- History
        local histFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        histFs:SetPoint("LEFT", row, "LEFT", 532, 0)
        histFs:SetWidth(65)
        histFs:SetJustifyH("RIGHT")
        cells.history = histFs

        row.cells = cells
        row:EnableMouse(true)
        row:SetScript("OnEnter", function()
            local idx = rowIndex + scrollOffset
            if idx > getn(AHT.matsDisplayResults) then return end
            local r = AHT.matsDisplayResults[idx]
            GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
            GameTooltip:AddLine("|cffffd700" .. r.name .. "|r", 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(AHT.L["mats_tt_weighted"], AHT:FormatMoneyPlain(r.weighted_avg), 1, 1, 0)
            GameTooltip:AddDoubleLine(AHT.L["mats_tt_deviation"], string.format("%+0.1f%%", r.deviation), 1, 1, 1)
            GameTooltip:AddDoubleLine(AHT.L["mats_tt_scans"], tostring(r.historyLength), 0.7, 0.7, 0.7)
            if r.lastUpdate then
                GameTooltip:AddDoubleLine(AHT.L["mats_tt_age"], date(AHT.L["date_short"], r.lastUpdate), 0.5, 0.5, 0.5)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(AHT.L["mats_tt_rightclick"])
            GameTooltip:Show()
        end)

        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function()
            if arg1 == "RightButton" then
                local idx = rowIndex + scrollOffset
                if idx > getn(AHT.matsDisplayResults) then return end
                local r = AHT.matsDisplayResults[idx]
                AHT:ShowMatsBuyDialog(r)
            end
        end)

        return row
    end

    for i = 1, MATS_MAX_ROWS do
        rowFrames[i] = CreateDataRow(i)
    end

    -- Scroll buttons
    local scrollUp = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    scrollUp:SetWidth(24)
    scrollUp:SetHeight(16)
    scrollUp:SetText("/\\")
    scrollUp:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -18, 55)
    scrollUp:SetScript("OnClick", function()
        if scrollOffset > 0 then
            scrollOffset = scrollOffset - 1
            UpdateMatssDisplay()
        end
    end)

    local scrollDown = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    scrollDown:SetWidth(24)
    scrollDown:SetHeight(16)
    scrollDown:SetText("\\/")
    scrollDown:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -18, 35)
    scrollDown:SetScript("OnClick", function()
        if scrollOffset + MATS_MAX_ROWS < getn(AHT.matsDisplayResults) then
            scrollOffset = scrollOffset + 1
            UpdateMatssDisplay()
        end
    end)

    -- ── Button-Leiste unten (wie Trank-Analyse) ──────────────────
    local btnScan = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    btnScan:SetWidth(130)
    btnScan:SetHeight(22)
    btnScan:SetText(AHT.L["btn_scan"])
    btnScan:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 14, 12)
    btnScan:SetScript("OnClick", function()
        if AHT:IsMatScanning() then
            AHT:CancelMatsScan()
        elseif not AuctionFrame or not AuctionFrame:IsVisible() then
            AHT:Print(AHT.L["scan_ah_required"])
        else
            AHT:StartMatsScan()
        end
    end)
    AHT.matsScanBtn = btnScan

    local btnManage = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    btnManage:SetWidth(150)
    btnManage:SetHeight(22)
    btnManage:SetText((AHT.L and AHT.L["mats_manage_btn"]) or "Materialverwaltung")
    btnManage:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 150, 12)
    btnManage:SetScript("OnClick", function()
        AHT:ShowMatsDialog()
    end)

    local btnAllOn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    btnAllOn:SetWidth(90)
    btnAllOn:SetHeight(22)
    btnAllOn:SetText(AHT.L["btn_select_all"])
    btnAllOn:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 308, 12)
    btnAllOn:SetScript("OnClick", function()
        for name, _ in pairs(AHT.materials) do
            AHT.matsSelected[name] = true
        end
        AHT:SaveDB()
        AHT:CalculateMatsMargins()
        AHT:RefreshMatsUI()
    end)

    local btnAllOff = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    btnAllOff:SetWidth(90)
    btnAllOff:SetHeight(22)
    btnAllOff:SetText(AHT.L["btn_deselect_all"])
    btnAllOff:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 403, 12)
    btnAllOff:SetScript("OnClick", function()
        for name, _ in pairs(AHT.materials) do
            AHT.matsSelected[name] = false
        end
        AHT:SaveDB()
        AHT:CalculateMatsMargins()
        AHT:RefreshMatsUI()
    end)

    mainFrame._updateDisplay = UpdateMatssDisplay
    mainFrame._rowFrames = rowFrames

    TWOW_AHT_MatsUI = mainFrame
end

function AHT:RefreshMatsUI()
    if not TWOW_AHT_MatsUI or not TWOW_AHT_MatsUI:IsVisible() then return end
    local mf = TWOW_AHT_MatsUI
    local matCount = getn(AHT.matsDisplayResults or {})

    if AHT.matsScanBtn then
        if AHT:IsMatScanning() then
            AHT.matsScanBtn:SetText(AHT.L["btn_cancel_scan"])
        else
            AHT.matsScanBtn:SetText(AHT.L["btn_scan"])
        end
    end

    if mf._statusText then
        if AHT:IsMatScanning() then
            mf._statusText:SetText(AHT.L["mats_status_scanning"] or "|cffffff00Scan laeuft...|r")
        elseif matCount > 0 then
            mf._statusText:SetText(string.format(AHT.L["mats_status_count"] or "|cffaaaaaa%d Materialien analysiert.|r", matCount))
        else
            mf._statusText:SetText(AHT.L["mats_status_empty"] or "|cffaaaaaa Keine Materialien. /aht mats zum Hinzufuegen.|r")
        end
    end

    if mf._updateDisplay then
        mf._updateDisplay()
    end
end

-- ═══════════════════════════════════════════════════════════════
-- MATERIALS BUY DIALOG
-- ═══════════════════════════════════════════════════════════════

-- Eigener Mats-Buy-State (unabhaengig vom Trank-Buyer)
AHT.matsBuyState        = "idle"   -- idle / waiting / sent
AHT.matsBuyPhase        = nil      -- collect / execute
AHT.matsBuyItem         = nil
AHT.matsBuyQuantity     = 0
AHT.matsBuyAllowedPPU   = 0
AHT.matsBuyTimer        = 0
AHT.matsBuySentTimer    = 0
AHT.matsBuyPage         = 0
AHT.matsBuyOffers       = {}
AHT.matsBuyLocked       = false
AHT.matsBuyPending      = nil
AHT.matsBuyBought       = 0
AHT.matsBuySpent        = 0
AHT.matsBuyTargetQty    = 0

local MATS_BUY_WAIT_TIMEOUT = 30.0
local MATS_BUY_SENT_TIMEOUT = 15.0

function AHT:IsMatsBuying()
    return AHT.matsBuyState ~= "idle"
end

function AHT:GetMatsBuyAllowedPPU(matData, deviationMax)
    local weighted = (matData and matData.weighted_avg) or 0
    if weighted <= 0 then
        weighted = (matData and matData.currentPrice) or 0
    end
    if weighted <= 0 then return 0 end

    local dev = tonumber(deviationMax) or 0
    -- User-Konvention: +10 = 10% unter Avg, -5 = 5% ueber Avg
    dev = -dev
    if dev < -95 then dev = -95 end

    local allowed = math.floor(weighted * (1 + dev / 100))
    if allowed < 1 then allowed = 1 end
    return allowed
end

function AHT:BuildMatsBuyPlanFromOffers(offers, quantity, allowedPPU)
    local filtered = {}
    for _, o in ipairs(offers or {}) do
        if o and o.ppu and o.count and o.count > 0 and o.ppu <= allowedPPU then
            tinsert(filtered, { ppu = o.ppu, count = o.count, buyout = o.buyout or (o.ppu * o.count) })
        end
    end

    table.sort(filtered, function(a, b) return a.ppu < b.ppu end)

    local need = quantity or 0
    local got = 0
    local cost = 0
    local maxPPU = 0
    local steps = {}

    for _, o in ipairs(filtered) do
        if got >= need then break end
        local take = o.count
        if got + take > need then take = need - got end
        got = got + take
        local stepCost = o.ppu * take
        cost = cost + stepCost
        if o.ppu > maxPPU then maxPPU = o.ppu end
        -- gleichpreisige Angebote zusammenfassen
        local n = getn(steps)
        if n > 0 and steps[n].ppu == o.ppu then
            steps[n].take = steps[n].take + take
            steps[n].cost = steps[n].cost + stepCost
        else
            tinsert(steps, { ppu = o.ppu, take = take, cost = stepCost })
        end
    end

    local avgPPU = 0
    if got > 0 then avgPPU = math.floor(cost / got) end

    return {
        available = getn(filtered),
        canBuyCount = got,
        totalCost = cost,
        avgPPU = avgPPU,
        maxPPU = maxPPU,
        enough = got >= need,
        steps = steps,
    }
end

function AHT:ShowMatsBuyDialog(matData)
    if not matData then return end

    local dlg = AHT:CreateMatsBuyDialog()
    dlg.matData = matData
    dlg.quantity = 1

    local quantityBox = dlg.quantityBox
    quantityBox:SetText("1")
    quantityBox:SetFocus()
    dlg.maxPriceBox:SetText(FormatMoneyInput(matData.weighted_avg or matData.currentPrice or 0))

    dlg.matNameLabel:SetText("|cffffd700" .. matData.name .. "|r")
    dlg.currentLabel:SetText(string.format(AHT.L["mats_buy_current"], AHT:FormatMoneyPlain(matData.currentPrice or 0)))
    dlg.avgLabel:SetText(string.format(AHT.L["mats_buy_weighted_avg"], AHT:FormatMoneyPlain(matData.weighted_avg or 0)))
    dlg.devLabel:SetText(string.format(AHT.L["mats_buy_deviation"], matData.deviation or 0))

    dlg:Show()
    dlg:RefreshCost()
end

function AHT:CreateMatsBuyDialog()
    if AHT.matsBuyDialog then
        return AHT.matsBuyDialog
    end

    local dlg = CreateFrame("Frame", "TWOW_AHT_MatsBuyDialog", UIParent)
    dlg:SetWidth(370)
    dlg:SetHeight(420)
    dlg:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dlg:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 32,
        insets   = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    dlg:SetBackdropColor(0.07, 0.07, 0.07, 1)
    dlg:EnableMouse(true)
    dlg:SetMovable(true)
    dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", function() this:StartMoving() end)
    dlg:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    dlg:SetFrameStrata("FULLSCREEN_DIALOG")
    dlg:Hide()

    -- Titel (wie Trank-Kaufdialog)
    local titleTex = dlg:CreateTexture(nil, "ARTWORK")
    titleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    titleTex:SetWidth(260)
    titleTex:SetHeight(64)
    titleTex:SetPoint("TOP", dlg, "TOP", 0, 12)

    local titleTextStatic = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleTextStatic:SetPoint("TOP", dlg, "TOP", 0, -5)
    titleTextStatic:SetText(AHT.L and AHT.L["mats_buy_dialog_title"] or "Materialien kaufen")

    -- Schliessen
    local closeBtn = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() this:GetParent():Hide() end)

    -- Material-Name (wie Trank-Name im Kaufdialog)
    local matNameLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    matNameLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 20, -38)
    matNameLabel:SetWidth(330)
    matNameLabel:SetJustifyH("LEFT")
    dlg.matNameLabel = matNameLabel

    -- Aktuelle Preis-Infos
    local currentLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currentLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 20, -60)
    currentLabel:SetWidth(330)
    currentLabel:SetJustifyH("LEFT")
    dlg.currentLabel = currentLabel

    local avgLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    avgLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 20, -77)
    avgLabel:SetWidth(330)
    avgLabel:SetJustifyH("LEFT")
    dlg.avgLabel = avgLabel

    local devLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    devLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 20, -94)
    devLabel:SetWidth(330)
    devLabel:SetJustifyH("LEFT")
    dlg.devLabel = devLabel

    -- Trennlinie
    local sep = dlg:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(0.6, 0.6, 0.6, 0.4)
    sep:SetPoint("TOPLEFT",  dlg, "TOPLEFT",  14, -110)
    sep:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -14, -110)
    sep:SetHeight(1)

    -- Menge
    local quantityLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    quantityLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 20, -121)
    quantityLabel:SetText(AHT.L["mats_buy_quantity"])

    local quantityBox = CreateFrame("EditBox", nil, dlg, "InputBoxTemplate")
    quantityBox:SetWidth(60)
    quantityBox:SetHeight(20)
    quantityBox:SetPoint("LEFT", quantityLabel, "RIGHT", 10, 0)
    quantityBox:SetAutoFocus(false)
    quantityBox:SetMaxLetters(8)
    quantityBox:SetNumeric(true)
    quantityBox:SetText("1")
    quantityBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    quantityBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    quantityBox:SetScript("OnTextChanged", function()
        if dlg.RefreshCost then dlg:RefreshCost() end
    end)
    dlg.quantityBox = quantityBox

    -- Max. Kaufpreis
    local maxPriceLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxPriceLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 20, -150)
    maxPriceLabel:SetText(AHT.L["mats_buy_max_price"])

    local maxPriceBox = CreateFrame("EditBox", nil, dlg)
    maxPriceBox:SetWidth(140)
    maxPriceBox:SetHeight(20)
    maxPriceBox:SetPoint("LEFT", maxPriceLabel, "RIGHT", 10, 0)
    maxPriceBox:SetAutoFocus(false)
    maxPriceBox:SetMaxLetters(20)
    maxPriceBox:SetFontObject(GameFontHighlight)
    maxPriceBox:SetTextInsets(6, 6, 0, 0)
    maxPriceBox:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    maxPriceBox:SetBackdropColor(0, 0, 0, 0.8)
    maxPriceBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.9)
    maxPriceBox:SetScript("OnChar", function()
        local char = arg1
        if char and string.find(char, "[0-9gsc ]") then return end
        this:SetText(string.sub(this:GetText(), 1, -2))
    end)
    maxPriceBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    maxPriceBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    maxPriceBox:SetScript("OnTextChanged", function()
        if dlg.RefreshCost then dlg:RefreshCost() end
    end)
    dlg.maxPriceBox = maxPriceBox

    -- Trennlinie 2
    local sep2 = dlg:CreateTexture(nil, "ARTWORK")
    sep2:SetTexture(0.6, 0.6, 0.6, 0.4)
    sep2:SetPoint("TOPLEFT",  dlg, "TOPLEFT",  14, -171)
    sep2:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -14, -171)
    sep2:SetHeight(1)

    -- Kaufplan-Anzeige
    local planHeaderLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    planHeaderLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 20, -182)
    planHeaderLabel:SetWidth(330)
    planHeaderLabel:SetJustifyH("LEFT")
    dlg.planHeaderLabel = planHeaderLabel

    dlg.planRows = {}
    for i = 1, 6 do
        local row = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row:SetPoint("TOPLEFT", dlg, "TOPLEFT", 28, -182 - i * 16)
        row:SetWidth(310)
        row:SetJustifyH("LEFT")
        dlg.planRows[i] = row
    end

    local sep3 = dlg:CreateTexture(nil, "ARTWORK")
    sep3:SetTexture(0.6, 0.6, 0.6, 0.4)
    sep3:SetPoint("TOPLEFT",  dlg, "TOPLEFT",  14, -293)
    sep3:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -14, -293)
    sep3:SetHeight(1)

    local planTotalLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    planTotalLabel:SetPoint("TOPLEFT", dlg, "TOPLEFT", 20, -302)
    planTotalLabel:SetWidth(330)
    planTotalLabel:SetJustifyH("LEFT")
    dlg.planTotalLabel = planTotalLabel

    -- Buttons (wie Trank-Kaufdialog: BOTTOMLEFT und BOTTOMRIGHT)
    local btnBuy = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    btnBuy:SetWidth(120)
    btnBuy:SetHeight(24)
    btnBuy:SetText(AHT.L["btn_buy"])
    btnBuy:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 20, 14)
    btnBuy:SetScript("OnClick", function()
        local qty = tonumber(dlg.quantityBox:GetText())
        if not qty or qty <= 0 then
            AHT:Print("Ungültige Menge!")
            return
        end
        local maxPPU = ParseMoney(dlg.maxPriceBox:GetText())
        if not AuctionFrame or not AuctionFrame:IsVisible() then
            AHT:Print(AHT.L["scan_ah_required"])
            return
        end
        dlg:Hide()
        AHT:StartMatsBuy(dlg.matData, qty, maxPPU)
    end)

    local btnCancel = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    btnCancel:SetWidth(120)
    btnCancel:SetHeight(24)
    btnCancel:SetText(AHT.L["btn_cancel"])
    btnCancel:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -20, 14)
    btnCancel:SetScript("OnClick", function()
        dlg:Hide()
    end)

    -- Hinweis: Daten veraltet
    local staleWarning = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    staleWarning:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 20, 44)
    staleWarning:SetWidth(220)
    staleWarning:SetJustifyH("LEFT")
    staleWarning:SetText("")
    staleWarning:Hide()
    dlg.staleWarning = staleWarning

    local btnRescan = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
    btnRescan:SetWidth(110)
    btnRescan:SetHeight(22)
    btnRescan:SetText(AHT.L["mats_buy_rescan_btn"] or "Neu scannen")
    btnRescan:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -20, 42)
    btnRescan:Hide()
    dlg.btnRescan = btnRescan
    btnRescan:SetScript("OnClick", function()
        if not AuctionFrame or not AuctionFrame:IsVisible() then
            AHT:Print(AHT.L["scan_ah_required"])
            return
        end
        if not dlg.matData then return end
        if AHT:IsMatScanning() then return end
        local name = dlg.matData.name
        -- Nur dieses eine Material in die Queue, dann sofort starten
        AHT.matsScanQueue         = { name }
        AHT.matsScanQueueIdx      = 0
        AHT.matsScanMinPrices     = {}
        AHT.matsScanListingCounts = {}
        AHT.matsScanOffers        = {}
        AHT.matsScanState         = "idle"   -- kurz idle, AdvanceMatsScanQueue setzt es
        AHT.matsScanTimer         = 0
        AHT.matsSentTimer         = 0
        AHT.matsCurrentItem       = nil
        btnRescan:SetText("...")
        btnRescan:Disable()
        AHT:AdvanceMatsScanQueue()
    end)

    function dlg:RefreshCost()
        if not self.matData then return end
        local qty = tonumber(self.quantityBox:GetText()) or 1
        local allowed = ParseMoney(self.maxPriceBox:GetText())

        -- Staleness pruefen (>10 min)
        local cache = AHT.matsOfferCache[self.matData.name]
        local now = time()
        local isStale = not (cache and cache.t and (now - cache.t) <= 600)
        if isStale then
            self.staleWarning:SetText(AHT.L["mats_buy_stale_warning"] or "|cffff4444Letzte Preisdaten aelter als 10 Minuten!|r")
            self.staleWarning:Show()
            self.btnRescan:Show()
            self.btnRescan:SetText(AHT.L["mats_buy_rescan_btn"] or "Neu scannen")
            self.btnRescan:Enable()
        else
            self.staleWarning:Hide()
            self.btnRescan:Hide()
        end

        local plan = nil
        if cache and cache.offers then
            plan = AHT:BuildMatsBuyPlanFromOffers(cache.offers, qty, allowed)
        end

        -- Kaufplan-Zeilen leeren
        for i = 1, 6 do self.planRows[i]:SetText("") end

        if plan and plan.canBuyCount > 0 then
            local suffix = ""
            if not plan.enough then
                suffix = string.format(" |cffff8800(%d fehlen)|r", qty - plan.canBuyCount)
            end
            self.planHeaderLabel:SetText(string.format("|cffffff00Kaufplan:|r %d von %d beschaffbar%s", plan.canBuyCount, qty, suffix))
            local steps = plan.steps or {}
            for i = 1, getn(steps) do
                if i > 6 then break end
                local s = steps[i]
                self.planRows[i]:SetText(string.format("%dx @ %s = %s", s.take, AHT:FormatMoneyPlain(s.ppu), AHT:FormatMoneyPlain(s.cost)))
            end
            if getn(steps) > 6 then
                self.planRows[6]:SetText("  ...")
            end
            self.planTotalLabel:SetText(string.format("|cffffff00Gesamt:|r %s  (Ø %s/Stk)", AHT:FormatMoneyPlain(plan.totalCost), AHT:FormatMoneyPlain(plan.avgPPU)))
        else
            self.planHeaderLabel:SetText("|cffff4444Keine Angebote im Preislimit|r")
            self.planTotalLabel:SetText("")
        end
    end

    AHT.matsBuyDialog = dlg
    return dlg
end

function AHT:CancelMatsBuy(silent)
    if AHT.matsBuyState == "idle" then return end
    AHT.matsBuyState = "idle"
    AHT.matsBuyPhase = nil
    AHT.matsBuyLocked = false
    AHT.matsBuyPending = nil
    if not silent then
        AHT:Print(AHT.L["mats_buy_cancelled"])
    end
end

function AHT:PrepareMatsBuyExecution()
    local plan = AHT:BuildMatsBuyPlanFromOffers(AHT.matsBuyOffers, AHT.matsBuyQuantity, AHT.matsBuyAllowedPPU)
    if plan.canBuyCount <= 0 then
        AHT:Print(AHT.L["mats_buy_no_offers"])
        AHT:CancelMatsBuy(true)
        return
    end

    AHT.matsBuyTargetQty = plan.canBuyCount
    AHT.matsBuyBought = 0
    AHT.matsBuySpent = 0

    AHT:Print(string.format(AHT.L["mats_buy_plan"],
        AHT.matsBuyItem,
        AHT.matsBuyTargetQty,
        AHT:FormatMoney(plan.avgPPU),
        AHT:FormatMoney(AHT.matsBuyAllowedPPU)))

    AHT.matsBuyPhase = "execute"
    AHT.matsBuyPage = 0
    AHT.matsBuyState = "waiting"
    AHT.matsBuyTimer = 0
    AHT.matsBuySentTimer = 0
end

function AHT:StartMatsBuy(matData, quantity, maxPPU)
    if not matData or not matData.name or quantity <= 0 then return end
    if AHT:IsMatsBuying() then
        AHT:Print(AHT.L["mats_buy_already_running"])
        return
    end

    AHT.matsBuyItem = matData.name
    AHT.matsBuyQuantity = quantity
    AHT.matsBuyAllowedPPU = math.floor(maxPPU or 0)

    if AHT.matsBuyAllowedPPU <= 0 then
        AHT:Print(AHT.L["mats_buy_no_avg"])
        return
    end

    local cache = AHT.matsOfferCache[matData.name]
    AHT.matsBuyOffers = (cache and cache.offers) or {}
    AHT:PrepareMatsBuyExecution()
end

function AHT:OnMatsBuyUpdate(elapsed)
    if AHT.matsBuyState ~= "waiting" and AHT.matsBuyState ~= "sent" then return end

    if AHT.matsBuyState == "waiting" then
        AHT.matsBuyTimer = AHT.matsBuyTimer + elapsed
        AHT.matsBuySentTimer = AHT.matsBuySentTimer + elapsed

        if AHT.matsBuySentTimer >= MATS_BUY_WAIT_TIMEOUT then
            AHT:Print(AHT.L["mats_buy_timeout"])
            AHT:CancelMatsBuy(true)
            return
        end

        if AHT.matsBuyTimer >= AHT.SCAN_DELAY then
            AHT.matsBuyTimer = 0
            if CanSendAuctionQuery() then
                local invTypeIndex, classIndex, subClassIndex = AHT:GetAuctionQueryFilters(
                    AHT.matsBuyItem,
                    AHT:GetMatCategoryId(AHT.matsBuyItem)
                )
                AHT.matsBuySentTimer = 0
                AHT.matsBuyState = "sent"
                QueryAuctionItems(AHT.matsBuyItem, nil, nil, invTypeIndex, classIndex, subClassIndex, AHT.matsBuyPage, nil, nil)
            end
        end
    else
        AHT.matsBuySentTimer = AHT.matsBuySentTimer + elapsed
        if AHT.matsBuySentTimer >= MATS_BUY_SENT_TIMEOUT then
            AHT:Print(AHT.L["mats_buy_timeout"])
            AHT:CancelMatsBuy(true)
        end
    end
end

function AHT:OnMatsBuyAuctionListUpdate()
    if AHT.matsBuyState ~= "sent" then return end
    if AHT.matsBuyLocked then return end

    local numItems = GetNumAuctionItems("list")
    local itemName = AHT.matsBuyItem
    local playerName = UnitName("player")
    AHT.matsBuySentTimer = 0

    if AHT.matsBuyPhase == "collect" then
        for i = 1, numItems do
            local name, texture, count, quality, canUse, level,
                  minBid, minIncrement, buyoutPrice,
                  bidAmount, highBidder, owner = GetAuctionItemInfo("list", i)

            if name == itemName
               and buyoutPrice and buyoutPrice > 0
               and count and count > 0
               and owner ~= playerName then
                local ppu = math.floor(buyoutPrice / count)
                if ppu <= AHT.matsBuyAllowedPPU then
                    tinsert(AHT.matsBuyOffers, { ppu = ppu, count = count, buyout = buyoutPrice })
                end
            end
        end

        if numItems >= 50 then
            AHT.matsBuyPage = AHT.matsBuyPage + 1
            AHT.matsBuyState = "waiting"
            AHT.matsBuyTimer = 0
        else
            -- Frischen Cache speichern
            AHT.matsOfferCache[itemName] = { t = time(), offers = AHT.matsBuyOffers }
            AHT:PrepareMatsBuyExecution()
        end
        return
    end

    -- execute phase
    local offers = {}
    for i = 1, numItems do
        local name, texture, count, quality, canUse, level,
              minBid, minIncrement, buyoutPrice,
              bidAmount, highBidder, owner = GetAuctionItemInfo("list", i)

        if name == itemName
           and buyoutPrice and buyoutPrice > 0
           and count and count > 0
           and owner ~= playerName then
            local ppu = math.floor(buyoutPrice / count)
            if ppu <= AHT.matsBuyAllowedPPU then
                tinsert(offers, { index = i, count = count, buyout = buyoutPrice, ppu = ppu })
            end
        end
    end

    table.sort(offers, function(a, b) return a.ppu < b.ppu end)

    local need = AHT.matsBuyTargetQty - AHT.matsBuyBought
    if need <= 0 then
        AHT:OnMatsBuyComplete()
        return
    end

    -- Immer das guenstigste Angebot zuerst (offers ist bereits nach ppu ASC sortiert)
    local chosen = offers[1]

    if chosen then
        if GetMoney() < chosen.buyout then
            AHT:Print(AHT.L["buy_no_gold"])
            AHT:CancelMatsBuy(true)
            return
        end

        AHT.matsBuyLocked = true
        AHT.matsBuyPending = {
            count = chosen.count,
            buyout = chosen.buyout,
            ppu = chosen.ppu,
            name = itemName,
        }
        PlaceAuctionBid("list", chosen.index, chosen.buyout)
        return
    end

    if numItems >= 50 then
        AHT.matsBuyPage = AHT.matsBuyPage + 1
        AHT.matsBuyState = "waiting"
        AHT.matsBuyTimer = 0
    else
        AHT:OnMatsBuyComplete()
    end
end

function AHT:OnMatsBidPlaced()
    AHT.matsBuyLocked = false
    local p = AHT.matsBuyPending
    if not p then return end

    AHT.matsBuyBought = AHT.matsBuyBought + p.count
    AHT.matsBuySpent = AHT.matsBuySpent + p.buyout

    AHT:Print(string.format(AHT.L["buy_purchased"], p.count, p.name, AHT:FormatMoney(p.buyout), AHT:FormatMoney(p.ppu)))

    AHT.matsBuyPending = nil

    if AHT.matsBuyBought >= AHT.matsBuyTargetQty then
        AHT:OnMatsBuyComplete()
    else
        AHT.matsBuyPage = 0
        AHT.matsBuyState = "waiting"
        AHT.matsBuyTimer = 0
        AHT.matsBuySentTimer = 0
    end
end

function AHT:OnMatsBuyComplete()
    local bought = AHT.matsBuyBought or 0
    local spent = AHT.matsBuySpent or 0
    if bought > 0 then
        local avgPPU = math.floor(spent / bought)
        AHT:Print(string.format(AHT.L["mats_buy_done"], AHT.matsBuyItem, bought, AHT:FormatMoney(avgPPU), AHT:FormatMoney(spent)))
    else
        AHT:Print(AHT.L["mats_buy_no_offers"])
    end
    AHT:CancelMatsBuy(true)
end
