-- RetailPartyFrames - built-in profile presets (created as profiles on first start, re-creatable any time)

local _, ns = ...

-- Each preset is a set of overrides on top of the defaults.
ns.Presets = {
    {
        key = "PvP - Arena",
        description = "2v2 / 3v3 / 5v5: big team frames with percent, mana, cast bars, trinket and defensive cooldowns, enemy target counter.",
        groups = { arena = true },
        overrides = {
            width = 132, height = 52, spacing = 3, orientation = "VERTICAL",
            sortMode = "GROUP", playerPosition = "FIRST", showPlayer = true, showSolo = false,
            partyPets = true, petWidth = 132, petHeight = 18, petMaxDebuffs = 1,
            healthText = "PERCENT", powerBar = "ALL", powerHeight = 6, statusTextSize = 12,
            healthColor = "CLASS", lowHealthHighlight = true, lowHealthPercent = 35,
            fontSize = 12, fontOutline = "OUTLINE", nameLength = 10,
            castbar = true, castbarHeight = 11, castbarIcon = true, castbarText = true, castbarTimer = true,
            cooldowns = true, cdAnchor = "RIGHT", cdSize = 26, cdPerRow = 5, cdMax = 10, cdSpacing = 2,
            cdOnlyActive = false, cdText = true, cdDesaturate = true, cdGlow = true, cdShowSelf = true,
            cdArenaTrinket = true,
            cdCategories = { interrupt = true, external = true, defensive = true, raid = false, cc = true,
                             utility = true, offensive = true, racial = true, pvp = true },
            arenaTargets = true, targetHighlight = true, focusHighlight = true, aggro = false,
            maxDebuffs = 4, debuffSize = 20, dispelHighlight = true, dispelIndicators = true,
            highlightAllTypes = true, hideTrivialDebuffs = true, priorityDebuffs = false, dispelSound = false,
            maxBuffs = 4, buffSize = 16, onlyMyBuffs = false, buffMaxDuration = 60,
            indicators = { enabled = true, size = 7, showTimer = true, timerThreshold = 5, showStacks = true, mine = true },
            reminders = { enabled = false },
            rangeCheck = "SPELL", rangeAlpha = 0.45,
            resIncoming = false, afkText = false, tooltips = "OOC", oocAlpha = 1,
            raidMode = "PARTY",
        },
    },
    {
        key = "PvE - Raid",
        description = "10 / 25-man raids: compact raid blocks per group, health deficit, priority debuffs, dispel sound, main tank frames, indicators and buff reminders.",
        groups = { raid10 = true, raid25 = true, raid40 = true },
        overrides = {
            raidMode = "RAID", raidLayout = "GROUPS", raidOrientation = "VERTICAL",
            raidGroupsPerLine = 8, raidMaxGroups = 8, raidSort = "INDEX", raidGroupBy = "GROUP",
            raidWidth = 82, raidHeight = 40, raidSpacing = 2, raidGroupSpacing = 6, raidScale = 1,
            raidShowLabels = false, raidPets = false, mtFrames = true,
            raidPowerBar = "HEALERS", raidFontSize = 10, raidHealthText = "LOST",
            raidCastbar = false, raidCooldowns = false,
            raidMaxDebuffs = 3, raidDebuffSize = 16, raidMaxBuffs = 2, raidBuffSize = 12,
            sortMode = "ROLE", playerPosition = "FIRST",
            healthText = "NONE", powerBar = "HEALERS", healthColor = "CLASS", lowHealthHighlight = true, lowHealthPercent = 30,
            castbar = true, castbarHeight = 8, castbarTimer = false,
            cooldowns = true, cdAnchor = "RIGHT", cdSize = 22, cdPerRow = 4, cdMax = 8,
            cdCategories = { interrupt = true, external = true, defensive = true, raid = true, cc = false,
                             utility = true, offensive = false, racial = false, pvp = false },
            cdArenaTrinket = false,
            maxDebuffs = 3, debuffSize = 17, dispelHighlight = true, dispelIndicators = true,
            highlightAllTypes = false, hideTrivialDebuffs = true, priorityDebuffs = true, prioritySize = 24,
            dispelSound = true, dispelSoundFile = "RaidWarning",
            maxBuffs = 3, buffSize = 14, onlyMyBuffs = true, buffMaxDuration = 300,
            indicators = { enabled = true, size = 7, showTimer = true, timerThreshold = 5, showStacks = true, mine = true },
            reminders = { enabled = true, hideInCombat = true },
            rangeCheck = "SPELL", rangeAlpha = 0.35,
            resIncoming = true, afkText = true, aggro = true, tooltips = "OOC", oocAlpha = 1,
            arenaTargets = false,
        },
    },
}

