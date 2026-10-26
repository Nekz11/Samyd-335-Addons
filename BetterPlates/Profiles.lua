-- BetterPlates - Profiles
-- Profile (global / pro Charakter), Zonen-Overrides, Design-Presets,
-- Import/Export ohne externe Bibliotheken.

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end

local P = {}
ns.Profiles = P

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local format, floor = string.format, math.floor

P.DB_VERSION = 2
P.DEFAULT_NAME = "Default"

-- Zonentypen, wie IsInInstance sie liefert ("none" = offene Welt)
P.ZONES = { "none", "party", "raid", "pvp", "arena" }
P.ZONE_LABELS = { none = "Open World", party = "Dungeon", raid = "Raid", pvp = "Battleground", arena = "Arena" }

-- Schlüssel, die pro Zone überschrieben werden dürfen (Boolesche Werte + wenige Zahlen)
P.ZONE_KEYS = {
	-- Blizzard-CVars (als "cvar:<name>" gespeichert, Wert "1"/"0")
	{ key = "cvar:nameplateShowFriends", label = "Show friendly nameplates", cvar = true },
	{ key = "cvar:nameplateShowEnemies", label = "Show enemy nameplates", cvar = true },
	{ key = "cvar:nameplateShowFriendlyPets", label = "Show friendly pets", cvar = true },
	{ key = "cvar:nameplateShowEnemyPets", label = "Show enemy pets", cvar = true },
	{ key = "cvar:nameplateShowFriendlyTotems", label = "Show friendly totems", cvar = true },
	{ key = "cvar:nameplateShowEnemyTotems", label = "Show enemy totems", cvar = true },
	{ key = "cvar:nameplateShowFriendlyGuardians", label = "Show friendly guardians", cvar = true },
	{ key = "cvar:nameplateShowEnemyGuardians", label = "Show enemy guardians", cvar = true },
	{ key = "cvar:nameplateAllowOverlap", label = "Allow overlapping nameplates (client)", cvar = true },
	-- Addon-Schalter
	{ key = "friendlyNameOnly", label = "Friends: names only" },
	{ key = "friendlyOnlyGroup", label = "Friends: only group members" },
	{ key = "auras", label = "Show auras" },
	{ key = "myDebuffs", label = "My debuffs" },
	{ key = "pvpAuras", label = "PvP auras (CC, immunities)" },
	{ key = "myBuffsOnFriends", label = "My HoTs / buffs on friends" },
	{ key = "dispelIndicator", label = "Dispellable debuffs on group" },
	{ key = "dr", label = "Diminishing returns" },
	{ key = "stacking", label = "Stack nameplates" },
	{ key = "healerIndicator", label = "Healer marker" },
	{ key = "classIconFriendly", label = "Class icon on friends" },
	{ key = "classIconEnemy", label = "Class icon on enemies" },
	{ key = "totemIndicator", label = "Totem indicator" },
	{ key = "castbar", label = "Cast bars" },
	{ key = "raidNpcHighlight", label = "Raid NPC highlight" },
	{ key = "targetedBy", label = "Targeted-by counter" },
	{ key = "flagCarrier", label = "Flag carrier highlight" },
	{ key = "arenaNumbers", label = "Arena numbers" },
	{ key = "threatMode", label = "Threat mode", values = { 1, 2, 3 }, valueLabels = { "Off", "DPS / Healer", "Tank" } },
	{ key = "friendlyScale", label = "Size of friendly nameplates", values = { 0.5, 0.6, 0.7, 0.8, 0.9, 1 } },
}

----------------------------------------------------------------
-- Hilfen
----------------------------------------------------------------
local function CopyTable(src)
	local t = {}
	for k, v in pairs(src) do
		if type(v) == "table" then t[k] = CopyTable(v) else t[k] = v end
	end
	return t
end
P.CopyTable = CopyTable

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil or type(dst[k]) ~= type(v) then
			dst[k] = v
		end
	end
end

