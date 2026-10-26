-- BetterFrames335 - Core.lua
-- Original implementation for WoW 3.3.5a (Interface 30300).
-- Inspired by the feature set of BetterBlizzFrames by Bodify; no code from it is used.

BBF335 = BBF335 or {}
local BBF = BBF335

BBF.ADDON   = "BetterFrames335"
BBF.version = "2.1.4"
BBF.modules = {}

-- Invisible parent used to hide secure frames without touching them in combat.
BBF.hider = CreateFrame("Frame", "BBF335Hider", UIParent)
BBF.hider:Hide()

-- Built-in textures / fonts selectable in the options
BBF.textures = {
    { key = "default", name = "Blizzard",      path = "Interface\\TargetingFrame\\UI-StatusBar" },
    { key = "flat",    name = "Flat",          path = "Interface\\Buttons\\WHITE8X8" },
    { key = "smooth",  name = "Raid (smooth)", path = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    { key = "skill",   name = "Skill bar",     path = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    { key = "tooltip", name = "Tooltip",       path = "Interface\\Tooltips\\UI-Tooltip-Background" },
    { key = "custom",  name = "Custom path",   path = nil },
}
BBF.fonts = {
    { key = "default",  name = "Friz Quadrata (default)", path = "Fonts\\FRIZQT__.TTF" },
    { key = "arial",    name = "Arial Narrow",            path = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", name = "Morpheus",                path = "Fonts\\MORPHEUS.ttf" },
    { key = "skurri",   name = "Skurri",                  path = "Fonts\\skurri.ttf" },
    { key = "custom",   name = "Custom path",             path = nil },
}

function BBF:TexturePath(key, custom)
    if key == "custom" and custom and custom ~= "" then return custom end
    for _, t in ipairs(self.textures) do if t.key == key and t.path then return t.path end end
    return self.textures[1].path
end

function BBF:FontPath(key, custom)
    if key == "custom" and custom and custom ~= "" then return custom end
    for _, f in ipairs(self.fonts) do if f.key == key and f.path then return f.path end end
    return self.fonts[1].path
end

local defaults = {
    ------------------------------------------------------------ unit frames
    classColorHealth     = true,
    classColorPlayer     = true,
    reactionColorNPC     = false,
    classColorNames      = false,
    classColorNameBG     = true,
    classColorLevel      = false,
    colorPetAfterOwner   = true,
    colorShamansBlue     = false,
    hideRealm            = true,
    arenaNumbers         = false,
    arenaNumbersOnTarget = false,
    classPortraits       = false,
    classPortraitsIgnoreSelf = false,
    playerElite          = false,
    miniFocus            = false,
    clickthroughPlayer   = false,
    clickthroughTarget   = false,
    clickthroughFocus    = false,
    -- per frame scale
    scalePlayer   = 1, scaleTarget = 1, scaleFocus = 1, scalePet = 1,
    scaleToT      = 1, scaleFocusToT = 1, scaleParty = 1,
    -- ToT offsets
    totOffsetX = 0, totOffsetY = 0, focusToTOffsetX = 0, focusToTOffsetY = 0,
    -- hide parts of unit frames
    hidePlayerMana = false, hideTargetMana = false, hideFocusMana = false,
    hidePlayerName = false, hideTargetName = false, hideFocusName = false,
    hidePetName    = false, hideToTName    = false, hideFocusToTName = false,
    hideTargetToT  = false, hideFocusToT   = false,
    hideLevelText  = false, hideLevelTextAlways = false,
    hideToTDebuffs = false,
    -- textures & fonts
    barTexture        = "default",
    barTextureCustom  = "",
    textureHealth     = true,
    textureMana       = true,
    textureCastbar    = true,
    textureXP         = false,
    fontEnabled       = false,
    font              = "default",
    fontCustom        = "",
    fontOutline       = "NONE",
    fontSizeName      = 10,
    fontSizeValue     = 10,
    -- status text
    textFormat        = "default",   -- default | short | percent | current | currentPercent | both
    -- smooth bars
    smoothBars        = false,
    smoothSpeed       = 8,
    ------------------------------------------------------------ dark mode
    darkMode        = false,
    darkValue       = 0.3,
    darkModeBars    = false,
    darkModeMinimap = false,
    ------------------------------------------------------------ indicators
    combatIndicator  = true,
    combatShowIn     = true,
    combatShowOut    = false,
    combatParty      = false,
    combatEnemyOnly  = false,
    combatPlayersOnly = false,
    combatArenaOnly  = false,
    absorbIndicator  = true,
    absorbPlayer     = false,
    absorbTimer      = true,
    absorbAmount     = true,     -- estimated number (base value - absorbed damage seen)
    indSize          = 20,
    indX             = 0,
    indY             = 0,
    racialIndicator  = false,
    racialTarget     = true,
    racialFocus      = true,
    racialHuman      = true,
    racialNelf       = true,
    racialOrc        = true,
    racialUndead     = true,
    racialSize       = 18,
    stealthIndicator = false,
    ------------------------------------------------------------ auras (target / focus)
    aurasEnabled       = true,
    targetBuffs        = true,
    targetDebuffs      = true,
    focusBuffs         = true,
    focusDebuffs       = true,
    maxBuffs           = 32,
    maxDebuffs         = 16,
    debuffsFirst       = true,
    onlyMyDebuffs      = false,
    onlyMyBuffs        = false,
    hidePermanentBuffs = false,
    underOneMinBuffs   = false,
    whitelistMode      = false,
    purgeHighlight     = true,
    purgeSize          = 0,       -- 0 = use normal size
    importantGlow      = true,
    expireGlow         = true,
    expireGlowPct      = 30,
    dotBorder          = false,
    ownAuraSize        = 23,
    otherAuraSize      = 18,
    aurasPerRow        = 6,
    auraGapX           = 3,
    auraGapY           = 3,
    auraOffsetX        = 0,
    auraOffsetY        = 0,
    sortImportantFirst = true,
    sortOwnFirst       = false,
    sortPurgeFirst     = false,
    spellIdTooltip     = false,
    clickthroughAuras  = false,
    -- player buff frame
    playerBuffFilter       = false,
    playerBuffWhitelist    = false,
    playerBuffUnderOneMin  = false,
    playerDebuffFilter     = false,
    playerAuraLayout       = false,
    playerAuraSize         = 30,
    playerAuraPerRow       = 8,
    playerAuraGapX         = 5,
    playerAuraGapY         = 8,
    playerAuraCooldown     = false,
    playerAuraHideDuration = false,
    playerAuraStackSize    = 12,
    blacklist = {},
    whitelist = {},
    important = {},
    ------------------------------------------------------------ castbars
    partyCastbars   = true,
    partyCastAttach = true,
    partyCastSelf   = false,
    partyCastIcon   = true,
    partyCastTimer  = true,
    partyCastWidth  = 110,
    partyCastHeight = 12,
    partyCastX      = 22,
    partyCastY      = -14,
    petCastbar      = false,
    petCastWidth    = 110,
    petCastHeight   = 12,
    petCastX        = 10,
    petCastY        = 0,
    castTimers      = true,
    targetCastScale = 1,
    focusCastScale  = 1,
    -- default castbars keep Blizzard's look; size via scale, target/focus optionally detached
    playerCastScale = 1,
    cbTargetDetach  = false,
    cbFocusDetach   = false,
    -- interrupt helpers
    interruptHighlight      = false,
    interruptHighlightStart = 0.3,
    interruptHighlightEnd   = 0.3,
    interruptHighlightFocus = true,
    interruptIcon           = false,
    interruptIconTarget     = true,
    interruptIconFocus      = true,
    interruptIconActiveOnly = false,
    interruptIconSize       = 22,
    interruptIconX          = 0,
    interruptIconY          = 0,
    interruptRecolor        = false,
    ------------------------------------------------------------ hide elements
    hideGryphons       = false,
    hideHitIndicators  = false,
    hidePvPIcons       = false,
    hideRestGlow       = false,
    hideCombatGlow     = false,
    hideLeaderIcons    = false,
    hideGroupIndicator = false,
    hideMinimapZoom    = false,
    hideWorldMapButton = false,
    hideMinimapToggle  = false,
    hideClock          = false,
    hideChatButtons    = false,
    hideBagButtons     = false,
    hideArenaFrames    = false,
    hideMacroText      = false,
    hideHotkeyText     = false,
    hideUIErrors       = false,
    hideMinimapArena   = false,
    hideTrackerArena   = false,
    hidePartyArena     = false,
    hideBossParty      = false,
    hideBossRaid       = false,
    hidePetFrame       = false,
    hideStanceBar      = false,
    hidePetActionBar   = false,
    ------------------------------------------------------------ misc
    chatFilterEmotes   = false,
    chatFilterSystem   = false,
    chatFilterTalents  = false,
    chatFilterArenaNpc = false,
    queueTimer         = false,
    queueTimerSound    = true,
    minimapButton      = true,
    minimapAngle       = 200,
    -- frame positions (Move.lua): key -> { point, relPoint, x, y } relative to UIParent
    positions = {},
}
BBF.defaults = defaults

-- Seeded once into the "important" list. IDs are converted to the client's
-- localized spell names, so every rank of a spell matches.
local importantSeed = {
    -- immunities / big defensives
    642, 45438, 1022, 1044, 6940, 33206, 47585, 31224, 26669, 19263, 34471,
    46924, 23920, 871, 48707, 48792, 49039, 22812, 61336, 29166, 8178,
    -- offensive cooldowns
    12042, 12472, 31884, 2825, 32182, 10060, 13750, 51690, 1719,
    -- crowd control
    118, 51514, 33786, 6770, 2094, 5782, 6358, 5484, 8122, 605, 853, 20066,
    1833, 408, 1776, 3355, 19386, 19503, 64044, 47476, 15487, 18469, 34490,
    1330, 44572, 31661, 30283, 6789, 49203, 47481, 339, 122, 33395, 12809, 46968,
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function CopyTable(src)
    local t = {}
    for k, v in pairs(src) do
        if type(v) == "table" then t[k] = CopyTable(v) else t[k] = v end
    end
    return t
end
BBF.CopyTable = CopyTable

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
function BBF:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBetterFrames:|r " .. tostring(msg))
end

local SHAMAN_BLUE = { r = 0, g = 0.44, b = 0.87 }
function BBF:ClassColor(unit, class)
    if not class then
        local _
        _, class = UnitClass(unit)
    end
    if class == "SHAMAN" and self.db and self.db.colorShamansBlue then
        return SHAMAN_BLUE.r, SHAMAN_BLUE.g, SHAMAN_BLUE.b
    end
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local c = class and colors[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

function BBF:InList(listName, name, spellId)
    local list = self.db and self.db[listName]
    if not list then return false end
    if name and list[strlower(name)] then return true end
    if spellId and list[spellId] then return true end
    return false
end

-- Returns key, display text. Spell IDs are turned into names (all ranks match).
function BBF:ParseEntry(text)
    text = strtrim(text or "")
    if text == "" then return nil end
    local id = tonumber(text)
    if id then
        local name = GetSpellInfo(id)
        if name then return strlower(name), name end
        return id, tostring(id)
    end
    return strlower(text), text
end

function BBF:AddToList(listName, text)
    local key, display = self:ParseEntry(text)
    if not key or not self.db[listName] then return end
    self.db[listName][key] = display
    return display
end

function BBF:RemoveFromList(listName, text)
    local key, display = self:ParseEntry(text)
    if not key or not self.db[listName] then return end
    if self.db[listName][key] then
        local stored = self.db[listName][key]
        self.db[listName][key] = nil
        return stored or display
    end
end

-- short number format: 1234 -> 1.2k, 1234567 -> 1.23m
function BBF:ShortNumber(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return format("%.2fm", n / 1000000) end
    if n >= 10000 then return format("%.0fk", n / 1000) end
    if n >= 1000 then return format("%.1fk", n / 1000) end
    return tostring(math.floor(n + 0.5))
end

function BBF:InArena()
    local _, instanceType = IsInInstance()
    return instanceType == "arena"
end

----------------------------------------------------------------------
-- modules & events
----------------------------------------------------------------------
function BBF:NewModule(name)
    local m = { name = name }
    tinsert(self.modules, m)
    return m
end

local function SafeCall(m, method, ...)
    local fn = m[method]
    if not fn then return end
    local ok, err = pcall(fn, m, ...)
    if not ok then BBF:Print("|cffff5555error in " .. m.name .. "." .. method .. ":|r " .. tostring(err)) end
end

function BBF:ApplyAll()
    if not self.db then return end
    for _, m in ipairs(self.modules) do SafeCall(m, "Apply") end
end

-- Debounced ApplyAll for sliders: many OnValueChanged calls while dragging -> one apply.
local applyTimer = CreateFrame("Frame")
applyTimer:Hide()
local applyDelay = 0
applyTimer:SetScript("OnUpdate", function(self, elapsed)
    applyDelay = applyDelay - elapsed
    if applyDelay <= 0 then
        self:Hide()
        BBF:ApplyAll()
    end
end)
function BBF:ApplySoon(delay)
    applyDelay = delay or 0.15
    applyTimer:Show()
end

-- Wraps an OnUpdate / OnEvent handler: an error inside is reported once instead of being
-- thrown silently every frame (which is what makes a broken addon feel "laggy").
local reported = {}
function BBF:Guard(name, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            local key = name .. ":" .. tostring(err)
            if not reported[key] then
                reported[key] = true
                BBF:Print("|cffff5555error in " .. name .. ":|r " .. tostring(err))
            end
        end
    end
end

-- /bbf cpu : per-addon CPU usage (needs the scriptProfile cvar)
function BBF:PrintCPU()
    if GetCVar("scriptProfile") ~= "1" then
        BBF:Print("CPU profiling is off. Run:  /console scriptProfile 1  then /reload, play a bit, then /bbf cpu again. "
            .. "Turn it off afterwards with  /console scriptProfile 0  + /reload (profiling itself costs a little).")
        return
    end
    UpdateAddOnCPUUsage()
    local list = {}
    for i = 1, GetNumAddOns() do
        if IsAddOnLoaded(i) then
            local name = GetAddOnInfo(i)
            list[#list + 1] = { name = name, cpu = GetAddOnCPUUsage(i) }
        end
    end
    table.sort(list, function(a, b) return a.cpu > b.cpu end)
    BBF:Print("CPU time (ms) since login/reload, top 10 addons:")
    for i = 1, math.min(10, #list) do
        local l = list[i]
        local mark = (l.name == BBF.ADDON) and "  |cff00ccff<- this addon|r" or ""
        DEFAULT_CHAT_FRAME:AddMessage(format("  %6.0f  %s%s", l.cpu, l.name, mark))
    end
    ResetCPUUsage()
    BBF:Print("counters reset - run /bbf cpu again after a while to measure a fresh interval")
end

local ev = CreateFrame("Frame")
BBF.eventFrame = ev
local handlers = {}

function BBF:RegisterEvent(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        ev:RegisterEvent(event)
    end
    tinsert(handlers[event], fn)
end

ev:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do list[i](event, ...) end
end)

-- run protected-ish things only out of combat
local queue = {}
function BBF:RunOOC(key, fn)
    if InCombatLockdown() then
        queue[key] = fn
    else
        fn()
    end
end

BBF:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    for k, fn in pairs(queue) do
        queue[k] = nil
        fn()
    end
end)

----------------------------------------------------------------------
-- "only touch it if asked" helpers: other addons (RetailUI, party frame addons ...) style the
-- same frames, so we change alpha / scale only while our option is on, and put the default
-- back exactly once when the option is turned off again.
----------------------------------------------------------------------
function BBF:SetAlphaIf(f, hide, key)
    if not f then return end
    local flag = "bbfAlpha_" .. key
    if hide then
        f:SetAlpha(0)
        f[flag] = true
    elseif f[flag] then
        f:SetAlpha(1)
        f[flag] = nil
    end
end

function BBF:SetScaleIf(f, scale)
    if not f then return end
    if scale and scale ~= 1 then
        f:SetScale(scale)
        f.bbfScaled = true
    elseif f.bbfScaled then
        f:SetScale(1)
        f.bbfScaled = nil
    end
end

-- HookScript on a frame without an existing handler is not guaranteed on old clients:
-- chain manually and keep whatever handler is already there
function BBF:HookScriptSafe(frame, script, fn)
    if not frame or not frame.GetScript then return end
    local old = frame:GetScript(script)
    frame:SetScript(script, function(self, ...)
        if old then old(self, ...) end
        fn(self, ...)
    end)
end

-- remembers that a feature was active once so its "off" path can restore defaults
BBF.touched = {}
function BBF:Once(key, active)
    if active then self.touched[key] = true; return true end
    if self.touched[key] then self.touched[key] = nil; return true end
    return false
end

----------------------------------------------------------------------
-- "keep hidden" helper shared by Hide.lua / Frames.lua:
-- hooks obj:Show() once and re-hides it while any attached option is on
----------------------------------------------------------------------
local hideHooked = {}   -- obj -> set of db keys

function BBF:HideWanted(obj)
    local keys = hideHooked[obj]
    if not keys or not self.db then return false end
    for k in pairs(keys) do
        if self.db[k] then return true end
    end
    return false
end

local function CanTouch(obj)
    return not (obj.IsProtected and obj:IsProtected() and InCombatLockdown())
end

function BBF:AttachHide(obj, key)
    if type(obj) ~= "table" or not obj.Hide then return end
    local keys = hideHooked[obj]
    if not keys then
        keys = {}
        hideHooked[obj] = keys
        hooksecurefunc(obj, "Show", function(self)
            if BBF:HideWanted(self) and CanTouch(self) then self:Hide() end
        end)
    end
    keys[key] = true
    if not CanTouch(obj) then return end
    if self.db[key] then
        obj:Hide()
        obj.bbfHiddenBy = key
    elseif obj.bbfHiddenBy == key and not self:HideWanted(obj) then
        -- option switched off: show it again; Blizzard corrects the state on its next update
        obj.bbfHiddenBy = nil
        obj:Show()
    end
end

----------------------------------------------------------------------
-- presets: a tuned set of options layered over the current profile
-- (aura lists and frame positions are never touched)
----------------------------------------------------------------------
BBF.presets = {
    arena = {
        name = "PvP - Arena",
        desc = "Class colors & icons, Arena 1-3 names, all enemy debuffs with important/purge glows, "
            .. "party castbars, interrupt window + enemy kick cooldown, racial/stealth/absorb indicators, "
            .. "minimap & tracker hidden in arena, queue timer, arena NPC chat muted.",
        settings = {
            classColorHealth = true, classColorPlayer = true, classColorNames = true, classColorNameBG = true,
            colorPetAfterOwner = true, hideRealm = true, arenaNumbers = true, arenaNumbersOnTarget = true,
            classPortraits = true, classPortraitsIgnoreSelf = true, miniFocus = false,
            scaleTarget = 1.1, scaleFocus = 1.1, scalePlayer = 1.1,
            textFormat = "currentShort", smoothBars = true, hideLevelText = true,
            -- auras: see every CC / cooldown on enemies, filter the clutter on yourself
            aurasEnabled = true, targetBuffs = true, targetDebuffs = true, focusBuffs = true, focusDebuffs = true,
            onlyMyDebuffs = false, onlyMyBuffs = false, hidePermanentBuffs = true, underOneMinBuffs = false,
            whitelistMode = false, maxBuffs = 12, maxDebuffs = 10, debuffsFirst = true,
            importantGlow = true, purgeHighlight = true, expireGlow = true, dotBorder = false,
            sortImportantFirst = true, sortPurgeFirst = true, sortOwnFirst = false,
            ownAuraSize = 26, otherAuraSize = 19, aurasPerRow = 6,
            playerBuffFilter = true, playerBuffWhitelist = false, playerDebuffFilter = false,
            -- castbars & interrupts
            partyCastbars = true, partyCastIcon = true, partyCastTimer = true, castTimers = true,
            playerCastScale = 1.1, targetCastScale = 1.25, focusCastScale = 1.25,
            interruptHighlight = false,
            interruptIcon = true, interruptIconTarget = true, interruptIconFocus = true, interruptIconActiveOnly = false,
            interruptRecolor = false,
            -- indicators
            combatIndicator = true, combatShowIn = true, combatShowOut = false, combatEnemyOnly = true, combatArenaOnly = false,
            absorbIndicator = true, absorbPlayer = true, absorbTimer = true, absorbAmount = true,
            racialIndicator = true, racialTarget = true, racialFocus = true, stealthIndicator = true,
            -- hide / misc
            hideGryphons = true, hideMinimapArena = true, hideTrackerArena = true, hideUIErrors = false,
            chatFilterArenaNpc = true, chatFilterEmotes = true, queueTimer = true, queueTimerSound = true,
        },
    },
    raid = {
        name = "PvE - Raid",
        desc = "Class colors, bigger target frame with a wide castbar, only your own debuffs on bosses with "
            .. "refresh glow, short numbers, smooth bars, absorb on yourself, no PvP indicators, "
            .. "party castbars off, talent-spam chat filter.",
        settings = {
            classColorHealth = true, classColorPlayer = true, classColorNames = false, classColorNameBG = true,
            colorPetAfterOwner = true, hideRealm = true, arenaNumbers = false, arenaNumbersOnTarget = false,
            classPortraits = false, miniFocus = false,
            scaleTarget = 1.15, scaleFocus = 1, scalePlayer = 1.05,
            textFormat = "short", smoothBars = true, hideLevelText = true,
            -- auras: boss debuff tracking
            aurasEnabled = true, targetBuffs = true, targetDebuffs = true, focusBuffs = true, focusDebuffs = true,
            onlyMyDebuffs = true, onlyMyBuffs = false, hidePermanentBuffs = false, underOneMinBuffs = false,
            whitelistMode = false, maxBuffs = 16, maxDebuffs = 16, debuffsFirst = true,
            importantGlow = true, purgeHighlight = false, expireGlow = true, expireGlowPct = 30, dotBorder = true,
            sortImportantFirst = true, sortPurgeFirst = false, sortOwnFirst = true,
            ownAuraSize = 24, otherAuraSize = 16, aurasPerRow = 7,
            playerBuffFilter = false, playerDebuffFilter = false,
            -- castbars
            partyCastbars = false, castTimers = true,
            playerCastScale = 1.1, targetCastScale = 1.4, focusCastScale = 1,
            interruptHighlight = false, interruptIcon = false, interruptRecolor = false,
            -- indicators
            combatIndicator = false, absorbIndicator = true, absorbPlayer = true, absorbTimer = true, absorbAmount = true,
            racialIndicator = false, stealthIndicator = false,
            -- hide / misc
            hideGryphons = true, hideMinimapArena = false, hideTrackerArena = false, hidePartyArena = false,
            chatFilterArenaNpc = false, chatFilterEmotes = false, chatFilterTalents = true, queueTimer = false,
        },
    },
}

function BBF:ApplyPreset(key)
    local preset = self.presets[key]
    if not preset or not self.db then return false end
    for k, v in pairs(preset.settings) do self.db[k] = v end
    self:ApplyAll()
    self:Print("preset applied: " .. preset.name .. "  (aura lists & positions kept)")
    return true
end

----------------------------------------------------------------------
-- profiles
----------------------------------------------------------------------
function BBF:CharKey()
    local name, realm = UnitName("player"), GetRealmName()
    return (name or "?") .. " - " .. (realm or "?")
end

function BBF:ProfileNames()
    local t = {}
    for name in pairs(BetterFrames335DB.profiles) do t[#t + 1] = name end
    table.sort(t)
    return t
end

function BBF:CurrentProfile()
    return BetterFrames335DB.profileKeys[self:CharKey()] or "Default"
end

-- switching needs a reload: every module caches its db table at Init
function BBF:SetProfile(name, noReload)
    if not name or name == "" then return end
    local sv = BetterFrames335DB
    if not sv.profiles[name] then
        sv.profiles[name] = CopyTable(self.db)       -- new profile starts as a copy of the current one
        sv.profiles[name].seeded = true
    end
    sv.profileKeys[self:CharKey()] = name
    if not noReload then ReloadUI() end
end

function BBF:DeleteProfile(name)
    local sv = BetterFrames335DB
    if name == "Default" or not sv.profiles[name] then return false end
    sv.profiles[name] = nil
    for k, v in pairs(sv.profileKeys) do
        if v == name then sv.profileKeys[k] = "Default" end
    end
    if self:CurrentProfile() == "Default" and name ~= "Default" then
        -- nothing else to do
    end
    return true
end

function BBF:CopyProfileFrom(name)
    local src = BetterFrames335DB.profiles[name]
    if not src or src == self.db then return false end
    local cur = self:CurrentProfile()
    BetterFrames335DB.profiles[cur] = CopyTable(src)
    ReloadUI()
    return true
end

-- simple, dependency-free serializer (strings, numbers, booleans, nested tables)
local function Serialize(v, out)
    local t = type(v)
    if t == "table" then
        out[#out + 1] = "{"
        for k, val in pairs(v) do
            out[#out + 1] = "["
            Serialize(k, out)
            out[#out + 1] = "]="
            Serialize(val, out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    elseif t == "string" then
        out[#out + 1] = format("%q", v)
    elseif t == "number" or t == "boolean" then
        out[#out + 1] = tostring(v)
    else
        out[#out + 1] = "nil"
    end
end

function BBF:ExportProfile()
    local out = { "BBF1:" }
    Serialize(self.db, out)
    return table.concat(out)
end

function BBF:ImportProfile(str)
    str = strtrim(str or "")
    if str:sub(1, 5) ~= "BBF1:" then return false, "not a BetterFrames export string" end
    local body = str:sub(6)
    -- the chunk runs in an empty environment: it can only build tables, nothing else is reachable
    local fn, err = loadstring("return " .. body)
    if not fn then return false, err end
    setfenv(fn, {})
    local ok, data = pcall(fn)
    if not ok or type(data) ~= "table" then return false, "could not decode" end
    data.positions = data.positions or {}
    data.blacklist = data.blacklist or {}
    data.whitelist = data.whitelist or {}
    data.important = data.important or {}
    data.seeded = true
    CopyDefaults(defaults, data)
    BetterFrames335DB.profiles[self:CurrentProfile()] = data
    ReloadUI()
    return true
end

----------------------------------------------------------------------
-- load
----------------------------------------------------------------------
local function MigrateFlatDB(sv)
    -- v1.x stored the settings directly in the saved variable; move them into profiles.Default
    if sv.profiles then return end
    local old = {}
    for k, v in pairs(sv) do old[k] = v; sv[k] = nil end
    sv.profiles = { Default = old }
    sv.profileKeys = {}
end

local function MigrateProfile(p)
    -- v1 frameScale -> per frame scales
    if p.frameScale and p.frameScale ~= 1 then
        if p.scalePlayer == nil then p.scalePlayer = p.frameScale end
        if p.scaleTarget == nil then p.scaleTarget = p.frameScale end
    end
    p.frameScale = nil
end

BBF:RegisterEvent("ADDON_LOADED", function(_, addon)
    if addon == BBF.ADDON then
        BetterFrames335DB = BetterFrames335DB or {}
        local sv = BetterFrames335DB
        MigrateFlatDB(sv)
        sv.profiles = sv.profiles or {}
        sv.profileKeys = sv.profileKeys or {}
        local key = sv.profileKeys[BBF:CharKey()] or "Default"
        if not sv.profiles[key] then
            sv.profiles[key] = sv.profiles.Default and CopyTable(sv.profiles.Default) or {}
        end
        sv.profileKeys[BBF:CharKey()] = key
        BBF.db = sv.profiles[key]
        MigrateProfile(BBF.db)
        CopyDefaults(defaults, BBF.db)
        if not BBF.db.seeded then
            for _, id in ipairs(importantSeed) do
                local name = GetSpellInfo(id)
                if name then BBF.db.important[strlower(name)] = name end
            end
            BBF.db.seeded = true
        end
        for _, m in ipairs(BBF.modules) do SafeCall(m, "Init") end
    end
    if BBF.db then
        for _, m in ipairs(BBF.modules) do SafeCall(m, "OnAddonLoaded", addon) end
    end
end)

BBF:RegisterEvent("PLAYER_LOGIN", function()
    BBF:ApplyAll()
end)

BBF:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    BBF:ApplyAll()
end)

----------------------------------------------------------------------
-- slash commands
----------------------------------------------------------------------
-- Replaced by Options.lua (standalone window); this fallback only runs if that module failed to load.
function BBF:OpenOptions()
    if not self.optionsPanel then return end
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
end

local listAlias = {
    bl = "blacklist", blacklist = "blacklist",
    wl = "whitelist", whitelist = "whitelist",
    imp = "important", important = "important",
}

local function PrintHelp()
    BBF:Print("v" .. BBF.version .. " commands:")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf  - open options")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf move  - toggle frame move mode (drag boxes, right-click = reset)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf test  - toggle castbar test mode")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf bl|wl|imp add <name or spellID>  - add to blacklist / whitelist / important")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf bl|wl|imp del <name or spellID>  - remove from a list")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf bl|wl|imp list  - print a list")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf profile <name>  - switch / create profile (reloads)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf preset arena|raid  - apply the PvP-Arena or PvE-Raid preset")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf cpu  - show CPU usage per addon (needs /console scriptProfile 1)")
    DEFAULT_CHAT_FRAME:AddMessage("  /bbf reset  - reset all settings (reloads UI)")
end

SLASH_BBFTHREE1 = "/bbf"
SLASH_BBFTHREE2 = "/betterframes"
SlashCmdList["BBFTHREE"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = strlower(cmd or "")
    if cmd == "" then
        BBF:OpenOptions()
    elseif cmd == "test" then
        if BBF.ToggleCastTest then BBF:ToggleCastTest() end
    elseif cmd == "move" or cmd == "unlock" or cmd == "lock" then
        if BBF.ToggleMove then BBF:ToggleMove() end
    elseif cmd == "cpu" then
        BBF:PrintCPU()
    elseif cmd == "profile" then
        if rest ~= "" then BBF:SetProfile(rest) else BBF:Print("current profile: " .. BBF:CurrentProfile()) end
    elseif cmd == "preset" then
        if not BBF:ApplyPreset(strlower(rest)) then BBF:Print("presets: /bbf preset arena   or   /bbf preset raid") end
    elseif cmd == "reset" then
        BetterFrames335DB = nil
        ReloadUI()
    elseif listAlias[cmd] then
        local listName = listAlias[cmd]
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        sub = strlower(sub or "")
        if sub == "add" then
            local added = BBF:AddToList(listName, arg)
            if added then BBF:Print("added to " .. listName .. ": " .. added) end
        elseif sub == "del" or sub == "remove" then
            local removed = BBF:RemoveFromList(listName, arg)
            BBF:Print(removed and ("removed from " .. listName .. ": " .. removed) or "not found in " .. listName)
        else
            BBF:Print(listName .. ":")
            for _, v in pairs(BBF.db[listName]) do DEFAULT_CHAT_FRAME:AddMessage("  " .. tostring(v)) end
        end
        BBF:ApplyAll()
    else
        PrintHelp()
    end
end
