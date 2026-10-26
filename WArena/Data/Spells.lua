-- WArena: spell data for WotLK 3.3.5a
-- All lists use spell IDs; at load time GetSpellInfo turns them into the (client-localized)
-- names, so every rank of a spell matches. Unknown/invalid IDs are simply ignored.

local _, ns = ...

ns.HAS_MEDIA_FOLDER = true

---------------------------------------------------------------------------
-- Diminishing returns
---------------------------------------------------------------------------
ns.DROrder = { "stun", "fear", "disorient", "scatter", "horror", "silence", "root", "cyclone", "charm", "disarm" }
ns.DRLabels = {
	stun = "Stuns", fear = "Fears (incl. Blind)", disorient = "Disorients (Poly, Sap, Gouge, Hex, Traps...)",
	scatter = "Scatter Shot / Dragon's Breath", horror = "Horror (Death Coil, Psychic Horror)",
	silence = "Silences", root = "Roots", cyclone = "Cyclone", charm = "Mind Control", disarm = "Disarms",
}

ns.DRSpells = {
	stun = {
		853, 5588, 5589, 10308, -- Hammer of Justice
		1833, 408, 8643,        -- Cheap Shot, Kidney Shot
		5211, 6798, 8983,       -- Bash
		22570, 49802,           -- Maim
		9005, 9823, 9827, 27006, 49803, -- Pounce
		12809,                  -- Concussion Blow
		46968,                  -- Shockwave
		24394,                  -- Intimidation (pet stun)
		30283, 30413, 30414, 47846, 47847, -- Shadowfury
		20549,                  -- War Stomp
		44572,                  -- Deep Freeze
		47481,                  -- Gnaw (ghoul)
		50519, 53564, 53565, 53566, 53567, 53568, -- Sonic Blast (pet)
		56626,                  -- Sting (wasp pet)
		20253, 20614, 20615, 25273, 25274, -- Intercept stun
		12798,                  -- Revenge stun
		5530,                   -- Mace stun effect
	},
	fear = {
		5782, 6213, 6215,       -- Fear
		5484, 17928,            -- Howl of Terror
		8122, 8124, 10888, 10890, -- Psychic Scream
		6358,                   -- Seduction
		5246,                   -- Intimidating Shout
		1513, 14326, 14327,     -- Scare Beast
		10326,                  -- Turn Evil
		2094,                   -- Blind
	},
	disorient = {
		118, 12824, 12825, 12826, 28271, 28272, 61305, 61025, 61721, 61780, -- Polymorph variants
		1776, 1777, 8629, 11285, 11286, 38764, 38863, -- Gouge
		6770, 2070, 11297, 51724, -- Sap
		20066,                  -- Repentance
		3355, 14308, 14309,     -- Freezing Trap Effect
		60210,                  -- Freezing Arrow Effect
		19386, 24132, 24133, 27068, 49011, 49012, -- Wyvern Sting
		49203,                  -- Hungering Cold
		51514,                  -- Hex
		710, 18647,             -- Banish (own DR in reality, grouped here)
		9484, 9485, 10955,      -- Shackle Undead
	},
	scatter = {
		19503,                  -- Scatter Shot
		31661, 33041, 33042, 33043, 42949, 42950, -- Dragon's Breath
	},
	horror = {
		6789, 17925, 17926, 27223, 47859, 47860, -- Death Coil (warlock)
		64044,                  -- Psychic Horror
	},
	silence = {
		15487,                  -- Silence
		1330,                   -- Garrote - Silence
		18469,                  -- Silenced - Improved Counterspell
		24259,                  -- Spell Lock
		47476,                  -- Strangulate
		34490,                  -- Silencing Shot
		28730, 25046, 50613,    -- Arcane Torrent
		18498,                  -- Silenced - Gag Order
		63529,                  -- Silenced - Shield of the Templar
		55021,                  -- Silenced - Improved Counterspell (rank 2)
		31117,                  -- Unstable Affliction silence
	},
	root = {
		122, 865, 6131, 10230, 27088, 42917, -- Frost Nova
		339, 1062, 5195, 5196, 9852, 9853, 26989, 53308, -- Entangling Roots
		19975, 19974, 19973, 19972, 19971, 19970, 27010, 53313, -- Nature's Grasp roots
		33395,                  -- Freeze (water elemental)
		50245, 53544, 53545, 53546, 53547, 53548, -- Pin (pet)
		64695,                  -- Earthgrab
		4167,                   -- Web (spider pet)
		50518, 53561, 53562, 53563, 53564, -- Venom Web Spray
		13810,                  -- Frost Trap aura? (slow, not root) – harmless if wrong
		45334,                  -- Feral Charge effect
		19185, 64803, 64804,    -- Entrapment
		55080,                  -- Shattered Barrier
		63685,                  -- Freeze (Frozen Power)
		12494,                  -- Frostbite
	},
	cyclone = { 33786 },
	charm = { 605, 10911, 10912 },
	disarm = {
		676,                    -- Disarm
		51722,                  -- Dismantle
		64058,                  -- Psychic Horror disarm
		53359,                  -- Chimera Shot - Scorpid
		50541,                  -- Snatch (bird pet)
	},
}

