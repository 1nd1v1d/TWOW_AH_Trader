-- ============================================================
-- TWOW AH Trader - Recipes.lua
-- Liest bekannte Alchemie-Rezepte aus dem Berufe-Fenster
-- Lua 5.0 kompatibel (vanilla WoW 1.12.1 / Turtle WoW)
-- ============================================================

local AHT = TWOW_AHT

-- Alchemie-Berufsname in verschiedenen Lokalisierungen
local ALCHEMY_NAMES = {
    ["Alchemy"]  = true,  -- Englisch (Turtle WoW Standard)
    ["Alchimie"] = true,  -- Franzoesisch
    ["Alchimia"] = true,  -- Italienisch
    ["Alchemie"] = true,  -- Deutsch
    ["Alquimia"] = true,  -- Spanisch
}

function AHT:LearnRecipes()
    -- Re-Entry-Schutz: verhindert mehrfache gleichzeitige Ausfuehrung
    if AHT._learningRecipes then return end
    AHT._learningRecipes = true

    local tradeSkillName = GetTradeSkillLine()
    if not tradeSkillName or not ALCHEMY_NAMES[tradeSkillName] then
        AHT._learningRecipes = false
        return
    end

    local totalSkills = GetNumTradeSkills()
    if not totalSkills or totalSkills == 0 then
        AHT._learningRecipes = false
        return
    end

    local newRecipes = {}

    for i = 1, totalSkills do
        local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)

        -- Kategorieheader ueberspringen
        if skillType ~= "header" and skillName then
            local numReagents = GetTradeSkillNumReagents(i)
            local reagents = {}

            for r = 1, numReagents do
                local rName, rTexture, rCount, rPlayerCount = GetTradeSkillReagentInfo(i, r)
                if rName then
                    tinsert(reagents, {
                        name  = rName,
                        count = rCount or 1,
                    })
                end
            end

            -- Duplikate vermeiden (manche Rezepte tauchen mehrfach auf)
            local isDuplicate = false
            for _, existing in ipairs(newRecipes) do
                if existing.name == skillName then
                    isDuplicate = true
                    break
                end
            end

            if not isDuplicate and getn(reagents) > 0 then
                tinsert(newRecipes, {
                    name     = skillName,
                    link     = nil,
                    reagents = reagents,
                })
            end
        end
    end

    AHT._learningRecipes = false

    if getn(newRecipes) > 0 then
        AHT.recipes = newRecipes
        AHT:SaveDB()
        AHT:Print("|cffffd700" .. string.format(AHT.L["recipes_loaded_msg"], getn(newRecipes)) .. "|r")

        -- UI aktualisieren falls geoeffnet
        if TWOW_AHT_UI and TWOW_AHT_UI:IsVisible() then
            AHT:RefreshUI()
        end
    end
end
