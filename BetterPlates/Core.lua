-- BetterPlates - Core
-- Grundgerüst: Einstellungen, Event-Verteiler, Hilfsfunktionen

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end

ns.ADDON = ADDON
ns.VERSION = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "1.0.0"
ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

-- Laufzeit-Caches (nicht gespeichert)
ns.classCache = {}   -- [Spielername] = "WARRIOR" ...
ns.guidByName = {}   -- [Spielername] = GUID
ns.guidTried = {}    -- [GUID] = Zeitpunkt der letzten Klassen-Abfrage
ns.healers = {}      -- [Spielername] = true
ns.instanceType = "none"

----------------------------------------------------------------
-- Standardwerte
----------------------------------------------------------------
ns.defaults = {
	-- Aussehen
	width = 110,
	height = 10,
	targetScale = 1.15,
	texture = 4,
	customTexture = "",      -- eigener Texturpfad (überschreibt texture)
	font = 1,
	customFont = "",         -- eigener Schriftpfad
	fontSize = 10,
	outline = true,
	fontShadow = true,
	borderStyle = 2,         -- 1 keiner, 2 dünn, 3 dick, 4 Glow
	bgStyle = 1,             -- 1 dunkel, 2 klassenfarbig abgedunkelt, 3 transparent
	bgAlpha = 0.85,
	healthText = 2,          -- 1 aus, 2 Prozent, 3 Wert, 4 Wert + Prozent, 5 Wert / Max, 6 fehlend
	healthDecimals = false,  -- Prozent mit einer Nachkommastelle
	healthTextPos = 1,       -- 1 Mitte, 2 links, 3 rechts
	healthFontSize = 9,
	healthTextOnlyTarget = false,
	healthGradient = false,  -- Balkenfarbe grün -> rot nach Lebenspunkten (nur NPCs)
	hideLevel = false,
	levelColor = true,       -- Level in Blizzard-Schwierigkeitsfarbe
	hideLevelMaxPlayers = true,
	eliteMark = true,        -- "+" / "R" hinter dem Level
	bossSkull = true,
	nameInBar = false,
	nameMaxLen = 0,          -- 0 = unbegrenzt
	abbrevNames = false,     -- "Lord Marrowgar" -> "L. Marrowgar"
	stripRealm = true,
	hideName = false,
	hideNameOnCast = false,
	raidIconSize = 18,
	raidIconPos = 1,         -- 1 rechts, 2 links, 3 oben, 4 aus
	targetStyle = 1,         -- 1 Rahmen, 2 Glow, 3 beides
	nonTargetAlpha = 1,      -- zusätzliche Abdunklung von Nicht-Zielen (1 = keine)
	mouseoverHighlight = true,
	hideNpcList = "",        -- NPC-Namen, deren Plaketten unsichtbar werden
	fadeNpcList = "",        -- NPC-Namen, deren Plaketten ausgeblendet (30 %) werden
	colorNpcList = "",       -- "Name:ff8800" -> eigene Balkenfarbe
	murlocMode = false,
	trivialMode = 1,         -- graue (triviale) NPCs: 1 normal, 2 abschwächen, 3 klein, 4 aus
	hideCritters = false,

	-- Element-Positionen (Offsets in Pixeln)
	nameX = 0, nameY = 0,
	healthX = 0, healthY = 0,
	classIconX = 0, classIconY = 0,
	aurasX = 0, aurasY = 0,
	drX = 0, drY = 0,
	castX = 0, castY = 0,
	raidX = 0, raidY = 0,
	totemX = 0, totemY = 0,
	partyX = 0, partyY = 0,
	targetedX = 0, targetedY = 0,

	-- Farben
	classColorEnemy = true,
	classColorFriendly = true,
	nameClassColor = false,
	threatColor = false,
	colorByAura = false,     -- Balkenfarbe nach CC-Kategorie (Stun rot, CC lila, ...)
	colors = {
		hostile = { 0.9, 0.1, 0.1 },
		neutral = { 1, 0.85, 0.1 },
		friendlyNpc = { 0.2, 0.8, 0.2 },
		friendlyPlayer = { 0.2, 0.6, 1 },
		enemyPlayer = { 0.9, 0.1, 0.1 },
		target = { 1, 1, 1 },
		focus = { 1, 0.55, 0.1 },
		friendBorder = { 0.2, 0.9, 0.2 },
		mouseover = { 0.6, 0.6, 0.6 },
		border = { 0, 0, 0 },
		bg = { 0.08, 0.08, 0.08 },
		castNormal = { 1, 0.7, 0 },
		castChannel = { 0.25, 0.8, 0.35 },
		castNoInt = { 0.55, 0.55, 0.6 },
		castEmph = { 1, 0.2, 0.2 },
		castInterrupted = { 0.8, 0.1, 0.1 },
		execute = { 1, 0.3, 0.3 },
		threatAggro = { 0.9, 0.1, 0.1 },
		threatWarn = { 1, 0.6, 0 },
		threatSafe = { 0.2, 0.8, 0.2 },
		raidNpc1 = { 1, 0.2, 0.2 },
		raidNpc2 = { 1, 0.85, 0.1 },
		flagAlliance = { 0.3, 0.5, 1 },
		flagHorde = { 1, 0.25, 0.25 },
		lowHealth = { 1, 0.2, 0.2 },
	},

	-- Freund & Feind
	friendlyNameOnly = false,
	friendlyClassIconOnly = false,
	friendlyNameOnlyPvP = false, -- in Schlachtfeld/Arena automatisch "nur Namen"
	friendlyBorder = true,       -- grüner Rahmen um verbündete Spieler
	friendlyScale = 1.0,         -- Größe verbündeter Spieler-Plaketten
	friendlyOnlyGroup = false,   -- Freunde nur, wenn in meiner Gruppe
	nameReactionColor = false,   -- Namen: Verbündete grün, Feinde rot
	lowHealthFlash = false,      -- Freunde: Balken blinkt unter Schwelle
	lowHealthPct = 35,
	stacking = false,
	stackingPvP = false,
	stackingRaid = true,
	stackSpacing = 2,
	stackMaxHeight = 200,

	-- Ziel
	targetArrows = true,
	targetBorder = true,
	focusIndicator = true,
	partyPointer = true,

	-- Totems
	totemIndicator = true,
	totemSize = 26,
	totemTimers = true,
	hideOtherTotems = false,
	allTotemIcons = true,
	smallPets = true,

	-- Spieler
	classIconEnemy = false,
	classIconFriendly = true,
	classIconSize = 20,
	healerIndicator = true,
	healerPriority = false,      -- BG: Nicht-Heiler abdunkeln
	arenaNumbers = true,
	targetedBy = true,           -- Zähler: Gruppenmitglieder, die diese Einheit anvisieren
	targetedByStyle = 1,         -- 1 Quadrate, 2 Zahl
	enemyTargetIndicator = true, -- Arena: Gegner zielt auf mich / Heiler
	trinketIndicator = true,
	flagCarrier = true,
	flagSound = false,

	-- Raid & Dungeon
	threatMode = 1,              -- 1 aus, 2 DPS/Heiler, 3 Tank
	threatPercent = false,
	raidNpcHighlight = true,
	raidNpcCustom = "",
	bossBig = true,
	dispelIndicator = true,
	dispelAll = false,
	myBuffsOnFriends = true,

	-- Execute
	execute = false,
	executePct = 20,
	executeColor = false,        -- Balken unter der Schwelle einfärben

	-- Zauberleiste
	castbar = true,
	castHeight = 8,
	castIcon = true,
	castIconSide = 1,            -- 1 links, 2 rechts
	castTimer = true,
	castTimerFormat = 1,         -- 1 Rest, 2 Rest / Gesamt, 3 Prozent
	castName = true,
	castNameMaxLen = 0,
	castInterruptIcon = true,
	kickCdText = true,
	castInterrupted = true,      -- "Unterbrochen von X" kurz anzeigen
	castEmphasisList = "",       -- wichtige Zauber: Balken rot + größer
	castHideList = "",           -- Zauber, für die keine Leiste gezeigt wird
	castSound = false,           -- Ton bei hervorgehobenem Zauber
	castSoundId = 1,
	immuneText = false,

	-- Auren
	auras = true,
	myDebuffs = true,
	pvpAuras = true,
	auraSize = 20,
	maxAuras = 6,
	auraRows = 1,
	auraGrow = 1,                -- 1 zentriert, 2 links, 3 rechts
	auraSpacing = 2,
	auraTimer = true,
	auraStacks = true,
	auraOnlyTarget = false,
	auraMineFirst = false,
	pandemic = true,             -- eigene DoTs: Timer rot bei < 30 % Restzeit
	keyAuraList = "",            -- vergrößerte Auren
	auraWhitelist = "",
	auraBlacklist = "",
	lockoutAura = true,          -- Schul-Lockout nach Unterbrechung als Aura
	auraCats = { stun = true, cc = true, silence = true, root = true, disarm = true, immune = true, buff = true },

	-- Diminishing Returns
	dr = true,
	drSize = 20,
	drOnlyEnemies = true,
	drOnlyPlayers = true,
	drInWorld = false,
	drCats = { stun = true, cheapshot = true, fear = true, horror = true, incapacitate = true, disorient = true, silence = true, root = true,
		entrapment = false, cyclone = true, banish = true, sleep = true, charge = false, disarm = true, mc = true },

	-- Sonstiges
	minimapButton = true,
	updateRate = 0.1,
}

