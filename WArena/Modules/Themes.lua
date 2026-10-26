-- WArena: themes – presets that set a group of look-related settings at once
local _, ns = ...
local Themes = ns:NewModule("Themes")
ns.Themes = Themes

ns:AddDefaults({ theme = "Classic", preset = "PvP – Arena" })

-- every theme lists the settings it changes; everything else stays as it is
ns.ThemeList = {
	{
		name = "Classic", desc = "Blizzard status bar texture, dark background, thin black border.",
		settings = {
			texture = "Blizzard", font = "Friz Quadrata", fontOutline = "OUTLINE", fontShadow = false,
			bgAlpha = 0.6, borderStyle = "thin", borderColor = { r = 0, g = 0, b = 0, a = 1 },
			classcolor = true, healthGradient = false, iconStyle = "blizzard", mirror = false,
			healthBg = { r = 0, g = 0, b = 0, a = 0.55 }, powerBg = { r = 0, g = 0, b = 0, a = 0.55 },
			castColor = { r = 1, g = 0.75, b = 0, a = 1 }, targetColor = { r = 1, g = 0.85, b = 0, a = 1 },
			focusColor = { r = 0.3, g = 0.6, b = 1, a = 1 }, powerBar = true, powerHeight = 8,
		},
	},
	{
		name = "Modern", desc = "Flat bars, 1 px border, class colors, slightly larger text with shadow.",
		settings = {
			texture = "Flat", font = "Arial Narrow", fontOutline = "OUTLINE", fontShadow = true, fontSize = 12,
			bgAlpha = 0.75, borderStyle = "thin", borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 },
			classcolor = true, healthGradient = false, iconStyle = "crop", mirror = false,
			healthBg = { r = 0.12, g = 0.12, b = 0.12, a = 0.9 }, powerBg = { r = 0.12, g = 0.12, b = 0.12, a = 0.9 },
			castColor = { r = 0.9, g = 0.65, b = 0.1, a = 1 }, targetColor = { r = 1, g = 1, b = 1, a = 1 },
			focusColor = { r = 0.2, g = 0.8, b = 1, a = 1 }, powerBar = true, powerHeight = 5,
		},
	},
	{
		name = "Minimal", desc = "No backgrounds or borders, bars only, small power bar.",
		settings = {
			texture = "Flat", font = "Friz Quadrata", fontOutline = "OUTLINE", fontShadow = false,
			bgAlpha = 0, borderStyle = "none", classcolor = true, healthGradient = false, iconStyle = "crop",
			healthBg = { r = 0, g = 0, b = 0, a = 0.25 }, powerBg = { r = 0, g = 0, b = 0, a = 0.25 },
			powerBar = true, powerHeight = 3, arenaId = false, mirror = false,
		},
	},
	{
		name = "Gladius", desc = "Compact rows, icons on the left, cast bar below, green health with gradient.",
		settings = {
			texture = "Smooth", font = "Friz Quadrata", fontOutline = "OUTLINE", fontShadow = false,
			bgAlpha = 0.7, borderStyle = "thin", borderColor = { r = 0, g = 0, b = 0, a = 1 },
			classcolor = false, healthGradient = true, iconStyle = "blizzard", mirror = true,
			iconSide = "left", drPos = "left", cdPos = "below", castPos = "below", castHeight = 12,
			width = 200, height = 34, spacing = 18, powerBar = true, powerHeight = 6,
			healthBg = { r = 0, g = 0, b = 0, a = 0.6 }, powerBg = { r = 0, g = 0, b = 0, a = 0.6 },
		},
	},
	{
		name = "Glass", desc = "Glossy bars with thick dark border and large interrupt-friendly cast bar.",
		settings = {
			texture = "Glass", font = "Friz Quadrata", fontOutline = "THICKOUTLINE", fontShadow = false, fontSize = 12,
			bgAlpha = 0.5, borderStyle = "thick", borderColor = { r = 0, g = 0, b = 0, a = 1 },
			classcolor = true, healthGradient = false, iconStyle = "blizzard", mirror = false,
			castPos = "below", castHeight = 18, castIcon = true, powerBar = true, powerHeight = 8,
			healthBg = { r = 0, g = 0, b = 0, a = 0.5 }, powerBg = { r = 0, g = 0, b = 0, a = 0.5 },
		},
	},
}

