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
local previousRareFlags = nil
local weeklyRowWidgets = {}
local dailiesRowWidgets = {}
local currencyRowWidgets = {}
local rareScanEnabled = false
local guid, cachedName, npcID
local lockedTarget = nil
local lastGuid = nil
local completedWeeklyIDs = {}
local previousWeeklyIDs = {}

local blacklist = {
    [75511] = true,
    [53435] = true
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
--[[    print("Updating scroll view for tab:", currentTab, "| sessionRares:", #sessionRares, "| sessionWeeklies:", #sessionWeeklies)
]]-- Blocked for now

    for _, widget in ipairs(rareRowWidgets or {}) do
        widget:Hide()
    end
    rareRowWidgets = {}

    for _, widget in ipairs(weeklyRowWidgets or {}) do
        widget:Hide()
    end
    weeklyRowWidgets = {}

    for _, widget in ipairs(dailiesRowWidgets or {}) do
        widget:Hide()
    end
    dailiesRowWidgets = {}

    for _, widget in ipairs(currencyRowWidgets or {}) do
        widget:Hide()
    end
    currencyRowWidgets = {}

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
            data = sessionWeeklies,
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
            data = sessionDailies,
            widgets = dailiesRowWidgets,
            fields = {
                { key = "name", x = 85, color = {1, 0.8, 0.2}, width = 250, tooltip = "name" },
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
    else
        print("Invalid tab selected:", currentTab)
    end
end

local function startRareTracking()
    previousRareFlags = scanQuestFlags()
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
            if lootGuid and lockedTarget and lockedTarget.npcID then
                local lootName = GetUnitName("mouseover") or cachedName or "Unknown"
                local lootNpcID = lootGuid and tonumber(lootGuid:match("Creature%-0%-%d+%-%d+%-%d+%-(%d+)")) or 0
                if lootNpcID ~= 0 and lootName ~= "Unknown" and lootNpcID == lockedTarget.npcID then
                    lockedTarget = { name = lootName, npcID = lootNpcID }
                    print("LOOT_OPENED: Updated locked target from corpse | Name=", lootName, "| NPCID=", lootNpcID)
                else
                    print("LOOT_OPENED: Skipped loot target | Name=", lootName, "| NPCID=", lootNpcID, "| Expected NPCID=", lockedTarget.npcID)
                end
            else
                print("LOOT_OPENED: No valid loot source or no locked target | LootGUID=", lootGuid and "Valid" or "Nil", "| LockedTarget=", lockedTarget and lockedTarget.npcID or "Nil")
            end
        elseif event == "QUEST_LOG_UPDATE" then
            C_Timer.After(0.5, function()
                for i = 1, C_QuestLog.GetNumQuestLogEntries() do
                    local info = C_QuestLog.GetInfo(i)
                    if info and not info.isHeader and info.frequency == 2 then
                        local questID = info.questID
                        local title = info.title or "Unknown"
                        if not blacklist[questID] then
                            if not previousWeeklyIDs[questID] then
                                previousWeeklyIDs[questID] = true
                                local zoneID = C_Map.GetBestMapForUnit("player") or 0
                                local entry = {
                                    id = questID,
                                    name = title,
                                    zone = getZoneName(),
                                    zoneID = zoneID,
                                    time = date("%Y-%m-%d %H:%M:%S")
                                }
                                table.insert(sessionWeeklies, entry)
                                PsychosHiddenQuestIdTrackerDB.weeklies[questID] = entry
                                print("Weekly quest logged:", entry.name, "| QuestID:", entry.id)
                                updateScrollView()
                            end
                            if C_QuestLog.IsComplete(questID) and not completedWeeklyIDs[questID] then
                                completedWeeklyIDs[questID] = true
                                local zoneID = C_Map.GetBestMapForUnit("player") or 0
                                local entry = {
                                    id = questID,
                                    name = title,
                                    zone = getZoneName(),
                                    zoneID = zoneID,
                                    time = date("%Y-%m-%d %H:%M:%S")
                                }
                                table.insert(sessionWeeklies, entry)
                                PsychosHiddenQuestIdTrackerDB.weeklies[questID] = entry
                                print("Weekly quest completed:", entry.name, "| QuestID:", entry.id)
                                updateScrollView()
                            end
                        end
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
                local newFlagsFound = false
                for id in pairs(currentFlags) do
                    if not previousRareFlags or not previousRareFlags[id] then
                        if not C_QuestLog.GetLogIndexForQuestID(id) then
                            local targetName = lockedTarget and lockedTarget.name or cachedName or "Unknown"
                            local targetNpcID = lockedTarget and lockedTarget.npcID or npcID or 0
                            if targetName == "Unknown" or targetNpcID == 0 then
                                print("QUEST_LOG_UPDATE: Skipped logging rare due to invalid data | Name=", targetName, "| NPCID=", targetNpcID, "| FlagID=", id)
                            else
                                newFlagsFound = true
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
                                print("Rare logged: Name=", entry.npc, "| FlagID=", id, "| NPCID=", entry.npcID, "| Zone=", entry.zone)
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

    local function createTab(label, xOffset, tabType)
        local btn = CreateFrame("Button", nil, scrollParent, "UIPanelButtonTemplate")
        btn:SetNormalFontObject("GameFontNormalLarge")
        btn:SetHighlightFontObject("GameFontNormalLarge")
        btn:SetSize(110, 30)
        btn:SetPoint("TOPLEFT", xOffset, -40)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            currentTab = tabType
            updateScrollView()
        end)
    end

    createTab("Rares", 320, "rares")
    createTab("Weeklies", 465, "weeklies")
    createTab("Dailies", 610, "dailies")
    createTab("Currency", 755, "currency")

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
    minBox:SetTextColor(1, 1, 1)
    minBox:SetPoint("TOPLEFT", 500, -10)
    minBox:SetMaxLetters(7)
    minBox:SetAutoFocus(false)

    local maxBox = CreateFrame("EditBox", nil, scrollParent, "InputBoxTemplate")
    maxBox:SetFontObject("GameFontNormalLarge")
    maxBox:SetSize(75, 25)
    maxBox:SetTextColor(1, 1, 1)
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
    customBtn:SetSize(240, 50)
    customBtn:SetPoint("TOPRIGHT", -60, -20)
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
        print("Rare scanning is now", rareScanEnabled and "enabled" or "disabled")
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
    print("Rare scanning initialized, state:", rareScanEnabled and "enabled" or "disabled")
end
