-- RetailPartyFrames - raid frames (SecureGroupHeaderTemplate), main tank frames, raid pets, raid preview

local _, ns = ...

local floor, max = math.floor, math.max
local NUM_GROUPS = 8
local UNITS_PER_GROUP = 5

local raidContainer, raidMover, mtContainer, mtMover
local groupHeaders, groupLabels = {}, {}
local combinedHeader, petHeader, mtHeader
local testContainer, testButtons = nil, {}
local CLASS_ORDER = "WARRIOR,DEATHKNIGHT,PALADIN,DRUID,SHAMAN,PRIEST,MAGE,WARLOCK,HUNTER,ROGUE"
local ROLE_RANK = { TANK = 1, HEALER = 2, DAMAGER = 3 }

-- names ordered tank > healer > damage > unknown, for the NAMELIST sort of the combined block
local function RoleNameList()
    local list = {}
    for i = 1, GetNumRaidMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            list[#list + 1] = { name = name, rank = ROLE_RANK[ns.GetRole("raid" .. i) or ""] or 4, index = i }
        end
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.index < b.index
    end)
    local names = {}
    for i, e in ipairs(list) do names[i] = e.name end
    return table.concat(names, ",")
end

------------------------------------------------------------------------
-- Header children
------------------------------------------------------------------------
local function InitialConfig(button)
    local kind = button:GetParent().rpfKind or "raid"
    ns:SetupUnitButton(button, kind)
    -- a child created while in combat is protected: size it after combat (RefreshAll -> ResizeChildren)
    if not InCombatLockdown() then
        button:SetWidth(ns:Cfg(button, "width"))
        button:SetHeight(ns:Cfg(button, "height"))
    end
    ns:LayoutButton(button)
end

-- create all children of a header now (out of combat), so nothing has to be created mid-fight
local function Precreate(h, n)
    if h.rpfPrecreated or InCombatLockdown() then return end
    h.rpfPrecreated = true
    h:SetAttribute("startingIndex", -(n - 1))
    h:SetAttribute("startingIndex", 1)
end

local function CreateHeader(name, kind, template)
    local h = CreateFrame("Frame", name, raidContainer, template or "SecureGroupHeaderTemplate")
    h.rpfKind = kind
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    -- 3.3.5 reads the field, later clients the attribute: set both
    h.initialConfigFunction = InitialConfig
    h:SetAttribute("initialConfigFunction", InitialConfig)
    h:SetAttribute("showRaid", true)
    h:SetAttribute("showParty", false)
    h:SetAttribute("showPlayer", true)
    h:SetAttribute("showSolo", false)
    h:Hide()
    return h
end

local function SetAttr(h, key, value)
    if h:GetAttribute(key) ~= value then h:SetAttribute(key, value) end
end

-- children sizes (existing children keep their size until re-layout)
local function ResizeChildren(h, kind)
    local w, hgt = ns.db.raidWidth, ns.db.raidHeight
    if kind == "pet" then w, hgt = ns.db.petWidth, ns.db.petHeight end
    local i = 1
    while true do
        local child = h:GetAttribute("child" .. i) or _G[h:GetName() .. "UnitButton" .. i]
        if not child then break end
        child:SetWidth(w)
        child:SetHeight(hgt)
        ns:LayoutButton(child)
        i = i + 1
    end
end

------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------
local function GroupSize()
    local db = ns.db
    local w, h, sp = db.raidWidth, db.raidHeight, db.raidSpacing
    if db.raidOrientation == "HORIZONTAL" then
        return UNITS_PER_GROUP * (w + sp) - sp, h
    end
    return w, UNITS_PER_GROUP * (h + sp) - sp
end

local function ApplyGrowth(h)
    local db = ns.db
    if db.raidOrientation == "HORIZONTAL" then
        SetAttr(h, "point", "LEFT")
        SetAttr(h, "xOffset", db.raidSpacing)
        SetAttr(h, "yOffset", 0)
        SetAttr(h, "columnAnchorPoint", "TOP")
    else
        SetAttr(h, "point", "TOP")
        SetAttr(h, "xOffset", 0)
        SetAttr(h, "yOffset", -db.raidSpacing)
        SetAttr(h, "columnAnchorPoint", "LEFT")
    end
    SetAttr(h, "sortMethod", db.raidSort == "NAME" and "NAME" or "INDEX")
    SetAttr(h, "sortDir", "ASC")
    SetAttr(h, "nameList", nil) -- a stale name list would act as a filter
