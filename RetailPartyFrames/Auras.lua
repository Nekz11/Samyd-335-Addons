-- RetailPartyFrames - buffs, debuffs, priority debuffs and dispel highlighting

local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local max = math.max
local GetTime = GetTime

local TYPE_COLORS = {
    Magic = { 0.2, 0.6, 1.0 },
    Curse = { 0.6, 0.0, 1.0 },
    Disease = { 0.6, 0.4, 0.0 },
    Poison = { 0.0, 0.6, 0.0 },
    none = { 0.8, 0.0, 0.0 },
}
local function TypeColor(dtype)
    local c = DebuffTypeColor and DebuffTypeColor[dtype or "none"]
    if c then return c.r, c.g, c.b end
    c = TYPE_COLORS[dtype or "none"] or TYPE_COLORS.none
    return c[1], c[2], c[3]
end
ns.DebuffTypeRGB = TypeColor

local TYPE_ORDER = { "Magic", "Curse", "Disease", "Poison" }
local TYPE_ICONS = {
    Magic = "Interface\\Icons\\Spell_Holy_DispelMagic",
    Curse = "Interface\\Icons\\Spell_Nature_RemoveCurse",
    Disease = "Interface\\Icons\\Spell_Holy_NullifyDisease",
    Poison = "Interface\\Icons\\Spell_Nature_NullifyPoison",
}

-- self debuffs nobody needs to see on a raid frame
local TRIVIAL = {
    [6788] = true,   -- Weakened Soul
    [25771] = true,  -- Forbearance
    [57723] = true,  -- Exhaustion
    [57724] = true,  -- Sated
    [41425] = true,  -- Hypothermia
    [11196] = true,  -- Recently Bandaged
    [15007] = true,  -- Resurrection Sickness
    [26013] = true,  -- Deserter
    [71041] = true,  -- Dungeon Deserter
    [69127] = true,  -- Chill of the Throne (ICC)
    [2479] = true,   -- Honorless Target
    [36032] = true,  -- Arcane Blast (mage self debuff)
    [44413] = true,  -- Incanter's Absorption
    [34709] = true,  -- Shadow Sight (arena)
}
ns.TrivialDebuffs = TRIVIAL

-- long buffs that are still worth showing
local BUFF_ALWAYS = {
    [974] = true, [32593] = true, [32594] = true, [49283] = true, [49284] = true, -- Earth Shield
    [53563] = true,  -- Beacon of Light
    [53601] = true, [58597] = true, -- Sacred Shield
    [41635] = true,  -- Prayer of Mending
}

------------------------------------------------------------------------
-- Which debuff types can the player remove?
------------------------------------------------------------------------
ns.canDispel = {}

-- spell names currently in the player's / pet's spellbook
local knownSpells, knownPetSpells = {}, {}

local function ScanBook(book, into)
    for k in pairs(into) do into[k] = nil end
    local i = 1
    while true do
        local name = GetSpellName(i, book)
        if not name then break end
        into[name] = true
        i = i + 1
        if i > 1024 then break end
    end
end

local function Knows(id)
    local name = GetSpellInfo(id)
    return name and knownSpells[name] or false
end

local function PetKnows(id)
    local name = GetSpellInfo(id)
    return name and knownPetSpells[name] or false
end

