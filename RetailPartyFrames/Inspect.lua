-- RetailPartyFrames - talent & glyph inspection of group members
-- Finds talent abilities (shown right away instead of after first use) and
-- cooldown reductions from talents/glyphs. Falls back to the usage based
-- detection in Cooldowns.lua whenever a unit cannot be inspected.

local _, ns = ...

local GetTime = GetTime
local INSPECT_TIMEOUT = 4
local INSPECT_INTERVAL = 2.5
local REINSPECT_AFTER = 600 -- refresh everyone every 10 minutes

local pending          -- { unit = "party1", guid = ..., at = time }
local lastRequest = 0
local lastNotifyGUID   -- who was inspected last, by anyone (we hook NotifyInspect)
local retries = {}     -- guid -> failed attempts
local inspected = {}   -- guid -> time of last successful inspection
local queued = {}      -- guid -> unit

ns.unitMods = {}       -- guid -> { [entryId] = { flat = seconds, pct = percent } }
ns.unitTalents = {}    -- guid -> { [talentName] = rank }

------------------------------------------------------------------------
-- Name tables (built lazily, names come from the client so they are localized)
------------------------------------------------------------------------
local talentNameToId  -- talent name -> TalentMods key
local function TalentNames()
    if talentNameToId then return talentNameToId end
    talentNameToId = {}
    for id in pairs(ns.TalentMods) do
        local name = GetSpellInfo(id)
        if name then talentNameToId[name] = id end
    end
    return talentNameToId
end

------------------------------------------------------------------------
-- Apply an inspection result
------------------------------------------------------------------------
local function AddMod(mods, spellId, flat, pct)
    local e = ns.SpellIndex[spellId]
    if not e then return end
    local m = mods[e.id]
    if not m then
        m = { flat = 0, pct = 0 }
        mods[e.id] = m
    end
    m.flat = m.flat + (flat or 0)
    m.pct = m.pct + (pct or 0)
end

-- talents: name -> rank, glyphs: list of glyph names, class: class token
function ns:ApplyInspection(guid, class, talents, glyphs)
    local mods = {}
    self.unitTalents[guid] = talents

    -- 1) cooldown reductions from talents
    local names = TalentNames()
    for tname, rank in pairs(talents) do
        local tid = names[tname]
        local list = tid and self.TalentMods[tid]
        if list then
            for _, mod in ipairs(list) do
                local flat = mod.flat and mod.flat[rank]
                local pct = mod.pct and mod.pct[rank]
                if flat or pct then AddMod(mods, mod[1], flat, pct) end
            end
        end
    end

    -- 2) cooldown reductions from glyphs ("Glyph of X" contains the spell name X)
    for spellId, seconds in pairs(self.GlyphMods) do
        local sname = GetSpellInfo(spellId)
        if sname then
            for _, gname in ipairs(glyphs) do
                if string.find(gname, sname, 1, true) then
                    AddMod(mods, spellId, seconds, 0)
                    break
                end
            end
        end
    end
    self.unitMods[guid] = mods

    -- 3) talent abilities: known from the talent tree, no need to wait for a cast
    local spells = self.ClassSpells[class]
    if spells then
        local seen = self:SeenTable(guid)
        for _, e in ipairs(spells) do
            if e.talent then
                local sname = GetSpellInfo(e.id)
                local has = false
                if sname then
                    for tname in pairs(talents) do
                        -- "Feral Charge - Bear" / "Demonic Circle: Teleport" start with the talent name
                        if sname == tname or string.find(sname, tname, 1, true) == 1 then
                            has = true
                            break
                        end
                    end
                end
                seen[e.id] = has or nil
            end
        end
    end

    inspected[guid] = GetTime()
    self:RefreshCooldownsFor(guid)
end

