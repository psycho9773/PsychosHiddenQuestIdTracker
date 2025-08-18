-- Initialize saved variables immediately on addon load
PsychosHiddenQuestIdTrackerDB = PsychosHiddenQuestIdTrackerDB or {}
PsychosHiddenQuestIdTrackerDB.rares = PsychosHiddenQuestIdTrackerDB.rares or {}
PsychosHiddenQuestIdTrackerDB.weeklies = PsychosHiddenQuestIdTrackerDB.weeklies or {}
PsychosHiddenQuestIdTrackerDB.dailies = PsychosHiddenQuestIdTrackerDB.dailies or {}
PsychosHiddenQuestIdTrackerDB.scanRange = PsychosHiddenQuestIdTrackerDB.scanRange or { min = 84000, max = 91000 }
PsychosHiddenQuestIdTrackerDB.rareScanEnabled = PsychosHiddenQuestIdTrackerDB.rareScanEnabled or false
PsychosHiddenQuestIdTrackerDB.idDisplayEnabled = PsychosHiddenQuestIdTrackerDB.idDisplayEnabled or false
PsychosHiddenQuestIdTrackerDB.minimapPos = PsychosHiddenQuestIdTrackerDB.minimapPos or { angle = math.rad(130) }

local frame = CreateFrame("Frame")
local initFrame = CreateFrame("Frame")
local currentTab = "rares"
local idDisplayFrame -- Frame for ID display
local idDisplayEnabled -- Local variable for ID display state

-- Minimap button config
local radius = 105
local buttonName = "PHQIDTracker_MinimapButton"
UpdateMinimapButtonColor = function() end -- placeholder

-- ID display functions
local defaultX, defaultY = 0, 0
local MAX_WATCHED_TOKENS = 3

local function CreateIdDisplayFrame()
    idDisplayFrame = CreateFrame("Frame", "IdDisplayFrame", UIParent, "BackdropTemplate")
    idDisplayFrame:SetFrameStrata("HIGH")
    idDisplayFrame:SetHeight(30)
    idDisplayFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    idDisplayFrame:SetBackdropColor(0, 0, 0, 0.9)
    idDisplayFrame:SetBackdropBorderColor(1, 1, 1, 1) -- Explicitly set border to white
    idDisplayFrame.text = idDisplayFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idDisplayFrame.text:SetPoint("CENTER")
    idDisplayFrame:Hide()
end

local function PositionFrameBelowTooltip()
    idDisplayFrame:ClearAllPoints()
    idDisplayFrame:SetPoint("TOP", GameTooltip, "BOTTOM", 0, 5)
end

local function SetupIdDisplayHooks()
    if not idDisplayFrame then
        CreateIdDisplayFrame()
    end

    if not idDisplayEnabled then
        idDisplayFrame:Hide()
        return
    end

    idDisplayFrame:ClearAllPoints()
    idDisplayFrame:SetPoint("CENTER", UIParent, "CENTER", defaultX, defaultY)

    GameTooltip:HookScript("OnHide", function()
        idDisplayFrame:Hide()
    end)

    GameTooltip:HookScript("OnUpdate", function()
        if GameTooltip:GetUnit() or not idDisplayEnabled then
            idDisplayFrame:Hide()
        end
    end)

    -- Item ID
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(_, data)
        if idDisplayEnabled and data and data.id then
            local itemID = data.id
            local quality = select(3, GetItemInfo(itemID)) or 1
            local r, g, b = GetItemQualityColor(quality)
            local colorCode = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
            PositionFrameBelowTooltip()
            idDisplayFrame.text:SetText(string.format("|cffffd500Item ID:|r %s%d|r", colorCode, itemID))
            idDisplayFrame:SetWidth(idDisplayFrame.text:GetStringWidth() + 20)
            idDisplayFrame:Show()
        end
    end)

    -- Spell ID
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(_, data)
        if idDisplayEnabled and data and data.id then
            PositionFrameBelowTooltip()
            idDisplayFrame.text:SetText(string.format("|cffffd500Spell ID:|r |cffffffff%d|r", data.id))
            idDisplayFrame:SetWidth(idDisplayFrame.text:GetStringWidth() + 20)
            idDisplayFrame:Show()
        end
    end)

    -- Backpack currencies
    for i = 1, MAX_WATCHED_TOKENS do
        local tokenButton = _G["BackpackTokenFrameToken" .. i]
        if tokenButton then
            tokenButton:HookScript("OnEnter", function()
                if idDisplayEnabled then
                    local _, _, _, currencyID = GetBackpackCurrencyInfo(i)
                    if currencyID then
                        GameTooltip:AddLine("Currency ID: " .. currencyID, 1, 1, 1)
                        GameTooltip:Show()
                        PositionFrameBelowTooltip()
                        idDisplayFrame.text:SetText(string.format("|cffffd500Currency ID:|r |cff00ffff%d|r", currencyID))
                        idDisplayFrame:SetWidth(idDisplayFrame.text:GetStringWidth() + 20)
                        idDisplayFrame:Show()
                    end
                end
            end)
        end
    end

    -- Tooltip-based currency hook
    local function ShowCurrencyIDOnHover(currencyID)
        if idDisplayEnabled and currencyID then
            GameTooltip:AddLine("Currency ID: " .. currencyID, 1, 1, 1)
            GameTooltip:Show()
            PositionFrameBelowTooltip()
            idDisplayFrame.text:SetText(string.format("|cffffd500Currency ID:|r |cff00ffff%d|r", currencyID))
            idDisplayFrame:SetWidth(idDisplayFrame.text:GetStringWidth() + 20)
            idDisplayFrame:Show()
        end
    end

    hooksecurefunc(GameTooltip, "SetCurrencyToken", function(self, index)
        if not idDisplayEnabled then return end
        local link = C_CurrencyInfo.GetCurrencyListLink(index)
        if link then
            local currencyID = tonumber(link:match("currency:(%d+)"))
            ShowCurrencyIDOnHover(currencyID)
        end
    end)

    hooksecurefunc(GameTooltip, "SetCurrencyByID", function(self, currencyID)
        if not idDisplayEnabled then return end
        ShowCurrencyIDOnHover(currencyID)
    end)