---------------------------------------------------------------------------
-- presets: which modules are active for a play style (look is untouched)
---------------------------------------------------------------------------
ns.PresetList = {
	{
		name = "PvP – Arena", desc = "Everything for arena: frames, DR, cooldowns, totems, indicators, HUD, announcements, nameplate numbers. Boss frames off.",
		settings = {
			trinket = true, racial = true, trinketReadyGlow = true, aura = true, auraRow = false, dr = true, cooldowns = true,
			cdShowReady = true, totems = true, castbar = true, pets = true, healer = "last", healerIcon = true,
			indTargetingYou = true, indPartyTargets = true, indEnemyTarget = true, indRange = true, indDrink = true,
			indStealth = true, indLowHP = true, plates = true, plateSpec = true,
			announce = true, annInArenaOnly = true, annSounds = true,
			ann_trinket = "screen", ann_drink = "party", ann_lowhp = "screen", ann_resurrect = "party", ann_spec = "self",
			ann_healer = "self", ann_enemyTeam = "self", ann_shadowsight = "screen", ann_gates = "screen",
			hud = true, hudPrep = true, hudMatch = true, hudShadowSight = true,
			bgEnabled = true, bossEnabled = false, historyEnabled = true, specMemory = true,
		},
	},
	{
		name = "PvP – Battleground", desc = "Battleground focus: enemy list with healers first and flag carrier, leaner arena frames, no HUD.",
		settings = {
			bgEnabled = true, bgSort = "role", bgShowRole = true, bgShowHealth = true, bgShowSpec = true, bgHeader = true,
			bgShowFriendlyFC = true, bgColumns = 2, bgMaxRows = 20,
			announce = true, annInArenaOnly = true, ann_flag = "screen", ann_drink = "none", ann_lowhp = "none",
			ann_trinket = "self", ann_shadowsight = "none", ann_gates = "none",
			hud = false, plates = false, totems = false, cooldowns = true, cdMax = 4, dr = true, indRange = false,
			bossEnabled = false, historyEnabled = true,
		},
	},
	{
		name = "PvE – Raid", desc = "Dungeon & raid: boss frames with cast bar, boss target and party targets; all PvP modules and alerts off.",
		settings = {
			bossEnabled = true, bossHideBlizzard = true, boss_indTargetingYou = true, boss_indPartyTargets = true,
			boss_indEnemyTarget = true, boss_healthText = "both", boss_castPos = "below",
			announce = false, hud = false, plates = false, bgEnabled = false,
			cooldowns = false, totems = false, dr = false, auraRow = false, indRange = false,
			historyEnabled = false,
		},
	},
}

function Themes:GetPreset(name)
	for _, p in ipairs(ns.PresetList) do
		if p.name == name then return p end
	end
end

function Themes:ApplyPreset(name)
	local p = self:GetPreset(name)
	if not p then return false end
	local db = ns.db
	for k, v in pairs(p.settings) do
		db[k] = ns.CopyValue(v)
	end
	db.preset = name
	for _, mod in ipairs(ns.modules) do
		if mod.OnProfileChanged then mod:OnProfileChanged() end
	end
	ns:Layout()
	ns:Fire("PRESET_APPLIED", name)
	return true
end

function Themes:Get(name)
	for _, t in ipairs(ns.ThemeList) do
		if t.name == name then return t end
	end
end

function Themes:Names()
	local out = {}
	for _, t in ipairs(ns.ThemeList) do out[#out + 1] = t.name end
	return out
end

function Themes:Apply(name)
	local t = self:Get(name)
	if not t then return false end
	local db = ns.db
	for k, v in pairs(t.settings) do
		db[k] = ns.CopyValue(v)
	end
	db.theme = name
	for _, mod in ipairs(ns.modules) do
		if mod.OnProfileChanged then mod:OnProfileChanged() end
	end
	ns:Layout()
	ns:Fire("THEME_APPLIED", name)
	return true
end

-- border/outline option lists used by the options panels
ns.BorderStyles = { { "none", "None" }, { "thin", "Thin (1 px)" }, { "thick", "Thick (2 px)" }, { "glow", "Glow" } }
ns.OutlineStyles = { { "NONE", "None" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick outline" }, { "MONOCHROME,OUTLINE", "Monochrome" } }
ns.IconStyles = { { "blizzard", "Blizzard" }, { "crop", "Cropped" } }

ns:AddCommand("preset", "apply a preset: /warena preset arena | bg | raid", function(arg)
	arg = ns:Trim(arg):lower()
	local map = { arena = "PvP – Arena", bg = "PvP – Battleground", battleground = "PvP – Battleground", raid = "PvE – Raid", pve = "PvE – Raid" }
	local name = map[arg]
	if not name then ns:Print("Presets: arena, bg, raid") return end
	Themes:ApplyPreset(name)
	ns:Print("Preset '%s' applied.", name)
end)

ns:AddCommand("theme", "apply a theme: /warena theme <name>", function(arg)
	arg = ns:Trim(arg)
	if arg == "" then
		ns:Print("Themes: " .. table.concat(Themes:Names(), ", "))
		return
	end
	for _, t in ipairs(ns.ThemeList) do
		if t.name:lower() == arg:lower() then
			Themes:Apply(t.name)
			ns:Print("Theme '%s' applied.", t.name)
			return
		end
	end
	ns:Print("Unknown theme '%s'.", arg)
end)
