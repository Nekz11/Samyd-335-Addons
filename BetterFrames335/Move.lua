-- BetterFrames335 - Move.lua
-- Drag the default frames around: /bbf move toggles overlays over every movable frame.
-- Positions are stored in the saved variables and re-applied on login (out of combat).

local BBF = BBF335
local M = BBF:NewModule("Move")
local db

local entries = {
    { key = "player",  frame = "PlayerFrame",        label = "Player" },
    { key = "target",  frame = "TargetFrame",        label = "Target" },
    { key = "focus",   frame = "FocusFrame",         label = "Focus" },
    { key = "pet",     frame = "PetFrame",           label = "Pet" },
    { key = "party",   frame = "PartyMemberFrame1",  label = "Party (1-4)",  w = 130, h = 215, anchor = "TOPLEFT" },
    { key = "castbar", frame = "CastingBarFrame",    label = "Castbar",      w = 200, h = 28 },
    { key = "partycast", frame = "BBF335PartyCastAnchor", label = "Party castbars" },
    { key = "queuetimer", frame = "BBF335QueueTimer", label = "Queue timer" },
    { key = "targetcast", frame = "TargetFrameSpellBar", label = "Target castbar", w = 150, h = 24,
      cond = function() return BBF.db.cbTargetDetach end },
    { key = "focuscast",  frame = "FocusFrameSpellBar",  label = "Focus castbar",  w = 150, h = 24,
      cond = function() return BBF.db.cbFocusDetach end },
    { key = "buffs",   frame = "BuffFrame",          label = "Buffs",        w = 320, h = 95,  anchor = "TOPRIGHT" },
    { key = "minimap", frame = "MinimapCluster",     label = "Minimap" },
    { key = "boss",    frame = "Boss1TargetFrame",   label = "Boss (1-4)",   w = 215, h = 90,  anchor = "TOPRIGHT" },
    { key = "arena",   frame = "ArenaEnemyFrames",   label = "Arena (1-5)",  w = 160, h = 220, anchor = "TOPRIGHT", lazy = true },
}

local original = {}     -- key -> list of original anchor points (captured before we touch the frame)
local overlays = {}     -- key -> overlay frame
local moving = false
local toolbar

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
local function Frame(e) return _G[e.frame] end

local function Capture(e)
    local f = Frame(e)
    if not f or original[e.key] then return end
    local pts = {}
    for i = 1, f:GetNumPoints() do
        local p, rel, rp, x, y = f:GetPoint(i)
        pts[#pts + 1] = { p, rel, rp, x, y }
    end
    original[e.key] = pts
end

local function Protected(f)
    return f.IsProtected and f:IsProtected() and InCombatLockdown()
end

local function SetFrom(f, pos)
    f:ClearAllPoints()
    f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
end

local function AfterMove(e, f)
    if e.key == "buffs" and TemporaryEnchantFrame then
        -- keep weapon enchants glued to the buff frame wherever it goes
        TemporaryEnchantFrame:ClearAllPoints()
        TemporaryEnchantFrame:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 0, 0)
    elseif e.key == "castbar" then
        -- UIParent's frame manager keeps re-anchoring the castbar above the action bars
        f.ignoreFramePositionManager = true
    end
end

local function ApplyEntry(e)
    local f = Frame(e)
    if not f then return end
    Capture(e)
    if e.cond and not e.cond() then return end
    local pos = db.positions[e.key]
    if not pos then return end
    BBF:RunOOC("move_" .. e.key, function()
        SetFrom(f, pos)
        AfterMove(e, f)
    end)
end

local function ResetEntry(e)
    local f = Frame(e)
    db.positions[e.key] = nil
    if not f then return end
    local pts = original[e.key]
    BBF:RunOOC("move_" .. e.key, function()
        if f.SetUserPlaced then pcall(f.SetUserPlaced, f, false) end
        if pts and #pts > 0 then
            f:ClearAllPoints()
            for _, pt in ipairs(pts) do f:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
        end
        if e.key == "castbar" then
            f.ignoreFramePositionManager = nil
            if UIParent_ManageFramePositions then UIParent_ManageFramePositions() end
        elseif e.key == "buffs" and TemporaryEnchantFrame and original.tempEnchant then
            TemporaryEnchantFrame:ClearAllPoints()
            for _, pt in ipairs(original.tempEnchant) do
                TemporaryEnchantFrame:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
            end
        end
    end)
