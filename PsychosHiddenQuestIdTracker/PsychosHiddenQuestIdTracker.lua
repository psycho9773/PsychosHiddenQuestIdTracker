local frame = CreateFrame("Frame")
local initFrame = CreateFrame("Frame")
local currentTab = "rares"

initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function()
    PsychosHiddenQuestIdTrackerDB = PsychosHiddenQuestIdTrackerDB or {}
    PsychosHiddenQuestIdTrackerDB.rares    = PsychosHiddenQuestIdTrackerDB.rares    or {}
    PsychosHiddenQuestIdTrackerDB.weeklies = PsychosHiddenQuestIdTrackerDB.weeklies or {}
    PsychosHiddenQuestIdTrackerDB.dailies  = PsychosHiddenQuestIdTrackerDB.dailies  or {}
    PsychosHiddenQuestIdTrackerDB.currency = PsychosHiddenQuestIdTrackerDB.currency or {}
    PsychosHiddenQuestIdTrackerDB.scanRange = PsychosHiddenQuestIdTrackerDB.scanRange or { min = 84000, max = 91000 }
    PsychosHiddenQuestIdTrackerDB.rareScanEnabled = PsychosHiddenQuestIdTrackerDB.rareScanEnabled or false
end)

local sessionRares = {}
local sessionWeeklies, sessionDailies, sessionCurrency = {}, {}, {}
local scrollParent, scrollFrame, scrollChild, textList
local knownidListFrame 
local rareRowWidgets = {}
local weeklyRowWidgets = {}
local dailiesRowWidgets = {}
local currencyRowWidgets = {}
local rareScanEnabled = false
local guid, cachedName, npcID
local lockedTarget = nil
local lastGuid = nil
local completedQuestIDs = {}
local previousQuestIDs = {}