------------------------------------------------------------------------
-- Reading talents (own or inspected)
------------------------------------------------------------------------
local function ReadTalents(isInspect)
    local talents, glyphs = {}, {}
    local numTabs = GetNumTalentTabs(isInspect) or 0
    for tab = 1, numTabs do
        local num = GetNumTalents(tab, isInspect) or 0
        for i = 1, num do
            local name, _, _, _, rank = GetTalentInfo(tab, i, isInspect)
            if name and rank and rank > 0 then talents[name] = rank end
        end
    end
    for socket = 1, 6 do
        local ok, enabled, _, glyphSpell = pcall(GetGlyphSocketInfo, socket, nil, isInspect)
        if ok and enabled and glyphSpell then
            local gname = GetSpellInfo(glyphSpell)
            if gname then glyphs[#glyphs + 1] = gname end
        end
    end
    return talents, glyphs
end

function ns:ReadOwnTalents()
    local guid = UnitGUID("player")
    local _, class = UnitClass("player")
    if not guid or not class then return end
    local talents, glyphs = ReadTalents(false)
    self:ApplyInspection(guid, class, talents, glyphs)
end

------------------------------------------------------------------------
-- Queue
------------------------------------------------------------------------
local function Inspectable(unit)
    if not UnitExists(unit) or not UnitIsConnected(unit) then return false end
    if not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return false end
    if not CanInspect(unit) then return false end
    if not CheckInteractDistance(unit, 1) then return false end -- 28 yards, same as inspecting
    return true
end

function ns:QueueInspect(unit, force)
    local guid = UnitGUID(unit)
    if not guid or UnitIsUnit(unit, "player") then return end
    if not force and inspected[guid] and GetTime() - inspected[guid] < REINSPECT_AFTER then return end
    queued[guid] = unit
end

function ns:QueueGroupInspect(force)
    for k in pairs(queued) do queued[k] = nil end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then self:QueueInspect(unit, force) end
    end
end

local function BlizzardInspectOpen()
    return InspectFrame and InspectFrame:IsShown()
end

local MAX_RETRIES = 3

local function Requeue(p)
    retries[p.guid] = (retries[p.guid] or 0) + 1
    if retries[p.guid] <= MAX_RETRIES then
        queued[p.guid] = p.unit
    else
        -- give up for this session; usage based detection still works
        inspected[p.guid] = GetTime()
    end
end

local function Tick()
    if not ns.db or not ns.db.cooldowns or not ns.db.cdInspect then return end
    local now = GetTime()
    if pending then
        if now - pending.at > INSPECT_TIMEOUT then
            Requeue(pending)
            pending = nil
        end
        return
    end
    local interval = INSPECT_INTERVAL
    if LibStub and LibStub("LibGroupTalents-1.0", true) then interval = 6 end -- share the inspect channel politely
    if now - lastRequest < interval or BlizzardInspectOpen() then return end
    for guid, unit in pairs(queued) do
        if UnitGUID(unit) ~= guid then
            queued[guid] = nil
        elseif Inspectable(unit) then
            queued[guid] = nil
            pending = { unit = unit, guid = guid, at = now }
            lastRequest = now
            lastNotifyGUID = guid
            NotifyInspect(unit)
            return
        end
    end
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.5 then return end
    acc = 0
    Tick()
end)

-- INSPECT_TALENT_READY carries no unit: remember who was asked for last, by any addon
if hooksecurefunc and NotifyInspect then
    hooksecurefunc("NotifyInspect", function(unit)
        local guid = unit and UnitGUID(unit)
        if guid then lastNotifyGUID = guid end
        -- somebody else inspected in between: our pending request is no longer reliable
        if pending and guid ~= pending.guid then
            Requeue(pending)
            pending = nil
        end
    end)
end

local function OnInspectReady()
    if not pending then return end
    local p = pending
    pending = nil
    if UnitGUID(p.unit) ~= p.guid then return end
    if lastNotifyGUID ~= p.guid then
        Requeue(p) -- the data belongs to someone else's inspection
        return
    end
    local _, class = UnitClass(p.unit)
    if not class then return end
    local talents, glyphs = ReadTalents(true)
    if next(talents) then
        retries[p.guid] = nil
        ns:ApplyInspection(p.guid, class, talents, glyphs)
    else
        -- empty result (out of range after all, or cleared by another addon): retry a few times
        Requeue(p)
    end
    -- do not call ClearInspectPlayer(): other addons (LibGroupTalents in Details!, oRA3) track the
    -- inspected unit themselves and break when the target is cleared under them
end

ns:On("INSPECT_TALENT_READY", OnInspectReady) -- 3.3.5
ns:On("INSPECT_READY", OnInspectReady)        -- later clients

------------------------------------------------------------------------
-- Triggers
------------------------------------------------------------------------
ns:RegisterInit(function()
    ns:ReadOwnTalents()
    ns:QueueGroupInspect()
end, "inspect")

local function groupChanged()
    if ns.container then
        ns:QueueGroupInspect()
    end
end
ns:On("PARTY_MEMBERS_CHANGED", groupChanged)
ns:On("PLAYER_ENTERING_WORLD", groupChanged)

local function ownTalentsChanged()
    if ns.container then ns:ReadOwnTalents() end
end
ns:On("PLAYER_TALENT_UPDATE", ownTalentsChanged)
ns:On("ACTIVE_TALENT_GROUP_CHANGED", ownTalentsChanged)
ns:On("GLYPH_ADDED", ownTalentsChanged)
ns:On("GLYPH_REMOVED", ownTalentsChanged)
ns:On("GLYPH_UPDATED", ownTalentsChanged)

-- a party member switched dual spec: re-inspect
local SPEC_SWITCH = { [63644] = true, [63645] = true } -- Activate Primary/Secondary Spec
ns:On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, spell)
    if not unit or string.sub(unit, 1, 5) ~= "party" then return end
    for id in pairs(SPEC_SWITCH) do
        if GetSpellInfo(id) == spell then
            ns:After(2, function()
                if UnitExists(unit) then ns:QueueInspect(unit, true) end
            end)
            return
        end
    end
end)

function ns:ForceInspect()
    self:ReadOwnTalents()
    self:QueueGroupInspect(true)
    self:Print("Re-inspecting group members.")
end