end

-- Initialize additional variables on ADDON_LOADED
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "PsychosHiddenQuestIdTracker" then
        -- Ensure saved variables are initialized
        PsychosHiddenQuestIdTrackerDB = PsychosHiddenQuestIdTrackerDB or {}
        PsychosHiddenQuestIdTrackerDB.rares = PsychosHiddenQuestIdTrackerDB.rares or {}
        PsychosHiddenQuestIdTrackerDB.weeklies = PsychosHiddenQuestIdTrackerDB.weeklies or {}
        PsychosHiddenQuestIdTrackerDB.dailies = PsychosHiddenQuestIdTrackerDB.dailies or {}
        PsychosHiddenQuestIdTrackerDB.scanRange = PsychosHiddenQuestIdTrackerDB.scanRange or { min = 84000, max = 91000 }
        PsychosHiddenQuestIdTrackerDB.rareScanEnabled = PsychosHiddenQuestIdTrackerDB.rareScanEnabled or false
        PsychosHiddenQuestIdTrackerDB.idDisplayEnabled = PsychosHiddenQuestIdTrackerDB.idDisplayEnabled or false
        PsychosHiddenQuestIdTrackerDB.minimapPos = PsychosHiddenQuestIdTrackerDB.minimapPos or { angle = math.rad(130) }
        -- Initialize previousQuestIDs, rareScanEnabled, and idDisplayEnabled
        previousQuestIDs = previousQuestIDs or {}
        rareScanEnabled = PsychosHiddenQuestIdTrackerDB.rareScanEnabled
        idDisplayEnabled = false -- Force ID display off on login
        PsychosHiddenQuestIdTrackerDB.idDisplayEnabled = false -- Sync global variable
        -- Populate sessionRares from saved variables
        sessionRares = {}
        for _, entry in pairs(PsychosHiddenQuestIdTrackerDB.rares) do
            table.insert(sessionRares, entry)
        end
        -- Unregister ADDON_LOADED to avoid redundant calls
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local sessionRares = {}
local sessionWeeklies, sessionDailies = {}, {}
local scrollParent, scrollFrame, scrollChild, textList
local knownidListFrame
local rareRowWidgets = {}
local weeklyRowWidgets = {}
local dailiesRowWidgets = {}
local guid, cachedName, npcID
local lockedTarget = nil
local lastGuid = nil
local completedQuestIDs = {}
local previousQuestIDs = {}

local blacklist = {
    [57562] = true, [53435] = true, [82146] = true, [82156] = true, [42170] = true,
    [50598] = true, [57567] = true, [50603] = true, [57565] = true,
    [50602] = true, [85489] = true, [48639] = true, [56120] = true,
    [82158] = true, [86174] = true, [42233] = true, [61982] = true,
    [48641] = true, [75511] = true, [50604] = true, [43179] = true,
    [57566] = true, [42421] = true, [57564] = true, [57563] = true,
    [50562] = true, [42422] = true, [42234] = true, [57566] = true,
}

local function getZoneName()
    local zoneID = C_Map.GetBestMapForUnit("player")
    local info = zoneID and C_Map.GetMapInfo(zoneID)
    return info and info.name or "Unknown Zone"
end

local function scanQuestFlags()
    local flags = {}
    local minID = PsychosHiddenQuestIdTrackerDB.scanRange.min
    local maxID = PsychosHiddenQuestIdTrackerDB.scanRange.max
    for i = minID, maxID do
        if C_QuestLog.IsQuestFlaggedCompleted(i) then
            flags[i] = true
        end
    end
    return flags
end