end

local function Save(e, f)
    local p, _, rp, x, y = f:GetPoint(1)
    if not p then return end
    db.positions[e.key] = { p, rp, math.floor(x + 0.5), math.floor(y + 0.5) }
end

----------------------------------------------------------------------
-- overlays
----------------------------------------------------------------------
local function OnDragStart(ov)
    local e, f = ov.entry, Frame(ov.entry)
    if not f then return end
    if Protected(f) then
        BBF:Print("can't move " .. e.label .. " while in combat")
        return
    end
    f:SetMovable(true)
    f:StartMoving()
    ov.dragging = true
end

local function OnDragStop(ov)
    if not ov.dragging then return end
    ov.dragging = nil
    local e, f = ov.entry, Frame(ov.entry)
    if not f then return end
    f:StopMovingOrSizing()
    if f.SetUserPlaced then pcall(f.SetUserPlaced, f, false) end   -- we store positions ourselves
    Save(e, f)
    local pos = db.positions[e.key]
    if pos then
        SetFrom(f, pos)
        AfterMove(e, f)
        ov.coords:SetText(format("%d, %d", pos[3], pos[4]))
    end
end

local function CreateOverlay(e)
    local f = Frame(e)
    if not f then return end
    local ov = CreateFrame("Frame", "BBF335Mover_" .. e.key, UIParent)
    ov.entry = e
    ov:SetFrameStrata("DIALOG")
    ov:SetFrameLevel(50)
    ov:EnableMouse(true)
    ov:RegisterForDrag("LeftButton")
    ov:SetScript("OnDragStart", OnDragStart)
    ov:SetScript("OnDragStop", OnDragStop)
    ov:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            ResetEntry(e)
            self.coords:SetText("default")
            BBF:Print(e.label .. " position reset")
        end
    end)
    ov:SetScript("OnEnter", function(self) self.bg:SetTexture(0.2, 0.8, 0.2, 0.55) end)
    ov:SetScript("OnLeave", function(self) self.bg:SetTexture(0, 0.6, 1, 0.4) end)

    ov.bg = ov:CreateTexture(nil, "BACKGROUND")
    ov.bg:SetAllPoints(ov)
    ov.bg:SetTexture(0, 0.6, 1, 0.4)

    ov.border = ov:CreateTexture(nil, "BORDER")
    ov.border:SetTexture(1, 1, 1, 0.6)
    ov.border:SetPoint("TOPLEFT", ov, "TOPLEFT", 0, 0)
    ov.border:SetPoint("TOPRIGHT", ov, "TOPRIGHT", 0, 0)
    ov.border:SetHeight(1)

    ov.label = ov:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ov.label:SetPoint("CENTER", ov, "CENTER", 0, 6)
    ov.label:SetText(e.label)

    ov.coords = ov:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ov.coords:SetPoint("CENTER", ov, "CENTER", 0, -8)

    -- size: follow the frame, or a fixed box for frames that are tiny containers
    if e.w then
        ov:SetWidth(e.w)
        ov:SetHeight(e.h)
        local a = e.anchor or "TOPLEFT"
        ov:SetPoint(a, f, a, 0, 0)
    else
        ov:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        ov:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    end
    ov:Hide()
    overlays[e.key] = ov
    return ov
end

