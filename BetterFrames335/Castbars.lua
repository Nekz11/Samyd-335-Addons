-- BetterFrames335 - Castbars.lua
-- Party / self / pet castbars, customisation of the default player/target/focus castbars
-- (size, icon, border, text, detach), cast timers, interrupt window highlight and
-- enemy interrupt cooldown icon.

local BBF = BBF335
local M = BBF:NewModule("Castbars")
local db
local GetTime, UnitCastingInfo, UnitChannelInfo = GetTime, UnitCastingInfo, UnitChannelInfo

local FADE = 0.4
local COLORS = {
    cast    = { 1, 0.7, 0 },
    channel = { 0, 1, 0 },
    shield  = { 0.6, 0.6, 0.6 },
    fail    = { 1, 0.1, 0.1 },
    done    = { 0.2, 1, 0.2 },
}

local bars = {}   -- unit -> bar (party1-4, player, pet)

local function Color(f, key)
    local c = COLORS[key]
    f:SetStatusBarColor(c[1], c[2], c[3])
end

local function Texture()
    if db.textureCastbar and db.barTexture ~= "default" then
        return BBF:TexturePath(db.barTexture, db.barTextureCustom)
    end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

----------------------------------------------------------------------
-- own castbars (party / self / pet)
----------------------------------------------------------------------
local function CreateBar(name, anchor, unit, index, kind)
    local f = CreateFrame("StatusBar", name, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    f:SetMinMaxValues(0, 1)
    f:SetValue(0)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetTexture(0, 0, 0, 0.6)
    f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1)
    f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon:SetPoint("RIGHT", f, "LEFT", -3, 0)

    f.iconBg = f:CreateTexture(nil, "BACKGROUND")
    f.iconBg:SetTexture(0, 0, 0, 0.8)
    f.iconBg:SetPoint("TOPLEFT", f.icon, "TOPLEFT", -1, 1)
    f.iconBg:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", 1, -1)

    f.time = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.time:SetPoint("RIGHT", f, "RIGHT", -3, 0)
    f.time:SetJustifyH("RIGHT")

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 3, 0)
    f.text:SetPoint("RIGHT", f.time, "LEFT", -2, 0)
    f.text:SetJustifyH("LEFT")

    f.spark = f:CreateTexture(nil, "OVERLAY")
    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    f.spark:SetBlendMode("ADD")
    f.spark:SetWidth(16)

    f.unit, f.anchor, f.index, f.kind = unit, anchor, index, kind
    f:Hide()
    return f
end

-- Free stack: used whenever the default party frames are not visible (solo, or another
-- party frame addon hides them) or when "attach" is turned off. Movable via /bbf move.
local container
local STACK_GAP = 8

local function Enabled(f)
    if f.kind == "pet" then return db.petCastbar end
    if f.kind == "self" then return db.partyCastbars and db.partyCastSelf end
    return db.partyCastbars
end

local function Attached(f)
    if f.kind == "pet" then return true end
    return db.partyCastAttach and f.anchor and f.anchor:IsVisible()
end

local function SizeContainer()
    if not container then return end
    local h = db.partyCastHeight
    local n = db.partyCastSelf and 5 or 4
    container:SetWidth(db.partyCastWidth + h + 10)
    container:SetHeight(n * (h + STACK_GAP))
end

local function Layout(f)
    local w, h, showIcon, x, y
    if f.kind == "pet" then
        w, h, showIcon, x, y = db.petCastWidth, db.petCastHeight, db.partyCastIcon, db.petCastX, db.petCastY
    else
        w, h, showIcon, x, y = db.partyCastWidth, db.partyCastHeight, db.partyCastIcon, db.partyCastX, db.partyCastY
    end
    f:SetWidth(w)
    f:SetHeight(h)
    f:SetStatusBarTexture(Texture())
    f.icon:SetWidth(h + 2)
    f.icon:SetHeight(h + 2)
    f.spark:SetHeight(h * 2.2)
    if showIcon then
        f.icon:Show(); f.iconBg:Show()
    else
        f.icon:Hide(); f.iconBg:Hide()
    end
    f:ClearAllPoints()
    if Attached(f) then
        f.attached = true
        f:SetPoint("LEFT", f.anchor, "RIGHT", x, y)
    else
        f.attached = false
        SizeContainer()
        -- self bar sits on top of the stack, party1-4 below; leave room for the icon on the left
        local row = f.index
        if not db.partyCastSelf then row = row - 1 end
        f:SetPoint("TOPLEFT", container, "TOPLEFT", h + 6, -(row * (h + STACK_GAP)))
    end
