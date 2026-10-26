-- BetterPlates - Data
-- Spell-Listen. Alles über Spell-IDs, die Namen holt der Client (GetSpellInfo),
-- damit es auf deutschen und englischen Clients gleich funktioniert.

local ADDON, ns = ...
if type(ns) ~= "table" then BetterPlatesNS = BetterPlatesNS or {} ns = BetterPlatesNS ADDON = "BetterPlates" end

----------------------------------------------------------------
-- Totems: [Spell-ID] = { wichtig, r, g, b }
----------------------------------------------------------------
local TOTEMS = {
	-- wichtig (großes Icon mit Farbrahmen)
	[8143]  = { true, 1.00, 0.85, 0.10 },  -- Totem des Erdstoßes / Tremor
	[8177]  = { true, 0.65, 0.35, 1.00 },  -- Totem der Erdung / Grounding
	[8170]  = { true, 0.30, 0.85, 1.00 },  -- Totem der Reinigung / Cleansing
	[2484]  = { true, 0.70, 0.50, 0.25 },  -- Totem der Erdbindung / Earthbind
	[16190] = { true, 0.20, 0.55, 1.00 },  -- Totem der Manaflut / Mana Tide
	[2894]  = { true, 1.00, 0.40, 0.00 },  -- Totem des Feuerelementars
	[2062]  = { true, 0.70, 0.50, 0.25 },  -- Totem des Erdelementars
	[6495]  = { true, 0.80, 0.80, 0.80 },  -- Totem des Wachens / Sentry
	-- normal
	[8512]  = { false },  -- Totem des Windzorns
	[5675]  = { false },  -- Totem der Manaquelle
	[5394]  = { false },  -- Totem des heilenden Flusses
	[3599]  = { false },  -- Totem der Verbrennung
	[8190]  = { false },  -- Totem des glühenden Magmas
	[5730]  = { false },  -- Totem der Steinklaue
	[3738]  = { false },  -- Totem des stürmischen Zorns
	[30706] = { false },  -- Totem des Zorns
	[8227]  = { false },  -- Totem der Flammenzunge
	[8075]  = { false },  -- Totem der Erdstärke
	[8071]  = { false },  -- Totem der Steinhaut
	[8184]  = { false },  -- Totem des Feuerwiderstands
	[8181]  = { false },  -- Totem des Frostwiderstands
	[10595] = { false },  -- Totem des Naturwiderstands
}

