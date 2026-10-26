-- BetterFrames335 - Hide.lua
-- Hide various default UI elements (permanent and situational).

local BBF = BBF335
local M = BBF:NewModule("Hide")
local db

local function Range(list, fmt, a, b)
    for i = a, b do list[#list + 1] = format(fmt, i) end
    return list
end

local elements = {
    hideGryphons       = { "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap" },
    hideHitIndicators  = { "PlayerHitIndicator", "PetHitIndicator" },
    hidePvPIcons       = Range({ "PlayerPVPIcon", "TargetFrameTextureFramePVPIcon", "FocusFrameTextureFramePVPIcon" },
                               "PartyMemberFrame%dPVPIcon", 1, 4),
    -- PlayerStatusTexture / PlayerStatusGlow are shared by rest & combat -> handled in StatusHook
    hideRestGlow       = { "PlayerRestIcon", "PlayerRestGlow" },
    hideCombatGlow     = { "PlayerAttackIcon", "PlayerAttackGlow", "PlayerAttackBackground" },
    hideLeaderIcons    = Range(Range({ "PlayerLeaderIcon", "PlayerMasterIcon",
                                       "TargetFrameTextureFrameLeaderIcon", "FocusFrameTextureFrameLeaderIcon" },
                                     "PartyMemberFrame%dLeaderIcon", 1, 4),
                               "PartyMemberFrame%dMasterIcon", 1, 4),
    hideGroupIndicator = { "PlayerFrameGroupIndicator" },
    hideMinimapZoom    = { "MinimapZoomIn", "MinimapZoomOut" },
    hideWorldMapButton = { "MiniMapWorldMapButton" },
    hideMinimapToggle  = { "MinimapToggleButton" },
    hideClock          = { "TimeManagerClockButton" },
    hideChatButtons    = Range(Range(Range(Range({ "ChatFrameMenuButton" },
                               "ChatFrame%dButtonFrame", 1, 10),
                               "ChatFrame%dUpButton", 1, 10),
                               "ChatFrame%dDownButton", 1, 10),
                               "ChatFrame%dBottomButton", 1, 10),
    hideBagButtons     = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
                           "CharacterBag2Slot", "CharacterBag3Slot", "KeyRingButton" },
    hideUIErrors       = { "UIErrorsFrame" },
}

local actionBars = {
    "ActionButton", "BonusActionButton", "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton",
}

-- frames parked on the hidden parent (secure -> out of combat only)
local parked = {
    hideArenaFrames  = { "ArenaEnemyFrames", "ArenaPrepFrames" },
    hideStanceBar    = { "ShapeshiftBarFrame" },
    hidePetActionBar = { "PetActionBarFrame" },
}

local function ApplyParked()
    for key, list in pairs(parked) do
        for _, name in ipairs(list) do
            local f = _G[name]
            if f then
                if db[key] then
                    if f:GetParent() ~= BBF.hider then
                        BBF:RunOOC("park_" .. name, function() f:SetParent(BBF.hider) end)
                    end
                elseif f:GetParent() == BBF.hider then
                    BBF:RunOOC("park_" .. name, function() f:SetParent(UIParent) end)
                end
            end
        end
    end
end

-- shared rest/combat glow around the player frame
local function StatusHook()
    if not db then return end
    local resting = IsResting()
    local combat = PlayerFrame and PlayerFrame.inCombat
    local hide = (resting and db.hideRestGlow) or (not resting and combat and db.hideCombatGlow)
    if hide then
        if PlayerStatusTexture then PlayerStatusTexture:Hide() end
        if PlayerStatusGlow then PlayerStatusGlow:Hide() end
    end
end

----------------------------------------------------------------------
-- situational hides (arena / group) - alpha based so they work in combat
----------------------------------------------------------------------
local function Situational()
    if not db then return end
    local arena = BBF:InArena()
    local inParty = GetNumPartyMembers() > 0
    local inRaid = GetNumRaidMembers() > 0

    BBF:SetAlphaIf(MinimapCluster, db.hideMinimapArena and arena, "arena")
    BBF:SetAlphaIf(WatchFrame, db.hideTrackerArena and arena, "arena")
    for i = 1, 4 do
        BBF:SetAlphaIf(_G["PartyMemberFrame" .. i], db.hidePartyArena and arena, "arena")
        local hideBoss = (db.hideBossRaid and inRaid) or (db.hideBossParty and inParty and not inRaid)
        BBF:SetAlphaIf(_G["Boss" .. i .. "TargetFrame"], hideBoss, "group")
    end
    BBF:SetAlphaIf(PetFrame, db.hidePetFrame, "pet")
end

function M:Init()
    db = BBF.db
    if PlayerFrame_UpdateStatus then
        hooksecurefunc("PlayerFrame_UpdateStatus", StatusHook)
    end
    BBF:RegisterEvent("PARTY_MEMBERS_CHANGED", Situational)
    BBF:RegisterEvent("RAID_ROSTER_UPDATE", Situational)
    BBF:RegisterEvent("ZONE_CHANGED_NEW_AREA", Situational)
    BBF:RegisterEvent("UNIT_PET", function(_, unit) if unit == "player" then Situational() end end)
end

function M:Apply()
    -- attach every element (also when the option is off) so switching off shows it again
    for key, list in pairs(elements) do
        for _, n in ipairs(list) do BBF:AttachHide(_G[n], key) end
    end

    -- action button texts (alpha based -> can be toggled live; untouched while both options are off)
    for _, bar in ipairs(actionBars) do
        for i = 1, 12 do
            BBF:SetAlphaIf(_G[bar .. i .. "Name"], db.hideMacroText, "macro")
            BBF:SetAlphaIf(_G[bar .. i .. "HotKey"], db.hideHotkeyText, "hotkey")
        end
    end

    ApplyParked()
    Situational()
    if PlayerFrame_UpdateStatus then PlayerFrame_UpdateStatus() end
end

function M:OnAddonLoaded(addon)
    if addon == "Blizzard_ArenaUI" or addon == "Blizzard_TimeManager" then
        self:Apply()
    end
end
