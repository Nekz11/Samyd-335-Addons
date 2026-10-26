-- RetailPartyFrames - group type detection (solo / party / raid10 / raid25 / raid40 / arena / bg)

local _, ns = ...

ns.groupType = "solo"
ns.groupSize = 0
ns.inArena = false
ns.inBattleground = false
ns.inRaidGroup = false

local function Detect()
    local numRaid, numParty = GetNumRaidMembers(), GetNumPartyMembers()
    local inInstance, itype = IsInInstance()
    local arena = inInstance and itype == "arena"
    local bg = inInstance and itype == "pvp"
    local gtype, size
    if numRaid > 0 then
        size = numRaid
        if bg then
            gtype = "bg"
        elseif numRaid > 25 then
            gtype = "raid40"
        elseif numRaid > 10 then
            gtype = "raid25"
        else
            gtype = "raid10"
        end
    elseif numParty > 0 then
        size = numParty + 1
        gtype = arena and "arena" or "party"
    else
        size = 1
        gtype = arena and "arena" or "solo"
    end
    return gtype, size, arena, bg, numRaid > 0
end

ns.GroupTypeLabels = {
    solo = "Solo", party = "Party / Dungeon", raid10 = "Raid (up to 10)", raid25 = "Raid (11-25)",
    raid40 = "Raid (26-40)", arena = "Arena", bg = "Battleground",
}

-- force = fire callbacks even when nothing changed (used at login)
function ns:UpdateGroupType(force)
    local gtype, size, arena, bg, raid = Detect()
    local changed = force or gtype ~= self.groupType or arena ~= self.inArena or bg ~= self.inBattleground or raid ~= self.inRaidGroup
    local sizeChanged = size ~= self.groupSize
    self.groupType, self.groupSize = gtype, size
    self.inArena, self.inBattleground, self.inRaidGroup = arena, bg, raid
    if changed then
        self:Fire("GROUP_TYPE_CHANGED", gtype, size)
    end
    if changed or sizeChanged then
        self:Fire("GROUP_CHANGED", gtype, size)
    end
end

-- which frame sets should be visible right now
function ns:WantPartyFrames()
    local db = self.db
    local g = self.groupType
    if self.testMode == "party" then return true end
    if self.testMode == "raid" then return false end
    if g == "solo" then return db.showSolo end
    if g == "party" or g == "arena" then return true end
    -- raid / bg
    return db.raidMode == "PARTY" or db.raidMode == "BOTH"
end

function ns:WantRaidFrames()
    local g = self.groupType
    if self.testMode == "raid" then return true end
    if self.testMode == "party" then return false end
    if not self.inRaidGroup then return false end
    return self.db.raidMode == "RAID" or self.db.raidMode == "BOTH"
end

local function changed()
    if ns.db then ns:UpdateGroupType() end
end
ns:On("PARTY_MEMBERS_CHANGED", changed)
ns:On("RAID_ROSTER_UPDATE", changed)
ns:On("ZONE_CHANGED_NEW_AREA", changed)
ns:On("PLAYER_ENTERING_WORLD", function()
    changed()
    -- after a zone change (arena, dungeon, BG) group data can still be incomplete
    ns:After(1, changed)
    ns:After(4, function()
        if ns.db then ns:UpdateGroupType(true) end
    end)
end)