----------------------------------------------------------------
-- PvP-Auren: [Spell-ID] = Kategorie
-- immune > stun > cc > silence > disarm > root > buff
----------------------------------------------------------------
local PVP_AURAS = {
	-- Immunitäten
	[642] = "immune",    -- Gottesschild
	[45438] = "immune",  -- Eisblock
	[1022] = "immune",   -- Hand des Schutzes
	[19263] = "immune",  -- Abschreckung
	[31224] = "immune",  -- Mantel der Schatten
	[48707] = "immune",  -- Antimagiehülle
	[47585] = "immune",  -- Dispersion
	[46924] = "immune",  -- Klingensturm
	[23920] = "immune",  -- Zauberreflexion

	-- Betäubungen
	[853] = "stun",      -- Hammer der Gerechtigkeit
	[1833] = "stun",     -- Fieser Trick
	[408] = "stun",      -- Nierenhieb
	[5211] = "stun",     -- Hieb
	[22570] = "stun",    -- Zerfleischen (Maim)
	[9005] = "stun",     -- Anspringen
	[12809] = "stun",    -- Erschütternder Schlag
	[46968] = "stun",    -- Schockwelle
	[24394] = "stun",    -- Einschüchterung
	[44572] = "stun",    -- Tiefkühlen
	[30283] = "stun",    -- Schattenfuror
	[47481] = "stun",    -- Nagen
	[20549] = "stun",    -- Kriegsdonner
	[7922] = "stun",     -- Sturmangriffsbetäubung
	[20253] = "stun",    -- Abfangen
	[12355] = "stun",    -- Einschlag
	[39796] = "stun",    -- Steinklauenbetäubung
	[12798] = "stun",    -- Rachebetäubung
	[50518] = "stun",    -- Verheeren (Ravager)

	-- Kontrollverlust
	[118] = "cc",        -- Verwandlung
	[6770] = "cc",       -- Kopfnuss
	[1776] = "cc",       -- Solarplexus
	[51514] = "cc",      -- Verhexen
	[20066] = "cc",      -- Buße
	[19503] = "cc",      -- Streuschuss
	[3355] = "cc",       -- Eiskältefalle
	[60210] = "cc",      -- Eiskältepfeil
	[19386] = "cc",      -- Wyverngift
	[2637] = "cc",       -- Winterschlaf
	[33786] = "cc",      -- Wirbelsturm
	[2094] = "cc",       -- Blenden
	[31661] = "cc",      -- Drachenodem
	[8122] = "cc",       -- Psychischer Schrei
	[5782] = "cc",       -- Furcht
	[5484] = "cc",       -- Schreckensgeheul
	[5246] = "cc",       -- Drohruf
	[20511] = "cc",      -- Drohruf (Effekt)
	[6358] = "cc",       -- Verführung
	[6789] = "cc",       -- Todesmantel
	[64044] = "cc",      -- Psychischer Horror
	[605] = "cc",        -- Gedankenkontrolle
	[10326] = "cc",      -- Untote vertreiben
	[710] = "cc",        -- Verbannen
	[9484] = "cc",       -- Untote fesseln
	[1513] = "cc",       -- Wildtier ängstigen

	-- Stille
	[15487] = "silence", -- Stille
	[1330] = "silence",  -- Erdrosseln - Stille
	[18425] = "silence", -- Verbesserter Tritt
	[47476] = "silence", -- Strangulieren
	[24259] = "silence", -- Zaubersperre
	[28730] = "silence", -- Arkaner Strom
	[34490] = "silence", -- Unterdrückender Schuss
	[18469] = "silence", -- Verbesserter Gegenzauber
	[55021] = "silence", -- Verbesserter Gegenzauber (Rang 2)
	[18498] = "silence", -- Knebelbefehl
	[63529] = "silence", -- Schild des Templers

	-- Entwaffnen
	[676] = "disarm",    -- Entwaffnen
	[51722] = "disarm",  -- Zerlegen
	[64346] = "disarm",  -- Feurige Rüstung (Entwaffnung)

	-- Bewegungsunfähig
	[122] = "root",      -- Frostnova
	[339] = "root",      -- Wucherwurzeln
	[33395] = "root",    -- Einfrieren (Elementar)
	[12494] = "root",    -- Frostbeulen
	[23694] = "root",    -- Verbesserte Kniesehne
	[55080] = "root",    -- Zerschmetterte Barriere
	[19185] = "root",    -- Fesselung
	[45334] = "root",    -- Wilde Attacke - Effekt

	-- wichtige Buffs
	[1044] = "buff",     -- Hand der Freiheit
	[6940] = "buff",     -- Hand der Opferung
	[33206] = "buff",    -- Schmerzunterdrückung
	[47788] = "buff",    -- Schutzgeist
	[48792] = "buff",    -- Eisige Gegenwehr
	[49039] = "buff",    -- Lichritter
	[5277] = "buff",     -- Entrinnen
	[22812] = "buff",    -- Baumrinde
	[871] = "buff",      -- Schildwall
	[498] = "buff",      -- Göttlicher Schutz
	[31821] = "buff",    -- Aurenbeherrschung
	[18499] = "buff",    -- Berserkerwut
	[7744] = "buff",     -- Wille der Verlassenen
	[29166] = "buff",    -- Anregen
	[10060] = "buff",    -- Seele der Macht
	[2825] = "buff",     -- Kampfrausch
	[32182] = "buff",    -- Heldentum
	[12292] = "buff",    -- Todeswunsch
	[12472] = "buff",    -- Eisige Adern
	[31884] = "buff",    -- Zornige Vergeltung
}