end

local function StartTest(f)
    Layout(f)
    local now = GetTime()
    f.mode = "cast"
    f.startT = now
    f.endT = now + 2 + (f.index or 1) * 0.5
    f.notInt = (f.index == 2)
    f.text:SetText(f.kind == "pet" and "Pet Cast" or f.kind == "self" and "Self Cast" or ("Test Cast " .. (f.index or "")))
    f.icon:SetTexture("Interface\\Icons\\Spell_Frost_FrostBolt02")
    Color(f, f.notInt and "shield" or "cast")
    f.fade = nil
    f:SetAlpha(1)
    f:Show()
end

local function Start(f)
    if f.test then StartTest(f) return true end
    if not Enabled(f) or not UnitExists(f.unit) then return false end
    Layout(f)   -- picks party frame or free stack depending on what is visible right now
    if f.kind == "pet" and not (f.anchor and f.anchor:IsVisible()) then return false end

    local name, _, _, tex, st, et, _, _, notInt = UnitCastingInfo(f.unit)
    local mode = "cast"
    if not name then
        name, _, _, tex, st, et, _, notInt = UnitChannelInfo(f.unit)
        mode = "channel"
    end
    if not name or not st or not et then return false end

    f.mode = mode
    f.startT = st / 1000
    f.endT = et / 1000
    f.notInt = notInt
    f.fade = nil
    f.text:SetText(name)
    f.icon:SetTexture(tex)
    Color(f, notInt and "shield" or mode)
    f:SetAlpha(1)
    f:Show()
    return true
end

local function Stop(f, failText)
    if not f.mode then return end
    local oldMode = f.mode
    f.mode = nil
    if failText then
        Color(f, "fail")
        f:SetValue(1)
        f.text:SetText(failText)
    elseif oldMode == "cast" then
        Color(f, "done")
        f:SetValue(1)
    end
    f.time:SetText("")
    f.lastTime = ""
    f.spark:Hide()
    f.fade = FADE
end

local function Refresh(f)
    if f.test then return end
    if not Start(f) then
        f.mode, f.fade = nil, nil
        f:Hide()
    end
end

local function OnUpdate(f, elapsed)
    -- attached bars follow the anchor's visibility; the free stack is always valid
    if not f.test and f.attached and f.anchor and not f.anchor:IsVisible() then
        f.mode, f.fade = nil, nil
        f:Hide()
        return
    end
    if f.mode then
        local now = GetTime()
        if now >= f.endT then
            if f.test then StartTest(f) else Stop(f) end
            return
        end
        local dur = f.endT - f.startT
        if dur <= 0 then dur = 0.001 end
        local v
        if f.mode == "cast" then v = (now - f.startT) / dur else v = (f.endT - now) / dur end
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        f:SetValue(v)
        f.spark:ClearAllPoints()
        f.spark:SetPoint("CENTER", f, "LEFT", v * f:GetWidth(), 0)
        f.spark:Show()
        local txt = db.partyCastTimer and format("%.1f", f.endT - now) or ""
        if txt ~= f.lastTime then
            f.lastTime = txt
            f.time:SetText(txt)
        end
    elseif f.fade then
        f.fade = f.fade - elapsed
        if f.fade <= 0 then
            f.fade = nil
            f:Hide()
        else
            f:SetAlpha(f.fade / FADE)
        end
    else
        f:Hide()
    end
end

local startEvents = {
    UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_DELAYED = true, UNIT_SPELLCAST_CHANNEL_UPDATE = true,
    UNIT_SPELLCAST_INTERRUPTIBLE = true, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
}

local function OnEvent(_, event, unit)
    if event == "PARTY_MEMBERS_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "UNIT_PET" then
        for _, f in pairs(bars) do Refresh(f) end
        return
    end
    local f = bars[unit]
    if not f or f.test then return end
    if startEvents[event] then
        Start(f)
    elseif event == "UNIT_SPELLCAST_STOP" then
        if f.mode == "cast" then Stop(f) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if f.mode == "channel" then Stop(f) end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        -- FAILED also fires for instants / "can't do that yet" while a cast keeps running
        if f.mode and not UnitCastingInfo(unit) and not UnitChannelInfo(unit) then
            if event == "UNIT_SPELLCAST_INTERRUPTED" then
                Stop(f, INTERRUPTED or "Interrupted")
            else
                Stop(f, FAILED or "Failed")
            end
        end
    end