function ns:UpdateDispelAbilities()
    local d = self.canDispel
    for k in pairs(d) do d[k] = nil end
    ScanBook(BOOKTYPE_SPELL or "spell", knownSpells)
    if UnitExists("pet") then
        ScanBook(BOOKTYPE_PET or "pet", knownPetSpells)
    else
        for k in pairs(knownPetSpells) do knownPetSpells[k] = nil end
    end
    local _, class = UnitClass("player")
    if class == "PRIEST" then
        if Knows(527) then d.Magic = true end                         -- Dispel Magic
        if Knows(528) or Knows(552) then d.Disease = true end         -- Cure / Abolish Disease
    elseif class == "PALADIN" then
        if Knows(1152) or Knows(4987) then d.Poison = true; d.Disease = true end -- Purify / Cleanse
        if Knows(4987) then d.Magic = true end
    elseif class == "DRUID" then
        if Knows(2782) then d.Curse = true end                        -- Remove Curse
        if Knows(8946) or Knows(2893) then d.Poison = true end        -- Cure / Abolish Poison
    elseif class == "SHAMAN" then
        if Knows(526) or Knows(51886) then d.Poison = true; d.Disease = true end -- Cure Toxins / Cleanse Spirit
        if Knows(51886) then d.Curse = true end
    elseif class == "MAGE" then
        if Knows(475) then d.Curse = true end                         -- Remove Curse
    elseif class == "WARLOCK" then
        -- Felhunter: Devour Magic (any rank), only while that pet is out
        if PetKnows(19505) or PetKnows(19731) or PetKnows(19734) or PetKnows(19736)
            or PetKnows(27276) or PetKnows(27277) or PetKnows(48011) then
            d.Magic = true
        end
    end
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
local function AuraOnEnter(self)
    if not ns.db.auraTooltips then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    if self.unit and self.auraIndex then
        GameTooltip:SetUnitAura(self.unit, self.auraIndex, self.filter)
    elseif self.testName then
        GameTooltip:SetText(self.testName)
    end
    GameTooltip:Show()
end

local function AuraOnLeave()
    GameTooltip:Hide()
end

local function CreateIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel(parent:GetFrameLevel() + 1)
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
    f.cd:SetReverse(true)
    f.cd.noCooldownCount = true -- OmniCC: no numbers on tiny aura icons

    local tf = CreateFrame("Frame", nil, f)
    tf:SetAllPoints(f)
    tf:SetFrameLevel(f.cd:GetFrameLevel() + 1)
    f.count = tf:CreateFontString(nil, "OVERLAY")
    f.count:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, 0)
    f.timer = tf:CreateFontString(nil, "OVERLAY")
    f.timer:SetPoint("CENTER", f, "CENTER", 0, 0)

    f:SetScript("OnEnter", AuraOnEnter)
    f:SetScript("OnLeave", AuraOnLeave)
    f:EnableMouse(false)
    f:Hide()
    return f
end

function ns:CreateAuraWidgets(b)
    local holder = CreateFrame("Frame", nil, b.overlay)
    holder:SetAllPoints(b.overlay)
    holder:SetFrameLevel(b.overlay:GetFrameLevel() + 1)
    b.auraHolder = holder
    b.debuffs, b.buffs, b.dispels = {}, {}, {}
end

local function PlaceIcon(b, kind, i, f)
    local db = ns.db
    local h = b.health
    local size
    f:ClearAllPoints()
    if kind == "debuffs" then
        size = ns:Cfg(b, "debuffSize")
        f:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 3 + (i - 1) * (size + 1), 3)
    elseif kind == "buffs" then
        size = ns:Cfg(b, "buffSize")
        f:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -3 - (i - 1) * (size + 1), 3)
    else
        size = (b.kind == "raid" or b.kind == "mt" or b.kind == "pet") and 10 or 12
        f:SetPoint("TOPRIGHT", h, "TOPRIGHT", -3 - (i - 1) * (size + 1), -3)
    end
    f.baseSize = size
    f:SetWidth(size)
    f:SetHeight(size)
    ns.StyleFont(f.count, max(8, math.floor(size * 0.55)), "OUTLINE")
    ns.StyleFont(f.timer, max(7, math.floor(size * 0.5)), "OUTLINE")
    f:EnableMouse(db.auraTooltips and kind ~= "dispels" and true or false)
end

local function GetIcon(b, kind, i)
    local list = b[kind]
    local f = list[i]
    if not f then
        f = CreateIcon(b.auraHolder)
        list[i] = f
        PlaceIcon(b, kind, i, f)
    end
    return f
end

function ns:LayoutAuras(b)
    for _, kind in ipairs({ "debuffs", "buffs", "dispels" }) do
        for i, f in ipairs(b[kind]) do PlaceIcon(b, kind, i, f) end
    end
end

local function HideFrom(list, first)
    for i = first, #list do list[i]:Hide() end
end

