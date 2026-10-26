-- RetailPartyFrames - party cooldown tracking (combat log based, no sync addon required)

local _, ns = ...

local GetTime = GetTime
local floor, ceil, max = math.floor, math.ceil, math.max
local WHITE = "Interface\\Buttons\\WHITE8X8"
local EMPTY = {}

local state = {}     -- state[guid][entryId] = { start, dur }
local seen = {}      -- seen[guid][entryId] = true   (talent spells are shown once seen)
local learned = {}   -- learned[guid][entryId] = shorter real cooldown (talents / glyphs)
local groupGUIDs = {}
local petOwner = {}
ns.cdState = state

-- base cooldown -> talent/glyph reductions from inspection -> observed value wins
local function CooldownFor(guid, e)
    local l = learned[guid] and learned[guid][e.id]
    if l then return l end
    local cd = e.cd
    local m = ns.unitMods[guid] and ns.unitMods[guid][e.id]
    if m then
        cd = cd * (1 - (m.pct or 0) / 100) - (m.flat or 0)
        if cd < 1 then cd = 1 end
    end
    return cd
end
ns.CooldownFor = CooldownFor

function ns:SeenTable(guid)
    seen[guid] = seen[guid] or {}
    return seen[guid]
end

------------------------------------------------------------------------
-- Group GUID mapping (pets map to their owner, e.g. Felhunter Spell Lock)
------------------------------------------------------------------------
function ns:RefreshGroupGUIDs()
    for k in pairs(groupGUIDs) do groupGUIDs[k] = nil end
    for k in pairs(petOwner) do petOwner[k] = nil end
    local function add(unit, pet)
        local g = UnitGUID(unit)
        if not g then return end
        groupGUIDs[g] = true
        local pg = UnitGUID(pet)
        if pg then petOwner[pg] = g end
    end
    add("player", "pet")
    for i = 1, 4 do add("party" .. i, "partypet" .. i) end
    for i = 1, GetNumRaidMembers() do add("raid" .. i, "raidpet" .. i) end
end

------------------------------------------------------------------------
-- Tracking
------------------------------------------------------------------------
function ns:RefreshCooldownsFor(guid)
    local all = self.allButtons
    for i = 1, #all do
        local b = all[i]
        if b.cdGUID == guid and b:IsShown() then self:UpdateCooldownIcons(b) end
    end
end

function ns:StartCooldown(guid, e, now)
    now = now or GetTime()
    state[guid] = state[guid] or {}
    seen[guid] = seen[guid] or {}
    local s = state[guid][e.id]
    if s and now - s.start < 1.5 then return false end -- same cast reported twice

    if s and self.db.cdLearn then
        local elapsed = now - s.start
        -- used again before our timer ran out: the real cooldown is shorter (talents/glyphs)
        if elapsed < s.dur - 2 and elapsed >= e.cd * 0.5 then
            learned[guid] = learned[guid] or {}
            learned[guid][e.id] = floor(elapsed + 0.5)
        end
    end

    seen[guid][e.id] = true
    if s then
        s.start, s.dur = now, CooldownFor(guid, e)
    else
        state[guid][e.id] = { start = now, dur = CooldownFor(guid, e) }
    end
    self:RefreshCooldownsFor(guid)
    return true
end

local function ResetCooldowns(guid, ids)
    local st = state[guid]
    if not st then return end
    for _, id in ipairs(ids) do
        local e = ns.SpellIndex[id]
        if e then st[e.id] = nil end
    end
end

ns:On("COMBAT_LOG_EVENT_UNFILTERED", function(_, _, subevent, srcGUID, srcName, _, _, destName, _, spellId)
    if subevent ~= "SPELL_CAST_SUCCESS" and subevent ~= "SPELL_RESURRECT" then return end
    if not srcGUID or not spellId then return end
    local owner = groupGUIDs[srcGUID] and srcGUID or petOwner[srcGUID]
    if not owner then return end
    local resets = ns.SpellResets[spellId]
    if resets then ResetCooldowns(owner, resets) end
    local e = ns.SpellIndex[spellId]
    if e then
        local started = ns:StartCooldown(owner, e)
        if started and ns.AnnounceCooldown then ns:AnnounceCooldown(e, srcName, destName, srcGUID) end
    elseif resets then
        ns:RefreshCooldownsFor(owner)
    end
end)

ns:On("UNIT_PET", function()
    ns:RefreshGroupGUIDs()
end)

