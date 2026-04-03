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
    -- Retry-Zaehler zuruecksetzen wenn vom Event aufgerufen (nicht vom Retry)
    if not AHT._recipeRetryPending then
        AHT._recipeRetryCount = 0
    end

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
    local needsRetry = false

    for i = 1, totalSkills do
        local skillName, skillType, numAvailable, isExpanded = GetTradeSkillInfo(i)

        -- Kategorieheader ueberspringen
        if skillType ~= "header" and skillName then
            local numReagents = GetTradeSkillNumReagents(i)
            local reagents = {}
            local hasMissing = false

            for r = 1, numReagents do
                local rName, rTexture, rCount, rPlayerCount = GetTradeSkillReagentInfo(i, r)
                if not rName or rName == "" then
                    -- Item nicht im Cache: versuche Name aus ItemLink zu extrahieren
                    if GetTradeSkillReagentItemLink then
                        local link = GetTradeSkillReagentItemLink(i, r)
                        if link then
                            local _, _, linkName = strfind(link, "%[(.-)%]")
                            if linkName then rName = linkName end
                        end
                    end
                end
                if rName and rName ~= "" then
                    tinsert(reagents, {
                        name  = rName,
                        count = rCount or 1,
                    })
                else
                    hasMissing = true
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
                -- Nur speichern wenn alle Reagenzien erkannt wurden
                if hasMissing then
                    needsRetry = true
                else
                    tinsert(newRecipes, {
                        name     = skillName,
                        link     = nil,
                        reagents = reagents,
                    })
                end
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

    -- Bei fehlenden Reagenzien: verzoegerter Retry (Item-Cache nachladen, max 3x)
    if needsRetry and not AHT._recipeRetryPending then
        AHT._recipeRetryCount = (AHT._recipeRetryCount or 0) + 1
        if AHT._recipeRetryCount <= 3 then
            AHT._recipeRetryPending = true
            AHT._recipeRetryTimer = 0
        end
    end
end

-- Verzoegerter Retry fuer Items die beim ersten Laden nicht im Cache waren
function AHT:OnRecipeRetryUpdate(elapsed)
    if not AHT._recipeRetryPending then return end
    AHT._recipeRetryTimer = (AHT._recipeRetryTimer or 0) + elapsed
    if AHT._recipeRetryTimer >= 1.0 then
        AHT._recipeRetryPending = false
        AHT._recipeRetryTimer = 0
        AHT:LearnRecipes()
    end
end