function P.CharKey()
	local name = UnitName and UnitName("player")
	local realm = GetRealmName and GetRealmName()
	if not name or name == "" or name == UNKNOWNOBJECT then
		P.keyUnknown = true
		name = "?"
	end
	return name .. " - " .. (realm or "Realm")
end

-- Falls der Spielername beim Laden noch nicht bekannt war: Zuordnung nachziehen
function P:FixCharKey()
	if not self.keyUnknown or not self.root then return end
	self.keyUnknown = false
	local key = self.CharKey()
	if self.keyUnknown then return end
	local old = self.root.charProfile["? - " .. (GetRealmName and GetRealmName() or "Realm")]
	self.root.charProfile["? - " .. (GetRealmName and GetRealmName() or "Realm")] = nil
	local name = self.root.charProfile[key] or old or P.DEFAULT_NAME
	if not self.root.profiles[name] then name = P.DEFAULT_NAME end
	if name ~= self.name then self:Activate(name) else self.root.charProfile[key] = name end
end

----------------------------------------------------------------
-- Laden & Migration
----------------------------------------------------------------
function P:Load()
	if type(BetterPlatesDB) ~= "table" then BetterPlatesDB = {} end
	local root = BetterPlatesDB

	-- Alte flache Datenbank (1.x) -> Profil "Default"
	if root.version ~= P.DB_VERSION then
		local old = {}
		local hadOld = false
		for k, v in pairs(root) do
			if k ~= "profiles" and k ~= "charProfile" and k ~= "minimap" and k ~= "version" then
				old[k] = v
				hadOld = true
			end
		end
		root.profiles = root.profiles or {}
		if hadOld and not root.profiles[P.DEFAULT_NAME] then
			root.profiles[P.DEFAULT_NAME] = old
		end
		for k in pairs(old) do root[k] = nil end
		root.version = P.DB_VERSION
	end

	root.profiles = root.profiles or {}
	root.charProfile = root.charProfile or {}
	root.minimap = root.minimap or { angle = 220, hide = false }
	if not root.profiles[P.DEFAULT_NAME] then root.profiles[P.DEFAULT_NAME] = {} end

	local key = P.CharKey()
	local name = root.charProfile[key]
	if not name or not root.profiles[name] then
		name = P.DEFAULT_NAME
		root.charProfile[key] = name
	end
	self.root = root
	self:Activate(name)
	self.activeZone = nil   -- erstes PLAYER_ENTERING_WORLD wendet die Zone (inkl. CVars) an
end

-- Profil aktivieren: Defaults ergänzen, Zonen-Tabelle anlegen, effektive Tabelle bauen
function P:Activate(name)
	local root = self.root
	local profile = root.profiles[name]
	if not profile then return false end
	CopyDefaults(ns.defaults, profile)
	profile.zones = profile.zones or {}
	for _, z in ipairs(P.ZONES) do profile.zones[z] = profile.zones[z] or {} end
	self.profile = profile
	self.name = name
	root.charProfile[P.CharKey()] = name
	self:Rebuild()
	return true
end