end

----------------------------------------------------------------------
-- enemy interrupt cooldown tracking (combat log)
----------------------------------------------------------------------
-- spellId -> cooldown seconds (3.3.5 values, talents not included)
local interruptCD = {
    [1766]  = 10,   -- Kick
    [2139]  = 24,   -- Counterspell
    [6552]  = 10,   -- Pummel
    [72]    = 12,   -- Shield Bash
    [57994] = 6,    -- Wind Shear
    [19647] = 24,   -- Spell Lock (Felhunter)
    [47528] = 10,   -- Mind Freeze
    [47476] = 120,  -- Strangulate
    [34490] = 20,   -- Silencing Shot
    [16979] = 15,   -- Feral Charge - Bear
    [15487] = 45,   -- Silence (Priest)
    [25046] = 120,  -- Arcane Torrent (energy)
    [28730] = 120,  -- Arcane Torrent (mana)
    [50613] = 120,  -- Arcane Torrent (runic)
}
local classInterrupt = {
    ROGUE = 1766, MAGE = 2139, WARRIOR = 6552, SHAMAN = 57994, WARLOCK = 19647,
    DEATHKNIGHT = 47528, HUNTER = 34490, DRUID = 16979, PRIEST = 15487,
}
local cds = {}   -- sourceGUID -> { spell = id, ready = time }

-- OnEvent args: frame, "COMBAT_LOG_EVENT_UNFILTERED", timestamp, subevent, sourceGUID, sourceName,
-- sourceFlags, destGUID, destName, destFlags, spellId, ...
local function LogInterrupt(_, _, _, event, sourceGUID, _, _, _, _, _, spellId)
    if event ~= "SPELL_CAST_SUCCESS" then return end
    local cd = interruptCD[spellId]
    if not cd or not sourceGUID then return end
    cds[sourceGUID] = { spell = spellId, ready = GetTime() + cd }
end

-- returns spellId (icon to show), remaining seconds (0 = ready) for a unit, or nil
local function InterruptState(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitCanAttack("player", unit) then return end
    local guid = UnitGUID(unit)
    local entry = guid and cds[guid]
    local now = GetTime()
    if entry and entry.ready > now then
        return entry.spell, entry.ready - now, entry.ready - interruptCD[entry.spell]
    end
    local _, class = UnitClass(unit)
    local spell = (entry and entry.spell) or classInterrupt[class]
    if not spell then return end
    return spell, 0
end

----------------------------------------------------------------------
-- default castbars: timer, size/icon/border/text, interrupt highlight & icon
----------------------------------------------------------------------
local defaultBars = {}   -- key -> bar

local function Orig(bar)
    if bar.bbfOrig then return bar.bbfOrig end
    local n = bar:GetName()
    local o = { w = bar:GetWidth(), h = bar:GetHeight() }
    local border, flash, icon = _G[n .. "Border"], _G[n .. "Flash"], _G[n .. "Icon"]
    if border then o.bw, o.bh = border:GetWidth(), border:GetHeight() end
    if flash then o.fw, o.fh = flash:GetWidth(), flash:GetHeight() end
    if icon then
        o.iw = icon:GetWidth()
        local p, rel, rp, x, y = icon:GetPoint(1)
        o.ipoint = p and { p, rel, rp, x, y }
    end
    bar.bbfOrig = o
    return o
end

local function GetInterruptIcon(bar)
    local ic = bar.bbfInt
    if ic then return ic end
    ic = CreateFrame("Frame", nil, bar)
    ic:SetFrameLevel(bar:GetFrameLevel() + 5)
    ic.tex = ic:CreateTexture(nil, "ARTWORK")
    ic.tex:SetAllPoints(ic)
    ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ic.cd = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
    ic.cd:SetAllPoints(ic)
    if ic.cd.SetReverse then pcall(ic.cd.SetReverse, ic.cd, true) end
    local ov = CreateFrame("Frame", nil, ic)
    ov:SetAllPoints(ic)
    ov:SetFrameLevel(ic:GetFrameLevel() + 3)
    ic.time = ov:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    ic.time:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    ic.time:SetPoint("CENTER", ic, "CENTER", 0, 0)
    ic.border = ic:CreateTexture(nil, "OVERLAY")
    ic.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    ic.border:SetBlendMode("ADD")
    ic.border:SetPoint("CENTER", ic, "CENTER", 0, 0)
    ic:Hide()
    bar.bbfInt = ic
    return ic
end

local function GetHighlights(bar)
    if bar.bbfHL then return bar.bbfHL end
    local hl = {}
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local t = bar:CreateTexture(nil, "OVERLAY")
        t:SetTexture(1, 0.15, 0.15, 0.55)
        t:SetPoint("TOP" .. side, bar, "TOP" .. side, 0, 0)
        t:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side, 0, 0)
        t:Hide()
        hl[side] = t
    end
    bar.bbfHL = hl
    return hl