------------------------------------------------------------------------
-- Icons
------------------------------------------------------------------------
local function IconOnEnter(self)
    if not self.entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("spell:" .. self.entry.id)
    local left = self.expires and (self.expires - GetTime()) or 0
    if left > 0 then
        GameTooltip:AddLine(string.format("Cooldown: %d:%02d", floor(left / 60), floor(left % 60)), 1, 0.3, 0.3)
    else
        GameTooltip:AddLine("Ready", 0.2, 1, 0.2)
    end
    GameTooltip:Show()
end

local function IconOnLeave()
    GameTooltip:Hide()
end

-- Shift + right-click hides a spell everywhere (undo in the options panel)
local function IconOnMouseUp(self, button)
    if button ~= "RightButton" or not IsShiftKeyDown() or not self.entry then return end
    local e = self.entry
    ns.db.cdHidden[e.id] = true
    GameTooltip:Hide()
    ns:Print(string.format("%s hidden. Restore it under Party cooldowns > Spell editor.", GetSpellInfo(e.id) or e.id))
    ns:ForEachButton(function(b) ns:UpdateCooldownIcons(b) end)
    if ns.RefreshOptions then ns:RefreshOptions() end
end

function ns:CreateCooldownWidgets(b)
    -- parented to the container so range fading does not dim the cooldowns
    local holder = CreateFrame("Frame", nil, b:GetParent())
    holder:SetAllPoints(b)
    holder:SetFrameLevel(b:GetFrameLevel() + 6)
    holder:Hide() -- shown/hidden by the button's OnShow/OnHide (Frames.lua)
    b.cdHolder = holder
    b.cdIcons = {}
end

local function CreateCDIcon(b)
    local f = CreateFrame("Frame", nil, b.cdHolder)
    f.border = f:CreateTexture(nil, "BACKGROUND")
    f.border:SetAllPoints(f)
    f.border:SetTexture(WHITE)
    f.border:SetVertexColor(0, 0, 0, 1)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cd:SetAllPoints(f.icon)

    local tf = CreateFrame("Frame", nil, f)
    tf:SetAllPoints(f)
    tf:SetFrameLevel(f.cd:GetFrameLevel() + 2)
    f.text = tf:CreateFontString(nil, "OVERLAY")
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)

    f.glow = ns.NewBorder(tf, "OVERLAY")
    f.glow:SetThickness(2, -1)
    f.glow:SetColor(1, 0.82, 0.1, 1)
    f.glow:Hide()

    f:EnableMouse(true)
    f:SetScript("OnEnter", IconOnEnter)
    f:SetScript("OnLeave", IconOnLeave)
    f:SetScript("OnMouseUp", IconOnMouseUp)
    f:Hide()
    return f
end

local ANCHORS = {
    RIGHT = { "TOPLEFT", "TOPRIGHT", 1, 0, 1, -1 },
    LEFT = { "TOPRIGHT", "TOPLEFT", -1, 0, -1, -1 },
    BOTTOM = { "TOPLEFT", "BOTTOMLEFT", 0, -1, 1, -1 },
    TOP = { "BOTTOMLEFT", "TOPLEFT", 0, 1, 1, 1 },
}

local function PlaceCDIcon(b, i, f)
    local db = ns.db
    local a = ANCHORS[db.cdAnchor] or ANCHORS.RIGHT
    local size, sp = db.cdSize, db.cdSpacing
    local perRow = max(db.cdPerRow, 1)
    local col = (i - 1) % perRow
    local row = floor((i - 1) / perRow)
    local gap = sp + 1
    local x = a[3] * gap + a[5] * col * (size + sp)
    local y = a[4] * gap + a[6] * row * (size + sp)
    f:ClearAllPoints()
    f:SetPoint(a[1], b, a[2], x, y)
    f:SetWidth(size)
    f:SetHeight(size)
    f:EnableMouse(db.cdTooltips and true or false)
    f.cd.noCooldownCount = db.cdText or nil -- our own text replaces OmniCC
    ns.StyleFont(f.text, max(8, floor(size * 0.48)), true)
end

function ns:LayoutCooldowns(b)
    for i, f in ipairs(b.cdIcons) do PlaceCDIcon(b, i, f) end
end

local function FormatTime(left)
    if left >= 60 then return ceil(left / 60) .. "m" end
    if left >= 10 then return tostring(floor(left)) end
    return tostring(ceil(left))
end

local list = {}

