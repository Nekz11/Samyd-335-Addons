-- RetailPartyFrames - corner indicators (Grid style): small squares for your own HoTs / shields

local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GetTime = GetTime
local floor, ceil = math.floor, math.ceil

ns.IndicatorSlots = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" }
local SLOTS = ns.IndicatorSlots

-- indicator colors per slot (retail Grid defaults)
local SLOT_COLORS = {
    TOPLEFT = { 0.2, 1, 0.2 },
    TOPRIGHT = { 1, 0.9, 0.2 },
    BOTTOMLEFT = { 0.3, 0.7, 1 },
    BOTTOMRIGHT = { 1, 0.4, 0.9 },
    CENTER = { 1, 1, 1 },
}

------------------------------------------------------------------------
-- Configured spells per slot (profile override or class defaults), resolved to names
------------------------------------------------------------------------
local resolved        -- slot -> list of { name=, id=, debuff=bool }
local resolvedKey

function ns:IndicatorSlotIds(slot)
    local cfg = self.db.indicators
    if cfg.slots and cfg.slots[slot] then return cfg.slots[slot] end
    local _, class = UnitClass("player")
    local defaults = self.IndicatorDefaults[class] or self.IndicatorDefaults.DEFAULT
    return defaults[slot] or {}
end

-- make the per-class defaults editable: copy them into the profile once
function ns:EnsureIndicatorSlots()
    local cfg = self.db.indicators
    if cfg.slots then return cfg.slots end
    cfg.slots = {}
    for _, slot in ipairs(SLOTS) do
        cfg.slots[slot] = self.DeepCopy(self:IndicatorSlotIds(slot))
    end
    return cfg.slots
end

local function Resolve()
    local key = {}
    resolved = {}
    for _, slot in ipairs(SLOTS) do
        local list = {}
        for _, id in ipairs(ns:IndicatorSlotIds(slot)) do
            local name = GetSpellInfo(id)
            if name then
                list[#list + 1] = { name = name, id = id, debuff = ns.IndicatorDebuffs[id] and true or false }
                key[#key + 1] = id
            end
        end
        resolved[slot] = list
    end
    resolvedKey = table.concat(key, ",")
end

function ns:InvalidateIndicators()
    resolved = nil
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
function ns:CreateIndicatorWidgets(b)
    local holder = CreateFrame("Frame", nil, b.overlay)
    holder:SetAllPoints(b.overlay)
    holder:SetFrameLevel(b.overlay:GetFrameLevel() + 3)
    b.indicatorHolder = holder
    b.indicators = {}
    for _, slot in ipairs(SLOTS) do
        local f = CreateFrame("Frame", nil, holder)
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
        f.bg:SetTexture(WHITE)
        f.bg:SetVertexColor(0, 0, 0, 0.9)
        f.fill = f:CreateTexture(nil, "ARTWORK")
        f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
        f.fill:SetTexture(WHITE)
        f.text = f:CreateFontString(nil, "OVERLAY")
        f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.slot = slot
        f:Hide()
        b.indicators[slot] = f
    end
end

function ns:LayoutIndicators(b)
    local cfg = self.db.indicators
    local size = cfg.size
    if b.kind == "pet" then size = math.max(4, size - 2) end
    local h = b.health
    for _, slot in ipairs(SLOTS) do
        local f = b.indicators[slot]
        f:SetWidth(size)
        f:SetHeight(size)
        f:ClearAllPoints()
        if slot == "TOPLEFT" then
            f:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1)
        elseif slot == "TOPRIGHT" then
            f:SetPoint("TOPRIGHT", h, "TOPRIGHT", -1, -1)
        elseif slot == "BOTTOMLEFT" then
            f:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 1, 1)
        elseif slot == "BOTTOMRIGHT" then
            f:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -1, 1)
        else
            f:SetPoint("CENTER", h, "CENTER", 0, -size)
        end
        ns.StyleFont(f.text, math.max(7, size + 2), "OUTLINE")
        local c = SLOT_COLORS[slot]
        f.fill:SetVertexColor(c[1], c[2], c[3], 1)
    end
end

------------------------------------------------------------------------
-- Update
------------------------------------------------------------------------
local function FindAura(unit, name, debuff, mineOnly)
    local filter = debuff and "HARMFUL" or (mineOnly and "HELPFUL|PLAYER" or "HELPFUL")
    for i = 1, 40 do
        local n, _, _, count, _, duration, expires, caster = UnitAura(unit, i, filter)
        if not n then break end
        if n == name and (not mineOnly or debuff or caster == "player") then
            return count, duration, expires
        end
    end
    return nil
end

function ns:UpdateIndicators(b)
    local cfg = self.db.indicators
    if not cfg.enabled or b.kind == "pet" then
        for _, slot in ipairs(SLOTS) do b.indicators[slot]:Hide() end
        return
    end
    if not resolved then Resolve() end
    local now = GetTime()
    for _, slot in ipairs(SLOTS) do
        local f = b.indicators[slot]
        local list = resolved[slot]
        local count, duration, expires
        if b.testData then
            -- preview: light up a couple of corners
            if #list > 0 and not b.testData.dead and ((b.index + #slot) % 3 == 0) then
                count, duration, expires = (slot == "BOTTOMLEFT") and 3 or 0, 15, now + 4 + (b.index % 9)
            end
        elseif b.unit then
            for _, spell in ipairs(list) do
                count, duration, expires = FindAura(b.unit, spell.name, spell.debuff, cfg.mine)
                if count then break end
            end
        end
        if count then
            f.expires = (duration and duration > 0) and expires or nil
            f.count = count
            f:Show()
            self:UpdateIndicatorText(f, now)
        else
            f.expires = nil
            f:Hide()
        end
    end
end

function ns:UpdateIndicatorText(f, now)
    local cfg = self.db.indicators
    local txt = ""
    if cfg.showTimer and f.expires then
        local left = f.expires - now
        if left <= cfg.timerThreshold then
            txt = tostring(ceil(left))
            if left <= 0 then
                f:Hide()
                f.expires = nil
                return
            end
        end
    end
    if txt == "" and cfg.showStacks and f.count and f.count > 1 then
        txt = tostring(f.count)
    end
    f.text:SetText(txt)
end

-- timer text ticker
local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.25 then return end
    acc = 0
    if not ns.db or not ns.db.indicators.enabled then return end
    local now = GetTime()
    local all = ns.allButtons
    for i = 1, #all do
        local b = all[i]
        if b:IsShown() and b.indicators then
            for _, slot in ipairs(SLOTS) do
                local f = b.indicators[slot]
                if f:IsShown() and f.expires then ns:UpdateIndicatorText(f, now) end
            end
        end
    end
end)

ns:RegisterCallback("PROFILE_CHANGED", function() ns:InvalidateIndicators() end)
ns:RegisterCallback("LAYOUT", function() ns:InvalidateIndicators() end)