local function countTable(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

local function updateScrollView()
    if not scrollChild then
        return
    end

    -- Clear all widgets
    for _, widget in ipairs(rareRowWidgets or {}) do
        widget:Hide()
        widget:ClearAllPoints()
        widget:SetParent(nil)
    end
    rareRowWidgets = {}

    for _, widget in ipairs(weeklyRowWidgets or {}) do
        widget:Hide()
        widget:ClearAllPoints()
        widget:SetParent(nil)
    end
    weeklyRowWidgets = {}

    for _, widget in ipairs(dailiesRowWidgets or {}) do
        widget:Hide()
        widget:ClearAllPoints()
        widget:SetParent(nil)
    end
    dailiesRowWidgets = {}

    local function sortByTimestamp(a, b)
        return a.time < b.time
    end

    local sortedDailies = {}
    for _, entry in ipairs(sessionDailies) do
        table.insert(sortedDailies, entry)
    end
    table.sort(sortedDailies, sortByTimestamp)

    local sortedWeeklies = {}
    for _, entry in ipairs(sessionWeeklies) do
        table.insert(sortedWeeklies, entry)
    end
    table.sort(sortedWeeklies, sortByTimestamp)

    local function buildRows(data, widgetTable, config)
        local startY = -5
        for i, entry in ipairs(data or {}) do
            local rowY = startY - (i * 24)
            for _, field in ipairs(config.fields) do
                local fontString = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
                fontString:SetPoint("TOPLEFT", field.x, rowY)
                fontString:SetText(tostring(field.format and field.format(entry) or entry[field.key] or "N/A"))
                fontString:SetTextColor(unpack(field.color))

                if field.width then
                    fontString:SetWidth(field.width)
                    fontString:SetWordWrap(false)
                    fontString:SetMaxLines(1)
                    fontString:SetJustifyH("LEFT")
                end

                if field.tooltip then
                    fontString:EnableMouse(true)
                    fontString:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 0, -24)
                        local r, g, b = unpack(field.color)
                        GameTooltip:AddLine(entry[field.tooltip] or "Unknown", r, g, b)
                        GameTooltip:Show()
                    end)
                    fontString:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                end

                table.insert(widgetTable, fontString)
            end

            local divider = scrollChild:CreateTexture(nil, "BACKGROUND")
            divider:SetColorTexture(0.2, 0.2, 0.2, 0.9)
            divider:SetPoint("TOPLEFT", 85, rowY - 20)
            divider:SetWidth(1050)
            divider:SetHeight(1)
            table.insert(widgetTable, divider)
        end
    end

    local tabConfigs = {
        rares = {
            data = sessionRares,
            widgets = rareRowWidgets,
            fields = {
                { key = "id", x = 85, color = {0.9, 0, 0} },
                { key = "npc", x = 190, color = {1, 0.8, 0.2} },
                { key = "npcID", x = 500, color = {1, 0.8, 0.2} },
                { key = "zone", x = 630, color = {0, 0.5, 0.1}, width = 200, tooltip = "zone" },
                { key = "zoneID", x = 845, color = {0, 0.5, 0.1} },
                { key = "time", x = 965, color = {0.5, 0.5, 0.5} },
            },
        },
        weeklies = {
            data = sortedWeeklies,
            widgets = weeklyRowWidgets,
            fields = {
                { key = "id", x = 85, color = {0.9, 0, 0} },
                { key = "name", x = 190, color = {1, 0.8, 0.2}, width = 300, tooltip = "name", format = function(entry)
                    return entry.isWorldQuest and ("WQ - " .. entry.name) or entry.name
                end },
                { key = "id", x = 500, color = {1, 0.8, 0.2} },
                { key = "zone", x = 630, color = {0, 0.5, 0.1}, width = 200, tooltip = "zone" },
                { key = "zoneID", x = 845, color = {0, 0.5, 0.1} },
                { key = "time", x = 965, color = {0.5, 0.5, 0.5} },
            },
        },
        dailies = {
            data = sortedDailies,
            widgets = dailiesRowWidgets,
            fields = {
                { key = "id", x = 85, color = {0.9, 0, 0} },
                { key = "name", x = 190, color = {1, 0.8, 0.2}, width = 300, tooltip = "name" },
                { key = "id", x = 500, color = {1, 0.8, 0.2} },
                { key = "zone", x = 630, color = {0, 0.5, 0.1}, width = 200, tooltip = "zone" },
                { key = "zoneID", x = 845, color = {0, 0.5, 0.1} },
                { key = "time", x = 965, color = {0.5, 0.5, 0.5} },
            },
        },
    }

    if tabConfigs[currentTab] then
        buildRows(tabConfigs[currentTab].data, tabConfigs[currentTab].widgets, tabConfigs[currentTab])
    else
        --print("Invalid tab selected:", currentTab)
    end
end