local blacklist = {
    [57562] = true, [53435] = true, [82146] = true, [82156] = true,
    [50598] = true, [57567] = true, [50603] = true, [57565] = true,
    [50602] = true, [85489] = true, [48639] = true, [56120] = true,
    [82158] = true, [86174] = true, [42233] = true, [61982] = true,
    [48641] = true, [75511] = true, [50604] = true,
    [57566] = true, [42421] = true, [57564] = true,
    [50562] = true, [42422] = true, [42234] = true,
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

    for _, widget in ipairs(currencyRowWidgets or {}) do
        widget:Hide()
        widget:ClearAllPoints()
        widget:SetParent(nil)
    end
    currencyRowWidgets = {}

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
                { key = "npcID", x = 460, color = {1, 0.8, 0.2} },
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
                { key = "name", x = 190, color = {1, 0.8, 0.2}, width = 250, tooltip = "name" },
                { key = "id", x = 460, color = {1, 0.8, 0.2} },
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
                { key = "name", x = 190, color = {1, 0.8, 0.2}, width = 250, tooltip = "name", format = function(entry)
                    return C_QuestLog.IsWorldQuest(entry.id) and (entry.name .. " (WQ)") or entry.name
                end },
                { key = "id", x = 460, color = {1, 0.8, 0.2} },
                { key = "zone", x = 630, color = {0, 0.5, 0.1}, width = 200, tooltip = "zone" },
                { key = "zoneID", x = 845, color = {0, 0.5, 0.1} },
                { key = "time", x = 965, color = {0.5, 0.5, 0.5} },
            },
        },
        currency = {
            data = sessionCurrency,
            widgets = currencyRowWidgets,
            fields = {
                { key = "name", x = 85, color = {1, 0.8, 0.2}, width = 250, tooltip = "name" },
                { key = "amount", x = 360, color = {0, 0.5, 0.1} },
            },
        },
    }

    if tabConfigs[currentTab] then
        buildRows(tabConfigs[currentTab].data, tabConfigs[currentTab].widgets, tabConfigs[currentTab])
        -- print(currentTab .. " tab data:", #tabConfigs[currentTab].data, "entries")
    else
        print("Invalid tab selected:", currentTab)
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
                for i = 1, C_QuestLog.GetNumQuestLogEntries() do
                    local info = C_QuestLog.GetInfo(i)
                    if info and not info.isHeader then
                        local questID = info.questID
                        local title = info.title or "Unknown"
                        local frequency = info.frequency or 0
                        local isWorldQuest = C_QuestLog.IsWorldQuest(questID)
                        if frequency == 2 or frequency == 1 or frequency == 3 or isWorldQuest then
                            -- Modified to handle nil timeLeft
                            local timeLeft = isWorldQuest and C_TaskQuest.GetQuestTimeLeftMinutes(questID) or nil
                            local isDaily = (frequency == 1 or frequency == 3 or (isWorldQuest and timeLeft and timeLeft <= 1440)) and not (frequency == 2)
                            local questType = isDaily and "Daily" or "Weekly"
                            local targetTable = isDaily and sessionDailies or sessionWeeklies
                            local dbTable = isDaily and PsychosHiddenQuestIdTrackerDB.dailies or PsychosHiddenQuestIdTrackerDB.weeklies

                            if not blacklist[questID] then
                                if not previousQuestIDs[questID] then
                                    previousQuestIDs[questID] = true
                                    local zoneID = C_Map.GetBestMapForUnit("player") or 0
                                    local entry = {
                                        id = questID,
                                        name = title,
                                        zone = getZoneName(),
                                        zoneID = zoneID,
                                        time = date("%Y-%m-%d %H:%M:%S")
                                    }
                                    table.insert(targetTable, entry)
                                    dbTable[questID] = entry
                                    print(questType .. " quest picked up:", title, "| QuestID:", questID)
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
                                        time = date("%Y-%m-%d %H:%M:%S")
                                    }
                                    table.insert(targetTable, entry)
                                    dbTable[questID] = entry
                                    print(questType .. " quest completed:", title, "| QuestID:", questID)
                                    updateScrollView()
                                end
                            end
                        end
                    end
                end
                local zoneID = C_Map.GetBestMapForUnit("player") or 0
                local worldQuests = C_TaskQuest.GetQuestsForPlayerByMapID(zoneID)
                for _, questInfo in ipairs(worldQuests or {}) do
                    local questID = questInfo.questId
                    if not questID then
                        -- Skip silently
                        break
                    end
                    local title = C_QuestLog.GetTitleForQuestID(questID) or "Unknown"
                    local timeLeft = C_TaskQuest.GetQuestTimeLeftMinutes(questID) or nil
                    local isDaily = timeLeft and timeLeft <= 1440
                    local questType = isDaily and "Daily" or "Weekly"
                    local targetTable = isDaily and sessionDailies or sessionWeeklies
                    local dbTable = isDaily and PsychosHiddenQuestIdTrackerDB.dailies or PsychosHiddenQuestIdTrackerDB.weeklies
                    if not blacklist[questID] and not previousQuestIDs[questID] then
                        previousQuestIDs[questID] = true
                        local entry = {
                            id = questID,
                            name = title,
                            zone = getZoneName(),
                            zoneID = zoneID,
                            time = date("%Y-%m-%d %H:%M:%S")
                        }
                        table.insert(targetTable, entry)
                        dbTable[questID] = entry
                        print(questType .. " (World) quest picked up:", title, "| QuestID:", questID)
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
    title:SetText("Psychos Hidden Quest Tracker")
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
    knownidListFrame:Hide() -- start hidden

    -- Create the known ID scroll frame inside knownidListFrame
    local knownidScrollFrame = CreateFrame("ScrollFrame", nil, knownidListFrame, "UIPanelScrollFrameTemplate")
    knownidScrollFrame:SetPoint("TOPLEFT", 8, -8)
    knownidScrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)
    knownidScrollFrame:EnableMouseWheel(true)
    knownidScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local scrollAmount = 24  -- adjust to your liking
        self:SetVerticalScroll(math.max(0, math.min(current - delta * scrollAmount, maxScroll)))
    end)

    -- Create the content frame to hold text
    local scrollContent = CreateFrame("Frame", nil, knownidScrollFrame)
    scrollContent:SetSize(370, 600)
    knownidScrollFrame:SetScrollChild(scrollContent)

    -- Main title, centered
    local header = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    header:SetPoint("TOP", scrollContent, "TOP", 0, -10)
    header:SetJustifyH("CENTER")
    header:SetTextColor(0.6, 0.8, 1)
    header:SetText("Known Completed Flag ID Ranges")

    -- The War Within section header, centered
    local twwHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    twwHeader:SetPoint("TOP", scrollContent, "TOP", 0, -50)
    twwHeader:SetJustifyH("CENTER")
    twwHeader:SetTextColor(0.4, 0.9, 1)
    twwHeader:SetText("-  The War Within  -")

    -- Range entries for The War Within, columnized
    local twwData = {
        { "Rares",     "84000–91000" },
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

        local labelText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        labelText:SetPoint("TOPLEFT", 50, y)
        labelText:SetTextColor(1, 0.8, 0.2)
        labelText:SetText(label)

        local rangeText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        rangeText:SetPoint("TOPLEFT", 190, y)
        rangeText:SetTextColor(0.9, 0, 0)
        rangeText:SetText(range)
    end

    -- Dragonflight & Prior section header, centered
    local dfHeaderY = yStart - (#twwData * spacing) - 20
    local dfHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    dfHeader:SetPoint("TOP", scrollContent, "TOP", 0, dfHeaderY)
    dfHeader:SetJustifyH("CENTER")
    dfHeader:SetTextColor(0.4, 0.9, 1)
    dfHeader:SetText("-  Dragonflight & Prior  -")

    -- Dragonflight range entries, columnized
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

        local labelText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        labelText:SetPoint("TOPLEFT", 50, y)
        labelText:SetTextColor(1, 0.8, 0.2)
        labelText:SetText(label)

        local rangeText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        rangeText:SetPoint("TOPLEFT", 190, y)
        rangeText:SetTextColor(0.9, 0, 0)
        rangeText:SetText(range)
    end

    -- Footer note, centered
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

    local function createTab(label, xOffset, tabType)
        local btn = CreateFrame("Button", nil, scrollParent, "UIPanelButtonTemplate")
        btn:SetNormalFontObject("GameFontNormalLarge")
        btn:SetHighlightFontObject("GameFontNormalLarge")
        btn:SetSize(110, 30)
        btn:SetPoint("TOPLEFT", xOffset, -40)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            currentTab = tabType
            if tabType == "weeklies" then
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

    createTab("Rares", 120, "rares")
    createTab("Weeklies", 265, "weeklies")
    createTab("Dailies", 410, "dailies")
    createTab("Currency", 555, "currency")

    local masterHeaders = {
        { text = "Completed Flag ID#", x = 10 },
        { text = "Name/Quest/Currency", x = 190 },
        { text = "Npc/Qst/Curr.ID#", x = 460 },
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

    customBtn:EnableMouse(true)
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

SLASH_PHQID1 = "/phqid"
SlashCmdList["PHQID"] = function()
    if not PsychosHiddenQuestIdTrackerDB then
        PsychosHiddenQuestIdTrackerDB = {}
    end
    PsychosHiddenQuestIdTrackerDB.rares    = PsychosHiddenQuestIdTrackerDB.rares    or {}
    PsychosHiddenQuestIdTrackerDB.weeklies = PsychosHiddenQuestIdTrackerDB.weeklies or {}
    PsychosHiddenQuestIdTrackerDB.dailies  = PsychosHiddenQuestIdTrackerDB.dailies  or {}
    PsychosHiddenQuestIdTrackerDB.currency = PsychosHiddenQuestIdTrackerDB.currency or {}
    PsychosHiddenQuestIdTrackerDB.scanRange = PsychosHiddenQuestIdTrackerDB.scanRange or { min = 84000, max = 91000 }
    PsychosHiddenQuestIdTrackerDB.rareScanEnabled = PsychosHiddenQuestIdTrackerDB.rareScanEnabled or false
    rareScanEnabled = PsychosHiddenQuestIdTrackerDB.rareScanEnabled

    if not scrollParent then
        buildScrollFrame()
    end

    startRareTracking()
    updateScrollView()
    scrollParent:Show()
end