end

local function GroupOffset(i)
    -- fixed grid so empty groups keep their slot
    local db = ns.db
    local gw, gh = GroupSize()
    local perLine = max(1, db.raidGroupsPerLine)
    local col, row
    if db.raidOrientation == "HORIZONTAL" then
        -- rows of units: groups stack downwards, "groups per line" = groups per column
        row = (i - 1) % perLine
        col = floor((i - 1) / perLine)
    else
        col = (i - 1) % perLine
        row = floor((i - 1) / perLine)
    end
    local labelPad = db.raidShowLabels and 12 or 0
    return col * (gw + db.raidGroupSpacing), -(row * (gh + db.raidGroupSpacing + labelPad) + labelPad)
end

local function ContainerSize(groupsShown)
    local db = ns.db
    local gw, gh = GroupSize()
    local perLine = max(1, db.raidGroupsPerLine)
    local cols = math.min(groupsShown, perLine)
    local rows = math.ceil(groupsShown / perLine)
    if db.raidOrientation == "HORIZONTAL" then cols, rows = rows, cols end
    local labelPad = db.raidShowLabels and 12 or 0
    return max(cols * (gw + db.raidGroupSpacing) - db.raidGroupSpacing, 10),
           max(rows * (gh + db.raidGroupSpacing + labelPad) - db.raidGroupSpacing, 10)
end