local function startRareTracking()
    local previousRareFlags = scanQuestFlags()
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("LOOT_OPENED")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            if not rareScanEnabled then
                guid = nil
                cachedName = nil
                npcID = nil
                lockedTarget = nil
                lastGuid = nil
                return
            end
            local newGuid = UnitGUID("target")
            if newGuid == lastGuid then
                return
            end
            lastGuid = newGuid
            if not UnitExists("target") then
                guid = nil
                cachedName = nil
                npcID = nil
                return
            end
            guid = newGuid
            cachedName = UnitName("target") or "Unknown"
            npcID = guid and tonumber(guid:match("Creature%-0%-%d+%-%d+%-%d+%-(%d+)")) or 0
            if npcID ~= 0 and not UnitIsPlayer("target") then
                lockedTarget = { name = cachedName, npcID = npcID }
                print("PLAYER_TARGET_CHANGED: Locked target | Name=", cachedName, "| NPCID=", npcID)
            else
                print("PLAYER_TARGET_CHANGED: Invalid target | Name=", cachedName, "| NPCID=", npcID)
                lockedTarget = nil
            end
        elseif event == "LOOT_OPENED" then
            if not rareScanEnabled then
                return
            end
            local lootGuid = GetLootSourceInfo(1)
            local lootName = GetUnitName("mouseover") or cachedName or "Unknown"
            local lootNpcID = lootGuid and tonumber(lootGuid:match("Creature%-0%-%d+%-%d+%-%d+%-(%d+)")) or 0
            if lootGuid then
                print("LOOT_OPENED: Looted | Name=", lootName, "| NPCID=", lootNpcID, "| LockedTarget=", lockedTarget and lockedTarget.npcID or "Nil")
            else
                print("LOOT_OPENED: No valid loot source | LockedTarget=", lockedTarget and lockedTarget.npcID or "Nil")
            end
        elseif event == "QUEST_LOG_UPDATE" then
            C_Timer.After(0.5, function()
                -- Scan quest log for quests
                for i = 1, C_QuestLog.GetNumQuestLogEntries() do
                    local info = C_QuestLog.GetInfo(i)
                    if info and not info.isHeader then
                        local questID = info.questID
                        local title = info.title or "Unknown"
                        local frequency = info.frequency or 0
                        local isWorldQuest = C_QuestLog.IsWorldQuest(questID) or C_TaskQuest.IsActive(questID)
                        local taskInfo = C_TaskQuest.GetQuestInfoByQuestID(questID)
                        isWorldQuest = isWorldQuest or (taskInfo and taskInfo.worldQuest)

                        if frequency == 2 or frequency == 1 or frequency == 3 or isWorldQuest then
                            local isDaily = (frequency == 1 or frequency == 3) and not isWorldQuest
                            local questType = isDaily and "Daily" or "Weekly"
                            local targetTable = isDaily and sessionDailies or sessionWeeklies
                            local dbTable = isDaily and PsychosHiddenQuestIdTrackerDB.dailies or PsychosHiddenQuestIdTrackerDB.weeklies

                            if not blacklist[questID] and not previousQuestIDs[questID] then
                                previousQuestIDs[questID] = true
                                local zoneID = C_Map.GetBestMapForUnit("player") or 0
                                local entry = {
                                    id = questID,
                                    name = title,
                                    zone = getZoneName(),
                                    zoneID = zoneID,
                                    time = date("%Y-%m-%d %H:%M:%S"),
                                    isWorldQuest = isWorldQuest
                                }
                                table.insert(targetTable, entry)
                                dbTable[questID] = entry
                                print(questType .. (isWorldQuest and " (World)" or "") .. " quest picked up:", title, "| QuestID:", questID)
                                updateScrollView()
                            end
                            if C_QuestLog.IsComplete(questID) and not completedQuestIDs[questID] then
                                completedQuestIDs[questID] = true
                                local zoneID = C_Map.GetBestMapForUnit("player") or 0
                                local entry = {
                                    id = questID,
                                    name = title,
                                    zone = getZoneName(),
                                    zoneID = zoneID,
                                    time = date("%Y-%m-%d %H:%M:%S"),
                                    isWorldQuest = isWorldQuest
                                }
                                table.insert(targetTable, entry)
                                dbTable[questID] = entry
                                print(questType .. (isWorldQuest and " (World)" or "") .. " quest completed:", title, "| QuestID:", questID)
                                updateScrollView()
                            end
                        end
                    end
                end

                -- Scan world quests for current zone only
                local zoneID = C_Map.GetBestMapForUnit("player") or 0
                local worldQuests = C_TaskQuest.GetQuestsForPlayerByMapID(zoneID)
                for _, questInfo in ipairs(worldQuests or {}) do
                    local questID = questInfo.questId
                    if not questID then
                        break
                    end
                    local title = C_QuestLog.GetTitleForQuestID(questID) or "Unknown"
                    local targetTable = sessionWeeklies
                    local dbTable = PsychosHiddenQuestIdTrackerDB.weeklies
                    if not blacklist[questID] and not previousQuestIDs[questID] then
                        previousQuestIDs[questID] = true
                        local entry = {
                            id = questID,
                            name = title,
                            zone = getZoneName(),
                            zoneID = zoneID,
                            time = date("%Y-%m-%d %H:%M:%S"),
                            isWorldQuest = true
                        }
                        table.insert(targetTable, entry)
                        dbTable[questID] = entry
                        print("Weekly (World) quest picked up:", title, "| QuestID:", questID)
                        updateScrollView()
                    end
                end

                if not rareScanEnabled then
                    guid = nil
                    cachedName = nil
                    npcID = nil
                    lockedTarget = nil
                    lastGuid = nil
                    updateScrollView()
                    return
                end
                local currentFlags = scanQuestFlags()
                for id in pairs(currentFlags) do
                    if not previousRareFlags[id] then
                        if not C_QuestLog.GetLogIndexForQuestID(id) then
                            local targetName = lockedTarget and lockedTarget.name or cachedName or "Unknown"
                            local targetNpcID = lockedTarget and lockedTarget.npcID or npcID or 0
                            if targetName ~= "Unknown" and targetNpcID ~= 0 then
                                local entry = {
                                    npcID = targetNpcID,
                                    npc = targetName,
                                    zone = getZoneName(),
                                    zoneID = C_Map.GetBestMapForUnit("player") or 0,
                                    id = id,
                                    time = date("%Y-%m-%d %H:%M:%S")
                                }
                                table.insert(sessionRares, entry)
                                PsychosHiddenQuestIdTrackerDB.rares[id] = entry
                                print("Rare logged: Name=", targetName, "| FlagID=", id, "| NPCID=", targetNpcID, "| Zone=", entry.zone)
                                lockedTarget = nil
                                updateScrollView()
                            end
                        end
                    end
                end
                previousRareFlags = currentFlags
            end)
        end
    end)
