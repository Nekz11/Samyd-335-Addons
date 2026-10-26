-- RetailPartyFrames - party frames (player + party1-4), party pets, party test preview

local _, ns = ...

local MAX_BUTTONS = 5
local buttons, pets = {}, {}
ns.partyButtons, ns.petButtons = buttons, pets
local container, mover
local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }

------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------
local function PlaceButton(b, i, w, h, sp, vertical)
    b:SetWidth(w)
    b:SetHeight(h)
    b:ClearAllPoints()
    if vertical then
        b:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * (h + sp))
    else
        b:SetPoint("TOPLEFT", container, "TOPLEFT", (i - 1) * (w + sp), 0)
    end
end

function ns:LayoutParty()
    if not container then return end
    local db = self.db
    if InCombatLockdown() then
        self:AfterCombat("layoutparty", function() ns:LayoutParty() end)
        for i = 1, #buttons do self:LayoutButton(buttons[i]) end
        for i = 1, #pets do self:LayoutButton(pets[i]) end
        return
    end
    self:PlaceContainer(container, "point", "scale")

    local w, h, sp = db.width, db.height, db.spacing
    local vertical = db.orientation ~= "HORIZONTAL"
    local pw, ph = db.petWidth, db.petHeight
    local showPets = db.partyPets
    local rows = 0
    for i, b in ipairs(buttons) do
        PlaceButton(b, i, w, h, sp, vertical)
        self:LayoutButton(b)
        local pet = pets[i]
        pet:SetWidth(pw)
        pet:SetHeight(ph)
        pet:ClearAllPoints()
        if vertical then
            -- pets hang to the right of their owner
            pet:SetPoint("TOPLEFT", b, "TOPRIGHT", sp, 0)
        else
            pet:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -sp)
        end
        self:LayoutButton(pet)
        rows = i
    end
    if vertical then
        container:SetWidth(w + (showPets and (sp + pw) or 0))
        container:SetHeight(MAX_BUTTONS * (h + sp) - sp)
    else
        container:SetWidth(MAX_BUTTONS * (w + sp) - sp)
        container:SetHeight(h + (showPets and (sp + ph) or 0))
    end
end

------------------------------------------------------------------------
-- Roster
------------------------------------------------------------------------
local function SortUnits(list, mode)
    if mode == "GROUP" then return end
    table.sort(list, function(a, b)
        if mode == "ROLE" then
            local ra = ROLE_ORDER[ns.GetRole(a) or ""] or 4
            local rb = ROLE_ORDER[ns.GetRole(b) or ""] or 4
            if ra ~= rb then return ra < rb end
        elseif mode == "CLASS" then
            local _, ca = UnitClass(a)
            local _, cb = UnitClass(b)
            ca, cb = ca or "", cb or ""
            if ca ~= cb then return ca < cb end
        end
        local na, nb = UnitName(a) or a, UnitName(b) or b
        if na ~= nb then return na < nb end
        return a < b
    end)
end

local function PetUnitFor(unit)
    if unit == "player" then return "pet" end
    local n = string.match(unit or "", "^party(%d)$")
    if n then return "partypet" .. n end
    return nil
end

local function Assign(b, unit)
    if unit then
        if b:GetAttribute("unit") ~= unit then b:SetAttribute("unit", unit) end
        b.unit = unit
        RegisterUnitWatch(b)
    else
        UnregisterUnitWatch(b)
        b:SetAttribute("unit", nil)
        b.unit = nil
        b:Hide()
    end
end