---------------------------------------------------------------------------
-- Auras shown on the class icon, grouped into toggleable categories
---------------------------------------------------------------------------
local function drcats(...)
	local ids = {}
	for _, cat in ipairs({ ... }) do
		for _, id in ipairs(ns.DRSpells[cat]) do ids[#ids + 1] = id end
	end
	return ids
end

ns.AuraCategories = {
	{ key = "Immune",    label = "Immunities",          prio = 100,
		ids = { 642, 1020, 45438, 19263, 46924, 1022, 5599, 10278, 33786, 710, 18647, 34692, 47585, 31224 } },
	{ key = "CC",        label = "Crowd control",       prio = 90,
		ids = drcats("stun", "fear", "disorient", "scatter", "horror", "charm") },
	{ key = "Silence",   label = "Silences",            prio = 80,
		ids = drcats("silence") },
	{ key = "Defensive", label = "Defensive cooldowns", prio = 75,
		ids = { 48707, 23920, 8178, 33206, 47788, 22812, 871, 5277, 26669, 498, 5573, 48792, 61336, 6940, 1044, 31821, 64205,
			17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218, 48065, 48066, -- PW:Shield ranks
			29166, 12975, 55694, 30823, 49039, 55233, 51271, 51052, 20594, 47891, 16190, 22842, 5384, 66, 1856, 1857, 26889 } },
	{ key = "Root",      label = "Roots / Disarm",      prio = 60,
		ids = drcats("root", "disarm") },
	{ key = "Offensive", label = "Offensive cooldowns", prio = 30,
		ids = { 1719, 31884, 13750, 12042, 12472, 51690, 12292, 47241, 49016, 33831, 10060, 16166, 3045, 14177, 51713,
			19574, 34471, 50334, 49028, 49206, 55342, 11129, 12043, 17116, 16188, 2825, 32182, 53201, 48505, 51533, 2894 } },
}

---------------------------------------------------------------------------
-- PvP trinket / racials / drinks / resurrects / flags
---------------------------------------------------------------------------
ns.TrinketSpells = { 42292, 59752 }
ns.TRINKET_CD = 120

-- key = English race token from UnitRace
ns.Racials = {
	Human    = { id = 59752, cd = 120 }, -- Every Man for Himself
	Scourge  = { id = 7744,  cd = 120 }, -- Will of the Forsaken
	Dwarf    = { id = 20594, cd = 120 }, -- Stoneform
	Gnome    = { id = 20589, cd = 105 }, -- Escape Artist
	NightElf = { id = 58984, cd = 120 }, -- Shadowmeld
	Draenei  = { id = 28880, cd = 180 }, -- Gift of the Naaru
	Orc      = { id = 20572, cd = 120 }, -- Blood Fury
	Tauren   = { id = 20549, cd = 120 }, -- War Stomp
	Troll    = { id = 26297, cd = 180 }, -- Berserking
	BloodElf = { id = 28730, cd = 120 }, -- Arcane Torrent
}

ns.DrinkSpells = { 430, 431, 432, 1133, 1135, 1137, 10250, 22734, 27089, 34291, 43182, 43183, 46755, 49472, 57073, 61830, 64056, 65363, 72623, 24355, 25696, 26263, 43706, 46289 }
ns.ResurrectSpells = { 2006, 2010, 10880, 10881, 20770, 25435, 48171, -- Resurrection
	7328, 10322, 10324, 20772, 20773, 48949, 48950,                     -- Redemption
	2008, 20609, 20610, 20776, 20777, 25590, 49277,                      -- Ancestral Spirit
	50769, 50768, 50767, 50766, 50765, 50764, 50763,                     -- Revive
	20484, 20739, 20742, 20747, 20748, 26994, 48477 }                    -- Rebirth

ns.FlagSpells = {
	[23333] = "Horde",    -- Warsong Flag (carried by Horde)
	[23335] = "Alliance", -- Silverwing Flag (carried by Alliance)
	[34976] = "Neutral",  -- Netherstorm Flag
}

-- spells (or classes) commonly used to check range from the player's side: class -> spell id list
-- (targeted, 30+ yd, no minimum range, usable in any stance/form where possible)
ns.RangeSpells = {
	WARRIOR = { 64382, 355, 1161 },      -- Shattering Throw, Taunt, Challenging Shout
	PALADIN = { 62124, 20271, 853 },     -- Hand of Reckoning, Judgement, HoJ
	HUNTER = { 1130, 19434, 3044 },      -- Hunter's Mark (100 yd), Aimed Shot, Arcane Shot
	ROGUE = { 48674, 2094, 1725 },       -- Deadly Throw, Blind, Distract
	PRIEST = { 589, 585, 2061 },         -- SW:P, Smite, Flash Heal
	DEATHKNIGHT = { 47541, 49576, 45524 }, -- Death Coil, Death Grip, Chains of Ice
	SHAMAN = { 403, 8042, 51514 },       -- Lightning Bolt, Earth Shock, Hex
	MAGE = { 133, 116, 118 },            -- Fireball, Frostbolt, Polymorph
	WARLOCK = { 686, 172, 5782 },        -- Shadow Bolt, Corruption, Fear
	DRUID = { 770, 5176, 8921 },         -- Faerie Fire, Wrath, Moonfire
}

---------------------------------------------------------------------------
-- Spec detection via talent spells and talent auras (3.3.5 has no spec API for enemies)
---------------------------------------------------------------------------
ns.HealerSpecs = { Holy = true, Discipline = true, Restoration = true }

ns.SpecSpells = {
	WARRIOR = {
		Arms = { 12294, 46924, 12328, 60503, 46857, 64976 },
		Fury = { 23881, 29801, 12292, 60970, 46916, 12880 },
		Protection = { 20243, 46968, 50720, 12809, 12975, 57499 },
	},
	PALADIN = {
		Holy = { 20473, 53563, 31842, 20216, 31834, 31821, 53655, 53656, 53657 },
		Retribution = { 35395, 53385, 20066, 20375, 59578, 20049, 31884 },
		Protection = { 53595, 31935, 20925, 64205, 20911, 31850 },
	},
	HUNTER = {
		Marksmanship = { 53209, 19434, 34490, 23989, 19506, 53220 },
		Survival = { 53301, 19386, 3674, 19306, 34501, 19503, 60192 },
		["Beast Mastery"] = { 19574, 19577, 34471, 19615, 56315 },
	},
	ROGUE = {
		Assassination = { 1329, 14177, 51662, 58426, 31233 },
		Combat = { 51690, 13877, 13750, 14251, 14278, 5171 },
		Subtlety = { 36554, 51713, 16511, 14183, 14185, 31228, 31665 },
	},
	PRIEST = {
		Discipline = { 47540, 33206, 10060, 47753, 59887, 59889, 47755, 52798, 63944 },
		Holy = { 47788, 34861, 724, 33151, 63731, 63734, 47750 },
		Shadow = { 34914, 47585, 15473, 15487, 64044, 15286, 15407, 48160, 15290 },
	},
	DEATHKNIGHT = {
		Blood = { 55050, 49016, 49005, 49028, 55233, 48982, 50371, 49222 },
		Frost = { 49184, 49143, 49203, 51271, 51411, 50401, 49039 },
		Unholy = { 55090, 49206, 49158, 51052, 63560, 50536, 49224, 51271 },
	},
	SHAMAN = {
		Elemental = { 51490, 16166, 30706, 16246, 51470, 59159 },
		Enhancement = { 17364, 60103, 51533, 30823, 53817, 16280, 51530 },
		Restoration = { 974, 61295, 16190, 16188, 55198, 51886, 16237, 51562, 51945 },
	},
	MAGE = {
		Arcane = { 44425, 12042, 12043, 31589, 44781, 36032, 12536 },
		Fire = { 44457, 31661, 11113, 11129, 11366, 48108, 11119, 44448 },
		Frost = { 44572, 11426, 31687, 11958, 12472, 44544, 57761, 12494, 11071, 55080 },
	},
	WARLOCK = {
		Affliction = { 48181, 30108, 18223, 18220, 30405, 63321 },
		Demonology = { 47241, 47193, 19028, 30146, 47243, 47283 },
		Destruction = { 50796, 17962, 30283, 54277, 34936, 17877, 18871 },
	},
	DRUID = {
		Balance = { 48505, 50516, 24858, 24907, 33831, 5570, 48468, 48525, 16870 },
		Feral = { 33876, 33878, 50334, 16979, 49376, 61336, 24932, 48566, 48572, 50213 },
		Restoration = { 48438, 18562, 33891, 17116, 48443, 34123, 45283, 16188 },
	},
}

-- spec -> short label and role
ns.SpecRole = {
	Holy = "HEALER", Discipline = "HEALER", Restoration = "HEALER",
	Protection = "TANK", Blood = "TANK",
}

---------------------------------------------------------------------------
-- enemy pets worth showing (owner class -> true), everything else is hidden
---------------------------------------------------------------------------
ns.PetClasses = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true, MAGE = true }