end

local idDisplayEventFrame = CreateFrame("Frame")
idDisplayEventFrame:RegisterEvent("PLAYER_LOGIN")
idDisplayEventFrame:SetScript("OnEvent", function()
    CreateIdDisplayFrame()
    SetupIdDisplayHooks()
end)

function buildScrollFrame()
    scrollParent = CreateFrame("Frame", "PHQIDTrackerFrame", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "PHQIDTrackerFrame")
    scrollParent:SetSize(1200, 440)
    scrollParent:SetPoint("CENTER", -130, 160)
    scrollParent:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    scrollParent:SetBackdropColor(0, 0, 0, 0.9)
    scrollParent:SetMovable(true)
    scrollParent:EnableMouse(true)
    scrollParent:RegisterForDrag("LeftButton")
    scrollParent:SetScript("OnDragStart", scrollParent.StartMoving)
    scrollParent:SetScript("OnDragStop", scrollParent.StopMovingOrSizing)
    scrollParent.scrollStep = 5
    scrollParent:Hide()

    local title = scrollParent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 20, -12)
    title:SetText("Psychos Hidden Quest ID Tracker")
    title:SetTextColor(.6, .8, 1)

    -- knownid Frame
    knownidListFrame = CreateFrame("Frame", nil, scrollParent, "BackdropTemplate")
    knownidListFrame:SetSize(410, 365)
    knownidListFrame:SetFrameLevel(scrollParent:GetFrameLevel() + 5)
    knownidListFrame:SetPoint("TOPRIGHT", scrollParent, "TOPRIGHT", -5, -70)
    knownidListFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    knownidListFrame:SetBackdropColor(0, 0, 0)
    knownidListFrame:Hide()

    local knownidScrollFrame = CreateFrame("ScrollFrame", nil, knownidListFrame, "UIPanelScrollFrameTemplate")
    knownidScrollFrame:SetPoint("TOPLEFT", 8, -8)
    knownidScrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)
    knownidScrollFrame:EnableMouseWheel(true)
    knownidScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local scrollAmount = 24
        self:SetVerticalScroll(math.max(0, math.min(current - delta * scrollAmount, maxScroll)))
    end)

    local scrollContent = CreateFrame("Frame", nil, knownidListFrame)
    scrollContent:SetSize(370, 600)
    knownidScrollFrame:SetScrollChild(scrollContent)

    local header = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    header:SetPoint("TOP", scrollContent, "TOP", 0, -10)
    header:SetJustifyH("CENTER")
    header:SetTextColor(0.6, 0.8, 1)
    header:SetText("Known Completed Flag ID Ranges")

    local twwHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    twwHeader:SetPoint("TOP", scrollContent, "TOP", 0, -50)
    twwHeader:SetJustifyH("CENTER")
    twwHeader:SetTextColor(0.4, 0.9, 1)
    twwHeader:SetText("-  The War Within  -")

    local twwData = {
        { "Rares",     "84000–92000" },
        { "Weeklies",  "85000–92000" },
        { "Dailies",   "85000–92000" },
        { "Dungeons",  "86000–91500" },
        { "Raids",     "88000–92000+" },
        { "Currency",  "88000–92000" },
    }

    local yStart = -90
    local spacing = 22

    for i, entry in ipairs(twwData) do
        local label, range = unpack(entry)
        local y = yStart - ((i - 1) * spacing)

        local labelText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        labelText:SetPoint("TOPLEFT", 50, y)
        labelText:SetTextColor(1, 0.8, 0.2)
        labelText:SetText(label)

        local rangeText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        rangeText:SetPoint("TOPLEFT", 190, y)
        rangeText:SetTextColor(0.9, 0, 0)
        rangeText:SetText(range)
    end

    local dfHeaderY = yStart - (#twwData * spacing) - 20
    local dfHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    dfHeader:SetPoint("TOP", scrollContent, "TOP", 0, dfHeaderY)
    dfHeader:SetJustifyH("CENTER")
    dfHeader:SetTextColor(0.4, 0.9, 1)
    dfHeader:SetText("-  Dragonflight & Prior  -")

    local dfData = {
        { "Rares",     "80000–85000" },
        { "Weeklies",  "50000–59999" },
        { "Dailies",   "40000–49999" },
        { "Dungeons",  "60000–69999" },
        { "Raids",     "70000–79999" },
        { "Currency",  "30000–39999" },
    }

    local dfStartY = dfHeaderY - 40
    for i, entry in ipairs(dfData) do
        local label, range = unpack(entry)
        local y = dfStartY - ((i - 1) * spacing)

        local labelText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        labelText:SetPoint("TOPLEFT", 50, y)
        labelText:SetTextColor(1, 0.8, 0.2)
        labelText:SetText(label)

        local rangeText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        rangeText:SetPoint("TOPLEFT", 190, y)
        rangeText:SetTextColor(0.9, 0, 0)
        rangeText:SetText(range)
    end

    local footerY = dfStartY - (#dfData * spacing) - 30
    local footer = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    footer:SetPoint("TOP", scrollContent, "TOP", 10, footerY)
    footer:SetWidth(350)
    footer:SetJustifyH("CENTER")
    footer:SetTextColor(0.9, 0, 0)
    footer:SetText("These ranges are approximate and represent common flag IDs for each content type.")

    local knownidbtn = CreateFrame("Button", nil, scrollParent, "UIPanelButtonTemplate")
    knownidbtn:SetNormalFontObject("GameFontNormalLarge")
    knownidbtn:SetHighlightFontObject("GameFontNormalLarge")
    knownidbtn:SetSize(150, 34)
    knownidbtn:SetPoint("TOPRIGHT", -18, -34)
    knownidbtn:SetText("Known ID Table")
    knownidbtn:SetScript("OnClick", function()
        if knownidListFrame:IsShown() then
            knownidListFrame:Hide()
        else
            knownidListFrame:Show()
        end
    end)

 local idDisplayBtn = CreateFrame("Frame", nil, scrollParent, "BackdropTemplate")
idDisplayBtn:SetSize(400, 30)
idDisplayBtn:SetPoint("TOPLEFT", 15, -40)
idDisplayBtn:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
idDisplayBtn:SetBackdropColor(PsychosHiddenQuestIdTrackerDB.idDisplayEnabled and 1 or 0, PsychosHiddenQuestIdTrackerDB.idDisplayEnabled and 0 or 1, 0, 0.6)

local idDisplayLabel = idDisplayBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
idDisplayLabel:SetPoint("CENTER")
idDisplayLabel:SetText(PsychosHiddenQuestIdTrackerDB.idDisplayEnabled and "Disable On Hover Tool for Currencies/Items/Spells" or "Enable On Hover Tool for Currencies/Items/Spells")
idDisplayLabel:SetTextColor(PsychosHiddenQuestIdTrackerDB.idDisplayEnabled and 1 or 0, PsychosHiddenQuestIdTrackerDB.idDisplayEnabled and 0 or 1, 0)

-- Add hover glow effect
local highlight = idDisplayBtn:CreateTexture(nil, "HIGHLIGHT")
highlight:SetAllPoints()
highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
highlight:SetBlendMode("ADD")
highlight:Hide()

idDisplayBtn:EnableMouse(true)
idDisplayBtn:SetScript("OnEnter", function()
    highlight:Show()
end)
idDisplayBtn:SetScript("OnLeave", function()
    highlight:Hide()
end)

idDisplayBtn:SetScript("OnMouseDown", function()
    idDisplayEnabled = not idDisplayEnabled
    PsychosHiddenQuestIdTrackerDB.idDisplayEnabled = idDisplayEnabled
    idDisplayLabel:SetText(idDisplayEnabled and "Disable On Hover Tool for Currencies/Items/Spells" or "Enable On Hover Tool for Currencies/Items/Spells")
    idDisplayLabel:SetTextColor(idDisplayEnabled and 1 or 0, idDisplayEnabled and 0 or 1, 0)
    idDisplayBtn:SetBackdropColor(idDisplayEnabled and 1 or 0, idDisplayEnabled and 0 or 1, 0, 0.6)
    print("On Hover Tool " .. (idDisplayEnabled and "enabled" or "disabled"))
    SetupIdDisplayHooks()
end)


    local function createTab(label, xOffset, tabType)
        local btn = CreateFrame("Button", nil, scrollParent, "UIPanelButtonTemplate")
        btn:SetNormalFontObject("GameFontNormalLarge")
        btn:SetHighlightFontObject("GameFontNormalLarge")
        btn:SetSize(110, 30)
        btn:SetPoint("TOPLEFT", xOffset, -40)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            currentTab = tabType
            if tabType == "rares" then
                sessionRares = {}
                for _, entry in pairs(PsychosHiddenQuestIdTrackerDB.rares) do
                    table.insert(sessionRares, entry)
                end
            elseif tabType == "weeklies" then
                sessionWeeklies = {}
                for _, entry in pairs(PsychosHiddenQuestIdTrackerDB.weeklies) do
                    table.insert(sessionWeeklies, entry)
                end
            elseif tabType == "dailies" then
                sessionDailies = {}
                for _, entry in pairs(PsychosHiddenQuestIdTrackerDB.dailies) do
                    table.insert(sessionDailies, entry)
                end
            end
            updateScrollView()
            C_Timer.After(0.1, updateScrollView)
        end)
    end

    createTab("Rares", 420, "rares")
    createTab("Weeklies", 540, "weeklies")
    createTab("Dailies", 660, "dailies")

    local masterHeaders = {
        { text = "Completed Flag ID#", x = 10 },
        { text = "Name/Quest", x = 195 },
        { text = "Npc/Quest ID#", x = 470 },
        { text = "Zone Name", x = 630 },
        { text = "Zone ID", x = 845 },
        { text = "Timestamp", x = 965 },
    }

    for _, h in ipairs(masterHeaders) do
        local label = PHQIDTrackerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("TOPLEFT", PHQIDTrackerFrame, "TOPLEFT", h.x + 15, -85)
        label:SetText(h.text)
        label:SetTextColor(.6, .8, 1)
    end

    local editFrom = scrollParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editFrom:SetPoint("TOPLEFT", 370, -15)
    editFrom:SetText("From quest ID :")

    local editTo = scrollParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editTo:SetPoint("TOPLEFT", 585, -15)
    editTo:SetText("To quest ID :")

    local minBox = CreateFrame("EditBox", nil, scrollParent, "InputBoxTemplate")
    minBox:SetFontObject("GameFontNormalLarge")
    minBox:SetSize(75, 25)
    minBox:SetTextColor(.9, 0, 0)
    minBox:SetPoint("TOPLEFT", 500, -10)
    minBox:SetMaxLetters(7)
    minBox:SetAutoFocus(false)

    local maxBox = CreateFrame("EditBox", nil, scrollParent, "InputBoxTemplate")
    maxBox:SetFontObject("GameFontNormalLarge")
    maxBox:SetSize(75, 25)
    maxBox:SetTextColor(.9, 0, 0)
    maxBox:SetPoint("TOPLEFT", minBox, "TOPRIGHT", 120, 0)
    maxBox:SetMaxLetters(7)
    maxBox:SetAutoFocus(false)

    C_Timer.After(0.1, function()
        local scan = PsychosHiddenQuestIdTrackerDB.scanRange
        minBox:SetText(tostring(scan.min))
        maxBox:SetText(tostring(scan.max))
    end)

    local function updateScanRange()
        local min = tonumber(minBox:GetText())
        local max = tonumber(maxBox:GetText())
        if min and max and min < max then
            PsychosHiddenQuestIdTrackerDB.scanRange.min = min
            PsychosHiddenQuestIdTrackerDB.scanRange.max = max
            print("Updated scan range:", min, "-", max)
            previousRareFlags = scanQuestFlags()
        else
            print("Invalid range. Use lower value in Min and higher in Max.")
        end
    end

    minBox:SetScript("OnEnterPressed", function(self)
        updateScanRange()
        self:ClearFocus()
    end)
    maxBox:SetScript("OnEnterPressed", function(self)
        updateScanRange()
        self:ClearFocus()
    end)

local customBtn = CreateFrame("Frame", nil, scrollParent, "BackdropTemplate")
customBtn:SetSize(240, 60)
customBtn:SetPoint("TOPRIGHT", -180, -10)
customBtn:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
customBtn:SetBackdropColor(PsychosHiddenQuestIdTrackerDB.rareScanEnabled and 1 or 0, PsychosHiddenQuestIdTrackerDB.rareScanEnabled and 0 or 1, 0, 0.6)

local label = customBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
label:SetPoint("CENTER")
label:SetText(PsychosHiddenQuestIdTrackerDB.rareScanEnabled and "Disable Rare Scan" or "Enable Rare Scan")
label:SetTextColor(PsychosHiddenQuestIdTrackerDB.rareScanEnabled and 1 or 0, PsychosHiddenQuestIdTrackerDB.rareScanEnabled and 0 or 1, 0)

-- Add hover glow effect
local highlight = customBtn:CreateTexture(nil, "HIGHLIGHT")
highlight:SetAllPoints()
highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
highlight:SetBlendMode("ADD")
highlight:SetAlpha(0.6) -- Optional: soften the glow
highlight:Hide()

customBtn:EnableMouse(true)
customBtn:SetScript("OnEnter", function()
    highlight:Show()
end)
customBtn:SetScript("OnLeave", function()
    highlight:Hide()
end)

customBtn:SetScript("OnMouseDown", function()
    rareScanEnabled = not rareScanEnabled
    PsychosHiddenQuestIdTrackerDB.rareScanEnabled = rareScanEnabled
    label:SetText(rareScanEnabled and "Disable Rare Scan" or "Enable Rare Scan")
    label:SetTextColor(rareScanEnabled and 1 or 0, rareScanEnabled and 0 or 1, 0)
    customBtn:SetBackdropColor(rareScanEnabled and 1 or 0, rareScanEnabled and 0 or 1, 0, 0.6)
    print("Rare scanning " .. (rareScanEnabled and "enabled" or "disabled"))

    if not rareScanEnabled then
        guid = nil
        cachedName = nil
        npcID = nil
        lockedTarget = nil
        lastGuid = nil
    end

    UpdateMinimapButtonColor()
end)


    local closeBtn = CreateFrame("Button", nil, scrollParent, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() scrollParent:Hide() end)

    scrollFrame = CreateFrame("ScrollFrame", nil, scrollParent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -100)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(580, 1000)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollAmount = 24
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(current - delta * scrollAmount, maxScroll)))
    end)

    textList = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    textList:SetJustifyH("LEFT")
    textList:SetPoint("TOPLEFT")
    textList:SetWidth(980)
    textList:SetTextColor(1, 1, 1)
    textList:SetText("")
