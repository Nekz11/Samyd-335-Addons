-- RetailPartyFrames - Core
-- Retail-style party and raid frames for WotLK 3.3.5a (Warmane)

local ADDON, ns = ...
_G.RetailPartyFrames = ns

ns.name = ADDON
ns.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "2.0.0"
ns.DB_VERSION = 2

------------------------------------------------------------------------
-- Profile defaults (everything the user can change per profile)
------------------------------------------------------------------------
ns.defaults = {
    -- party layout
    locked = true,
    point = { "TOPLEFT", "TOPLEFT", 40, -220 },
    scale = 1,
    width = 112,
    height = 58,
    spacing = 3,
    orientation = "VERTICAL",   -- VERTICAL / HORIZONTAL
    sortMode = "ROLE",          -- GROUP / ROLE / CLASS / NAME
    playerPosition = "FIRST",   -- FIRST / LAST / SORTED
    showPlayer = true,
    showSolo = false,
    hideBlizzard = true,
    partyPets = false,
    petWidth = 112,
    petHeight = 22,
    petMaxDebuffs = 1,

    -- raid layout
    raidMode = "RAID",          -- RAID (raid frames) / PARTY (own group as party frames) / BOTH
    raidLayout = "GROUPS",      -- GROUPS (one block per group) / COMBINED (one sorted block)
    raidPoint = { "TOPLEFT", "TOPLEFT", 20, -300 },
    raidScale = 1,
    raidWidth = 72,
    raidHeight = 36,
    raidSpacing = 2,
    raidGroupSpacing = 8,
    raidOrientation = "VERTICAL",   -- units inside a group grow VERTICAL / HORIZONTAL
    raidGroupsPerLine = 8,          -- groups per row (vertical units) or per column (horizontal units)
    raidMaxGroups = 8,
    raidSort = "INDEX",             -- INDEX / NAME
    raidGroupBy = "GROUP",          -- COMBINED layout: GROUP / CLASS / ROLE / NONE
    raidShowLabels = false,
    raidPets = false,
    raidPowerBar = "NONE",
    raidFontSize = 10,
    raidCastbar = false,
    raidCooldowns = false,
    raidMaxDebuffs = 2,
    raidDebuffSize = 14,
    raidMaxBuffs = 2,
    raidBuffSize = 12,
    raidHealthText = "NONE",
    mtFrames = false,
    mtPoint = { "TOPLEFT", "TOPLEFT", 20, -120 },

    -- look
    texture = "Blizzard",
    font = "Friz Quadrata",
    fontSize = 11,
    fontOutline = "NONE",       -- NONE / OUTLINE
    statusTextSize = 10,
    classColors = true,
    healthColor = "CLASS",      -- CLASS / GRADIENT / CUSTOM
    healthCustom = { 0.1, 0.8, 0.1 },
    lowHealthPercent = 30,
    lowHealthHighlight = true,
    nameClassColor = false,
    nameLength = 12,
    showLevel = false,
    showBorder = true,
    borderColor = { 0, 0, 0 },
    healthText = "NONE",        -- NONE / HEALTH / LOST / PERCENT
    powerBar = "HEALERS",       -- ALL / HEALERS / MANA / NONE
    powerHeight = 5,
    aggro = true,
    roleIcon = true,
    leaderIcon = true,
    raidIcon = true,
    readyCheck = true,
    targetHighlight = true,
    focusHighlight = true,
    rangeAlpha = 0.4,
    rangeCheck = "UNIT",        -- UNIT (UnitInRange) / SPELL (IsSpellInRange with rangeSpell)
    rangeSpell = "",
    healPrediction = true,
    bgAlpha = 0.85,
    frameAlpha = 1,
    oocAlpha = 1,               -- alpha out of combat (1 = no fading)
    resIncoming = true,
    afkText = true,
    vehicleSwap = true,
    arenaTargets = true,
    bgFlags = true,
    tooltips = "ALWAYS",        -- ALWAYS / OOC / NEVER

    -- auras
    maxDebuffs = 3,
    debuffSize = 17,
    onlyDispellable = false,
    hideTrivialDebuffs = true,
    dispelHighlight = true,
    dispelIndicators = true,
    highlightAllTypes = false,
    dispelSound = false,
    dispelSoundFile = "RaidWarning",
    priorityDebuffs = true,
    prioritySize = 22,
    debuffBlacklist = {},       -- [spellId] = true
    debuffWhitelist = {},       -- [spellId] = true  (always shown, even when trivial/filtered)
    maxBuffs = 3,
    buffSize = 15,
    onlyMyBuffs = true,
    buffMaxDuration = 300,
    buffWhitelistOnly = false,
    buffWhitelist = {},
    auraTooltips = false,

    -- indicators (own HoTs / shields in the frame corners)
    indicators = {
        enabled = true,
        size = 7,
        showTimer = true,
        timerThreshold = 5,
        showStacks = true,
        mine = true,
        slots = nil,            -- nil = class defaults from SpellData (filled on load)
    },

    -- missing buff reminders
    reminders = {
        enabled = true,
        size = 14,
        position = "BOTTOMRIGHT", -- BOTTOMRIGHT / TOPRIGHT / CENTER
        alpha = 0.85,
        hideInCombat = true,
    },

    -- cast bars
    castbar = true,
    castbarHeight = 9,
    castbarIcon = true,
    castbarText = true,
    castbarTimer = false,

    -- party cooldowns
    cooldowns = true,
    cdAnchor = "RIGHT",         -- RIGHT / LEFT / BOTTOM / TOP
    cdSize = 22,
    cdSpacing = 2,
    cdPerRow = 4,
    cdMax = 8,
    cdOnlyActive = false,
    cdText = true,
    cdDesaturate = true,
    cdGlow = true,
    cdShowSelf = true,
    cdLearn = true,
    cdTooltips = true,
    cdInspect = true,
    cdArenaTrinket = true,      -- in arena: PvP trinket first and larger
    cdHidden = {},              -- [spellId] = true
    customSpells = {},          -- { id=, cd=, class=, cat= }
    cdCategories = {
        interrupt = true,
        external = true,
        defensive = true,
        raid = true,
        cc = false,
        utility = true,
        offensive = false,
        racial = false,
        pvp = false,
    },

    -- click casting
    clickCast = {
        enabled = true,
        respectClique = true,
        bindings = {
            { button = 1, mod = "", type = "target" },
            { button = 2, mod = "", type = "menu" },
        },
    },

    -- announcements (off by default)
    announce = {
        cooldowns = false,
        dispels = false,
        channel = "AUTO",       -- AUTO (raid/party) / PARTY / RAID / SAY / SELF
        categories = { external = true, raid = true, interrupt = false, defensive = false },
    },
}

