-- RetailPartyFrames - extras: minimap button, announcements, out-of-combat fading, key bindings

local _, ns = ...

------------------------------------------------------------------------
-- Key bindings (Bindings.xml)
------------------------------------------------------------------------
BINDING_HEADER_RETAILPARTYFRAMES = "RetailPartyFrames"
BINDING_NAME_RPF_TOGGLE_OPTIONS = "Toggle options window"
BINDING_NAME_RPF_TOGGLE_TEST = "Cycle test mode (party / raid / off)"
BINDING_NAME_RPF_TOGGLE_LOCK = "Lock / unlock frames"

------------------------------------------------------------------------
-- Out-of-combat fading
------------------------------------------------------------------------
local function ApplyOOCAlpha(inCombat)
    local db = ns.db
    if not db then return end
    local alpha = inCombat and 1 or db.oocAlpha
    for _, c in ipairs({ ns.container, ns.raidContainer, ns.mtContainer }) do
        if c then c:SetAlpha(alpha) end
    end
end

ns:On("PLAYER_REGEN_DISABLED", function() ApplyOOCAlpha(true) end)
ns:On("PLAYER_REGEN_ENABLED", function() ApplyOOCAlpha(false) end)
ns:RegisterCallback("LAYOUT", function() ApplyOOCAlpha(InCombatLockdown()) end)

------------------------------------------------------------------------
-- Announcements
------------------------------------------------------------------------
local function Channel()
    local mode = ns.db.announce.channel
    if mode == "SELF" then return nil end
    if ns.inBattleground and mode ~= "SAY" then return "BATTLEGROUND" end
    if mode == "AUTO" then
        if GetNumRaidMembers() > 0 then return "RAID" end
        if GetNumPartyMembers() > 0 then return "PARTY" end
        return nil
    end
    if mode == "RAID" and GetNumRaidMembers() == 0 then mode = "PARTY" end
    if mode == "PARTY" and GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then return nil end
    return mode
end

local function Say(text)
    local chan = Channel()
    if chan then
        SendChatMessage(text, chan)
    else
        ns:Print(text)
    end
end

local lastAnnounce = {}
function ns:AnnounceCooldown(e, srcName, destName, srcGUID)
    local a = self.db.announce
    if not a.cooldowns or not a.categories[e.cat] then return end
    if self.testMode then return end
    -- announce only cooldowns of other people when I am not the one who used it? no: announce all, but once
    local now = GetTime()
    local key = srcGUID .. ":" .. e.id
    if lastAnnounce[key] and now - lastAnnounce[key] < 3 then return end
    lastAnnounce[key] = now
    local spell = GetSpellInfo(e.id) or ("spell " .. e.id)
    local text
    if destName and destName ~= "" and destName ~= srcName then
        text = string.format("%s: %s on %s", srcName or "?", spell, destName)
    else
        text = string.format("%s: %s", srcName or "?", spell)
    end
    Say(text)
end

ns:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, subevent, srcGUID, _, _, _, destName, _, _, _, _, _, extraName)
    if subevent ~= "SPELL_DISPEL" then return end
    local a = ns.db and ns.db.announce
    if not a or not a.dispels then return end
    if srcGUID ~= UnitGUID("player") then return end
    Say(string.format("Dispelled %s from %s", extraName or "?", destName or "?"))
end)

------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------
local minimapButton

local function UpdateMinimapPosition()
    local angle = math.rad(ns.global.minimap.angle or 220)
    local x, y = math.cos(angle) * 80, math.sin(angle) * 80
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    local b = CreateFrame("Button", "RetailPartyFramesMinimapButton", Minimap)
    b:SetWidth(31)
    b:SetHeight(31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    local overlay = b:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", 7, -5)

    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns:ToggleLock()
        elseif IsShiftKeyDown() then
            ns:CycleTestMode()
        else
            ns:OpenOptions()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("RetailPartyFrames")
        GameTooltip:AddLine("Left-click: options", 1, 1, 1)
        GameTooltip:AddLine("Shift + left-click: test mode", 1, 1, 1)
        GameTooltip:AddLine("Right-click: lock / unlock frames", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            ns.global.minimap.angle = math.deg(math.atan2(py - my, px - mx))
            UpdateMinimapPosition()
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    return b
end

function ns:UpdateMinimapButton()
    if not self.global then return end
    if self.global.minimap.show then
        if not minimapButton then minimapButton = CreateMinimapButton() end
        UpdateMinimapPosition()
        minimapButton:Show()
    elseif minimapButton then
        minimapButton:Hide()
    end
end

function ns:ToggleMinimapButton(force)
    if force ~= nil then
        self.global.minimap.show = force
    else
        self.global.minimap.show = not self.global.minimap.show
    end
    self:UpdateMinimapButton()
    if self.RefreshOptions then self:RefreshOptions() end
end

ns:RegisterInit(function()
    ns:UpdateMinimapButton()
end, "extras")