-- Lockout-Dauer je Unterbrechungszauber (Sekunden)
ns.LOCKOUTS = {
	[1766] = 5,   -- Tritt
	[2139] = 8,   -- Gegenzauber
	[6552] = 4,   -- Zuschlagen
	[72] = 6,     -- Schildhieb
	[47528] = 4,  -- Gedankenfrost
	[57994] = 2,  -- Windstoß
	[19244] = 5,  -- Zaubersperre (Rang 1)
	[19647] = 6,  -- Zaubersperre (Rang 2)
	[34490] = 3,  -- Unterdrückender Schuss
	[47476] = 5,  -- Strangulieren
	[15487] = 5,  -- Stille
	[26679] = 3,  -- Tödlicher Wurf (Glyphe)
	[25046] = 2,  -- Arkaner Strom
}

ns.AURA_PRIO = { immune = 1, stun = 2, cc = 3, custom = 3.5, silence = 4, disarm = 5, root = 6, buff = 7 }
ns.AURA_COLORS = {
	immune = { 1.00, 0.85, 0.00 },
	stun = { 1.00, 0.15, 0.15 },
	cc = { 0.75, 0.30, 1.00 },
	silence = { 0.30, 0.60, 1.00 },
	disarm = { 1.00, 0.55, 0.00 },
	root = { 0.30, 1.00, 0.30 },
	buff = { 0.00, 1.00, 0.70 },
	custom = { 1.00, 1.00, 1.00 },
	hot = { 0.30, 1.00, 0.30 },
}

----------------------------------------------------------------
-- Eigene Buffs/HoTs, die auf Freundes-Plaketten gezeigt werden
----------------------------------------------------------------
local MY_BUFFS = {
	774, 8936, 33763, 48438, 29166,      -- Verjüngung, Nachwachsen, Blühendes Leben, Wildwuchs, Anregen
	139, 41635, 17, 33206, 47788, 10060, -- Erneuerung, Gebet der Besserung, Machtwort: Schild, Schmerzunterdrückung, Schutzgeist, Machtinfusion
	61295, 974, 2825, 32182,             -- Springflut, Schild der Erde, Kampfrausch, Heldentum
	53563, 53601, 6940, 1044, 1022, 10278, -- Flamme des Glaubens, Heiliger Schild, Hand der Aufopferung, Hand der Freiheit, Hand des Schutzes
	34477, 57934,                        -- Irreführung, Tricks des Handwerks
	19752, 47440,                        -- Göttliche Intervention (Platzhalter), Befehlsruf
}

-- Kleintiere (Option "Critter ausblenden")
local CRITTERS = {
	{ "Rat", "Ratte" }, { "Rabbit", "Kaninchen" }, { "Squirrel", "Eichhörnchen" }, { "Cockroach", "Kakerlake" },
	{ "Frog", "Frosch" }, { "Toad", "Kröte" }, { "Snake", "Schlange" }, { "Deer", "Hirsch" }, { "Fawn", "Rehkitz" },
	{ "Cat", "Katze" }, { "Sheep", "Schaf" }, { "Chicken", "Huhn" }, { "Cow", "Kuh" }, { "Prairie Dog", "Präriehund" },
	{ "Beetle", "Käfer" }, { "Spider", "Spinne" }, { "Maggot", "Made" }, { "Larva", "Larve" }, { "Roach", "Schabe" },
	{ "Hare", "Hase" }, { "Mouse", "Maus" }, { "Crab", "Krabbe" }, { "Fire Beetle", "Feuerkäfer" }, { "Adder", "Natter" },
	{ "Moth", "Motte" }, { "Gazelle", "Gazelle" }, { "Parrot", "Papagei" }, { "Swine", "Schwein" }, { "Pig", "Schwein" },
	{ "Horse", "Pferd" }, { "Ram", "Widder" }, { "Penguin", "Pinguin" }, { "Huge Toad", "Riesenkröte" }, { "Borean Frog", "Boreanischer Frosch" },
	{ "Arctic Hare", "Arktischer Hase" }, { "Tundra Penguin", "Tundrapinguin" }, { "Glacier Penguin", "Gletscherpinguin" },
	{ "Steam Frog", "Dampffrosch" }, { "Lava Crab", "Lavakrabbe" }, { "Albino Snake", "Albinoschlange" }, { "Black Rat", "Schwarze Ratte" },
	{ "Dalaran Rat", "Dalaranratte" }, { "Sewer Rat", "Kanalratte" }, { "Scalawag Frog", "Halunkenfrosch" }, { "Shore Crab", "Uferkrabbe" },
}