---------------------------------------------------------------------------
-- name lookups (built once GetSpellInfo is available)
---------------------------------------------------------------------------
ns.Lookup = { dr = {}, aura = {}, spec = {}, racial = {}, trinket = {}, drink = {}, resurrect = {}, flag = {} }

function ns:BuildSpellLookups()
	local LK = ns.Lookup
	for cat, ids in pairs(ns.DRSpells) do
		for _, id in ipairs(ids) do
			local name = GetSpellInfo(id)
			if name and not LK.dr[name] then LK.dr[name] = cat end
		end
	end
	for _, c in ipairs(ns.AuraCategories) do
		for _, id in ipairs(c.ids) do
			local name = GetSpellInfo(id)
			if name and (not LK.aura[name] or LK.aura[name].prio < c.prio) then LK.aura[name] = c end
		end
	end
	for class, specs in pairs(ns.SpecSpells) do
		for spec, ids in pairs(specs) do
			for _, id in ipairs(ids) do
				local name = GetSpellInfo(id)
				if name then
					LK.spec[name] = LK.spec[name] or {}
					LK.spec[name][class] = spec
				end
			end
		end
	end
	for race, info in pairs(ns.Racials) do
		local name, _, icon = GetSpellInfo(info.id)
		if name then
			info.name, info.icon, info.race = name, icon, race
			LK.racial[name] = info
		end
	end
	for _, id in ipairs(ns.TrinketSpells) do
		local name = GetSpellInfo(id)
		if name then LK.trinket[name] = true end
	end
	for _, id in ipairs(ns.DrinkSpells) do
		local name = GetSpellInfo(id)
		if name then LK.drink[name] = true end
	end
	for _, id in ipairs(ns.ResurrectSpells) do
		local name = GetSpellInfo(id)
		if name then LK.resurrect[name] = true end
	end
	for id, side in pairs(ns.FlagSpells) do
		local name = GetSpellInfo(id)
		if name then LK.flag[name] = side end
	end
end

-- spell/aura name -> spec, checked against the unit's class
function ns:LookupSpec(class, name)
	local t = ns.Lookup.spec[name]
	if not t then return end
	if class then return t[class] end
	local only, n = nil, 0
	for _, sp in pairs(t) do only, n = sp, n + 1 end
	if n == 1 then return only end
end