local function Consider(e, db, now, st, sn, race)
    if not db.cdCategories[e.cat] then return end
    if db.cdHidden[e.id] then return end
    if e.race and e.race ~= race then return end
    -- talents: known from inspection; usage-only spells (pet, trinket): known after first use
    if (e.talent or e.usage) and not (sn and sn[e.id]) then return end
    if db.cdOnlyActive then
        local s = st and st[e.id]
        if not (s and s.start + s.dur > now) then return end
    end
    list[#list + 1] = e
end

function ns:UpdateCooldownIcons(b)
    local db = self.db
    local icons = b.cdIcons
    local guid, class, race
    if self:Cfg(b, "cooldowns") then
        if b.testData then
            guid, class, race = "TEST-" .. b.index, b.testData.class, b.testData.race
        elseif b.unit and (db.cdShowSelf or not UnitIsUnit(b.unit, "player")) then
            guid = UnitGUID(b.unit)
            local _
            _, class = UnitClass(b.unit)
            _, race = UnitRace(b.unit)
        end
    end
    b.cdGUID = guid
    if not guid or not class then
        for i = 1, #icons do icons[i]:Hide() end
        return
    end

    for i = #list, 1, -1 do list[i] = nil end
    local now = GetTime()
    local st, sn = state[guid], seen[guid]
    for _, e in ipairs(self.ClassSpells[class] or EMPTY) do Consider(e, db, now, st, sn, race) end
    for _, e in ipairs(self.ClassSpells.RACIAL or EMPTY) do Consider(e, db, now, st, sn, race) end
    for _, e in ipairs(self.ClassSpells.ANY or EMPTY) do Consider(e, db, now, st, sn, race) end

    -- arena: the PvP trinket is what everyone wants to see first
    if self.inArena and db.cdArenaTrinket and #list > 1 then
        for i = 2, #list do
            if list[i].cat == "pvp" then
                local e = table.remove(list, i)
                table.insert(list, 1, e)
                break
            end
        end
    end

    local n = math.min(#list, db.cdMax)
    for i = 1, n do
        local e = list[i]
        local f = icons[i]
        if not f then
            f = CreateCDIcon(b)
            icons[i] = f
            PlaceCDIcon(b, i, f)
        end
        f.entry = e
        local _, _, tex = GetSpellInfo(e.id)
        f.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
        local s = st and st[e.id]
        if s and s.start + s.dur > now then
            f.expires = s.start + s.dur
            f.cd:SetCooldown(s.start, s.dur)
            f.cd:Show()
            f.icon:SetDesaturated(db.cdDesaturate and true or false)
            if db.cdGlow and e.active and now < s.start + e.active then
                f.glowEnd = s.start + e.active
                f.glow:Show()
            else
                f.glowEnd = nil
                f.glow:Hide()
            end
        else
            f.expires = nil
            f.glowEnd = nil
            f.cd:Hide()
            f.icon:SetDesaturated(false)
            f.glow:Hide()
            f.text:SetText("")
        end
        f:Show()
    end
    for i = n + 1, #icons do icons[i]:Hide() end
    b.cdDirty = nil
end

------------------------------------------------------------------------
-- Ticker: countdown text and state transitions
------------------------------------------------------------------------
local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    if not ns.db or not ns.db.cooldowns then return end
    local now = GetTime()
    local showText = ns.db.cdText
    local all = ns.allButtons
    for i = 1, #all do
        local b = all[i]
        if b:IsShown() and b.cdGUID then
            local dirty = false
            for _, f in ipairs(b.cdIcons) do
                if f:IsShown() and f.expires then
                    local left = f.expires - now
                    if left <= 0 then
                        dirty = true
                    elseif showText then
                        f.text:SetText(FormatTime(left))
                    else
                        f.text:SetText("")
                    end
                    if f.glowEnd and now >= f.glowEnd then dirty = true end
                end
            end
            if dirty then ns:UpdateCooldownIcons(b) end
        end
    end
end)

------------------------------------------------------------------------
-- Test mode
------------------------------------------------------------------------
function ns:SeedTestCooldowns()
    local now = GetTime()
    for i = 1, 25 do
        local d = self:TestUnit(i)
        local guid = "TEST-" .. i
        state[guid], seen[guid] = {}, {}
        local spells = self.ClassSpells[d.class] or EMPTY
        local started = 0
        for _, e in ipairs(spells) do
            seen[guid][e.id] = true
            if started < 2 and e.cd >= 30 and (e.cat == "defensive" or e.cat == "external" or e.cat == "raid") then
                started = started + 1
                local ago = (started == 1) and 3 or e.cd * 0.4
                state[guid][e.id] = { start = now - ago, dur = e.cd }
            end
        end
    end
end