end

local function CustomizeBar(key, bar)
    if not bar then return end
    local o = Orig(bar)
    local n = bar:GetName()
    local custom = db["cb" .. key .. "Custom"]
    local w = custom and db["cb" .. key .. "Width"] or o.w
    local h = custom and db["cb" .. key .. "Height"] or o.h
    bar:SetWidth(w)
    bar:SetHeight(h)
    local border, flash, icon, text = _G[n .. "Border"], _G[n .. "Flash"], _G[n .. "Icon"], _G[n .. "Text"]
    local sx, sy = w / o.w, h / o.h
    if border and o.bw then border:SetWidth(o.bw * sx); border:SetHeight(o.bh * sy) end
    if flash and o.fw then flash:SetWidth(o.fw * sx); flash:SetHeight(o.fh * sy) end
    bar.bbfShowBorder = (not custom) or db["cb" .. key .. "Border"]
    if border then
        if bar.bbfShowBorder then border:Show() else border:Hide() end
    end
    if text then text:SetAlpha((custom and not db["cb" .. key .. "Text"]) and 0 or 1) end
    if icon then
        bar.bbfShowIcon = custom and db["cb" .. key .. "Icon"]
        if custom then
            local size = db["cb" .. key .. "IconSize"]
            icon:SetWidth(size)
            icon:SetHeight(size)
            icon:ClearAllPoints()
            icon:SetPoint("RIGHT", bar, "LEFT", -4, 0)
        elseif o.ipoint then
            icon:SetWidth(o.iw)
            icon:SetHeight(o.iw)
            icon:ClearAllPoints()
            icon:SetPoint(o.ipoint[1], o.ipoint[2], o.ipoint[3], o.ipoint[4], o.ipoint[5])
        end
        if key == "Player" then
            if bar.bbfShowIcon then icon:Show() else icon:Hide() end
        end
    end
    -- timer position
    if bar.bbfTimer then
        bar.bbfTimer:ClearAllPoints()
        if key == "Player" and db.cbPlayerTimerCenter then
            bar.bbfTimer:SetPoint("CENTER", bar, "CENTER", 0, 0)
        elseif key == "Player" then
            bar.bbfTimer:SetPoint("LEFT", bar, "RIGHT", 8, 1)
        else
            bar.bbfTimer:SetPoint("LEFT", bar, "RIGHT", 6, 0)
        end
    end
end

-- the Blizzard spellbar for target/focus is re-anchored by Blizzard on every aura update
local function Detach(bar, key)
    if not bar or not db then return end
    local detach = db["cb" .. key .. "Detach"]
    local pos = db.positions[key == "Target" and "targetcast" or "focuscast"]
    if detach and pos then
        bar:ClearAllPoints()
        bar:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
end