ns.textures = {
	{ "Blizzard", "Interface\\TargetingFrame\\UI-StatusBar" },
	{ "Flat", "Interface\\Buttons\\WHITE8X8" },
	{ "Raid", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
	{ "Smooth", ns.MEDIA .. "smooth" },
}

ns.fonts = {
	{ "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
	{ "Arial Narrow", "Fonts\\ARIALN.TTF" },
	{ "Skurri", "Fonts\\SKURRI.TTF" },
	{ "Morpheus", "Fonts\\MORPHEUS.TTF" },
}

ns.healthTextModes = { "Off", "Percent", "Value", "Value + Percent", "Value / Max", "Missing" }

----------------------------------------------------------------
-- Event-Verteiler
----------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns:On(event, fn)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		eventFrame:RegisterEvent(event)
	end
	list[#list + 1] = fn
end

local function Dispatch(event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		list[i](event, ...)
	end
end
eventFrame:SetScript("OnEvent", function(_, event, ...) Dispatch(event, ...) end)
-- Für den Testmodus: Ereignisse künstlich auslösen
function ns:Fire(event, ...) Dispatch(event, ...) end

----------------------------------------------------------------
-- Hilfsfunktionen
----------------------------------------------------------------
function ns:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffBetterPlates:|r " .. tostring(msg))
end

local abs = math.abs
-- Feindliche Spieler werden vom 3.3.5a-Client in Klassenfarbe gezeichnet
-- (CVar ShowClassColorInNameplate). Daraus lässt sich die Klasse ablesen.
function ns.ClassFromColor(r, g, b)
	for class, c in pairs(RAID_CLASS_COLORS) do
		if abs(c.r - r) < 0.03 and abs(c.g - g) < 0.03 and abs(c.b - b) < 0.03 then
			return class
		end
	end
end

function ns.ShortValue(v)
	if v >= 1e6 then
		return string.format("%.1fm", v / 1e6)
	elseif v >= 1e4 then
		return string.format("%.0fk", v / 1e3)
	elseif v >= 1e3 then
		return string.format("%.1fk", v / 1e3)
	end
	return tostring(math.floor(v + 0.5))
end

function ns:CacheUnit(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
	local name = UnitName(unit)
	if not name or name == UNKNOWNOBJECT then return end
	local _, class = UnitClass(unit)
	if class then ns.classCache[name] = class end
	local guid = UnitGUID(unit)
	if guid then ns.guidByName[name] = guid end
end

-- Klasse zu einer Spieler-GUID holen (Kampflog, Chat, Ziele anderer).
-- Der Client kennt die Klasse jedes Spielers, dessen Namen er schon aufgelöst hat.
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
function ns:CacheGUID(guid, name)
	if not guid or guid == "" then return end
	if name and name ~= "" then
		ns.guidByName[name] = guid
		if ns.classCache[name] then return end
	end
	if not GetPlayerInfoByGUID then return end
	-- Unbekannte GUIDs nicht bei jedem Kampflog-Ereignis erneut abfragen
	local now = GetTime()
	local tried = ns.guidTried[guid]
	if tried and now - tried < 5 then return end
	ns.guidTried[guid] = now
	local ok, _, class, _, _, _, n = pcall(GetPlayerInfoByGUID, guid)
	if not ok then return end
	name = (name and name ~= "") and name or n
	if class and name and name ~= "" and RAID_CLASS_COLORS[class] then
		ns.classCache[name] = class
		ns.guidByName[name] = guid
	end
end

-- Lokalisierter Klassenname -> englischer Schlüssel (für Freundesliste)
local classByLocal
local function ClassFromLocalized(localized)
	if not localized then return end
	if not classByLocal then
		classByLocal = {}
		for _, tbl in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
			if type(tbl) == "table" then
				for key, loc in pairs(tbl) do classByLocal[loc] = key end
			end
		end
	end
	return classByLocal[localized]
end

local function CacheGuild()
	if not IsInGuild or not IsInGuild() then return end
	for i = 1, (GetNumGuildMembers and GetNumGuildMembers(true) or 0) do
		local name, _, _, _, locClass, _, _, _, _, _, classFile = GetGuildRosterInfo(i)
		if name then
			local class = (classFile and RAID_CLASS_COLORS[classFile]) and classFile or ClassFromLocalized(locClass)
			if class then ns.classCache[name] = class end
		end
	end
end

local function CacheFriends()
	for i = 1, (GetNumFriends and GetNumFriends() or 0) do
		local name, _, locClass = GetFriendInfo(i)
		local class = ClassFromLocalized(locClass)
		if name and class then ns.classCache[name] = class end
	end
end

-- Eigene Auren-Listen: "118, 853, Polymorph" -> Namen
ns.auraExtra, ns.auraBlock = {}, {}
local function ParseSpellList(str, into)
	wipe(into)
	if type(str) ~= "string" then return end
	for token in str:gmatch("[^,;\n]+") do
		token = token:gsub("^%s+", ""):gsub("%s+$", "")
		if token ~= "" then
			local id = tonumber(token)
			local name = id and GetSpellInfo(id) or token
			if name then into[name] = true end
		end
	end
end
ns.castEmphasis, ns.castHide, ns.keyAuras = {}, {}, {}
ns.hideNpc, ns.fadeNpc, ns.colorNpc = {}, {}, {}

-- NPC-Listen: Namen, Groß-/Kleinschreibung egal
local function ParseNameList(str, into)
	wipe(into)
	if type(str) ~= "string" then return end
	for token in str:gmatch("[^,;\n]+") do
		token = token:gsub("^%s+", ""):gsub("%s+$", "")
		if token ~= "" then into[token:lower()] = true end
	end
end

-- "Name:ff8800, Other Name:00ff00" -> [name] = {r,g,b}
local function ParseColorList(str, into)
	wipe(into)
	if type(str) ~= "string" then return end
	for token in str:gmatch("[^,;\n]+") do
		local name, hex = token:match("^%s*(.-)%s*[:=]%s*#?(%x%x%x%x%x%x)%s*$")
		if name and name ~= "" then
			into[name:lower()] = {
				tonumber(hex:sub(1, 2), 16) / 255,
				tonumber(hex:sub(3, 4), 16) / 255,
				tonumber(hex:sub(5, 6), 16) / 255,
			}
		end
	end
end

function ns:RebuildAuraLists()
	ParseSpellList(ns.db.auraWhitelist, ns.auraExtra)
	ParseSpellList(ns.db.auraBlacklist, ns.auraBlock)
	ParseSpellList(ns.db.castEmphasisList, ns.castEmphasis)
	ParseSpellList(ns.db.castHideList, ns.castHide)
	ParseSpellList(ns.db.keyAuraList, ns.keyAuras)
	if ns.BuildRaidNpcs then ns:BuildRaidNpcs() end
	ParseNameList(ns.db.hideNpcList, ns.hideNpc)
	ParseNameList(ns.db.fadeNpcList, ns.fadeNpc)
	ParseColorList(ns.db.colorNpcList, ns.colorNpc)
end

function ns:Refresh()
	if ns.Plates and ns.db then ns.Plates:RefreshAll() end
end

----------------------------------------------------------------
-- Start
----------------------------------------------------------------
ns.db = {}
local function CopyDefaultsInto(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaultsInto(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end
ns:On("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	if ns.Profiles then
		ns.Profiles:Load()
	else
		-- Neue Dateien in der TOC, aber der Client läuft noch mit der alten Dateiliste
		-- (nur /reload statt Neustart): Notbetrieb mit flacher Tabelle.
		if type(BetterPlatesDB) ~= "table" then BetterPlatesDB = {} end
		local prof = (BetterPlatesDB.profiles and BetterPlatesDB.profiles.Default) or BetterPlatesDB
		CopyDefaultsInto(ns.defaults, prof)
		ns.db = prof
		ns.needsRestart = true
		if not ns.Set then
			function ns:Set(key, value, noRefresh)
				ns.db[key] = value
				if not noRefresh and ns.Refresh then ns:Refresh() end
			end
		end
	end
end)

ns.DONATE_URL = "https://www.warmane.com/account/services"
ns.DONATE_CHAR = "Samyd - Blackrock"

ns:On("PLAYER_LOGIN", function()
	ns.playerGUID = UnitGUID("player")
	if ns.Profiles then ns.Profiles:FixCharKey() end
	ns:BuildData()
	-- Klassenfarben für feindliche Spieler einschalten: daraus wird die Klasse erkannt
	pcall(SetCVar, "ShowClassColorInNameplate", "1")
	-- Kein Aufblähen der Plaketten bei Bedrohung, sonst stimmen Größen nicht
	pcall(SetCVar, "bloattest", "0")
	pcall(SetCVar, "bloatnameplates", "0")
	pcall(SetCVar, "bloatthreat", "0")
	ns:RebuildAuraLists()
	ns.Plates:ResolveInterrupt()
	ns.Plates:Init()
	if ns.CreateOptions then ns:CreateOptions() end
	if ns.Minimap then ns.Minimap:Create() end
	if ns.needsRestart then
		ns:Print("|cffff5555BetterPlates was updated. Please restart the game client completely (not just /reload) to load the new files.|r")
	end
end)
ns:On("SPELLS_CHANGED", function()
	if ns.Plates then ns.Plates:ResolveInterrupt() end
	if ns.ResolveDispel then ns:ResolveDispel() end
end)
ns:On("UPDATE_SHAPESHIFT_FORM", function() if ns.Plates then ns.Plates:ResolveInterrupt() end end)

-- Keybindings (Bindings.xml)
BINDING_HEADER_BETTERPLATES = "BetterPlates"
BINDING_NAME_BETTERPLATES_FRIENDS = "Toggle friendly nameplates"
BINDING_NAME_BETTERPLATES_ENEMIES = "Toggle enemy nameplates"
BINDING_NAME_BETTERPLATES_STACKING = "Toggle nameplate stacking"
BINDING_NAME_BETTERPLATES_OPTIONS = "Open BetterPlates settings"
BINDING_NAME_BETTERPLATES_ALL = "Toggle all nameplates"
BINDING_NAME_BETTERPLATES_TEST = "Run nameplate test mode"
local function ToggleCVar(cvar)
	local ok, v = pcall(GetCVar, cvar)
	if ok then pcall(SetCVar, cvar, v == "1" and "0" or "1") end
end
function BetterPlates_ToggleFriends() ToggleCVar("nameplateShowFriends") end
function BetterPlates_ToggleEnemies() ToggleCVar("nameplateShowEnemies") end
function BetterPlates_ToggleStacking()
	if ns.db then ns:Set("stacking", not ns.db.stacking) ns:Print("Stacking " .. (ns.db.stacking and "on" or "off")) end
end
function BetterPlates_ToggleAll()
	local ok, f = pcall(GetCVar, "nameplateShowFriends")
	local ok2, e = pcall(GetCVar, "nameplateShowEnemies")
	local anyOn = (ok and f == "1") or (ok2 and e == "1")
	if anyOn then
		ns.allWasFriends, ns.allWasEnemies = f, e
		pcall(SetCVar, "nameplateShowFriends", "0")
		pcall(SetCVar, "nameplateShowEnemies", "0")
	else
		pcall(SetCVar, "nameplateShowFriends", ns.allWasFriends or "0")
		pcall(SetCVar, "nameplateShowEnemies", ns.allWasEnemies or "1")
	end
end
function BetterPlates_Test() if ns.Plates and ns.Plates.Test then ns.Plates:Test() end end
function BetterPlates_Options() if ns.ToggleOptions then ns:ToggleOptions() end end

local function UpdateInstance()
	local _, instanceType = IsInInstance()
	ns.instanceType = instanceType or "none"
	if ns.Profiles then ns.Profiles:OnZoneChanged() end
end

ns.groupNames = {}
local function UpdateGroup()
	wipe(ns.groupNames)
	if GetNumRaidMembers() > 0 then
		for i = 1, 40 do
			ns:CacheUnit("raid" .. i)
			local n = UnitName("raid" .. i)
			if n then ns.groupNames[n] = true end
		end
	else
		for i = 1, 4 do
			ns:CacheUnit("party" .. i)
			local n = UnitName("party" .. i)
			if n then ns.groupNames[n] = true end
		end
	end
end

ns:On("PLAYER_ENTERING_WORLD", function()
	UpdateInstance()
	UpdateGroup()
	wipe(ns.healers)
end)
ns:On("ZONE_CHANGED_NEW_AREA", UpdateInstance)
ns:On("PARTY_MEMBERS_CHANGED", UpdateGroup)
ns:On("RAID_ROSTER_UPDATE", UpdateGroup)
ns:On("PLAYER_TARGET_CHANGED", function() ns:CacheUnit("target") end)
ns:On("PLAYER_FOCUS_CHANGED", function() ns:CacheUnit("focus") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() ns:CacheUnit("mouseover") end)
ns:On("ARENA_OPPONENT_UPDATE", function()
	for i = 1, 5 do ns:CacheUnit("arena" .. i) end
end)

-- Ziele von Gruppenmitgliedern, Arena-Gegnern, eigenem Ziel/Fokus
ns:On("UNIT_TARGET", function(_, unit)
	if unit and unit ~= "player" and not unit:find("pet") then
		ns:CacheUnit(unit .. "target")
	end
end)

-- Chat-Nachrichten tragen in 3.3.5a die GUID des Absenders (12. Argument)
local CHAT_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_CHANNEL",
	"CHAT_MSG_PARTY", "CHAT_MSG_RAID", "CHAT_MSG_GUILD", "CHAT_MSG_WHISPER", "CHAT_MSG_BATTLEGROUND",
	"CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_BATTLEGROUND_LEADER", "CHAT_MSG_OFFICER",
}
for _, ev in ipairs(CHAT_EVENTS) do
	ns:On(ev, function(_, _, sender, _, _, _, _, _, _, _, _, _, guid)
		if sender and guid and guid ~= "" and guid ~= 0 and not ns.classCache[sender] then
			ns:CacheGUID(tostring(guid), sender)
		end
	end)
end

-- Gilde und Freunde
ns:On("GUILD_ROSTER_UPDATE", CacheGuild)
ns:On("FRIENDLIST_UPDATE", CacheFriends)
ns:On("PLAYER_ENTERING_WORLD", function()
	if GuildRoster and IsInGuild and IsInGuild() then pcall(GuildRoster) end
	if ShowFriends then pcall(ShowFriends) end
	CacheFriends()
end)