local function CreateToolbar()
    local t = CreateFrame("Frame", "BBF335MoveToolbar", UIParent)
    t:SetWidth(430)
    t:SetHeight(46)
    t:SetPoint("TOP", UIParent, "TOP", 0, -80)
    t:SetFrameStrata("DIALOG")
    t:SetFrameLevel(60)
    t:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    t:SetBackdropColor(0, 0, 0, 0.85)
    local txt = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", t, "LEFT", 12, 0)
    txt:SetJustifyH("LEFT")
    txt:SetText("|cff00ccffBetterFrames|r  Drag a box to move the frame.\nRight-click a box to reset it. Esc or Done to finish.")
    local done = CreateFrame("Button", nil, t, "UIPanelButtonTemplate")
    done:SetWidth(70)
    done:SetHeight(22)
    done:SetText("Done")
    done:SetPoint("RIGHT", t, "RIGHT", -10, 0)
    done:SetScript("OnClick", function() M:SetMoving(false) end)
    local reset = CreateFrame("Button", nil, t, "UIPanelButtonTemplate")
    reset:SetWidth(80)
    reset:SetHeight(22)
    reset:SetText("Reset all")
    reset:SetPoint("RIGHT", done, "LEFT", -4, 0)
    reset:SetScript("OnClick", function() M:ResetAll() end)
    t:Hide()
    -- Esc closes the toolbar -> OnHide ends move mode
    tinsert(UISpecialFrames, "BBF335MoveToolbar")
    t:SetScript("OnHide", function() if moving then M:SetMoving(false) end end)
    return t
end

----------------------------------------------------------------------
-- public
----------------------------------------------------------------------
function M:SetMoving(state)
    if state and InCombatLockdown() then
        BBF:Print("frames can't be moved during combat")
        return
    end
    moving = state and true or false
    if not toolbar then toolbar = CreateToolbar() end
    for _, e in ipairs(entries) do
        local f = Frame(e)
        local ov = overlays[e.key] or (f and CreateOverlay(e))
        if ov then
            -- arena frames parked on the hider (hidden by option) have no usable position
            if moving and not (f and f:GetParent() == BBF.hider) and not (e.cond and not e.cond()) then
                Capture(e)
                local pos = db.positions[e.key]
                ov.coords:SetText(pos and format("%d, %d", pos[3], pos[4]) or "default")
                ov:Show()
            else
                ov:Hide()
            end
        end
    end
    if moving then toolbar:Show() else toolbar:Hide() end
    if moving then BBF:Print("move mode ON - /bbf move or Esc to finish") end
end

function M:ToggleMoving() self:SetMoving(not moving) end
function BBF:ToggleMove() M:ToggleMoving() end
function BBF:ResetPositions() M:ResetAll() end

function M:ResetAll()
    for _, e in ipairs(entries) do
        if db.positions[e.key] then ResetEntry(e) end
        local ov = overlays[e.key]
        if ov then ov.coords:SetText("default") end
    end
    BBF:Print("all frame positions reset")
end

function M:Init()
    db = BBF.db
    if TemporaryEnchantFrame then
        local pts = {}
        for i = 1, TemporaryEnchantFrame:GetNumPoints() do
            local p, rel, rp, x, y = TemporaryEnchantFrame:GetPoint(i)
            pts[#pts + 1] = { p, rel, rp, x, y }
        end
        original.tempEnchant = pts
    end
    for _, e in ipairs(entries) do Capture(e) end

    -- Blizzard re-anchors the castbar whenever action bars change; put it back
    if UIParent_ManageFramePositions then
        hooksecurefunc("UIParent_ManageFramePositions", function()
            if db.positions.castbar and CastingBarFrame then
                local e
                for _, entry in ipairs(entries) do if entry.key == "castbar" then e = entry end end
                BBF:RunOOC("move_castbar", function()
                    SetFrom(CastingBarFrame, db.positions.castbar)
                    AfterMove(e, CastingBarFrame)
                end)
            end
        end)
    end

    BBF:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        if moving then M:SetMoving(false) end
    end)
end

function M:Apply()
    for _, e in ipairs(entries) do ApplyEntry(e) end
end

function M:OnAddonLoaded(addon)
    if addon == "Blizzard_ArenaUI" then
        for _, e in ipairs(entries) do
            if e.lazy then Capture(e); ApplyEntry(e) end
        end
    end
end