----------------------------------------------------------------
-- Heiler-Erkennung: Zauber, die nur Heiler-Talentbäume haben
----------------------------------------------------------------
local HEALER_SPELLS = {
	47540,  -- Sühne (Disziplin)
	33206,  -- Schmerzunterdrückung
	34861,  -- Kreis der Heilung (Heilig)
	47788,  -- Schutzgeist
	724,    -- Brunnen des Lichts
	20473,  -- Heiliger Schock
	53563,  -- Flamme des Glaubens / Beacon of Light
	31842,  -- Göttliche Eingebung / Divine Illumination
	974,    -- Erdschild
	61295,  -- Springflut
	16190,  -- Totem der Manaflut
	48438,  -- Wildwuchs
	18562,  -- Rasche Heilung
	33891,  -- Baum des Lebens
}

----------------------------------------------------------------
-- Klassen-Icons (UI-CharacterCreate-Classes)
----------------------------------------------------------------
ns.CLASS_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
	DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 },
	SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 },
	WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
	DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
}

----------------------------------------------------------------
-- Wichtige NPCs / Begleiter (Namen, da Plaketten keine GUID haben):
-- { enUS, deDE, Icon-Spell, wichtig, r, g, b, pet }
-- pet = kleinere Plakette (Option "Begleiter kleiner")
----------------------------------------------------------------
local NPCS = {
	{ "Shadowfiend", "Schattenteufel", 34433, true, 0.43, 0.20, 1.00 },
	{ "Ebon Gargoyle", "Ebenholzgargoyle", 49206, true, 1.00, 0.69, 0.00 },
	{ "Lightwell", "Brunnen des Lichts", 724, true, 1.00, 0.95, 0.55 },
	{ "Greater Fire Elemental", "Großer Feuerelementar", 2894, true, 1.00, 0.23, 0.00 },
	{ "Greater Earth Elemental", "Großer Erdelementar", 2062, true, 0.78, 0.51, 0.39 },
	{ "Water Elemental", "Wasserelementar", 31687, false, 0.25, 1.00, 0.83, true },
	{ "Mirror Image", "Spiegelbild", 55342, false, 0.41, 0.80, 0.94, true },
	{ "Army of the Dead Ghoul", "Ghul der Armee der Toten", 42650, false, 0.77, 0.12, 0.23, true },
	{ "Risen Ghoul", "Erweckter Ghul", 46584, false, 0.77, 0.12, 0.23, true },
	{ "Treant", "Treant", 33831, false, 1.00, 0.49, 0.04, true },
	{ "Spirit Wolf", "Geisterwolf", 51533, false, 0.14, 0.35, 1.00, true },
	{ "Venomous Snake", "Giftschlange", 34600, false, 0.67, 0.83, 0.45, true },
	{ "Viper", "Viper", 34600, false, 0.67, 0.83, 0.45, true },
	{ "Infernal", "Höllenbestie", 1122, false, 0.58, 0.51, 0.79 },
	{ "Doomguard", "Verdammniswache", 18540, false, 0.58, 0.51, 0.79 },
	{ "Explosive Decoy", "Explosiver Köder", 0, false, 1, 1, 1, true },
}