end

-- Create minimap button
local minimapButton = CreateFrame("Button", buttonName, Minimap)
minimapButton:SetSize(28, 28)
minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 5)
minimapButton:EnableMouse(true)
minimapButton:RegisterForDrag("RightButton")
minimapButton:SetClampedToScreen(true)

-- Icon texture
local texture = minimapButton:CreateTexture(nil, "BACKGROUND")
texture:SetTexture("136122")
texture:SetAllPoints()
minimapButton.texture = texture

-- Circular mask
local mask = minimapButton:CreateMaskTexture()
mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
mask:SetAllPoints()
texture:AddMaskTexture(mask)

-- Optional border
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Common\\GoldRing")
border:SetSize(30, 30)
border:SetPoint("CENTER", minimapButton, "CENTER")
function UpdateMinimapButtonColor()
    if not border then return end
    if PsychosHiddenQuestIdTrackerDB.rareScanEnabled then
        border:SetVertexColor(1, 0, 0)
    else
        border:SetVertexColor(0, 1, 0)
    end
end

-- Position updater
local function UpdateButtonPosition()
    local a = PsychosHiddenQuestIdTrackerDB.minimapPos.angle or math.rad(130)
    local x = math.cos(a) * radius
    local y = math.sin(a) * radius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Drag behavior