-- remaining time on the icon (retail style: seconds, minutes above 60 s)
local function UpdateTimerText(f, now)
    local db = ns.db
    local expires = f.expires
    if not (db.auraTimers and expires) then
        f.timer:SetText("")
        return
    end
    local left = expires - now
    local threshold = db.auraTimerThreshold or 0
    if left <= 0 or (threshold > 0 and left > threshold) then
        f.timer:SetText("")
        return
    end
    if left >= 60 then
        f.timer:SetText(math.floor(left / 60 + 0.5) .. "m")
        f.timer:SetTextColor(1, 1, 1)
    else
        f.timer:SetText(math.ceil(left))
        if left <= 5 then f.timer:SetTextColor(1, 0.3, 0.3) else f.timer:SetTextColor(1, 1, 1) end
    end
end
ns.UpdateAuraTimerText = UpdateTimerText

local function SetIcon(f, texture, count, duration, expires, r, g, bl, big)
    f.icon:SetTexture(texture)
    f.count:SetText((count and count > 1) and count or "")
    if duration and duration > 0 and expires then
        f.cd:SetCooldown(expires - duration, duration)
        f.cd:Show()
        f.expires = expires
    else
        f.cd:Hide()
        f.expires = nil
    end
    UpdateTimerText(f, GetTime())
    f.border:SetVertexColor(r or 0, g or 0, bl or 0, 1)
    -- priority debuffs get the larger size, everything else the configured one
    local size = big or f.baseSize
    if size and f:GetWidth() ~= size then
        f:SetWidth(size)
        f:SetHeight(size)
    end
    f:Show()
end

function ns:SetDispelHighlight(b, dtype)
    if dtype and self.db.dispelHighlight then
        local r, g, bl = TypeColor(dtype)
        b.dispelBorder:SetColor(r, g, bl, 1)
        b.dispelBorder:Show()
        b.dispelGlow:SetGradientAlpha("VERTICAL", r, g, bl, 0.45, r, g, bl, 0)
        b.dispelGlow:Show()
    else
        b.dispelBorder:Hide()
        b.dispelGlow:Hide()
    end
end

local function ShowIndicators(b, types)
    local n = 0
    if ns.db.dispelIndicators then
        for _, t in ipairs(TYPE_ORDER) do
            if types[t] then
                n = n + 1
                local f = GetIcon(b, "dispels", n)
                local r, g, bl = TypeColor(t)
                SetIcon(f, TYPE_ICONS[t], 0, 0, nil, r, g, bl)
            end
        end
    end
    HideFrom(b.dispels, n + 1)
end

------------------------------------------------------------------------
-- Dispel sound (once per frame per new dispellable debuff)
------------------------------------------------------------------------
local lastSound = 0
local function DispelSound(b, dtype)
    if not ns.db.dispelSound or not dtype then
        b.dispelSounded = nil
        return
    end
    if b.dispelSounded == dtype then return end
    b.dispelSounded = dtype
    local now = GetTime()
    if now - lastSound < 1.5 then return end
    lastSound = now
    PlaySoundFile(ns:Fetch("sound", ns.db.dispelSoundFile))
end

------------------------------------------------------------------------
-- Update
------------------------------------------------------------------------
local prioList, dispellable, others, seenTypes = {}, {}, {}, {}