function ns:LayoutRaid()
    if not raidContainer then return end
    if InCombatLockdown() then
        self:AfterCombat("layoutraid", function() ns:LayoutRaid() end)
        return
    end
    local db = self.db
    self:PlaceContainer(raidContainer, "raidPoint", "raidScale")
    self:PlaceContainer(mtContainer, "mtPoint", "raidScale")

    local wantRaid = self:WantRaidFrames() and self.testMode ~= "raid"
    local wantTest = self.testMode == "raid"
    if wantRaid then raidContainer:Show() end

    -- group headers
    local groupsShown = 0
    for i = 1, NUM_GROUPS do
        local h = groupHeaders[i]
        local show = wantRaid and db.raidLayout == "GROUPS" and i <= db.raidMaxGroups
        if show then
            groupsShown = groupsShown + 1
            ApplyGrowth(h)
            SetAttr(h, "groupFilter", tostring(i))
            SetAttr(h, "unitsPerColumn", UNITS_PER_GROUP)
            SetAttr(h, "maxColumns", 1)
            SetAttr(h, "columnSpacing", db.raidGroupSpacing)
            h:ClearAllPoints()
            local x, y = GroupOffset(i)
            h:SetPoint("TOPLEFT", raidContainer, "TOPLEFT", x, y)
            h:Show()
            Precreate(h, UNITS_PER_GROUP)
            ResizeChildren(h, "raid")
            local label = groupLabels[i]
            label:ClearAllPoints()
            label:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 2, 1)
            label:SetText("Group " .. i)
            if db.raidShowLabels then label:Show() else label:Hide() end
        else
            h:Hide()
            groupLabels[i]:Hide()
        end
    end

    -- combined header
    if wantRaid and db.raidLayout == "COMBINED" then
        local h = combinedHeader
        ApplyGrowth(h)
        SetAttr(h, "groupFilter", nil)
        SetAttr(h, "unitsPerColumn", UNITS_PER_GROUP)
        SetAttr(h, "maxColumns", db.raidMaxGroups)
        SetAttr(h, "columnSpacing", db.raidGroupSpacing)
        local by = db.raidGroupBy
        if by == "LFGROLE" then
            SetAttr(h, "groupBy", nil)
            SetAttr(h, "groupingOrder", nil)
            SetAttr(h, "sortMethod", "NAMELIST")
            SetAttr(h, "nameList", RoleNameList())
        elseif by == "CLASS" then
            SetAttr(h, "groupBy", "CLASS")
            SetAttr(h, "groupingOrder", CLASS_ORDER)
        elseif by == "ROLE" then
            SetAttr(h, "groupBy", "ROLE")
            SetAttr(h, "groupingOrder", "MAINTANK,MAINASSIST,NONE")
        elseif by == "GROUP" then
            SetAttr(h, "groupBy", "GROUP")
            SetAttr(h, "groupingOrder", "1,2,3,4,5,6,7,8")
        else
            SetAttr(h, "groupBy", nil)
            SetAttr(h, "groupingOrder", nil)
        end
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", raidContainer, "TOPLEFT", 0, 0)
        h:Show()
        Precreate(h, 40)
        ResizeChildren(h, "raid")
        groupsShown = db.raidMaxGroups
    else
        combinedHeader:Hide()
    end

    -- raid pets
    if wantRaid and db.raidPets then
        local h = petHeader
        local gw, gh = GroupSize()
        SetAttr(h, "point", db.raidOrientation == "HORIZONTAL" and "LEFT" or "TOP")
        SetAttr(h, "xOffset", db.raidOrientation == "HORIZONTAL" and db.raidSpacing or 0)
        SetAttr(h, "yOffset", db.raidOrientation == "HORIZONTAL" and 0 or -db.raidSpacing)
        SetAttr(h, "unitsPerColumn", 10)
        SetAttr(h, "maxColumns", 4)
        SetAttr(h, "columnSpacing", db.raidGroupSpacing)
        SetAttr(h, "columnAnchorPoint", db.raidOrientation == "HORIZONTAL" and "TOP" or "LEFT")
        SetAttr(h, "filterOnPet", true)
        h:ClearAllPoints()
        local cw, ch = ContainerSize(groupsShown)
        if db.raidOrientation == "HORIZONTAL" then
            h:SetPoint("TOPLEFT", raidContainer, "TOPLEFT", 0, -(ch + db.raidGroupSpacing))
        else
            h:SetPoint("TOPLEFT", raidContainer, "TOPLEFT", cw + db.raidGroupSpacing, 0)
        end
        h:Show()
        Precreate(h, 40)
        ResizeChildren(h, "pet")
    else
        petHeader:Hide()
    end

    -- main tanks / assists
    if wantRaid and db.mtFrames then
        local h = mtHeader
        SetAttr(h, "point", "TOP")
        SetAttr(h, "xOffset", 0)
        SetAttr(h, "yOffset", -db.raidSpacing)
        SetAttr(h, "unitsPerColumn", 10)
        SetAttr(h, "maxColumns", 1)
        -- 3.3.5 filters roles through groupFilter (MAINTANK / MAINASSIST are valid tokens there)
        SetAttr(h, "groupFilter", "MAINTANK,MAINASSIST")
        SetAttr(h, "roleFilter", "MAINTANK,MAINASSIST")
        SetAttr(h, "strictFiltering", nil)
        SetAttr(h, "nameList", nil)
        SetAttr(h, "sortMethod", "INDEX")
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", mtContainer, "TOPLEFT", 0, 0)
        mtContainer:SetWidth(db.raidWidth)
        mtContainer:SetHeight(3 * (db.raidHeight + db.raidSpacing))
        mtContainer:Show()
        h:Show()
        Precreate(h, 10)
        ResizeChildren(h, "mt")
    else
        mtHeader:Hide()
        mtContainer:Hide()
    end

    local cw, ch = ContainerSize(max(groupsShown, 1))
    raidContainer:SetWidth(cw)
    raidContainer:SetHeight(ch)
    if wantRaid then raidContainer:Show() else raidContainer:Hide() end

    self:LayoutRaidTest(wantTest)
end