function ns:UpdatePartyRoster()
    if not container then return end
    if InCombatLockdown() then
        self:AfterCombat("partyroster", function()
            ns:UpdatePartyRoster()
            ns:UpdateAllButtons()
        end)
        return
    end
    local db = self.db

    -- preview
    if self.testMode == "party" then
        for i, b in ipairs(buttons) do
            UnregisterUnitWatch(b)
            b.testData = self:TestUnit(i)
            b.unit = nil
            b:SetAttribute("unit", nil)
            b:Show()
            local pet = pets[i]
            UnregisterUnitWatch(pet)
            pet.unit = nil
            pet:SetAttribute("unit", nil)
            if db.partyPets and i <= 3 then
                pet.testData = { name = (i == 1) and "Grrak" or (i == 2) and "Shadowfiend" or "Kitty", class = nil, hp = 0.7 + i * 0.08, power = 1, powerType = 0 }
                pet:Show()
            else
                pet.testData = nil
                pet:Hide()
            end
        end
        self:RebuildUnitMap()
        self:LayoutParty()
        return
    end

    for _, b in ipairs(buttons) do b.testData = nil end
    for _, p in ipairs(pets) do p.testData = nil end

    local list = {}
    if self:WantPartyFrames() then
        local numParty = GetNumPartyMembers()
        for i = 1, numParty do list[#list + 1] = "party" .. i end
        if db.showPlayer and db.playerPosition == "SORTED" then list[#list + 1] = "player" end
        SortUnits(list, db.sortMode)
        if db.showPlayer then
            if db.playerPosition == "FIRST" then
                table.insert(list, 1, "player")
            elseif db.playerPosition == "LAST" then
                list[#list + 1] = "player"
            end
        end
        -- spare slots so people joining during combat still get a frame
        if not self.inRaidGroup then
            for i = numParty + 1, 4 do list[#list + 1] = "party" .. i end
        end
    end

    for i, b in ipairs(buttons) do
        local unit = list[i]
        Assign(b, unit)
        Assign(pets[i], (unit and db.partyPets) and PetUnitFor(unit) or nil)
    end
    self:RebuildUnitMap()
    self:LayoutParty()
end

------------------------------------------------------------------------
-- Blizzard party frames
------------------------------------------------------------------------
local function noop() end
local blizzardHidden = false
function ns:HideBlizzardParty()
    if blizzardHidden then return end
    if InCombatLockdown() then
        self:AfterCombat("hideblizzparty", function() ns:HideBlizzardParty() end)
        return
    end
    blizzardHidden = true
    for i = 1, (MAX_PARTY_MEMBERS or 4) do
        local f = _G["PartyMemberFrame" .. i]
        if f then
            f:UnregisterAllEvents()
            f:Hide()
            f.Show = noop
            local hb = _G["PartyMemberFrame" .. i .. "HealthBar"]
            local mb = _G["PartyMemberFrame" .. i .. "ManaBar"]
            if hb then hb:UnregisterAllEvents() end
            if mb then mb:UnregisterAllEvents() end
        end
        local pet = _G["PartyMemberFrame" .. i .. "PetFrame"]
        if pet then
            pet:UnregisterAllEvents()
            pet:Hide()
            pet.Show = noop
        end
    end
    if PartyMemberBackground then
        PartyMemberBackground:Hide()
        PartyMemberBackground.Show = noop
    end
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
ns:RegisterInit(function()
    container = CreateFrame("Frame", "RetailPartyFramesContainer", UIParent)
    container:SetFrameStrata("LOW")
    container:SetWidth(10)
    container:SetHeight(10)
    ns.container = container

    for i = 1, MAX_BUTTONS do
        local b = ns:CreateUnitButton(container, "RetailPartyFramesUnitButton" .. i, "party")
        b.index = i
        buttons[i] = b
        local pet = ns:CreateUnitButton(container, "RetailPartyFramesPetButton" .. i, "pet")
        pet.index = i
        pets[i] = pet
    end

    mover = ns:CreateMover(container, "RetailPartyFrames - party", "point")
    if ns.db.hideBlizzard then ns:HideBlizzardParty() end
end, "party")

ns:RegisterCallback("LAYOUT", function()
    if not container then return end
    if ns.db.hideBlizzard then ns:HideBlizzardParty() end
    ns:UpdatePartyRoster()
end)

ns:RegisterCallback("ROLES_CHANGED", function()
    if container and ns.db.sortMode == "ROLE" then ns:UpdatePartyRoster() end
end)