function ns:UpdateAuras(b)
    if b.testData then return self:UpdateTestAuras(b) end
    local unit = b.unit
    if not unit then return end
    local db = self.db
    local maxDebuffs = self:Cfg(b, "maxDebuffs")
    local blacklist, whitelist = db.debuffBlacklist, db.debuffWhitelist
    local usePrio = db.priorityDebuffs and b.kind ~= "pet"
    local mode = db.debuffFilter or "IMPORTANT"
    local importantNames = (mode == "IMPORTANT") and self:ImportantDebuffNames() or nil

    for k in pairs(seenTypes) do seenTypes[k] = nil end
    for i = #prioList, 1, -1 do prioList[i] = nil end
    for i = #dispellable, 1, -1 do dispellable[i] = nil end
    for i = #others, 1, -1 do others[i] = nil end

    local highlight
    for i = 1, 40 do
        local name, _, _, _, dtype, _, _, _, _, _, spellId = UnitAura(unit, i, "HARMFUL")
        if not name then break end
        if dtype == "" then dtype = nil end
        local can = dtype and self.canDispel[dtype]
        local listed = spellId and whitelist[spellId]
        local hidden = spellId and (blacklist[spellId] or (db.hideTrivialDebuffs and TRIVIAL[spellId])) and not listed
        if not hidden then
            if dtype and (can or db.highlightAllTypes) then
                seenTypes[dtype] = true
                if not highlight or (can and not self.canDispel[highlight]) then highlight = dtype end
            end
            if usePrio and spellId and (self.PriorityDebuffs[spellId] or listed) then
                prioList[#prioList + 1] = i
            elseif can then
                dispellable[#dispellable + 1] = i
            elseif mode == "ALL" or (importantNames and importantNames[name]) then
                others[#others + 1] = i
            end
        end
    end

    -- debuff icons: priority first, then dispellable, then the rest
    local shown = 0
    for pass = 1, 3 do
        local list = (pass == 1) and prioList or (pass == 2) and dispellable or others
        for j = 1, #list do
            if shown >= maxDebuffs then break end
            local idx = list[j]
            local _, _, texture, count, dtype, duration, expires = UnitAura(unit, idx, "HARMFUL")
            shown = shown + 1
            local f = GetIcon(b, "debuffs", shown)
            f.unit, f.auraIndex, f.filter, f.testName = unit, idx, "HARMFUL", nil
            local r, g, bl = TypeColor(dtype ~= "" and dtype or nil)
            if pass == 1 then r, g, bl = 1, 0.1, 0.1 end
            SetIcon(f, texture, count, duration, expires, r, g, bl, (pass == 1) and db.prioritySize or nil)
        end
    end
    HideFrom(b.debuffs, shown + 1)
    -- a larger priority icon pushes the following icons to the right
    if shown > 1 then
        local x = 3
        for i = 1, shown do
            local f = b.debuffs[i]
            f:ClearAllPoints()
            f:SetPoint("BOTTOMLEFT", b.health, "BOTTOMLEFT", x, 3)
            x = x + f:GetWidth() + 1
        end
    end

    self:SetDispelHighlight(b, highlight)
    DispelSound(b, highlight and self.canDispel[highlight] and highlight or nil)
    ShowIndicators(b, seenTypes)

    -- buffs
    local maxBuffs = self:Cfg(b, "maxBuffs")
    local bmode = db.buffFilter or "IMPORTANT"
    -- IMPORTANT: important buffs from anyone + my own short buffs; SHORT: every short buff (optionally only mine)
    local filter = (bmode == "SHORT" and db.onlyMyBuffs) and "HELPFUL|PLAYER" or "HELPFUL"
    local importantBuffs = (bmode == "IMPORTANT") and self:ImportantBuffNames() or nil
    shown = 0
    if maxBuffs > 0 then
        for i = 1, 40 do
            local name, _, texture, count, _, duration, expires, caster, _, _, spellId = UnitAura(unit, i, filter)
            if not name then break end
            local always = spellId and (BUFF_ALWAYS[spellId] or db.buffWhitelist[spellId])
            local short = duration and duration > 0 and duration <= db.buffMaxDuration
            local ok
            if bmode == "WHITELIST" then
                ok = always
            elseif bmode == "IMPORTANT" then
                ok = always or importantBuffs[name] or (short and (caster == "player" or caster == "pet" or caster == "vehicle"))
            else
                ok = always or short
            end
            if ok then
                shown = shown + 1
                local f = GetIcon(b, "buffs", shown)
                f.unit, f.auraIndex, f.filter, f.testName = unit, i, filter, nil
                SetIcon(f, texture, count, duration, expires, 0, 0, 0)
                if shown >= maxBuffs then break end
            end
        end
    end
    HideFrom(b.buffs, shown + 1)
end

------------------------------------------------------------------------
-- Test mode
------------------------------------------------------------------------
local TEST_DEBUFF = {
    Magic = { "Frost Nova", "Interface\\Icons\\Spell_Frost_FrostNova" },
    Curse = { "Curse of Agony", "Interface\\Icons\\Spell_Shadow_CurseOfSargeras" },
    Poison = { "Deadly Poison", "Interface\\Icons\\Spell_Nature_CorrosiveBreath" },
    Disease = { "Plague", "Interface\\Icons\\Spell_Shadow_CallofBone" },
}
local TEST_BUFFS = {
    { "Renew", "Interface\\Icons\\Spell_Holy_Renew" },
    { "Rejuvenation", "Interface\\Icons\\Spell_Nature_Rejuvenation" },
    { "Power Word: Shield", "Interface\\Icons\\Spell_Holy_PowerWordShield" },
}

function ns:UpdateTestAuras(b)
    local d = b.testData
    local db = self.db
    local now = GetTime()
    local shown = 0
    local maxDebuffs = self:Cfg(b, "maxDebuffs")
    for k in pairs(seenTypes) do seenTypes[k] = nil end

    if b.kind ~= "pet" and db.priorityDebuffs and b.index == 3 and maxDebuffs > 0 then
        shown = shown + 1
        local f = GetIcon(b, "debuffs", shown)
        f.unit, f.auraIndex, f.testName = nil, nil, "Necrotic Plague"
        SetIcon(f, "Interface\\Icons\\Spell_Shadow_DeathandDecay", 0, 15, now + 11, 1, 0.1, 0.1, db.prioritySize)
    end
    if d.debuffType and maxDebuffs > shown then
        local info = TEST_DEBUFF[d.debuffType]
        shown = shown + 1
        local f = GetIcon(b, "debuffs", shown)
        f.unit, f.auraIndex, f.testName = nil, nil, info[1]
        local r, g, bl = TypeColor(d.debuffType)
        SetIcon(f, info[2], 1, 18, now + 12, r, g, bl)
        seenTypes[d.debuffType] = true
    end
    if b.index == 1 and b.kind == "party" and db.debuffFilter == "ALL" and maxDebuffs > shown then
        shown = shown + 1
        local f = GetIcon(b, "debuffs", shown)
        f.unit, f.auraIndex, f.testName = nil, nil, "Sunder Armor"
        SetIcon(f, "Interface\\Icons\\Ability_Warrior_Sunder", 5, 30, now + 20, TypeColor(nil))
    end
    HideFrom(b.debuffs, shown + 1)

    self:SetDispelHighlight(b, d.debuffType)
    ShowIndicators(b, seenTypes)

    shown = 0
    local maxBuffs = self:Cfg(b, "maxBuffs")
    if not d.dead and maxBuffs > 0 then
        for i = 1, math.min(maxBuffs, (b.index % 3) + 1) do
            shown = shown + 1
            local f = GetIcon(b, "buffs", shown)
            f.unit, f.auraIndex, f.testName = nil, nil, TEST_BUFFS[i][1]
            SetIcon(f, TEST_BUFFS[i][2], 0, 15, now + 9 + i, 0, 0, 0)
        end
    end
    HideFrom(b.buffs, shown + 1)
end

------------------------------------------------------------------------
-- Timer text ticker
------------------------------------------------------------------------
local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    if not ns.db or not ns.db.auraTimers or not ns.allButtons then return end
    local now = GetTime()
    local all = ns.allButtons
    for i = 1, #all do
        local b = all[i]
        if b:IsShown() and b.debuffs then
            for _, f in ipairs(b.debuffs) do
                if f.expires and f:IsShown() then UpdateTimerText(f, now) end
            end
            for _, f in ipairs(b.buffs) do
                if f.expires and f:IsShown() then UpdateTimerText(f, now) end
            end
        end
    end
end)

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
ns:RegisterInit(function()
    ns:UpdateDispelAbilities()
end, "auras")

ns:On("UNIT_AURA", function(_, unit)
    ns.ForUnit(unit, function(self, b)
        self:UpdateAuras(b)
        self:UpdateIndicators(b)
        self:UpdateReminder(b)
        if self.inBattleground then self:UpdateFlag(b) end
    end)
end)

local function dispelChanged()
    if not ns.db then return end
    ns:UpdateDispelAbilities()
    if ns.container then ns:ForEachButton(function(b) ns:UpdateAuras(b) end) end
end
ns:On("SPELLS_CHANGED", dispelChanged)
ns:On("LEARNED_SPELL_IN_TAB", dispelChanged)
ns:On("PLAYER_TALENT_UPDATE", dispelChanged)
ns:On("CHARACTER_POINTS_CHANGED", dispelChanged)
ns:On("UNIT_PET", function(_, unit)
    if unit == "player" then dispelChanged() end
end)
ns:On("PET_BAR_UPDATE", dispelChanged)