function P:GetNames()
	local names = {}
	for n in pairs(self.root.profiles) do names[#names + 1] = n end
	table.sort(names)
	return names
end

function P:Exists(name) return self.root.profiles[name] ~= nil end

function P:Create(name, copyFrom)
	if not name or name == "" or self.root.profiles[name] then return false end
	local src = copyFrom and self.root.profiles[copyFrom]
	self.root.profiles[name] = src and CopyTable(src) or {}
	return true
end

function P:Delete(name)
	if name == self.name or name == P.DEFAULT_NAME or not self.root.profiles[name] then return false end
	self.root.profiles[name] = nil
	for char, pn in pairs(self.root.charProfile) do
		if pn == name then self.root.charProfile[char] = P.DEFAULT_NAME end
	end
	return true
end

function P:Rename(old, new)
	if not self.root.profiles[old] or self.root.profiles[new] or not new or new == "" or old == P.DEFAULT_NAME then return false end
	self.root.profiles[new] = self.root.profiles[old]
	self.root.profiles[old] = nil
	for char, pn in pairs(self.root.charProfile) do
		if pn == old then self.root.charProfile[char] = new end
	end
	if self.name == old then self.name = new end
	return true
end

function P:Reset()
	local zones = self.profile.zones
	wipe(self.profile)
	CopyDefaults(ns.defaults, self.profile)
	self.profile.zones = zones   -- Zonenregeln bleiben erhalten
	self:ApplyZone()
end

-- Alle Profile, die diesen Charakter betreffen (Anzeige)
function P:CharactersUsing(name)
	local n = 0
	for _, pn in pairs(self.root.charProfile) do if pn == name then n = n + 1 end end
	return n
end

----------------------------------------------------------------
-- Effektive Einstellungen (Profil + Zonen-Override)
----------------------------------------------------------------
-- ns.db bleibt eine einfache Tabelle (schnelle Lesezugriffe). Schreiben über ns:Set.
function P:CurrentZone()
	local z = ns.instanceType or "none"
	if z ~= "party" and z ~= "raid" and z ~= "pvp" and z ~= "arena" then z = "none" end
	return z
end

function P:Overrides(zone)
	return self.profile.zones[zone or self:CurrentZone()]
end

function P:Rebuild()
	local db = ns.db
	if type(db) ~= "table" then db = {} ns.db = db end
	wipe(db)
	for k, v in pairs(self.profile) do
		if k ~= "zones" then db[k] = v end
	end
	local over = self:Overrides()
	for k, v in pairs(over) do
		if type(k) == "string" and k:sub(1, 5) ~= "cvar:" and ns.defaults[k] ~= nil and type(ns.defaults[k]) == type(v) then
			db[k] = v
		end
	end
	db.zones = nil
	self.activeZone = self:CurrentZone()
end

-- Beim Zonenwechsel: Tabelle neu bauen, CVar-Overrides anwenden
function P:ApplyZone()
	self:Rebuild()
	local over = self:Overrides()
	local root = self.root
	root.cvarBase = root.cvarBase or {}
	-- CVars: überschriebene setzen (Vorwert merken), nicht überschriebene auf den Vorwert zurück
	for _, def in ipairs(P.ZONE_KEYS) do
		if def.cvar then
			local cvar = def.key:sub(6)
			local v = over[def.key]
			if v ~= nil then
				if root.cvarBase[cvar] == nil then
					local ok, cur = pcall(GetCVar, cvar)
					if ok and cur ~= nil then root.cvarBase[cvar] = tostring(cur) end
				end
				pcall(SetCVar, cvar, v and "1" or "0")
			elseif root.cvarBase[cvar] ~= nil then
				pcall(SetCVar, cvar, root.cvarBase[cvar])
				root.cvarBase[cvar] = nil
			end
		end
	end
	if ns.RebuildAuraLists then ns:RebuildAuraLists() end
	if ns.Refresh then ns:Refresh() end
end

-- Mehrere Regeln auf einmal setzen (ein ApplyZone)
function P:SetOverrides(zone, rules)
	local zt = self.profile.zones[zone]
	if not zt then return end
	for k, v in pairs(rules) do zt[k] = v end
	if zone == self:CurrentZone() then self:ApplyZone() end
end

function P:IsOverridden(key)
	local over = self:Overrides()
	return over[key] ~= nil
end

-- Override setzen (nil = folgt Profil)
function P:SetOverride(zone, key, value)
	local zt = self.profile.zones[zone]
	if not zt then return end
	zt[key] = value
	if zone == self:CurrentZone() then self:ApplyZone() end
end

function P:GetOverride(zone, key)
	local zt = self.profile.zones[zone]
	return zt and zt[key]
end

-- Wert im Profil setzen; die effektive Tabelle folgt, solange kein Override greift
function ns:Set(key, value, noRefresh)
	local prof = P.profile
	if not prof then
		if ns.db then ns.db[key] = value end
		return
	end
	prof[key] = value
	if not P:IsOverridden(key) then ns.db[key] = value end
	if not noRefresh and ns.Refresh then ns:Refresh() end
end

function ns:Get(key)
	return ns.db and ns.db[key]
end

----------------------------------------------------------------
-- Presets (Design-Vorlagen)
----------------------------------------------------------------
local ARENA_CASTS = "Polymorph, Fear, Cyclone, Hex, Repentance, Mind Control, Seduction, Mana Burn, Drain Mana, Entangling Roots, Chaos Bolt, Lava Burst, Greater Heal, Healing Wave, Chain Heal, Penance, Holy Light, Regrowth, Nourish, Resurrection, Hungering Cold, Shadowfury"
local DUNGEON_CASTS = "Shadow Bolt Volley, Heal, Frostbolt, Chain Heal, Mind Flay, Flash Heal, Greater Heal, Fireball, Shadow Bolt, Arcane Blast, Lightning Bolt, Holy Light, Dark Mending, Renew, Healing Wave"

P.PRESETS = {
	{
		name = "PvP Arena", full = true,
		desc = "Complete arena/BG setup: enemies big with class icons, DR, auras, lockouts, trinket & kick timers, emphasized arena casts with sound, friends as names only in PvP, stacking off. Also writes arena/BG zone rules.",
		settings = {
			width = 130, height = 12, fontSize = 11, targetScale = 1.2, texture = 4, borderStyle = 2, bgStyle = 1,
			healthText = 2, healthDecimals = false, hideLevelMaxPlayers = true,
			classColorEnemy = true, classColorFriendly = true, classIconEnemy = true, classIconFriendly = true, classIconSize = 22,
			arenaNumbers = true, healerIndicator = true, partyPointer = true,
			dr = true, drSize = 22, drOnlyEnemies = true, drOnlyPlayers = true,
			auras = true, myDebuffs = true, pvpAuras = true, auraSize = 24, maxAuras = 6, auraRows = 1, lockoutAura = true,
			colorByAura = true, myBuffsOnFriends = false, dispelIndicator = false,
			castbar = true, castHeight = 10, castIcon = true, castTimer = true, castName = true,
			castInterruptIcon = true, kickCdText = true, castInterrupted = true, castSound = true, castSoundId = 1,
			castEmphasisList = ARENA_CASTS,
			friendlyNameOnly = false, friendlyNameOnlyPvP = false, friendlyClassIconOnly = false, friendlyBorder = true, friendlyScale = 0.8,
			trinketIndicator = true, enemyTargetIndicator = true, targetedBy = true, flagCarrier = true, healerPriority = false,
			totemIndicator = true, allTotemIcons = true, totemTimers = true, smallPets = true,
			stacking = false, stackingPvP = false, threatMode = 1, raidNpcHighlight = false, bossBig = false,
			trivialMode = 1, execute = false,
		},
		zones = {
			arena = { ["cvar:nameplateShowEnemies"] = true, ["cvar:nameplateShowFriends"] = true, ["cvar:nameplateShowEnemyPets"] = true,
				["cvar:nameplateShowFriendlyPets"] = false, ["cvar:nameplateShowEnemyTotems"] = true, dr = true, arenaNumbers = true, stacking = false },
			pvp = { ["cvar:nameplateShowEnemies"] = true, ["cvar:nameplateShowFriends"] = true, ["cvar:nameplateShowEnemyPets"] = true,
				["cvar:nameplateShowFriendlyPets"] = false, dr = true, stacking = false, flagCarrier = true, targetedBy = true },
		},
	},
	{
		name = "PvE Raid", full = true,
		desc = "Complete raid/dungeon setup: threat colors (DPS/Healer), important adds highlighted, bosses bigger, my debuffs, HoTs and dispels on friends, client nameplate spreading, no PvP auras/DR, dungeon kicks emphasized. Also writes raid/dungeon zone rules.",
		settings = {
			width = 115, height = 10, fontSize = 10, targetScale = 1.15, texture = 4, borderStyle = 2, bgStyle = 1,
			healthText = 4, healthDecimals = false, abbrevNames = true, nameMaxLen = 0, levelColor = true, eliteMark = true,
			classColorEnemy = true, classColorFriendly = true, classIconEnemy = false, classIconFriendly = false,
			arenaNumbers = false, healerIndicator = false, partyPointer = false,
			threatMode = 2, threatPercent = true, threatColor = false, raidNpcHighlight = true, bossBig = true,
			dr = false, auras = true, myDebuffs = true, pvpAuras = false, auraSize = 20, maxAuras = 5, lockoutAura = false,
			colorByAura = false, myBuffsOnFriends = true, dispelIndicator = true, pandemic = true,
			castbar = true, castHeight = 8, castIcon = true, castTimer = true, castName = true,
			castInterruptIcon = true, kickCdText = true, castInterrupted = true, castSound = false,
			castEmphasisList = DUNGEON_CASTS,
			friendlyNameOnly = true, friendlyNameOnlyPvP = false, friendlyClassIconOnly = false, friendlyBorder = false, friendlyScale = 1,
			lowHealthFlash = true, lowHealthPct = 35,
			trinketIndicator = false, enemyTargetIndicator = false, targetedBy = false, flagCarrier = false,
			totemIndicator = false, allTotemIcons = false, smallPets = true, hideCritters = true, trivialMode = 2,
			stacking = false, stackingRaid = true, stackingPvP = false, stackSpacing = 2,
			execute = true, executePct = 20, executeColor = false,
		},
		zones = {
			raid = { ["cvar:nameplateShowFriends"] = false, ["cvar:nameplateShowFriendlyPets"] = false, ["cvar:nameplateShowEnemyPets"] = false,
				["cvar:nameplateShowFriendlyTotems"] = false, ["cvar:nameplateShowFriendlyGuardians"] = false, ["cvar:nameplateShowEnemies"] = true,
				["cvar:nameplateAllowOverlap"] = false,
				pvpAuras = false, dr = false, threatMode = 2, raidNpcHighlight = true, stacking = false },
			party = { ["cvar:nameplateShowFriends"] = false, ["cvar:nameplateShowFriendlyPets"] = false, ["cvar:nameplateShowEnemies"] = true,
				["cvar:nameplateAllowOverlap"] = false,
				pvpAuras = false, dr = false, threatMode = 2, raidNpcHighlight = true, stacking = false },
		},
	},
	{
		name = "Classic Blizzard", desc = "Blizzard texture, thin black border, percent text.",
		settings = { texture = 1, borderStyle = 2, height = 10, width = 110, font = 1, fontSize = 10, outline = true,
			healthText = 2, healthTextPos = 1, bgStyle = 1, targetStyle = 1, nameInBar = false },
	},
	{
		name = "Clean Flat", desc = "Flat bars, no texture noise, name inside the bar.",
		settings = { texture = 2, borderStyle = 2, height = 12, width = 120, font = 2, fontSize = 11, outline = true,
			healthText = 2, healthTextPos = 3, bgStyle = 1, targetStyle = 2, nameInBar = true, castHeight = 10 },
	},
	{
		name = "Modern", desc = "Smooth texture, thin border, bigger name, glow on target.",
		settings = { texture = 4, borderStyle = 2, height = 11, width = 130, font = 1, fontSize = 12, outline = true,
			healthText = 4, healthTextPos = 1, bgStyle = 2, targetStyle = 2, targetScale = 1.2, castHeight = 9, auraSize = 22 },
	},
	{
		name = "PvP Big", desc = "Wide bars, big auras, arena numbers, DR, class icons on enemies.",
		settings = { texture = 4, width = 140, height = 14, fontSize = 12, targetScale = 1.25, auraSize = 26, maxAuras = 6,
			classIconEnemy = true, arenaNumbers = true, dr = true, castHeight = 10, castInterruptIcon = true,
			lockoutAura = true, castInterrupted = true, friendlyScale = 0.7, friendlyBorder = true },
	},
	{
		name = "Raid Minimal", desc = "Threat colors, no auras, small plates, no friendly bars.",
		settings = { width = 100, height = 8, fontSize = 9, auras = false, threatMode = 2, raidNpcHighlight = true,
			friendlyNameOnly = true, stacking = false, totemIndicator = false, castHeight = 7, hideLevel = true },
	},
	{
		name = "Healer", desc = "Friends larger, my HoTs on friends, dispellable debuffs, low-health flash.",
		settings = { friendlyScale = 1, friendlyNameOnly = false, myBuffsOnFriends = true, dispelIndicator = true,
			lowHealthFlash = true, classIconFriendly = true, healerIndicator = true, auraSize = 22, friendlyBorder = true },
	},
}

function P:ApplyPreset(index)
	local preset = type(index) == "table" and index or self.PRESETS[index]
	if not preset then return end
	for k, v in pairs(preset.settings) do ns:Set(k, v, true) end
	if preset.zones then
		for zone, rules in pairs(preset.zones) do
			local zt = self.profile.zones[zone]
			if zt then
				for k, v in pairs(rules) do zt[k] = v end
			end
		end
		self:ApplyZone()
	end
	if ns.RebuildAuraLists then ns:RebuildAuraLists() end
	if ns.Refresh then ns:Refresh() end
end

function P:PresetByName(name)
	for i, p in ipairs(self.PRESETS) do if p.name == name then return p, i end end
end

----------------------------------------------------------------
-- Serialisierung (Import / Export)
----------------------------------------------------------------
-- Format: kompakte Textdarstellung, anschließend Base64-ähnlich kodiert.
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789()"
local encMap, decMap = {}, {}
for i = 1, 64 do
	local c = ALPHABET:sub(i, i)
	encMap[i - 1] = c
	decMap[c] = i - 1
end

local function Encode(str)
	local out = {}
	local n = #str
	for i = 1, n, 3 do
		local a, b, c = str:byte(i, i + 2)
		b = b or 0
		c = c or 0
		local v = a * 65536 + b * 256 + c
		out[#out + 1] = encMap[floor(v / 262144) % 64] .. encMap[floor(v / 4096) % 64]
			.. ((i + 1 <= n) and encMap[floor(v / 64) % 64] or "")
			.. ((i + 2 <= n) and encMap[v % 64] or "")
	end
	return table.concat(out)
end

local function Decode(str)
	local out = {}
	local n = #str
	for i = 1, n, 4 do
		local c1, c2, c3, c4 = str:sub(i, i), str:sub(i + 1, i + 1), str:sub(i + 2, i + 2), str:sub(i + 3, i + 3)
		local a, b = decMap[c1], decMap[c2]
		if not a or not b then return nil end
		local c, d = decMap[c3], decMap[c4]
		local v = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
		out[#out + 1] = string.char(floor(v / 65536) % 256)
		if c then out[#out + 1] = string.char(floor(v / 256) % 256) end
		if d then out[#out + 1] = string.char(v % 256) end
	end
	return table.concat(out)
end
P.Encode, P.Decode = Encode, Decode

local function Serialize(v, out)
	local t = type(v)
	if t == "boolean" then
		out[#out + 1] = v and "T" or "F"
	elseif t == "number" then
		out[#out + 1] = "N" .. format("%.6g", v) .. ";"
	elseif t == "string" then
		out[#out + 1] = "S" .. #v .. ":" .. v
	elseif t == "table" then
		out[#out + 1] = "{"
		for k, val in pairs(v) do
			Serialize(k, out)
			Serialize(val, out)
		end
		out[#out + 1] = "}"
	else
		out[#out + 1] = "Z"
	end
end

local function Deserialize(str, pos)
	local c = str:sub(pos, pos)
	if c == "T" then return true, pos + 1
	elseif c == "F" then return false, pos + 1
	elseif c == "Z" then return nil, pos + 1
	elseif c == "N" then
		local e = str:find(";", pos, true)
		if not e then return nil end
		return tonumber(str:sub(pos + 1, e - 1)), e + 1
	elseif c == "S" then
		local colon = str:find(":", pos, true)
		if not colon then return nil end
		local len = tonumber(str:sub(pos + 1, colon - 1))
		if not len then return nil end
		return str:sub(colon + 1, colon + len), colon + len + 1
	elseif c == "{" then
		local t = {}
		pos = pos + 1
		while str:sub(pos, pos) ~= "}" do
			if pos > #str then return nil end
			local k, v
			k, pos = Deserialize(str, pos)
			if pos == nil then return nil end
			v, pos = Deserialize(str, pos)
			if pos == nil then return nil end
			if k ~= nil then t[k] = v end
		end
		return t, pos + 1
	end
	return nil
end
P.Serialize = function(v) local out = {} Serialize(v, out) return table.concat(out) end
P.Deserialize = function(s) local v, pos = Deserialize(s, 1) if pos then return v end end

P.EXPORT_PREFIX = "!BP2!"

-- Nur bekannte Schlüssel exportieren (keine Fremddaten)
function P:Export(includeZones)
	local data = { v = P.DB_VERSION, name = self.name, s = {} }
	for k, v in pairs(self.profile) do
		if k ~= "zones" and ns.defaults[k] ~= nil then data.s[k] = v end
	end
	if includeZones then data.z = CopyTable(self.profile.zones) end
	return P.EXPORT_PREFIX .. Encode(P.Serialize(data))
end

-- Liefert Tabelle oder nil + Fehlertext
function P:Parse(str)
	if type(str) ~= "string" then return nil, "empty" end
	str = str:gsub("%s+", "")
	if str:sub(1, #P.EXPORT_PREFIX) ~= P.EXPORT_PREFIX then return nil, "prefix" end
	local raw = Decode(str:sub(#P.EXPORT_PREFIX + 1))
	if not raw then return nil, "decode" end
	local data = P.Deserialize(raw)
	if type(data) ~= "table" or type(data.s) ~= "table" then return nil, "format" end
	if data.v ~= P.DB_VERSION then return nil, "version" end
	return data
end

-- Import in das aktuelle Profil (oder in ein neues Profil mit Namen)
function P:Import(str, intoName)
	local data, err = self:Parse(str)
	if not data then return false, err end
	local target
	if intoName and intoName ~= "" then
		if not self:Create(intoName) then return false, "exists" end
		target = self.root.profiles[intoName]
	else
		target = self.profile
	end
	local n = 0
	for k, v in pairs(data.s) do
		local def = ns.defaults[k]
		if def ~= nil and type(def) == type(v) then
			if type(def) == "table" then
				-- Untertabellen elementweise mit Typprüfung (Farben: 3 Zahlen; Kategorien: Boolean)
				local t = type(target[k]) == "table" and target[k] or {}
				target[k] = t
				for sk, sv in pairs(v) do
					local sd = def[sk]
					if sd ~= nil and type(sd) == type(sv) then
						if type(sd) == "table" then
							if type(sv[1]) == "number" and type(sv[2]) == "number" and type(sv[3]) == "number" then
								t[sk] = { sv[1], sv[2], sv[3] }
							end
						else
							t[sk] = sv
						end
					end
				end
			else
				target[k] = v
			end
			n = n + 1
		end
	end
	CopyDefaults(ns.defaults, target)
	if type(data.z) == "table" then
		target.zones = target.zones or {}
		for _, z in ipairs(P.ZONES) do
			local src = data.z[z]
			if type(src) == "table" then
				local zt = {}
				for _, def in ipairs(P.ZONE_KEYS) do
					local v = src[def.key]
					if v ~= nil then
						local okType = def.cvar and type(v) == "boolean" or (not def.cvar and type(v) == type(ns.defaults[def.key]))
						if okType then zt[def.key] = v end
					end
				end
				target.zones[z] = zt
			end
		end
	end
	if target == self.profile then self:ApplyZone() end
	return true, n
end

----------------------------------------------------------------
-- Zonenwechsel
----------------------------------------------------------------
function P:OnZoneChanged()
	if not self.profile then return end
	if self.activeZone ~= self:CurrentZone() then self:ApplyZone() end
end
