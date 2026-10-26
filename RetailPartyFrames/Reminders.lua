-- RetailPartyFrames - missing buff reminders: a small icon on frames that lack a raid buff you can cast

local _, ns = ...

------------------------------------------------------------------------
-- Buff groups: the player must know one of `cast` (any rank); a unit counts as buffed when it
-- has any of the `has` auras (names are resolved from the spell ids, so this is locale independent).
------------------------------------------------------------------------
local GROUPS = {
    PRIEST = {
        { key = "fortitude", cast = { 1243, 21562 }, has = { 1243, 21562 } },      -- Power Word: Fortitude / Prayer of Fortitude
        { key = "spirit", cast = { 14752, 27681 }, has = { 14752, 27681 } },       -- Divine Spirit / Prayer of Spirit
        { key = "shadowprot", cast = { 976, 27683 }, has = { 976, 27683 } },       -- Shadow Protection / Prayer of Shadow Protection
    },
    MAGE = {
        { key = "intellect", cast = { 1459, 23028, 61024 }, has = { 1459, 23028, 61024, 61316 } }, -- Arcane Intellect / Brilliance / Dalaran
    },
    DRUID = {
        { key = "wild", cast = { 1126, 21849 }, has = { 1126, 21849 } },           -- Mark / Gift of the Wild
    },
    PALADIN = {
        -- any blessing counts, shown when the unit has none of yours
        { key = "blessing", cast = { 20217, 19740, 19742, 20911 }, has = { 20217, 25898, 19740, 25782, 19742, 25894, 20911, 25899 }, anyBlessing = true },
    },
}

local resolved          -- list of { key, icon, castNames = {..}, hasNames = {..} } for the player's class
local knownBook = {}

local function ScanBook()
    for k in pairs(knownBook) do knownBook[k] = nil end
    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL or "spell")
        if not name then break end
        knownBook[name] = true
        i = i + 1
        if i > 1024 then break end
    end
end

local function Resolve()
    resolved = {}
    local _, class = UnitClass("player")
    local groups = GROUPS[class]
    if not groups then return end
    ScanBook()
    for _, g in ipairs(groups) do
        local entry = { key = g.key, hasNames = {}, anyBlessing = g.anyBlessing }
        local known = false
        for _, id in ipairs(g.cast) do
            local name, _, icon = GetSpellInfo(id)
            if name and knownBook[name] then
                known = true
                entry.icon = entry.icon or icon
            end
        end
        for _, id in ipairs(g.has) do
            local name = GetSpellInfo(id)
            if name then entry.hasNames[name] = true end
        end
        if known then resolved[#resolved + 1] = entry end
    end
end

function ns:InvalidateReminders()
    resolved = nil
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
function ns:CreateReminderWidgets(b)
    local f = b.overlay:CreateTexture(nil, "OVERLAY")
    f:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f:SetWidth(12)
    f:SetHeight(12)
    f:Hide()
    b.reminder = f
end

function ns:LayoutReminder(b)
    local db = self.db.reminders
    local size = (b.kind == "raid" or b.kind == "mt") and math.max(8, db.size - 4) or db.size
    b.reminder:SetWidth(size)
    b.reminder:SetHeight(size)
    b.reminder:ClearAllPoints()
    if db.position == "TOPRIGHT" then
        b.reminder:SetPoint("TOPRIGHT", b.health, "TOPRIGHT", -2, -2)
    elseif db.position == "CENTER" then
        b.reminder:SetPoint("CENTER", b.health, "CENTER", 0, 0)
    else
        b.reminder:SetPoint("BOTTOMRIGHT", b.health, "BOTTOMRIGHT", -2, 2)
    end
    b.reminder:SetAlpha(db.alpha)
end

------------------------------------------------------------------------
-- Update
------------------------------------------------------------------------
local function HasAny(unit, names)
    for i = 1, 40 do
        local name = UnitAura(unit, i, "HELPFUL")
        if not name then break end
        if names[name] then return true end
    end
    return false
end

function ns:UpdateReminder(b)
    local db = self.db.reminders
    local f = b.reminder
    if not db.enabled or b.kind == "pet" or (db.hideInCombat and InCombatLockdown()) then
        f:Hide()
        return
    end
    if b.testData then
        if b.index % 4 == 2 and not b.testData.dead then
            f:SetTexture("Interface\\Icons\\Spell_Holy_WordFortitude")
            f:Show()
        else
            f:Hide()
        end
        return
    end
    local unit = b.unit
    if not unit or not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) or not UnitIsPlayer(unit) then
        f:Hide()
        return
    end
    if not resolved then Resolve() end
    for _, g in ipairs(resolved) do
        if not HasAny(unit, g.hasNames) then
            f:SetTexture(g.icon)
            f:Show()
            return
        end
    end
    f:Hide()
end

local function refreshAll()
    if not ns.db then return end
    ns:InvalidateReminders()
    ns:ForEachButton(function(b) ns:UpdateReminder(b) end)
end

ns:On("SPELLS_CHANGED", refreshAll)
ns:On("LEARNED_SPELL_IN_TAB", refreshAll)
ns:On("PLAYER_REGEN_ENABLED", function()
    if ns.db and ns.db.reminders.enabled then ns:ForEachButton(function(b) ns:UpdateReminder(b) end) end
end)
ns:On("PLAYER_REGEN_DISABLED", function()
    if ns.db and ns.db.reminders.enabled then ns:ForEachButton(function(b) ns:UpdateReminder(b) end) end
end)
ns:RegisterCallback("PROFILE_CHANGED", function() ns:InvalidateReminders() end)
