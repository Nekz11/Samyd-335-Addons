-- WArena: enemy cooldown database (WotLK 3.3.5a, base cooldowns without talents/glyphs)
-- cd      = base cooldown in seconds
-- cat     = category key (see ns.CDCategories)
-- ids     = every rank / alternative spell id that triggers this cooldown
-- active  = buff duration, the icon glows while active
-- talent  = talent ability (only exists on some specs; shown once seen)
-- prio    = sort priority inside the row (lower = further left); defaults per category

local _, ns = ...

ns.CDCategories = {
	{ key = "interrupt", label = "Interrupts",          prio = 1 },
	{ key = "defensive", label = "Defensive cooldowns", prio = 2 },
	{ key = "external",  label = "External defensives", prio = 3 },
	{ key = "offensive", label = "Offensive cooldowns", prio = 4 },
	{ key = "cc",        label = "Crowd control",       prio = 5 },
	{ key = "utility",   label = "Utility / mobility",  prio = 6 },
	{ key = "heal",      label = "Big heals / mana",    prio = 7 },
}

local DB = {}
ns.CooldownDB = DB

local function add(class, id, cd, cat, opts)
	local e = { id = id, class = class, cd = cd, cat = cat }
	if opts then for k, v in pairs(opts) do e[k] = v end end
	DB[#DB + 1] = e
end

-- WARRIOR
add("WARRIOR", 6552, 10, "interrupt", { ids = { 6552, 6554 } })                -- Pummel
add("WARRIOR", 72, 12, "interrupt", { ids = { 72, 1671, 1672, 29704 } })        -- Shield Bash
add("WARRIOR", 871, 300, "defensive", { active = 12 })                          -- Shield Wall
add("WARRIOR", 12975, 180, "defensive", { talent = true, active = 20 })         -- Last Stand
add("WARRIOR", 23920, 10, "defensive", { active = 5 })                          -- Spell Reflection
add("WARRIOR", 55694, 180, "defensive", { active = 10 })                        -- Enraged Regeneration
add("WARRIOR", 3411, 30, "utility")                                             -- Intervene
add("WARRIOR", 100, 15, "utility", { ids = { 100, 6178, 11578 } })              -- Charge
add("WARRIOR", 20252, 30, "utility", { ids = { 20252, 20616, 20617, 25272, 25275 } }) -- Intercept
add("WARRIOR", 5246, 120, "cc")                                                 -- Intimidating Shout
add("WARRIOR", 46968, 20, "cc", { talent = true })                              -- Shockwave
add("WARRIOR", 12809, 30, "cc", { talent = true })                              -- Concussion Blow
add("WARRIOR", 1719, 300, "offensive", { active = 12 })                         -- Recklessness
add("WARRIOR", 12292, 180, "offensive", { talent = true, active = 30 })         -- Death Wish
add("WARRIOR", 64382, 300, "offensive")                                         -- Shattering Throw
add("WARRIOR", 46924, 90, "offensive", { talent = true, active = 6 })           -- Bladestorm
add("WARRIOR", 676, 60, "cc")                                                   -- Disarm
add("WARRIOR", 18499, 30, "utility", { active = 10 })                           -- Berserker Rage
add("WARRIOR", 2565, 60, "defensive", { active = 10 })                          -- Shield Block

-- PALADIN
add("PALADIN", 642, 300, "defensive", { ids = { 642, 1020 }, active = 12 })     -- Divine Shield
add("PALADIN", 498, 180, "defensive", { ids = { 498, 5573 }, active = 12 })     -- Divine Protection
add("PALADIN", 10278, 300, "external", { ids = { 1022, 5599, 10278 }, active = 10 }) -- Hand of Protection
add("PALADIN", 6940, 120, "external", { active = 12 })                          -- Hand of Sacrifice
add("PALADIN", 48788, 1200, "heal", { ids = { 633, 2800, 10310, 27154, 48788 } }) -- Lay on Hands
add("PALADIN", 31821, 120, "external", { talent = true, active = 6 })           -- Aura Mastery
add("PALADIN", 64205, 120, "external", { talent = true, active = 10 })          -- Divine Sacrifice
add("PALADIN", 1044, 25, "utility", { active = 10 })                            -- Hand of Freedom
add("PALADIN", 10308, 60, "cc", { ids = { 853, 5588, 5589, 10308 } })           -- Hammer of Justice
add("PALADIN", 20066, 60, "cc", { talent = true })                              -- Repentance
add("PALADIN", 31884, 180, "offensive", { active = 20 })                        -- Avenging Wrath
add("PALADIN", 31842, 180, "heal", { talent = true, active = 15 })              -- Divine Illumination
add("PALADIN", 20216, 120, "heal", { talent = true })                           -- Divine Favor
add("PALADIN", 54428, 60, "heal")                                               -- Divine Plea
add("PALADIN", 10326, 30, "cc")                                                 -- Turn Evil
add("PALADIN", 31935, 30, "utility", { talent = true, ids = { 31935, 32699, 32700, 48826, 48827 } }) -- Avenger's Shield

-- DEATH KNIGHT
add("DEATHKNIGHT", 47528, 10, "interrupt")                                      -- Mind Freeze
add("DEATHKNIGHT", 47476, 120, "interrupt")                                     -- Strangulate
add("DEATHKNIGHT", 48792, 120, "defensive", { active = 12 })                    -- Icebound Fortitude
add("DEATHKNIGHT", 48707, 45, "defensive", { active = 5 })                      -- Anti-Magic Shell
add("DEATHKNIGHT", 55233, 60, "defensive", { talent = true, active = 10 })      -- Vampiric Blood
add("DEATHKNIGHT", 49039, 120, "defensive", { talent = true, active = 10 })     -- Lichborne
add("DEATHKNIGHT", 51271, 60, "defensive", { talent = true, active = 20 })      -- Unbreakable Armor
add("DEATHKNIGHT", 51052, 120, "external", { talent = true, active = 10 })      -- Anti-Magic Zone
add("DEATHKNIGHT", 49016, 180, "offensive", { talent = true, active = 30 })     -- Hysteria
add("DEATHKNIGHT", 49028, 90, "offensive", { talent = true, active = 12 })      -- Dancing Rune Weapon
add("DEATHKNIGHT", 49206, 180, "offensive", { talent = true, active = 30 })     -- Summon Gargoyle
add("DEATHKNIGHT", 42650, 600, "offensive")                                     -- Army of the Dead
add("DEATHKNIGHT", 49576, 35, "utility")                                        -- Death Grip
add("DEATHKNIGHT", 48982, 30, "defensive", { talent = true })                   -- Rune Tap
add("DEATHKNIGHT", 48743, 120, "defensive")                                     -- Death Pact
add("DEATHKNIGHT", 49203, 60, "cc", { talent = true })                          -- Hungering Cold
add("DEATHKNIGHT", 47481, 60, "cc")                                             -- Gnaw (ghoul)
add("DEATHKNIGHT", 47568, 300, "offensive")                                     -- Empower Rune Weapon

-- DRUID
add("DRUID", 16979, 15, "interrupt", { talent = true, ids = { 16979, 49376 } }) -- Feral Charge
add("DRUID", 22812, 60, "defensive", { active = 12 })                           -- Barkskin
add("DRUID", 61336, 180, "defensive", { talent = true, active = 20 })           -- Survival Instincts
add("DRUID", 22842, 180, "defensive", { active = 10 })                          -- Frenzied Regeneration
add("DRUID", 29166, 180, "heal", { active = 10 })                               -- Innervate
add("DRUID", 48447, 480, "heal", { ids = { 740, 8918, 9862, 9863, 26983, 48446, 48447 }, active = 8 }) -- Tranquility
add("DRUID", 8983, 60, "cc", { ids = { 5211, 6798, 8983 } })                    -- Bash
add("DRUID", 17116, 180, "heal", { talent = true })                             -- Nature's Swiftness
add("DRUID", 50334, 180, "offensive", { talent = true, active = 15 })           -- Berserk
add("DRUID", 53201, 90, "offensive", { talent = true, ids = { 48505, 53199, 53200, 53201 } }) -- Starfall
add("DRUID", 33831, 180, "offensive", { talent = true })                        -- Force of Nature
add("DRUID", 53312, 60, "utility", { ids = { 16689, 16810, 16811, 16812, 16813, 17329, 27009, 53312 } }) -- Nature's Grasp
add("DRUID", 50516, 20, "cc", { talent = true, ids = { 50516, 53223, 53225, 53226, 61384 } }) -- Typhoon
add("DRUID", 33786, 0, "cc", { usage = true })                                  -- Cyclone (no cooldown; shown as used)
add("DRUID", 1850, 180, "utility", { ids = { 1850, 9821 } })                    -- Dash
add("DRUID", 22570, 10, "cc", { ids = { 22570, 49802 } })                       -- Maim

-- HUNTER
add("HUNTER", 34490, 20, "interrupt", { talent = true })                        -- Silencing Shot
add("HUNTER", 19263, 90, "defensive", { active = 5 })                           -- Deterrence
add("HUNTER", 5384, 30, "defensive")                                            -- Feign Death
add("HUNTER", 53271, 60, "utility")                                             -- Master's Call
add("HUNTER", 23989, 180, "utility", { talent = true })                         -- Readiness
add("HUNTER", 14311, 30, "cc", { ids = { 1499, 14310, 14311, 60192 } })         -- Freezing Trap / Arrow
add("HUNTER", 19503, 30, "cc", { talent = true })                               -- Scatter Shot
add("HUNTER", 3045, 300, "offensive", { active = 15 })                          -- Rapid Fire
add("HUNTER", 19574, 120, "offensive", { talent = true, active = 18 })          -- Bestial Wrath
add("HUNTER", 49012, 60, "cc", { talent = true, ids = { 19386, 24132, 24133, 27068, 49011, 49012 } }) -- Wyvern Sting
add("HUNTER", 19577, 60, "cc", { talent = true })                               -- Intimidation
add("HUNTER", 781, 25, "utility")                                               -- Disengage
add("HUNTER", 13809, 30, "cc")                                                  -- Frost Trap
add("HUNTER", 34477, 30, "utility")                                             -- Misdirection

-- MAGE
add("MAGE", 2139, 24, "interrupt")                                              -- Counterspell
add("MAGE", 45438, 300, "defensive", { active = 10 })                           -- Ice Block
add("MAGE", 66, 180, "defensive")                                               -- Invisibility
add("MAGE", 12051, 240, "heal")                                                 -- Evocation
add("MAGE", 11958, 480, "utility", { talent = true })                           -- Cold Snap
add("MAGE", 44572, 30, "cc", { talent = true })                                 -- Deep Freeze
add("MAGE", 42950, 20, "cc", { talent = true, ids = { 31661, 33041, 33042, 33043, 42949, 42950 } }) -- Dragon's Breath
add("MAGE", 12472, 180, "offensive", { talent = true, active = 20 })            -- Icy Veins
add("MAGE", 12042, 120, "offensive", { talent = true, active = 15 })            -- Arcane Power
add("MAGE", 11129, 120, "offensive", { talent = true })                         -- Combustion
add("MAGE", 55342, 180, "offensive", { active = 30 })                           -- Mirror Image
add("MAGE", 42917, 25, "cc", { ids = { 122, 865, 6131, 10230, 27088, 42917 } }) -- Frost Nova
add("MAGE", 12043, 120, "utility", { talent = true })                           -- Presence of Mind
add("MAGE", 1953, 15, "utility")                                                -- Blink
add("MAGE", 11426, 30, "defensive", { talent = true, ids = { 11426, 13031, 13032, 13033, 27134, 33405, 43038, 43039 } }) -- Ice Barrier
add("MAGE", 31687, 180, "offensive", { talent = true, active = 45 })            -- Summon Water Elemental
add("MAGE", 11113, 30, "cc", { talent = true, ids = { 11113, 13018, 13019, 13020, 13021, 27133, 33933, 42944, 42945 } }) -- Blast Wave

-- PRIEST
add("PRIEST", 15487, 45, "interrupt", { talent = true })                        -- Silence
add("PRIEST", 33206, 180, "external", { talent = true, active = 8 })            -- Pain Suppression
add("PRIEST", 47788, 180, "external", { talent = true, active = 10 })           -- Guardian Spirit
add("PRIEST", 47585, 120, "defensive", { talent = true, active = 6 })           -- Dispersion
add("PRIEST", 48173, 120, "defensive", { talent = true, ids = { 19236, 19238, 19240, 19241, 19242, 19243, 25437, 48172, 48173 } }) -- Desperate Prayer
add("PRIEST", 64843, 480, "heal", { active = 8 })                               -- Divine Hymn
add("PRIEST", 64901, 360, "heal", { active = 8 })                               -- Hymn of Hope
add("PRIEST", 6346, 180, "utility")                                             -- Fear Ward
add("PRIEST", 34433, 300, "offensive")                                          -- Shadowfiend
add("PRIEST", 10890, 30, "cc", { ids = { 8122, 8124, 10888, 10890 } })          -- Psychic Scream
add("PRIEST", 64044, 120, "cc", { talent = true })                              -- Psychic Horror
add("PRIEST", 10060, 120, "offensive", { talent = true, active = 15 })          -- Power Infusion
add("PRIEST", 14751, 180, "heal", { talent = true })                            -- Inner Focus
add("PRIEST", 47540, 12, "heal", { talent = true, ids = { 47540, 53005, 53006, 53007 } }) -- Penance
add("PRIEST", 724, 180, "heal", { talent = true, ids = { 724, 27870, 27871, 28275, 48086, 48087 } }) -- Lightwell

-- ROGUE
add("ROGUE", 1766, 10, "interrupt", { ids = { 1766, 1767, 1768, 1769, 38768 } }) -- Kick
add("ROGUE", 31224, 90, "defensive", { active = 5 })                            -- Cloak of Shadows
add("ROGUE", 26669, 180, "defensive", { ids = { 5277, 26669 }, active = 15 })   -- Evasion
add("ROGUE", 26889, 180, "defensive", { ids = { 1856, 1857, 26889 } })          -- Vanish
add("ROGUE", 14185, 480, "utility", { talent = true })                          -- Preparation
add("ROGUE", 2094, 180, "cc")                                                   -- Blind
add("ROGUE", 8643, 20, "cc", { ids = { 408, 8643 } })                           -- Kidney Shot
add("ROGUE", 13750, 180, "offensive", { talent = true, active = 15 })           -- Adrenaline Rush
add("ROGUE", 51690, 120, "offensive", { talent = true })                        -- Killing Spree
add("ROGUE", 36554, 30, "utility", { talent = true })                           -- Shadowstep
add("ROGUE", 51722, 60, "cc")                                                   -- Dismantle
add("ROGUE", 11305, 180, "utility", { ids = { 2983, 8696, 11305 } })            -- Sprint
add("ROGUE", 1776, 10, "cc")                                                    -- Gouge
add("ROGUE", 51713, 60, "offensive", { talent = true, active = 6 })             -- Shadow Dance
add("ROGUE", 14177, 180, "offensive", { talent = true })                        -- Cold Blood
add("ROGUE", 1833, 0, "cc", { usage = true })                                   -- Cheap Shot (no cooldown, shown as usage)

-- SHAMAN
add("SHAMAN", 57994, 6, "interrupt")                                            -- Wind Shear
add("SHAMAN", 30823, 60, "defensive", { talent = true, active = 15 })           -- Shamanistic Rage
add("SHAMAN", 2825, 300, "offensive", { active = 40 })                          -- Bloodlust
add("SHAMAN", 32182, 300, "offensive", { active = 40 })                         -- Heroism
add("SHAMAN", 16190, 300, "heal", { talent = true, active = 12 })               -- Mana Tide Totem
add("SHAMAN", 16188, 180, "heal", { talent = true })                            -- Nature's Swiftness
add("SHAMAN", 8177, 15, "defensive")                                            -- Grounding Totem
add("SHAMAN", 51514, 45, "cc")                                                  -- Hex
add("SHAMAN", 59159, 45, "cc", { talent = true, ids = { 51490, 59156, 59158, 59159 } }) -- Thunderstorm
add("SHAMAN", 2894, 600, "offensive")                                           -- Fire Elemental Totem
add("SHAMAN", 51533, 180, "offensive", { talent = true, active = 45 })          -- Feral Spirit
add("SHAMAN", 16166, 180, "offensive", { talent = true })                       -- Elemental Mastery
add("SHAMAN", 8143, 0, "utility", { usage = true })                            -- Tremor Totem (no cooldown; shown as used)
add("SHAMAN", 61295, 6, "heal", { talent = true, ids = { 61295, 61299, 61300, 61301 } }) -- Riptide

-- WARLOCK
add("WARLOCK", 19647, 24, "interrupt", { ids = { 19244, 19647 } })              -- Spell Lock (Felhunter)
add("WARLOCK", 47860, 120, "cc", { ids = { 6789, 17925, 17926, 27223, 47859, 47860 } }) -- Death Coil
add("WARLOCK", 17928, 40, "cc", { ids = { 5484, 17928 } })                      -- Howl of Terror
add("WARLOCK", 47847, 20, "cc", { talent = true, ids = { 30283, 30413, 30414, 47846, 47847 } }) -- Shadowfury
add("WARLOCK", 48020, 30, "utility", { talent = true })                         -- Demonic Circle: Teleport
add("WARLOCK", 47241, 180, "offensive", { talent = true, active = 30 })         -- Metamorphosis
add("WARLOCK", 47891, 30, "defensive", { ids = { 6229, 11739, 11740, 28610, 47890, 47891 }, active = 30 }) -- Shadow Ward
add("WARLOCK", 18708, 180, "utility", { talent = true })                        -- Fel Domination
add("WARLOCK", 19505, 8, "utility", { ids = { 19505, 19731, 19734, 19736, 27276, 27277, 48011 } }) -- Devour Magic
add("WARLOCK", 1122, 600, "offensive", { active = 60 })                         -- Inferno

-- Spells that reset other cooldowns
ns.CooldownResets = {
	[11958] = { 45438, 12472, 44572, 42917, 11426, 31687 },                -- Cold Snap
	[14185] = { 26669, 26889, 36554, 11305, 31224, 2094, 14177 },           -- Preparation
	[23989] = { 19263, 34477, 5384, 34490, 53271, 14311, 19503, 3045, 49012, 19577, 781 }, -- Readiness
}

---------------------------------------------------------------------------
-- indexes
---------------------------------------------------------------------------
ns.CooldownIndex = {}   -- spell name -> list of entries
ns.CooldownByKey = {}   -- entry key (class..id) -> entry

local catPrio = {}
for _, c in ipairs(ns.CDCategories) do catPrio[c.key] = c.prio end

function ns:BuildCooldownIndex()
	local idx = {}
	for _, e in ipairs(DB) do
		e.key = e.class .. ":" .. e.id
		e.prio = e.prio or catPrio[e.cat] or 9
		local name, _, icon = GetSpellInfo(e.id)
		e.name, e.icon = name, icon
		ns.CooldownByKey[e.key] = e
		for _, id in ipairs(e.ids or { e.id }) do
			local n = GetSpellInfo(id)
			if n then
				idx[n] = idx[n] or {}
				idx[n][#idx[n] + 1] = e
			end
		end
	end
	ns.CooldownIndex = idx
	-- reset lists by name
	ns.CooldownResetByName = {}
	for id, list in pairs(ns.CooldownResets) do
		local n = GetSpellInfo(id)
		if n then
			local names = {}
			for _, rid in ipairs(list) do
				local rn = GetSpellInfo(rid)
				if rn then names[rn] = true end
			end
			ns.CooldownResetByName[n] = names
		end
	end
end
