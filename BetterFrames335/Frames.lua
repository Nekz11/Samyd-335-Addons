-- BetterFrames335 - Frames.lua
-- Unit frame looks: class/reaction colors, names, level text, dark mode, per-frame scale,
-- mini focus, hide parts, ToT offsets, statusbar textures, fonts, status text format,
-- smooth bars, class portraits, player elite art, clickthrough.

local BBF = BBF335
local M = BBF:NewModule("Frames")
local db

local function Names(list, fmt, a, b)
    for i = a, b do list[#list + 1] = format(fmt, i) end
    return list
end

local healthBarNames = {
    "PlayerFrameHealthBar", "PetFrameHealthBar", "TargetFrameHealthBar", "FocusFrameHealthBar",
    "TargetFrameToTHealthBar", "FocusFrameToTHealthBar",
}
Names(healthBarNames, "PartyMemberFrame%dHealthBar", 1, 4)
Names(healthBarNames, "PartyMemberFrame%dPetFrameHealthBar", 1, 4)
Names(healthBarNames, "ArenaEnemyFrame%dHealthBar", 1, 5)
Names(healthBarNames, "Boss%dTargetFrameHealthBar", 1, 4)

local manaBarNames = {
    "PlayerFrameManaBar", "PetFrameManaBar", "TargetFrameManaBar", "FocusFrameManaBar",
    "TargetFrameToTManaBar", "FocusFrameToTManaBar",
}
Names(manaBarNames, "PartyMemberFrame%dManaBar", 1, 4)
Names(manaBarNames, "ArenaEnemyFrame%dManaBar", 1, 5)
Names(manaBarNames, "Boss%dTargetFrameManaBar", 1, 4)

local castBarNames = { "CastingBarFrame", "TargetFrameSpellBar", "FocusFrameSpellBar", "PetCastingBarFrame" }
Names(castBarNames, "ArenaEnemyFrame%dCastingBar", 1, 5)
Names(castBarNames, "Boss%dTargetFrameSpellBar", 1, 4)

local xpBarNames = { "MainMenuExpBar", "ReputationWatchStatusBar" }

local unitFrameNames = {
    "PlayerFrame", "PetFrame", "TargetFrame", "FocusFrame", "TargetFrameToT", "FocusFrameToT",
}
Names(unitFrameNames, "PartyMemberFrame%d", 1, 4)
Names(unitFrameNames, "ArenaEnemyFrame%d", 1, 5)
Names(unitFrameNames, "Boss%dTargetFrame", 1, 4)

local frameTextures = {
    "PlayerFrameTexture", "PetFrameTexture",
    "TargetFrameTextureFrameTexture", "FocusFrameTextureFrameTexture",
    "TargetFrameToTTextureFrameTexture", "FocusFrameToTTextureFrameTexture",
    "CastingBarFrameBorder", "TargetFrameSpellBarBorder", "FocusFrameSpellBarBorder", "PetCastingBarFrameBorder",
}
Names(frameTextures, "PartyMemberFrame%dTexture", 1, 4)
Names(frameTextures, "PartyMemberFrame%dPetFrameTexture", 1, 4)
Names(frameTextures, "ArenaEnemyFrame%dTexture", 1, 5)
Names(frameTextures, "Boss%dTargetFrameTextureFrameTexture", 1, 4)

local barTextures = {
    "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
    "BonusActionBarTexture0", "BonusActionBarTexture1",
    "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight",
    "SlidingActionBarTexture0", "SlidingActionBarTexture1",
}
Names(barTextures, "MainMenuBarTexture%d", 0, 3)
Names(barTextures, "MainMenuMaxLevelBar%d", 0, 3)
Names(barTextures, "MainMenuXPBarTexture%d", 0, 3)
Names(barTextures, "ReputationWatchBarTexture%d", 0, 3)
Names(barTextures, "ReputationXPBarTexture%d", 0, 3)

local mapTextures = {
    "MinimapBorder", "MinimapBorderTop", "MiniMapTrackingButtonBorder", "MiniMapMailBorder",
    "MiniMapBattlefieldBorder", "MiniMapLFGFrameBorder",
}

-- font strings: names / levels / values / castbar text
local nameFonts = {
    "PlayerName", "PetName", "TargetFrameTextureFrameName", "FocusFrameTextureFrameName",
    "TargetFrameToTTextureFrameName", "FocusFrameToTTextureFrameName",
}
Names(nameFonts, "PartyMemberFrame%dName", 1, 4)
Names(nameFonts, "ArenaEnemyFrame%dName", 1, 5)
Names(nameFonts, "Boss%dTargetFrameTextureFrameName", 1, 4)
local levelFonts = { "PlayerLevelText", "TargetFrameTextureFrameLevelText", "FocusFrameTextureFrameLevelText" }
local valueFonts = {
    "PlayerFrameHealthBarText", "PlayerFrameManaBarText", "PetFrameHealthBarText", "PetFrameManaBarText",
    "TargetFrameHealthBarText", "TargetFrameManaBarText", "FocusFrameHealthBarText", "FocusFrameManaBarText",
    "CastingBarFrameText", "TargetFrameSpellBarText", "FocusFrameSpellBarText",
}
Names(valueFonts, "PartyMemberFrame%dHealthBarText", 1, 4)
Names(valueFonts, "PartyMemberFrame%dManaBarText", 1, 4)

local function Tint(list, v)
    for _, n in ipairs(list) do
        local t = _G[n]
        if t and t.SetVertexColor then t:SetVertexColor(v, v, v) end
    end
end

local function OwnerUnit(unit)
    if unit == "pet" then return "player" end
    local n = unit:match("^partypet(%d)$")
    if n then return "party" .. n end
end

----------------------------------------------------------------------
-- health bar colors
----------------------------------------------------------------------
local function ColorHealthBar(bar, unit)
    if not db or not db.classColorHealth or not bar or not bar.SetStatusBarColor then return end
    unit = unit or bar.unit
    if type(unit) ~= "string" or not UnitExists(unit) then return end
    if bar == PlayerFrameHealthBar and not db.classColorPlayer then return end

    local r, g, b
    if UnitIsPlayer(unit) then
        r, g, b = BBF:ClassColor(unit)
    else
        local owner = db.colorPetAfterOwner and OwnerUnit(unit)
        if owner and UnitExists(owner) then
            r, g, b = BBF:ClassColor(owner)
        elseif db.reactionColorNPC then
            if UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
                r, g, b = 0.5, 0.5, 0.5
            else
                local reaction = UnitReaction(unit, "player")
                local c = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
                if c then r, g, b = c.r, c.g, c.b end
            end
        end
    end
    if r then bar:SetStatusBarColor(r, g, b) end
end

----------------------------------------------------------------------
-- names
----------------------------------------------------------------------
local function ArenaIndex(unit)
    local n = unit:match("^arena(%d)$")
    if n then return tonumber(n) end
    if db.arenaNumbersOnTarget and BBF:InArena() then
        for i = 1, 5 do
            if UnitIsUnit(unit, "arena" .. i) then return i end
        end
    end
end

local function FixName(frame)
    if not db or not frame then return end
    local unit, fs = frame.unit, frame.name
    if type(unit) ~= "string" or type(fs) ~= "table" or not fs.SetText or not UnitExists(unit) then return end

    local text
    if db.arenaNumbers then
        local i = ArenaIndex(unit)
        if i then text = "Arena " .. i end
    end
    if not text and db.hideRealm and UnitIsPlayer(unit) then
        text = UnitName(unit)
    end
    if text and fs:GetText() ~= text then fs:SetText(text) end

    if db.classColorNames and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if frame.bbfNameColored ~= class then       -- recolor only when the class changes
            fs:SetTextColor(BBF:ClassColor(unit))
            frame.bbfNameColored = class or true
        end
    elseif frame.bbfNameColored then
        fs:SetTextColor(1, 0.82, 0)
        frame.bbfNameColored = nil
    end
end

local function NameBackground(frame)
    if not db or not db.classColorNameBG or not frame then return end
    local unit = frame.unit
    local bg = frame.nameBackground or (frame.GetName and frame:GetName() and _G[frame:GetName() .. "NameBackground"])
    if bg and type(unit) == "string" and UnitIsPlayer(unit) then
        bg:SetVertexColor(BBF:ClassColor(unit))
    end
end

----------------------------------------------------------------------
-- level text (color / hide)
----------------------------------------------------------------------
local function MaxLevel() return MAX_PLAYER_LEVEL or 80 end

local function LevelText(frame)
    if not db or not frame then return end
    local unit = frame.unit
    local fs = frame.levelText or (frame == PlayerFrame and PlayerLevelText)
    if type(unit) ~= "string" or not fs then return end
    if db.hideLevelText and UnitExists(unit) then
        local lvl = UnitLevel(unit)
        if db.hideLevelTextAlways or lvl >= MaxLevel() then
            fs:Hide()
            local skull = frame.highLevelTexture
            if skull then skull:Hide() end
            return
        end
    end
    if db.classColorLevel and UnitIsPlayer(unit) then
        fs:SetVertexColor(BBF:ClassColor(unit))
        frame.bbfLevelColored = true
    elseif frame.bbfLevelColored and frame ~= PlayerFrame then
        local color = GetQuestDifficultyColor(UnitLevel(unit) > 0 and UnitLevel(unit) or MaxLevel())
        fs:SetVertexColor(color.r, color.g, color.b)
        frame.bbfLevelColored = nil
    end
end

----------------------------------------------------------------------
-- class portraits
----------------------------------------------------------------------
local function Portrait(frame)
    if not db or not frame or not frame.portrait then return end
    local p, unit = frame.portrait, frame.unit
    if db.classPortraits and type(unit) == "string" and UnitIsPlayer(unit)
        and not (db.classPortraitsIgnoreSelf and UnitIsUnit(unit, "player")) then
        local _, class = UnitClass(unit)
        local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        if coords then
            p:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            p:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            p.bbfClass = true
            return
        end
    end
    if p.bbfClass then
        p:SetTexCoord(0, 1, 0, 1)
        p.bbfClass = nil
        if type(unit) == "string" and UnitExists(unit) then SetPortraitTexture(p, unit) end
    end
end

----------------------------------------------------------------------
-- status text format
----------------------------------------------------------------------
local function FormatText(bar)
    if not db or db.textFormat == "default" then return end
    local fs = bar.TextString
    if not fs or not fs:IsShown() then return end
    local cur = bar:GetValue()
    local _, max = bar:GetMinMaxValues()
    if not cur or not max or max <= 0 then return end
    local pct = math.floor(cur / max * 100 + 0.5)
    local mode = db.textFormat
    local txt
    if mode == "short" then
        txt = BBF:ShortNumber(cur) .. " / " .. BBF:ShortNumber(max)
    elseif mode == "percent" then
        txt = pct .. "%"
    elseif mode == "current" then
        txt = tostring(math.floor(cur))
    elseif mode == "currentShort" then
        txt = BBF:ShortNumber(cur)
    elseif mode == "currentPercent" then
        txt = BBF:ShortNumber(cur) .. "  " .. pct .. "%"
    elseif mode == "both" then
        txt = BBF:ShortNumber(cur) .. " / " .. BBF:ShortNumber(max) .. "  (" .. pct .. "%)"
    end
    if txt and fs:GetText() ~= txt then fs:SetText(txt) end
end

----------------------------------------------------------------------
-- textures & fonts
----------------------------------------------------------------------
local DEFAULT_TEX = "Interface\\TargetingFrame\\UI-StatusBar"

local function ApplyTexture(list, enabled)
    local path = enabled and BBF:TexturePath(db.barTexture, db.barTextureCustom) or DEFAULT_TEX
    for _, n in ipairs(list) do
        local bar = _G[n]
        if bar and bar.SetStatusBarTexture then
            bar:SetStatusBarTexture(path)
            -- keep the bar's current color (SetStatusBarTexture resets vertex color on some clients)
            if bar.GetStatusBarColor then
                local r, g, b, a = bar:GetStatusBarColor()
                if r then bar:SetStatusBarColor(r, g, b, a) end
            end
        end
    end
end

local fontOrig = {}
local function ApplyFonts(list, size)
    for _, n in ipairs(list) do
        local fs = _G[n]
        if fs and fs.SetFont then
            if not fontOrig[n] then
                local p, s, f = fs:GetFont()
                fontOrig[n] = { p, s, f }
            end
            if db.fontEnabled then
                fs:SetFont(BBF:FontPath(db.font, db.fontCustom), size, db.fontOutline ~= "NONE" and db.fontOutline or nil)
            else
                local o = fontOrig[n]
                if o[1] then fs:SetFont(o[1], o[2], o[3]) end
            end
        end
    end
end

----------------------------------------------------------------------
-- smooth bars
----------------------------------------------------------------------
local smoothBars = {}        -- bar -> true while animating
local smoothHooked = {}
local rawSetValue

local function SnapBar(bar)
    bar.bbfShown = nil
    smoothBars[bar] = nil
end

local function SmoothSetValue(bar, value)
    if not db or not db.smoothBars or bar.bbfBypass then return end
    local shown = bar.bbfShown
    if shown == nil or not bar:IsVisible() then
        bar.bbfShown = value
        smoothBars[bar] = nil
        return
    end
    if math.abs(value - shown) < 1 then
        bar.bbfShown = value
        smoothBars[bar] = nil
        return
    end
    bar.bbfTarget = value
    bar.bbfBypass = true
    rawSetValue(bar, shown)          -- undo the instant jump, animate from the shown value
    bar.bbfBypass = nil
    smoothBars[bar] = true
end

local function HookSmooth(bar)
    if not bar or smoothHooked[bar] then return end
    smoothHooked[bar] = true
    if not rawSetValue then
        local mt = getmetatable(bar)
        rawSetValue = mt and mt.__index and mt.__index.SetValue
    end
    hooksecurefunc(bar, "SetValue", SmoothSetValue)
    hooksecurefunc(bar, "SetMinMaxValues", SnapBar)
end

local function SmoothDriver(_, elapsed)
    if not db.smoothBars then return end
    local speed = db.smoothSpeed or 8
    local k = elapsed * speed
    if k > 1 then k = 1 end
    for bar in pairs(smoothBars) do
        local target, shown = bar.bbfTarget, bar.bbfShown
        if not target or not shown then
            smoothBars[bar] = nil
        else
            local new = shown + (target - shown) * k
            if math.abs(target - new) < 1 then
                new = target
                smoothBars[bar] = nil
            end
            bar.bbfShown = new
            bar.bbfBypass = true
            rawSetValue(bar, new)
            bar.bbfBypass = nil
        end
    end
end

----------------------------------------------------------------------
-- ToT offsets / clickthrough / scale / mini focus / elite
----------------------------------------------------------------------
local totOrig = {}
local function CaptureToT(f)
    if not f or totOrig[f] then return end
    local p, rel, rp, x, y = f:GetPoint(1)
    if p then totOrig[f] = { p, rel, rp, x, y } end
end

local function ApplyToT(f, ox, oy)
    local o = f and totOrig[f]
    if not o then return end
    BBF:RunOOC("tot_" .. f:GetName(), function()
        f:ClearAllPoints()
        f:SetPoint(o[1], o[2], o[3], o[4] + ox, o[5] + oy)
    end)
end

local function PlayerArt()
    if not db or not PlayerFrameTexture then return end
    if db.playerElite then
        PlayerFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
    elseif PlayerFrameTexture.bbfElite then
        PlayerFrameTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame")
    end
    PlayerFrameTexture.bbfElite = db.playerElite or nil
end

----------------------------------------------------------------------
function M:Init()
    db = BBF.db
    if HealthBar_OnValueChanged then
        hooksecurefunc("HealthBar_OnValueChanged", function(bar) ColorHealthBar(bar) end)
    end
    if UnitFrameHealthBar_Update then
        -- Blizzard calls this with foreign units too and ignores them; always color by the bar's own unit
        hooksecurefunc("UnitFrameHealthBar_Update", function(bar)
            ColorHealthBar(bar)
            if bar and bar.unit and db.smoothBars then
                local guid = UnitGUID(bar.unit)
                if bar.bbfGUID ~= guid then bar.bbfGUID = guid; SnapBar(bar) end
            end
        end)
    end
    if UnitFrameManaBar_Update then
        hooksecurefunc("UnitFrameManaBar_Update", function(bar)
            if bar and bar.unit and db.smoothBars then
                local guid = UnitGUID(bar.unit)
                if bar.bbfGUID ~= guid then bar.bbfGUID = guid; SnapBar(bar) end
            end
        end)
    end
    if UnitFrameManaBar_UpdateType then
        hooksecurefunc("UnitFrameManaBar_UpdateType", function(bar)
            if db.textureMana and db.barTexture ~= "default" and bar and bar.SetStatusBarTexture then
                local r, g, b = bar:GetStatusBarColor()
                bar:SetStatusBarTexture(BBF:TexturePath(db.barTexture, db.barTextureCustom))
                if r then bar:SetStatusBarColor(r, g, b) end
            end
        end)
    end
    if UnitFrame_Update then
        hooksecurefunc("UnitFrame_Update", function(frame)
            FixName(frame)
            if frame and frame.healthbar then ColorHealthBar(frame.healthbar) end
            Portrait(frame)
        end)
    end
    if UnitFrame_OnEvent then
        hooksecurefunc("UnitFrame_OnEvent", function(frame) FixName(frame) end)
    end
    if UnitFramePortrait_Update then
        hooksecurefunc("UnitFramePortrait_Update", Portrait)
    end
    if TargetFrame_CheckFaction then
        hooksecurefunc("TargetFrame_CheckFaction", NameBackground)
    end
    if TargetFrame_CheckLevel then
        hooksecurefunc("TargetFrame_CheckLevel", LevelText)
    end
    if PlayerFrame_Update then
        hooksecurefunc("PlayerFrame_Update", function() LevelText(PlayerFrame) end)
    end
    if TextStatusBar_UpdateTextString then
        hooksecurefunc("TextStatusBar_UpdateTextString", FormatText)
    end
    if PlayerFrame_ToPlayerArt then
        hooksecurefunc("PlayerFrame_ToPlayerArt", PlayerArt)
    end

    CaptureToT(TargetFrameToT)
    CaptureToT(FocusFrameToT)

    for _, n in ipairs(healthBarNames) do HookSmooth(_G[n]) end
    for _, n in ipairs(manaBarNames) do HookSmooth(_G[n]) end
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", BBF:Guard("SmoothBars", SmoothDriver))
end

function M:Apply()
    -- dark mode
    Tint(frameTextures, db.darkMode and db.darkValue or 1)
    Tint(barTextures, (db.darkMode and db.darkModeBars) and db.darkValue or 1)
    Tint(mapTextures, (db.darkMode and db.darkModeMinimap) and db.darkValue or 1)

    -- textures
    ApplyTexture(healthBarNames, db.textureHealth and db.barTexture ~= "default")
    ApplyTexture(manaBarNames, db.textureMana and db.barTexture ~= "default")
    ApplyTexture(castBarNames, db.textureCastbar and db.barTexture ~= "default")
    ApplyTexture(xpBarNames, db.textureXP and db.barTexture ~= "default")

    -- fonts
    ApplyFonts(nameFonts, db.fontSizeName)
    ApplyFonts(levelFonts, db.fontSizeName)
    ApplyFonts(valueFonts, db.fontSizeValue)

    -- health colors (re-runs Blizzard's coloring, our hook recolors afterwards)
    if HealthBar_OnValueChanged then
        for _, n in ipairs(healthBarNames) do
            local bar = _G[n]
            if bar and type(bar.unit) == "string" and UnitExists(bar.unit) then
                HealthBar_OnValueChanged(bar, bar:GetValue())
            end
        end
    end

    -- names, portraits, levels, status text
    for _, n in ipairs(unitFrameNames) do
        local f = _G[n]
        if f and type(f.unit) == "string" and UnitExists(f.unit) then
            if type(f.name) == "table" and f.name.SetText then
                f.name:SetText(GetUnitName(f.unit))
                FixName(f)
            end
            Portrait(f)
            if f.levelText and f.levelText.Show then
                if TargetFrame_CheckLevel and (f == TargetFrame or f == FocusFrame) then
                    TargetFrame_CheckLevel(f)
                end
            end
        end
    end
    if PlayerLevelText then
        if not db.hideLevelText then PlayerLevelText:Show() end
        LevelText(PlayerFrame)
    end
    if TextStatusBar_UpdateTextString then
        for _, list in ipairs({ healthBarNames, manaBarNames }) do
            for _, n in ipairs(list) do
                local bar = _G[n]
                if bar and bar.TextString then TextStatusBar_UpdateTextString(bar) end
            end
        end
    end

    -- name backgrounds
    if TargetFrame_CheckFaction then
        for _, f in ipairs({ TargetFrame, FocusFrame }) do
            if f and type(f.unit) == "string" and UnitExists(f.unit) then TargetFrame_CheckFaction(f) end
        end
    end

    -- player elite art
    PlayerArt()

    -- hide parts
    BBF:AttachHide(PlayerFrameManaBar, "hidePlayerMana")
    BBF:AttachHide(PlayerFrameManaBarText, "hidePlayerMana")
    BBF:AttachHide(TargetFrameManaBar, "hideTargetMana")
    BBF:AttachHide(TargetFrameManaBarText, "hideTargetMana")
    BBF:AttachHide(FocusFrameManaBar, "hideFocusMana")
    BBF:AttachHide(FocusFrameManaBarText, "hideFocusMana")
    BBF:AttachHide(PlayerName, "hidePlayerName")
    BBF:AttachHide(TargetFrameTextureFrameName, "hideTargetName")
    BBF:AttachHide(FocusFrameTextureFrameName, "hideFocusName")
    BBF:AttachHide(PetName, "hidePetName")
    BBF:AttachHide(TargetFrameToTTextureFrameName, "hideToTName")
    BBF:AttachHide(FocusFrameToTTextureFrameName, "hideFocusToTName")
    for i = 1, 4 do
        BBF:AttachHide(_G["TargetFrameToTDebuff" .. i], "hideToTDebuffs")
        BBF:AttachHide(_G["FocusFrameToTDebuff" .. i], "hideToTDebuffs")
    end
    -- ToT frames are secure: alpha works in combat, Hide() wouldn't
    if TargetFrameToT then TargetFrameToT:SetAlpha(db.hideTargetToT and 0 or 1) end
    if FocusFrameToT then FocusFrameToT:SetAlpha(db.hideFocusToT and 0 or 1) end
    ApplyToT(TargetFrameToT, db.totOffsetX, db.totOffsetY)
    ApplyToT(FocusFrameToT, db.focusToTOffsetX, db.focusToTOffsetY)

    -- secure frame tweaks -> out of combat only
    BBF:RunOOC("frameScale", function()
        PlayerFrame:SetScale(db.scalePlayer)
        TargetFrame:SetScale(db.scaleTarget)
        if PetFrame then PetFrame:SetScale(db.scalePet) end
        if TargetFrameToT then TargetFrameToT:SetScale(db.scaleToT) end
        if FocusFrameToT then FocusFrameToT:SetScale(db.scaleFocusToT) end
        for i = 1, 4 do
            local f = _G["PartyMemberFrame" .. i]
            if f then f:SetScale(db.scaleParty) end
        end
        if FocusFrame then
            if FocusFrame_SetSmallSize then
                FocusFrame_SetSmallSize(db.miniFocus and true or false, true)
            end
            FocusFrame:SetScale(db.scaleFocus * (db.miniFocus and (SMALL_FOCUS_SCALE or 0.75) or 1))
        end
        PlayerFrame:EnableMouse(not db.clickthroughPlayer)
        TargetFrame:EnableMouse(not db.clickthroughTarget)
        if FocusFrame then FocusFrame:EnableMouse(not db.clickthroughFocus) end
    end)

    if not db.smoothBars then
        for bar in pairs(smoothBars) do smoothBars[bar] = nil end
    end
end

function M:OnAddonLoaded(addon)
    if addon == "Blizzard_ArenaUI" then
        for i = 1, 5 do
            HookSmooth(_G["ArenaEnemyFrame" .. i .. "HealthBar"])
            HookSmooth(_G["ArenaEnemyFrame" .. i .. "ManaBar"])
        end
        self:Apply()
    end
end