minimapButton:SetScript("OnDragStart", function(self)
    self.dragging = true
end)

minimapButton:SetScript("OnDragStop", function(self)
    self.dragging = false
    self:StopMovingOrSizing()
end)

minimapButton:SetScript("OnUpdate", function(self)
    if self.dragging then
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local dx = (px / scale - mx)
        local dy = (py / scale - my)
        local newAngle = math.atan2(dy, dx)
        PsychosHiddenQuestIdTrackerDB.minimapPos.angle = newAngle
        UpdateButtonPosition()
    end
end)

-- Tooltip on hover
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("|cff00FF00Psychos Hidden Quest ID Tracker|r")
    GameTooltip:AddLine("|cff00A800Left click|r to open/close|r")
    GameTooltip:AddLine("|cffFF7733Right click|r to drag")
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Click behavior to toggle main frame
minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if scrollParent and scrollParent:IsShown() then
            scrollParent:Hide()
        else
            SlashCmdList["PHQID"]()
        end
    end
end)

-- Initialize minimap button position on login
local minimapEventFrame = CreateFrame("Frame")
minimapEventFrame:RegisterEvent("PLAYER_LOGIN")
minimapEventFrame:SetScript("OnEvent", function()
    UpdateButtonPosition()
    UpdateMinimapButtonColor()
    --print("PsychosHiddenQuestIdTracker: Minimap button initialized")
end)

SLASH_PHQID1 = "/phqid"
SlashCmdList["PHQID"] = function()
    if not scrollParent then
        buildScrollFrame()
    end

    startRareTracking()
    updateScrollView()
    SetupIdDisplayHooks()
    scrollParent:Show()
end