function ns:PresetByKey(key)
    for _, p in ipairs(self.Presets) do
        if p.key == key then return p end
    end
    return nil
end

local function ApplyOverrides(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" and #v == 0 then
            ApplyOverrides(dst[k], v)
        else
            dst[k] = ns.DeepCopy(v)
        end
    end
end

-- settings that are personal rather than part of a preset: positions, solo frame, locking
local PERSONAL = { "point", "raidPoint", "mtPoint", "scale", "raidScale", "showSolo", "locked", "hideBlizzard", "texture", "font" }

local function CopyPersonal(dst, base)
    if not base then return end
    for _, k in ipairs(PERSONAL) do
        if base[k] ~= nil then dst[k] = ns.DeepCopy(base[k]) end
    end
end

-- Builds a fresh profile table from a preset (defaults + overrides + personal settings of `base`)
function ns:BuildPresetProfile(key, base)
    local preset = self:PresetByKey(key)
    local p = self.PrepareProfile({})
    if preset then ApplyOverrides(p, preset.overrides) end
    CopyPersonal(p, base or self.db)
    return p
end

-- Creates (or re-creates under a free name) a profile from a preset; returns the profile name
function ns:CreatePresetProfile(key, name)
    local preset = self:PresetByKey(key)
    if not preset then return nil, "Unknown preset." end
    name = self.Trim(name or "")
    if name == "" then name = preset.key end
    local base, n = name, 1
    while self:ProfileExists(name) do
        n = n + 1
        name = base .. " " .. n
    end
    self.global.profiles[name] = self:BuildPresetProfile(key, self.db)
    return name
end

-- First start of 2.0: create both presets and map them to arena / raids
function ns:EnsurePresets()
    local g = self.global
    local base = g.profiles["Default"] or g.profiles[next(g.profiles)]
    -- one-time repair for profiles created by 2.0.1: take over positions / solo setting,
    -- and undo the automatic switch that was stored as the manual choice
    if g.presetsCreated and not g.presetsFixed then
        g.presetsFixed = true
        for _, preset in ipairs(self.Presets) do
            local p = g.profiles[preset.key]
            if p and base and p ~= base then CopyPersonal(p, base) end
        end
        for key, name in pairs(g.profileKeys) do
            if self:PresetByKey(name) and base then
                for pname, prof in pairs(g.profiles) do
                    if prof == base then g.profileKeys[key] = pname end
                end
            end
        end
        -- solo / party now mean "my own profile" unless mapped on purpose later
        if g.autoProfiles.solo == "PvP - Arena" then g.autoProfiles.solo = "" end
    end
    if g.presetsCreated then return end
    g.presetsCreated = true
    g.presetsFixed = true
    local created = {}
    for _, preset in ipairs(self.Presets) do
        if not self:ProfileExists(preset.key) then
            g.profiles[preset.key] = self:BuildPresetProfile(preset.key, base)
            created[#created + 1] = preset.key
            for gtype in pairs(preset.groups) do
                if not g.autoProfiles[gtype] or g.autoProfiles[gtype] == "" then
                    g.autoProfiles[gtype] = preset.key
                end
            end
        end
    end
    if #created > 0 then
        g.autoProfiles.enabled = true
        self.presetNotice = created
    end
end