ns.globalDefaults = {
    version = 2,
    profiles = {},
    profileKeys = {},
    autoProfiles = { enabled = false, solo = "", party = "", raid10 = "", raid25 = "", raid40 = "", arena = "", bg = "" },
    minimap = { show = true, angle = 220 },
}

function ns.DeepCopy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = ns.DeepCopy(x) end
    return t
end

-- Fills missing keys from the defaults. Dictionary tables are merged recursively; list tables
-- (click bindings, colors, anchors) are only copied when missing, so a list the user emptied stays empty.
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = ns.DeepCopy(v)
            elseif #v == 0 then
                CopyDefaults(v, dst[k])
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end
ns.CopyDefaults = CopyDefaults

------------------------------------------------------------------------
-- Media (built-in + optional LibSharedMedia)
------------------------------------------------------------------------
ns.media = {
    statusbar = {
        ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
        ["Flat"] = "Interface\\Buttons\\WHITE8X8",
        ["Smooth"] = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
        ["Raid"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    },
    font = {
        ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
        ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
        ["Morpheus"] = "Fonts\\MORPHEUS.ttf",
        ["Skurri"] = "Fonts\\skurri.ttf",
    },
    sound = {
        ["RaidWarning"] = "Sound\\Interface\\RaidWarning.wav",
        ["Ready Check"] = "Sound\\Interface\\ReadyCheck.wav",
        ["Alarm Clock"] = "Sound\\Interface\\AlarmClockWarning3.wav",
        ["Auction Open"] = "Sound\\Interface\\AuctionWindowOpen.wav",
        ["Bell"] = "Sound\\Doodad\\BellTollNightElf.wav",
        ["Whisper"] = "Sound\\Interface\\iTellMessage.wav",
    },
}

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function ns:Fetch(kind, name)
    local builtin = self.media[kind]
    if builtin[name] then return builtin[name] end
    local lsm = LSM()
    if lsm then
        local path = lsm:Fetch(kind, name, true)
        if path then return path end
    end
    if kind == "font" then return builtin["Friz Quadrata"] end
    if kind == "sound" then return builtin["RaidWarning"] end
    return builtin["Blizzard"]
end

function ns:MediaList(kind)
    local seen, list = {}, {}
    for name in pairs(self.media[kind]) do
        seen[name] = true
        list[#list + 1] = name
    end
    local lsm = LSM()
    if lsm then
        for _, name in ipairs(lsm:List(kind)) do
            if not seen[name] then
                seen[name] = true
                list[#list + 1] = name
            end
        end
    end
    table.sort(list)
    return list
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
ns.handlers = {}

function ns:On(event, fn)
    local list = self.handlers[event]
    if not list then
        -- pcall: never die on an event that does not exist in this client build
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return end
        list = {}
        self.handlers[event] = list
    end
    list[#list + 1] = fn
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = ns.handlers[event]
    if not list then return end
    for i = 1, #list do
        list[i](event, ...)
    end
end)

-- lightweight internal messages between modules
ns.callbacks = {}
function ns:RegisterCallback(msg, fn)
    self.callbacks[msg] = self.callbacks[msg] or {}
    table.insert(self.callbacks[msg], fn)
end
function ns:Fire(msg, ...)
    local list = self.callbacks[msg]
    if not list then return end
    for i = 1, #list do list[i](...) end
end

------------------------------------------------------------------------
-- Combat queue (secure frame changes only out of combat)
------------------------------------------------------------------------
ns.combatQueue = {}

function ns:AfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
        return true
    end
    self.combatQueue[key] = fn
    return false
end

ns:On("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(ns.combatQueue) do
        ns.combatQueue[key] = nil
        fn()
    end
end)

------------------------------------------------------------------------
-- Tiny timer
------------------------------------------------------------------------
local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self)
    local now = GetTime()
    for i = #timers, 1, -1 do
        local t = timers[i]
        if t and now >= t.at then
            table.remove(timers, i)
            t.fn()
        end
    end
    if #timers == 0 then self:Hide() end
end)

function ns:After(delay, fn)
    timers[#timers + 1] = { at = GetTime() + delay, fn = fn }
    timerFrame:Show()
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff3fa9ffRetailPartyFrames|r: " .. tostring(msg))
end

function ns.ShortValue(v)
    if v >= 1e6 then
        return string.format("%.1fm", v / 1e6)
    elseif v >= 1e4 then
        return string.format("%.0fk", v / 1e3)
    elseif v >= 1e3 then
        return string.format("%.1fk", v / 1e3)
    end
    return tostring(v)
end

function ns.ClassColor(class)
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if c then return c.r, c.g, c.b end
    return 0.5, 0.5, 0.5
end

function ns.PlayerKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or ""
    return name .. " - " .. realm
end

function ns.Trim(s)
    return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
ns.inits = {}
function ns:RegisterInit(fn, name)
    self.inits[#self.inits + 1] = { fn = fn, name = name or ("module " .. (#self.inits + 1)) }
end

function ns:ReportInitErrors()
    if not self.initErrors or #self.initErrors == 0 then return false end
    self:Print("|cffff4040Errors during startup|r - please report these:")
    for _, e in ipairs(self.initErrors) do
        DEFAULT_CHAT_FRAME:AddMessage("  |cffff8080" .. e .. "|r")
    end
    return true
end

ns:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    ns:LoadDatabase() -- Profiles.lua: migration, profile selection, ns.db / ns.global
end)

local function RunInits()
    ns.initErrors = {}
    for i = 1, #ns.inits do
        local ok, err = pcall(ns.inits[i].fn)
        if not ok then
            ns.initErrors[#ns.initErrors + 1] = ns.inits[i].name .. ": " .. tostring(err)
        end
    end
    local ok, err = pcall(ns.UpdateGroupType, ns, true)
    if not ok then ns.initErrors[#ns.initErrors + 1] = "group: " .. tostring(err) end
    ns.initialized = true
    ns:Print("v" .. ns.version .. " loaded. Type |cffffff00/rpf|r for options.")
    if ns.presetNotice then
        ns:Print("Preset profiles created: |cffffffff" .. table.concat(ns.presetNotice, "|r, |cffffffff") ..
            "|r. They switch on automatically in arenas and raids (Profiles page > Automatic profiles).")
        ns.presetNotice = nil
    end
    ns:ReportInitErrors()
end

ns:On("PLAYER_LOGIN", function()
    if not ns.db then ns:LoadDatabase() end
    ns:RebuildSpellIndex() -- now with the user's custom spells
    if InCombatLockdown() then
        -- /reload in combat: secure frames cannot be set up now, do it right after combat
        ns:Print("Loaded during combat - the frames will appear when combat ends.")
        ns:AfterCombat("init", RunInits)
    else
        RunInits()
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_RETAILPARTYFRAMES1 = "/rpf"
SLASH_RETAILPARTYFRAMES2 = "/retailpartyframes"
SlashCmdList["RETAILPARTYFRAMES"] = function(msg)
    msg = ns.Trim(msg)
    local cmd, rest = string.match(msg, "^(%S+)%s*(.-)$")
    cmd = string.lower(cmd or "")
    if cmd == "lock" or cmd == "unlock" or cmd == "move" then
        ns:ToggleLock()
    elseif cmd == "test" then
        ns:CycleTestMode(rest ~= "" and rest or nil)
    elseif cmd == "reset" then
        ns:ResetPosition()
    elseif cmd == "inspect" then
        ns:ForceInspect()
    elseif cmd == "debug" then
        ns:Debug()
    elseif cmd == "profile" then
        if rest == "" then
            ns:Print("Active profile: |cffffffff" .. ns:ActiveProfileName() .. "|r. Profiles: " .. table.concat(ns:ProfileNames(), ", "))
        else
            ns:SetProfile(rest, true)
        end
    elseif cmd == "export" then
        ns:ShowExport()
    elseif cmd == "minimap" then
        ns:ToggleMinimapButton()
    elseif cmd == "help" then
        ns:Print("/rpf - options | move - unlock/lock | test [party|raid] - preview | reset - position")
        ns:Print("/rpf profile [name] | export | inspect - re-read talents | minimap | debug")
    else
        ns:OpenOptions()
    end
end