------------------------------------------------------------------------
-- Raid preview (25 fake units in 5 groups)
------------------------------------------------------------------------
function ns:LayoutRaidTest(show)
    if not show then
        if testContainer then testContainer:Hide() end
        for _, b in ipairs(testButtons) do
            b.testData = nil
            b:Hide()
        end
        return
    end
    if not testContainer then
        testContainer = CreateFrame("Frame", "RetailPartyFramesRaidPreview", UIParent)
        testContainer:SetFrameStrata("LOW")
    end
    local db = self.db
    testContainer:ClearAllPoints()
    testContainer:SetScale(db.raidScale)
    local pt = db.raidPoint
    testContainer:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
    local groups = math.min(5, db.raidMaxGroups)
    local w, h, sp = db.raidWidth, db.raidHeight, db.raidSpacing
    local horizontal = db.raidOrientation == "HORIZONTAL"
    local n = 0
    for g = 1, groups do
        local gx, gy = GroupOffset(g)
        for u = 1, UNITS_PER_GROUP do
            n = n + 1
            local b = testButtons[n]
            if not b then
                b = self:CreateUnitButton(testContainer, "RetailPartyFramesRaidPreview" .. n, "raid")
                b.index = n
                testButtons[n] = b
            end
            b.testData = self:TestUnit(n)
            b:SetWidth(w)
            b:SetHeight(h)
            b:ClearAllPoints()
            if horizontal then
                b:SetPoint("TOPLEFT", testContainer, "TOPLEFT", gx + (u - 1) * (w + sp), gy)
            else
                b:SetPoint("TOPLEFT", testContainer, "TOPLEFT", gx, gy - (u - 1) * (h + sp))
            end
            self:LayoutButton(b)
            b:Show()
        end
    end
    for i = n + 1, #testButtons do
        testButtons[i].testData = nil
        testButtons[i]:Hide()
    end
    local cw, ch = ContainerSize(groups)
    testContainer:SetWidth(cw)
    testContainer:SetHeight(ch)
    testContainer:Show()
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
ns:RegisterInit(function()
    raidContainer = CreateFrame("Frame", "RetailPartyFramesRaidContainer", UIParent)
    raidContainer:SetFrameStrata("LOW")
    raidContainer:SetWidth(10)
    raidContainer:SetHeight(10)
    raidContainer:Hide()
    ns.raidContainer = raidContainer

    mtContainer = CreateFrame("Frame", "RetailPartyFramesMTContainer", UIParent)
    mtContainer:SetFrameStrata("LOW")
    mtContainer:SetWidth(10)
    mtContainer:SetHeight(10)
    mtContainer:Hide()
    ns.mtContainer = mtContainer

    for i = 1, NUM_GROUPS do
        groupHeaders[i] = CreateHeader("RetailPartyFramesRaidGroup" .. i, "raid")
        local label = raidContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:Hide()
        groupLabels[i] = label
    end
    combinedHeader = CreateHeader("RetailPartyFramesRaidCombined", "raid")
    petHeader = CreateHeader("RetailPartyFramesRaidPets", "pet", "SecureGroupPetHeaderTemplate")
    mtHeader = CreateHeader("RetailPartyFramesMainTanks", "mt")
    mtHeader:SetParent(mtContainer)

    raidMover = ns:CreateMover(raidContainer, "RetailPartyFrames - raid", "raidPoint")
    mtMover = ns:CreateMover(mtContainer, "RetailPartyFrames - main tanks", "mtPoint")
    -- the raid mover should be usable even when the raid container is hidden (solo setup)
    raidMover:SetScript("OnShow", function(self)
        if not raidContainer:IsShown() and not InCombatLockdown() then
            local cw, ch = ContainerSize(math.min(ns.db.raidMaxGroups, 5))
            raidContainer:SetWidth(cw)
            raidContainer:SetHeight(ch)
        end
    end)
end, "raid")

ns:RegisterCallback("LAYOUT", function()
    if raidContainer then ns:LayoutRaid() end
end)

local function RefreshRoleList()
    if not raidContainer or ns.db.raidLayout ~= "COMBINED" or ns.db.raidGroupBy ~= "LFGROLE" then return end
    if not combinedHeader:IsShown() then return end
    ns:AfterCombat("rolelist", function()
        SetAttr(combinedHeader, "nameList", RoleNameList())
    end)
end
ns:RegisterCallback("ROLES_CHANGED", RefreshRoleList)
ns:On("RAID_ROSTER_UPDATE", RefreshRoleList)
