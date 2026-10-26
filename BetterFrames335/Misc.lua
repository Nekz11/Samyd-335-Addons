-- BetterFrames335 - Misc.lua
-- Chat spam filters and a battleground / arena queue timer.

local BBF = BBF335
local M = BBF:NewModule("Misc")
local db

----------------------------------------------------------------------
-- chat filters
----------------------------------------------------------------------
local function PatternFromGlobal(str)
    -- turn a GlobalStrings format ("%s has come online.") into a Lua pattern:
    -- escape magic characters first, then replace the format specifiers with captures
    if not str then return end
    str = str:gsub("([%.%+%-%*%?%[%]%^%$%(%)])", "%%%1")
    str = str:gsub("%%%d?%$?s", "(.-)"):gsub("%%%d?%$?d", "(%%d+)")
    return "^" .. str .. "$"
end

local systemPatterns, talentPatterns = {}, {}
local function AddPatterns(list, names)
    for _, gname in ipairs(names) do
        local p = PatternFromGlobal(_G[gname])     -- missing globals are simply skipped
        if p then list[#list + 1] = p end
    end
end

local function BuildPatterns()
    AddPatterns(systemPatterns, { "ERR_FRIEND_ONLINE_SS", "ERR_FRIEND_OFFLINE_S", "MARKED_AFK", "CLEARED_AFK",
        "MARKED_DND", "CLEARED_DND", "MARKED_AFK_MESSAGE", "ERR_CHAT_PLAYER_NOT_FOUND_S", "ERR_NOT_IN_RAID",
        "ERR_GUILD_PLAYER_NOT_IN_GUILD_S" })
    AddPatterns(talentPatterns, { "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_SPELL_UNLEARNED_S", "ERR_LEARN_PASSIVE_S" })
end

local function Matches(list, msg)
    for i = 1, #list do
        if msg:find(list[i]) then return true end
    end
    return false
end

-- 3.3.5 passes (chatFrame, event, msg, ...) to filters; older builds passed (msg, ...) - handle both
local function SystemFilter(a, b, c)
    local msg = (type(a) == "table") and c or a
    if not db or type(msg) ~= "string" then return false end
    if db.chatFilterTalents and Matches(talentPatterns, msg) then return true end
    if db.chatFilterSystem and Matches(systemPatterns, msg) then return true end
    return false
end

local function EmoteFilter()
    return db and db.chatFilterEmotes
end

local function ArenaNpcFilter()
    return db and db.chatFilterArenaNpc and BBF:InArena()
end

----------------------------------------------------------------------
-- queue timer
----------------------------------------------------------------------
local qframe
local function CreateQueueFrame()
    local f = CreateFrame("Frame", "BBF335QueueTimer", UIParent)
    f:SetWidth(190)
    f:SetHeight(44)
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -10)
    f:SetFrameStrata("MEDIUM")
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0, 0, 0, 0.7)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
    f.title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -6)
    f.title:SetJustifyH("LEFT")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 7)
    f.text:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 7)
    f.text:SetJustifyH("LEFT")
    f:Hide()
    return f
end

local function FormatTime(sec)
    sec = math.max(0, math.floor(sec))
    return format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local lastConfirm = {}
local function UpdateQueue()
    if not db or not db.queueTimer then if qframe then qframe:Hide() end return end
    local shown = false
    for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
        local status, mapName, _, _, _, teamSize, registered = GetBattlefieldStatus(i)
        if status == "queued" or status == "confirm" then
            if not qframe then qframe = CreateQueueFrame() end
            local label = mapName or "Queue"
            if teamSize and teamSize > 0 then
                label = format("Arena %dv%d%s", teamSize, teamSize, registered and " (rated)" or " (skirmish)")
            end
            qframe.title:SetText(label)
            if status == "confirm" then
                qframe.text:SetText("|cff00ff00READY|r - " .. FormatTime((GetBattlefieldPortExpiration(i) or 0)))
                if db.queueTimerSound and not lastConfirm[i] then
                    PlaySoundFile("Sound\\Interface\\ReadyCheck.wav")
                    lastConfirm[i] = true
                end
            else
                lastConfirm[i] = nil
                local waited = (GetBattlefieldTimeWaited(i) or 0) / 1000
                local est = (GetBattlefieldEstimatedWaitTime(i) or 0) / 1000
                local txt = "waiting " .. FormatTime(waited)
                if est > 0 then txt = txt .. "   est. " .. FormatTime(est) end
                qframe.text:SetText(txt)
            end
            qframe:Show()
            shown = true
            break
        else
            lastConfirm[i] = nil
        end
    end
    if not shown and qframe then qframe:Hide() end
end

----------------------------------------------------------------------
-- minimap button
----------------------------------------------------------------------
local mmButton

local function MinimapButtonPosition()
    local angle = math.rad(db.minimapAngle or 200)
    local radius = 80
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function MinimapButtonDrag()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    MinimapButtonPosition()
end

local function CreateMinimapButton()
    local b = CreateFrame("Button", "BBF335MinimapButton", Minimap)
    b:SetWidth(31)
    b:SetHeight(31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetMovable(true)

    local overlay = b:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetWidth(20)
    bg:SetHeight(20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -5)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(18)
    icon:SetHeight(18)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -6)

    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            BBF:ToggleMove()
        elseif IsShiftKeyDown() then
            BBF:ToggleCastTest()
        else
            BBF:OpenOptions()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", MinimapButtonDrag)
    end)
    b:SetScript("OnDragStop", function(self)
        self.dragging = nil
        self:SetScript("OnUpdate", nil)
    end)
    b:SetScript("OnEnter", function(self)
        if self.dragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff00ccffBetterFrames|r 335  |cff888888v" .. BBF.version .. "|r")
        GameTooltip:AddLine("Left-click: options", 1, 1, 1)
        GameTooltip:AddLine("Right-click: move frames", 1, 1, 1)
        GameTooltip:AddLine("Shift+click: castbar test", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function UpdateMinimapButton()
    if not Minimap then return end
    if not mmButton then mmButton = CreateMinimapButton() end
    if db.minimapButton then
        MinimapButtonPosition()
        mmButton:Show()
    else
        mmButton:Hide()
    end
end

function M:Init()
    db = BBF.db
    BuildPatterns()
    UpdateMinimapButton()
    if ChatFrame_AddMessageEventFilter then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", SystemFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_EMOTE", EmoteFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_TEXT_EMOTE", EmoteFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_YELL", ArenaNpcFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_SAY", ArenaNpcFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", ArenaNpcFilter)
    end

    qframe = CreateQueueFrame()
    BBF:RegisterEvent("UPDATE_BATTLEFIELD_STATUS", UpdateQueue)
    local t = 0
    qframe.ticker = CreateFrame("Frame")
    qframe.ticker:SetScript("OnUpdate", BBF:Guard("QueueTimer", function(_, elapsed)
        t = t + elapsed
        if t < 1 then return end
        t = 0
        if db.queueTimer then UpdateQueue() end
    end))
end

function M:Apply()
    UpdateQueue()
    UpdateMinimapButton()
end