local function BarOnUpdate(self)
    local t = self.bbfTimer
    local key = self.bbfKey
    -- timer
    local txt = ""
    if db.castTimers then
        local rem
        if self.casting and self.maxValue and self.value then
            rem = self.maxValue - self.value
        elseif self.channeling and self.value then
            rem = self.value
        end
        if rem and rem > 0 then txt = format("%.1f", rem) end
    end
    if txt ~= self.bbfLast then      -- SetText only when the visible value changes
        self.bbfLast = txt
        t:SetText(txt)
    end
    if key == "Player" then return end

    local active = (self.casting or self.channeling) and self.maxValue and self.maxValue > 0
    local unit = key == "Target" and "target" or "focus"

    -- interrupt window highlight (edges = not kickable because of latency / cast end)
    local wantHL = db.interruptHighlight and (key == "Target" or db.interruptHighlightFocus) and active
    if wantHL then
        local hl = GetHighlights(self)
        if self.bbfHLMax ~= self.maxValue or self.bbfHLW ~= self:GetWidth() then
            self.bbfHLMax, self.bbfHLW = self.maxValue, self:GetWidth()
            local w = self:GetWidth()
            local l = math.min(w * 0.45, w * (db.interruptHighlightStart / self.maxValue))
            local r = math.min(w * 0.45, w * (db.interruptHighlightEnd / self.maxValue))
            hl.LEFT:SetWidth(math.max(l, 0.1))
            hl.RIGHT:SetWidth(math.max(r, 0.1))
        end
        hl.LEFT:Show(); hl.RIGHT:Show()
    elseif self.bbfHL then
        self.bbfHL.LEFT:Hide(); self.bbfHL.RIGHT:Hide()
        self.bbfHLMax = nil
    end

    -- enemy interrupt cooldown icon / recolor
    local wantIcon = db.interruptIcon and ((key == "Target" and db.interruptIconTarget) or (key == "Focus" and db.interruptIconFocus))
    local spell, remaining, startT
    if active and (wantIcon or db.interruptRecolor) then
        spell, remaining, startT = InterruptState(unit)
    end
    if wantIcon and spell and (remaining > 0 or not db.interruptIconActiveOnly) then
        local ic = GetInterruptIcon(self)
        local size = db.interruptIconSize
        ic:SetWidth(size); ic:SetHeight(size)
        ic.border:SetWidth(size * 1.7); ic.border:SetHeight(size * 1.7)
        ic:ClearAllPoints()
        ic:SetPoint("LEFT", self, "RIGHT", 30 + db.interruptIconX, db.interruptIconY)
        if ic.bbfSpell ~= spell then
            local _, _, tex = GetSpellInfo(spell)
            ic.tex:SetTexture(tex)
            ic.bbfSpell = spell
        end
        if remaining > 0 then
            if ic.bbfStart ~= startT then
                CooldownFrame_SetTimer(ic.cd, startT, interruptCD[spell], 1)
                ic.bbfStart = startT
            end
            local s = format("%d", remaining + 0.99)
            if ic.bbfTxt ~= s then ic.time:SetText(s); ic.bbfTxt = s end
            ic.border:SetVertexColor(0.2, 1, 0.2)      -- green ring: enemy can't kick you
            ic.tex:SetDesaturated(true)
        else
            if ic.bbfStart then CooldownFrame_SetTimer(ic.cd, 0, 0, 0); ic.bbfStart = nil end
            if ic.bbfTxt ~= "" then ic.time:SetText(""); ic.bbfTxt = "" end
            ic.border:SetVertexColor(1, 0.2, 0.2)      -- red ring: interrupt ready
            ic.tex:SetDesaturated(false)
        end
        ic:Show()
    elseif self.bbfInt then
        self.bbfInt:Hide()
    end

    if db.interruptRecolor and active then
        if spell and remaining > 0 then
            if not self.bbfRecolored then
                self:SetStatusBarColor(0.2, 0.9, 0.3)
                self.bbfRecolored = true
            end
        elseif self.bbfRecolored then
            if self.channeling then self:SetStatusBarColor(0, 1, 0) else self:SetStatusBarColor(1, 0.7, 0) end
            self.bbfRecolored = nil
        end
    elseif self.bbfRecolored then
        if self.channeling then self:SetStatusBarColor(0, 1, 0) else self:SetStatusBarColor(1, 0.7, 0) end
        self.bbfRecolored = nil
    end
end

local function HookDefaultBar(key, bar)
    if not bar or bar.bbfTimer then return end
    defaultBars[key] = bar
    bar.bbfKey = key
    local t = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.bbfTimer = t
    bar:HookScript("OnUpdate", BBF:Guard("Castbar" .. key, BarOnUpdate))
    bar:HookScript("OnShow", function(self)
        local n = self:GetName()
        local icon, border = _G[n .. "Icon"], _G[n .. "Border"]
        if key == "Player" and icon then
            if self.bbfShowIcon then icon:Show() else icon:Hide() end
        end
        if border and self.bbfShowBorder == false then border:Hide() end
        self.bbfRecolored = nil
        if key ~= "Player" then Detach(self, key) end
    end)
    bar:HookScript("OnHide", function(self)
        if self.bbfInt then self.bbfInt:Hide() end
        if self.bbfHL then self.bbfHL.LEFT:Hide(); self.bbfHL.RIGHT:Hide() end
    end)