----------------------------------------------------------------
-- Aufbau der Namens-Tabellen (beim Login)
----------------------------------------------------------------
function ns:BuildData()
	ns.totemsByName = {}
	for id, info in pairs(TOTEMS) do
		local name, _, icon = GetSpellInfo(id)
		if name then
			ns.totemsByName[name] = {
				icon = icon,
				important = info[1],
				r = info[2] or 1, g = info[3] or 1, b = info[4] or 1,
			}
		end
	end

	for _, n in ipairs(NPCS) do
		local _, _, icon = GetSpellInfo(n[3])
		local info = { icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark", important = n[4], r = n[5], g = n[6], b = n[7], pet = n[8] or false, npc = true }
		ns.totemsByName[n[1]] = info
		ns.totemsByName[n[2]] = info
	end

	ns.pvpAuras = {}
	for id, cat in pairs(PVP_AURAS) do
		local name = GetSpellInfo(id)
		if name then
			local old = ns.pvpAuras[name]
			if not old or ns.AURA_PRIO[cat] < ns.AURA_PRIO[old] then
				ns.pvpAuras[name] = cat
			end
		end
	end

	ns.healerSpells = {}
	for _, id in ipairs(HEALER_SPELLS) do
		local name = GetSpellInfo(id)
		if name then ns.healerSpells[name] = true end
	end

	ns.myBuffs = ns.myBuffs or {}
	wipe(ns.myBuffs)
	for _, id in ipairs(MY_BUFFS) do
		local name = GetSpellInfo(id)
		if name then ns.myBuffs[name] = true end
	end

	ns.critters = {}
	for _, c in ipairs(CRITTERS) do
		ns.critters[c[1]:lower()] = true
		ns.critters[c[2]:lower()] = true
	end

	ns:BuildRaidNpcs()
	ns:ResolveDispel()
end

-- Raid-NPC-Liste (GameData) + eigene Einträge ("Name" oder "Name:1")
function ns:BuildRaidNpcs()
	ns.raidNpc = {}
	if ns.RAID_NPCS then
		for _, n in ipairs(ns.RAID_NPCS) do
			local prio = n[4] or 2
			if n[1] then ns.raidNpc[n[1]:lower()] = prio end
			if n[2] then ns.raidNpc[n[2]:lower()] = prio end
		end
	end
	local custom = ns.db and ns.db.raidNpcCustom
	if type(custom) == "string" then
		for token in custom:gmatch("[^,;\n]+") do
			local name, prio = token:match("^%s*(.-)%s*:%s*(%d)%s*$")
			if not name then name = token:gsub("^%s+", ""):gsub("%s+$", "") prio = "1" end
			if name ~= "" then ns.raidNpc[name:lower()] = tonumber(prio) == 2 and 2 or 1 end
		end
	end
end

-- Was kann meine Klasse entzaubern? (Dispel-Matrix aus GameData + Talente)
function ns:ResolveDispel()
	ns.canDispel = {}
	local _, class = UnitClass("player")
	local m = ns.DISPEL and ns.DISPEL[class]
	if m then
		for k, v in pairs(m) do ns.canDispel[k] = v end
	end
	-- Talente/Zauber prüfen: Schamane "Geist reinigen" (Fluch), Druide? nichts weiter
	if class == "SHAMAN" then
		local name = GetSpellInfo(51886)
		ns.canDispel.Curse = (name and GetSpellInfo(name)) and true or false
	end
	-- Jeder kann es sehen, wenn "alle anzeigen" aktiv ist (siehe Option dispelAll)
end

-- "Totem der Manaquelle VIII" -> "Totem der Manaquelle"
function ns.TotemInfo(name)
	if not name or not ns.totemsByName then return end
	local base = name:gsub("%s+[IVXL]+$", "")
	return ns.totemsByName[base]
end