end

----------------------------------------------------------------------
function BBF:ToggleCastTest()
    M.testing = not M.testing
    local freeStack = false
    for _, f in pairs(bars) do
        f.test = M.testing
        if M.testing then
            StartTest(f)
            if not f.attached then freeStack = true end
        else
            f.mode, f.fade = nil, nil
            f:Hide()
            Refresh(f)
        end
    end
    if M.testing then
        BBF:Print("castbar test ON (/bbf test to stop)")
        if freeStack then
            BBF:Print("default party frames are not visible -> showing the free stack; place it with /bbf move")
        end
    else
        BBF:Print("castbar test OFF")
    end
end

function M:Init()
    db = BBF.db
    container = CreateFrame("Frame", "BBF335PartyCastAnchor", UIParent)
    container:SetPoint("LEFT", UIParent, "LEFT", 40, 80)
    SizeContainer()
    container:Show()

    for i = 1, 4 do
        local anchor = _G["PartyMemberFrame" .. i]
        if anchor then
            local f = CreateBar("BBF335PartyCastbar" .. i, anchor, "party" .. i, i, "party")
            f:SetScript("OnUpdate", BBF:Guard("PartyCastbar", OnUpdate))
            bars["party" .. i] = f
        end
    end
    local selfBar = CreateBar("BBF335SelfCastbar", PlayerFrame, "player", 0, "self")
    selfBar:SetScript("OnUpdate", BBF:Guard("SelfCastbar", OnUpdate))
    bars.player = selfBar
    if PetFrame then
        local petBar = CreateBar("BBF335PetCastbar", PetFrame, "pet", 1, "pet")
        petBar:SetScript("OnUpdate", BBF:Guard("PetCastbar", OnUpdate))
        bars.pet = petBar
    end

    local ev = CreateFrame("Frame")
    for _, e in ipairs({
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
        "PARTY_MEMBERS_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_PET",
    }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", BBF:Guard("Castbars", OnEvent))

    local log = CreateFrame("Frame")
    log:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    log:SetScript("OnEvent", BBF:Guard("InterruptLog", LogInterrupt))

    HookDefaultBar("Player", CastingBarFrame)
    HookDefaultBar("Target", TargetFrameSpellBar)
    HookDefaultBar("Focus", FocusFrameSpellBar)

    if Target_Spellbar_AdjustPosition then
        hooksecurefunc("Target_Spellbar_AdjustPosition", function(spellbar)
            if spellbar == TargetFrameSpellBar then Detach(spellbar, "Target")
            elseif spellbar == FocusFrameSpellBar then Detach(spellbar, "Focus") end
        end)
    end
end

function M:Apply()
    SizeContainer()
    for _, f in pairs(bars) do
        Layout(f)
        if not Enabled(f) and not f.test then
            f.mode, f.fade = nil, nil
            f:Hide()
        else
            Refresh(f)
        end
    end
    CustomizeBar("Player", CastingBarFrame)
    CustomizeBar("Target", TargetFrameSpellBar)
    CustomizeBar("Focus", FocusFrameSpellBar)
    if TargetFrameSpellBar then
        TargetFrameSpellBar:SetScale(db.targetCastScale)
        if db.cbTargetDetach then Detach(TargetFrameSpellBar, "Target")
        elseif Target_Spellbar_AdjustPosition and TargetFrame.spellbar then pcall(Target_Spellbar_AdjustPosition, TargetFrameSpellBar) end
    end
    if FocusFrameSpellBar then
        FocusFrameSpellBar:SetScale(db.focusCastScale)
        if db.cbFocusDetach then Detach(FocusFrameSpellBar, "Focus")
        elseif Target_Spellbar_AdjustPosition and FocusFrame and FocusFrame.spellbar then pcall(Target_Spellbar_AdjustPosition, FocusFrameSpellBar) end
    end
end
